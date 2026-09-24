import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/license_config.dart';
import 'tables/users.dart';

part 'app_database.g.dart';

/// Current schema version.
///
/// Bump by exactly one per phase and add a matching `up` step in
/// [migration]. Never rewrite an already-released step: a device that skips a
/// migration cannot be repaired without a Phase 7 cloud restore, which does not
/// exist yet.
const int kSchemaVersion = 1;

/// Offline-first pharmacy database.
///
/// Phase 1 registers only [Users] and [LicenseConfig]. Remaining modules add
/// their tables in later phases and bump [kSchemaVersion].
@DriftDatabase(tables: [Users, LicenseConfig])
class AppDatabase extends _$AppDatabase {
  /// Production constructor. Opens `pharmacy_pos` in the app-supported
  /// directory via drift_flutter.
  AppDatabase() : super(driftDatabase(name: 'pharmacy_pos'));

  /// Test-only constructor so an in-memory executor can be injected.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Phase 2+: `if (from < 2) { await m.createTable(medicines); ... }`
      //
      // Fail loudly rather than letting a released build silently boot
      // against a stale schema.
      if (from != to) {
        throw UnsupportedError(
          'No migration path defined for schema $from -> $to. '
          'Add the missing step to AppDatabase.migration.onUpgrade.',
        );
      }
    },
    beforeOpen: (details) async {
      await _applyPragmas();
    },
  );

  /// Per-connection SQLite tuning.
  ///
  /// Runs on **every** open, not only during migrations, because SQLite applies
  /// `foreign_keys` per connection. Setting it once in `onCreate` would leave it
  /// OFF for every later launch, and the Phase 3/4/6 `ON DELETE CASCADE` clauses
  /// would then do nothing at all.
  Future<void> _applyPragmas() async {
    // Referential integrity for all later phases.
    await customStatement('PRAGMA foreign_keys = ON');
    // Write-Ahead Logging so POS inserts do not block dashboard reads.
    await customStatement('PRAGMA journal_mode = WAL');
    // WAL + NORMAL is the accepted durability/speed trade for a till on cheap
    // Android flash; FULL measurably slows sale commit.
    await customStatement('PRAGMA synchronous = NORMAL');
  }
}
