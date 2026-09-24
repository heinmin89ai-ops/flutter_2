import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../data/backup_service.dart';

final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);

/// Whether the signed-in user may run a backup or restore.
final Provider<bool> canManageBackupProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.manageBackup)),
);

/// The directory backups are exported to / imported from.
///
/// The app-documents `Backups/` folder, created on demand. Kept a `Future`
/// provider rather than baked into [BackupService] so the service stays free of
/// `path_provider` and stays unit-testable against a temp directory, while the
/// screen resolves the real location.
final FutureProvider<Directory> backupDirectoryProvider =
    FutureProvider<Directory>((ref) async {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/Backups');
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      return dir;
    });

/// The signed-in user, for attributing a backup/restore action to.
final Provider<int?> currentBackupUserIdProvider = Provider<int?>(
  (ref) => ref.watch(authProvider)?.id,
);

/// A production `reopen` callback for [BackupService.restoreIntoPlace].
///
/// After the service has swapped the file on disk it closes the old handle and
/// calls this to get a new one. Rather than building an orphan `AppDatabase()`
/// that nothing else knows about, the callback invalidates [appDatabaseProvider]
/// and reads it back: the provider re-runs its own create, so the fresh handle is
/// the exact instance every repository will see *and* it carries the provider's
/// `ref.onDispose(db.close)` wiring. `invalidate`/`read` are synchronous and
/// public on [ProviderContainer], so this works from a plain callback.
///
/// The screen obtains the container with `ProviderScope.containerOf(context)`.
/// Kept here rather than in the service so the service stays free of Riverpod and
/// of drift_flutter's file layout.
AppDatabase Function() reopenFactory(ProviderContainer container) {
  return () {
    container.invalidate(appDatabaseProvider);
    return container.read(appDatabaseProvider);
  };
}
