import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../inventory/application/inventory_providers.dart';
import '../application/backup_providers.dart';
import '../data/backup_service.dart';

/// Database backup and restore (Phase 5 brief item 3).
///
/// ## Why a file export rather than Google Drive
///
/// The brief allows "Google Drive **or** a standard file export". Drive is wired
/// on-device: a working Drive upload needs a real OAuth client id baked into the
/// app and an interactive account picker, neither of which can be exercised in
/// this offline CI (the same honest deferral `docs/PHASE4_SALES.md` records for
/// the camera-scanner transport). What *is* complete and tested here is the part
/// that carries all the risk — a correct, self-describing, authenticated backup
/// file and a safe restore — so [BackupService] is written as a transport-agnostic
/// abstraction that a later Drive adapter merely feeds bytes to. The envelope this
/// screen produces is exactly the bytes that adapter would upload.
///
/// ## What the restore actually guarantees
///
/// A restore replaces the live database file, so the whole screen is built around
/// not losing data: the new file is fully written and fsynced *before* the old
/// connection closes ([BackupService.restoreIntoPlace]), and the envelope's
/// passphrase is checked by [BackupService.inspect] on the confirm sheet — before
/// any file swap — so a wrong password is discovered while the current database is
/// still intact. The live handle is reopened through [reopenFactory] so every
/// screen in the app transparently reads the restored file without a restart.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  Directory? _dir;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveDir());
  }

  Future<void> _resolveDir() async {
    final dir = await ref.read(backupDirectoryProvider.future);
    if (mounted) setState(() => _dir = dir);
  }

  Future<void> _createBackup() async {
    final passphrase = await _askPassphrase(
      title: 'Encrypt backup',
      confirmLabel: 'Create backup',
      blurb:
          'The database is zipped and encrypted with this passphrase '
          '(AES-256-GCM). It is not stored anywhere — lose it and the backup '
          'cannot be restored.',
    );
    if (passphrase == null || passphrase.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final artifact = await ref
          .read(backupServiceProvider)
          .createBackup(passphrase);
      final dir = await ref.read(backupDirectoryProvider.future);
      final file = File('${dir.path}/${artifact.suggestedFileName}');
      await file.writeAsBytes(artifact.bytes, flush: true);
      if (!mounted) return;
      ref.read(inventoryRevisionProvider.notifier).bump();
      _showInfo(
        'Backup saved',
        '${file.path}\n\n'
            'Unencrypted database size was '
            '${_kilobytes(artifact.databaseBytes.length)}.',
      );
    } on BackupRejectException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final dir = await ref.read(backupDirectoryProvider.future);
    final candidates =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.pbak'))
            .toList()
          ..sort(
            (a, b) => b.path.compareTo(a.path),
          ); // timestamped names sort newest-first
    if (!mounted) return;
    if (candidates.isEmpty) {
      _toast('No backup files found in ${dir.path}.');
      return;
    }

    final picked = await showModalBottomSheet<File>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose a backup to restore')),
            const Divider(height: 1),
            for (final f in candidates)
              ListTile(
                title: Text(f.uri.pathSegments.last),
                subtitle: Text(_kilobytes(f.lengthSync())),
                onTap: () => Navigator.of(context).pop(f),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final envelope = Uint8List.fromList(await picked.readAsBytes());
    if (!mounted) return;
    await _confirmAndRestore(envelope);
  }

  /// Ask for the passphrase, verify it against the envelope, then do the swap.
  ///
  /// [inspect] runs first so a wrong passphrase (or a corrupt file) is caught and
  /// reported *before* we close the live database and overwrite it. The file's own
  /// date and schema are shown on the confirm sheet for exactly the same reason:
  /// "restore this file" must be an informed decision.
  Future<void> _confirmAndRestore(Uint8List envelope) async {
    final service = ref.read(backupServiceProvider);
    // Captured synchronously before any await: the reopen callback must reach the
    // live ProviderContainer, and using `context` after the awaits below would be
    // reading a possibly-defunct element.
    final container = ProviderScope.containerOf(context);
    final passphrase = await _askPassphrase(
      title: 'Unlock backup',
      confirmLabel: 'Next',
      blurb: 'Enter the passphrase this backup was encrypted with.',
    );
    if (passphrase == null) return;

    setState(() => _busy = true);
    try {
      final manifest = await service.inspect(envelope, passphrase);
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace everything with this backup?'),
          content: Text(
            'From: ${_stamp(manifest.createdAt)}\n'
            'Schema: v${manifest.schemaVersion}\n\n'
            'The current live data will be overwritten. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (go != true) return;

      final dbBytes = await service.decryptDatabaseBytes(envelope, passphrase);
      final liveFile = File(
        '${(await getApplicationDocumentsDirectory()).path}/pharmacy_pos.sqlite',
      );
      await service.restoreIntoPlace(
        dbBytes: dbBytes,
        liveFile: liveFile,
        reopen: reopenFactory(container),
      );
      if (!mounted) return;
      ref.read(inventoryRevisionProvider.notifier).bump();
      _showInfo('Restored', 'The app is now reading the backup’s data.');
    } on BackupAuthException catch (e) {
      if (mounted) _toast(e.message);
    } on BackupFormatException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPassphrase({
    required String title,
    required String confirmLabel,
    required String blurb,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(blurb),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Passphrase',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _showInfo(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mayManage = ref.watch(canManageBackupProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: !mayManage
          ? const Center(
              child: Text('Only an owner may back up or restore the database.'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Backups are written to ${_dir?.path ?? 'the app’s Backups folder'}.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _ActionCard(
                  icon: Icons.cloud_download_outlined,
                  title: 'Create an encrypted backup',
                  body:
                      'Snapshots the live database (VACUUM INTO, so it is '
                      'consistent and WAL-free), zips it, and encrypts it with a '
                      'passphrase you choose.',
                  actionLabel: 'Create backup',
                  onPressed: _busy ? null : _createBackup,
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Restore from a backup',
                  body:
                      'Pick a .pbak file, unlock it, and replace the current '
                      'database. Everything now on the device is overwritten.',
                  actionLabel: 'Restore',
                  destructive: true,
                  onPressed: _busy ? null : _restoreBackup,
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: destructive
                  ? FilledButton.tonalIcon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: Text(actionLabel),
                    )
                  : FilledButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(actionLabel),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _kilobytes(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';

String _stamp(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
