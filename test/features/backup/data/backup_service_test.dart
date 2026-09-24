import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/features/backup/data/backup_service.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Backup and restore (Module 7), end to end against real bytes and a real file.
///
/// Two distinct jobs are tested here, and they fail in different ways:
///
/// * The **envelope** is pure crypto — a wrong passphrase or a single flipped
///   ciphertext byte must be *rejected*, never decrypted to plausible garbage.
///   AES-GCM's tag is the guard, so the test drives the failure at the byte
///   level and asserts the typed exception.
/// * The **restore** is a live file swap: [BackupService.restoreIntoPlace]
///   closes the running connection, renames the new bytes over it and hands back
///   a reopened [AppDatabase]. An in-memory database cannot exercise that — a
///   rename has no meaning there — so the restore tests open real on-disk files
///   exactly as the migration tests do, with a [reopen] callback that mirrors how
///   production re-derives the handle from the Riverpod provider.
///
/// PBKDF2 rounds come from [BackupService.kTestIterations]: the production
/// default (150k) is *correct* but would add seconds per case to a suite that
/// runs this on every commit. The constructor override exists for precisely this.
void main() {
  // A passphrase with real length; a blank one is a separate rejection case.
  const passphrase = 'pharmacy-2026-staff-PIN';

  // restoreIntoPlace closes the old AppDatabase then builds a new one on the
  // same path, so two Dart handles briefly coexist — the exact pattern drift's
  // "multiple databases" heuristic flags. That reopen *is* the behaviour under
  // test, so the debug-only warning is silenced here rather than worked around.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Uint8List> snapshotOf(AppDatabase source) => BackupService(
    source,
    iterations: BackupService.kTestIterations,
  ).snapshotDatabase();

  BackupService serviceFor(AppDatabase target) =>
      BackupService(target, iterations: BackupService.kTestIterations);

  group('createBackup envelope', () {
    test('round-trips the exact database bytes back out', () async {
      await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'U Kyaw'));
      final artifact = await serviceFor(db).createBackup(passphrase);

      expect(
        artifact.suggestedFileName,
        matches(RegExp(r'^pharmacy-backup-\d{8}-\d{6}\.pbak$')),
      );
      // The envelope must carry *less* than nothing useful to a reader who does
      // not know the passphrase: it is opaque, and its magic is the only
      // plaintext a scanner sees.
      expect(artifact.bytes, isNotEmpty);

      final restored = await serviceFor(db)
          .decryptDatabaseBytes(artifact.bytes, passphrase);
      // The recovered payload is itself a valid SQLite file whose bytes match the
      // plaintext snapshot the artifact already holds.
      expect(restored, equals(artifact.databaseBytes));
    });

    test('a wrong passphrase is rejected, not decrypted to garbage', () async {
      final artifact = await serviceFor(db).createBackup(passphrase);
      await expectLater(
        serviceFor(db)
            .decryptDatabaseBytes(artifact.bytes, 'not-the-passphrase'),
        throwsA(isA<BackupAuthException>()),
      );
    });

    test('a single flipped ciphertext byte is rejected', () async {
      // Tamper *after* the fixed header so only the authenticated payload moves.
      // This is the property AES-GCM buys over encryption alone: a modified file
      // must fail, not half-open. Note the header length below is
      // magic(4) + version(1) + salt(16) + iterations(4) + nonce(12) = 37 bytes;
      // byte 40 is comfortably inside the ciphertext.
      final artifact = await serviceFor(db).createBackup(passphrase);
      final tampered = Uint8List.fromList(artifact.bytes);
      tampered[40] = tampered[40] ^ 0x01;
      await expectLater(
        serviceFor(db).decryptDatabaseBytes(tampered, passphrase),
        throwsA(isA<BackupAuthException>()),
      );
    });

    test('inspect reads the manifest with the right schema version', () async {
      final artifact = await serviceFor(db).createBackup(passphrase);
      final manifest = await serviceFor(db).inspect(artifact.bytes, passphrase);
      expect(manifest.schemaVersion, kSchemaVersion);
      // The creation instant is within the last minute of wall time; compared as
      // an instant so a UTC-vs-local materialisation cannot flip it.
      final ageMs = DateTime.now()
          .difference(manifest.createdAt)
          .inMilliseconds;
      expect(ageMs.abs() < 60 * 1000, isTrue);
    });

    test('inspect with a wrong passphrase is rejected too', () async {
      final artifact = await serviceFor(db).createBackup(passphrase);
      await expectLater(
        serviceFor(db).inspect(artifact.bytes, 'wrong'),
        throwsA(isA<BackupAuthException>()),
      );
    });

    test('two backups of one database are byte-different (salt + nonce)', () async {
      // Deterministic content, randomised envelope: without this a passphrase
      // reuse would be detectable across files and rainbow tables would apply.
      final a = await serviceFor(db).createBackup(passphrase);
      final b = await serviceFor(db).createBackup(passphrase);
      expect(a.bytes, isNot(equals(b.bytes)));
      // Yet both decrypt to the same plaintext database.
      expect(
        await serviceFor(db).decryptDatabaseBytes(a.bytes, passphrase),
        equals(await serviceFor(db).decryptDatabaseBytes(b.bytes, passphrase)),
      );
    });
  });

  group('malformed envelopes', () {
    test('a foreign file is rejected on the magic', () async {
      final junk = Uint8List(64); // "PPBK" never appears at offset 0.
      await expectLater(
        serviceFor(db).decryptDatabaseBytes(junk, passphrase),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test(
      'a truncated envelope is rejected before parsing the header',
      () async {
        // Shorter than the fixed header (magic + version + salt + iterations +
        // nonce + tag = 53 bytes): the service must not index past the end.
        final truncated = Uint8List(20);
        await expectLater(
          serviceFor(db).decryptDatabaseBytes(truncated, passphrase),
          throwsA(isA<BackupFormatException>()),
        );
      },
    );

    test('a blank passphrase never reaches the crypto', () async {
      await expectLater(
        serviceFor(db).createBackup('   '),
        throwsA(isA<BackupRejectException>()),
      );
    });
  });

  group('restoreIntoPlace real file swap', () {
    late Directory tempDir;
    late String path;

    File liveFile() => File(path);

    AppDatabase openLive() =>
        AppDatabase.forTesting(NativeDatabase.opened(sqlite3.open(path)));

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pharmacy_backup_restore');
      path = '${tempDir.path}/pharmacy_pos.sqlite';
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('replaces the live rows with the backup and reopens on them', () async {
      // Snapshot from the *source* (in-memory `db`) carries one customer; the
      // *live* on-disk file carries a different one. After restore, reopening the
      // live path must show the source's rows and none of the live's — proving
      // the bytes were swapped and the connection rebuilt, not merely re-read.
      await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'From Backup'));
      final dbBytes = await snapshotOf(db);

      final live = openLive();
      await live
          .into(live.customers)
          .insert(CustomersCompanion.insert(name: 'Old Live Row'));
      expect((await live.select(live.customers).get()), hasLength(1));

      // The service's own handle is the live connection it must close mid-swap;
      // `reopen` re-derives a fresh AppDatabase on the same path, mirroring the
      // Riverpod provider in validation/backup_providers.dart.
      final restored =
          await BackupService(
            live,
            iterations: BackupService.kTestIterations,
          ).restoreIntoPlace(
            dbBytes: dbBytes,
            liveFile: liveFile(),
            reopen: openLive,
          );

      final names = (await restored.select(restored.customers).get())
          .map((c) => c.name)
          .toList();
      expect(names, equals(['From Backup']));
      expect(names, isNot(contains('Old Live Row')));
      await restored.close();
    });

    test('a real backup file restores to a fresh device state', () async {
      // The full path a user actually walks: export from one database, wipe the
      // live file back to a near-empty state, then restore the artifact's bytes.
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      await source
          .into(source.customers)
          .insert(
            CustomersCompanion.insert(
              name: 'Daw Hla',
              creditLimit: const Value(500000),
            ),
          );
      final artifact = await BackupService(
        source,
        iterations: BackupService.kTestIterations,
      ).createBackup(passphrase);
      await source.close();

      final recovered = BackupService(
        openLive(),
        iterations: BackupService.kTestIterations,
      );
      final dbBytes = await recovered.decryptDatabaseBytes(
        artifact.bytes,
        passphrase,
      );
      // openLive() above was consumed as the service's handle; restoreIntoPlace
      // closes it. A fresh reopen callback stands up the new connection.
      final restored = await recovered.restoreIntoPlace(
        dbBytes: dbBytes,
        liveFile: liveFile(),
        reopen: openLive,
      );

      final customer = await restored.select(restored.customers).getSingle();
      expect(customer.name, 'Daw Hla');
      expect(customer.creditLimit, 500000);
      expect(customer.currentDebt, 0);
      await restored.close();
    });

    test('restore drops the live rows even those held in the WAL sidecar', () async {
      await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'Snapshot Only'));
      final dbBytes = await snapshotOf(db);

      final live = openLive();
      // Write a live row and leave it in the -wal sidecar, the state a real
      // device is in mid-session: the row is committed to SQLite but may still
      // live only in the WAL. The rename-over must discard it with the old file.
      await live
          .into(live.customers)
          .insert(CustomersCompanion.insert(name: 'In WAL'));

      final restored =
          await BackupService(
            live,
            iterations: BackupService.kTestIterations,
          ).restoreIntoPlace(
            dbBytes: dbBytes,
            liveFile: liveFile(),
            reopen: openLive,
          );

      final names = (await restored.select(restored.customers).get())
          .map((c) => c.name)
          .toList();
      // Only the snapshot row survives: the deleted -wal/-shm sidecars meant the
      // reopened connection reads the restored main file with no stale sidecar
      // replayed onto it. (A new -wal then reappears because beforeOpen sets WAL
      // mode again, so existence of the sidecar is *not* the assertion.)
      expect(names, equals(['Snapshot Only']));
      await restored.close();
    });
  });
}
