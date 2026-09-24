import 'package:drift/drift.dart';

/// `license_config` — device activation state (Module 1).
///
/// **Singleton table.** Exactly one row is permitted and its [id] is always 1.
/// Enforced twice on purpose:
///
/// 1. A SQL `CHECK (id = 1)` on the primary key column, so a bad write fails in
///    the database rather than silently creating a second row. The column stays
///    a plain `NOT NULL` column and [primaryKey] declares it, because repeating
///    `PRIMARY KEY` inside the column constraint makes SQLite emit two primary
///    keys and refuse the `CREATE TABLE`.
/// 2. `insertOrReplace` with an explicit `id: 1` in `LicenseRepository`.
///
/// The double layer matters because the boot flow reads this table before any
/// Dart-side logic has decided anything; two rows would make the licence check
/// non-deterministic across restarts.
class LicenseConfig extends Table {
  IntColumn get id => integer().customConstraint('NOT NULL CHECK (id = 1)')();

  /// Raw vendor-issued key, kept verbatim so it can be re-submitted when the
  /// shop moves to a new device.
  ///
  /// **This column is the source of truth.** Since Phase 2 the boot flow
  /// re-verifies it (signature and expiry) on every start, so the value below is
  /// never trusted on its own.
  TextColumn get activationKey => text().named('activation_key')();

  /// JSON string of module permissions, e.g.
  /// `{"retail":true,"wholesale":true}`.
  ///
  /// Display cache only — derived from [activationKey] at activation and never
  /// read to make an access decision. A hand-edited value here grants nothing,
  /// which is the tamper path Phase 1 left open.
  TextColumn get featuresData => text().named('features_data')();

  DateTimeColumn get activatedAt => dateTime().named('activated_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'license_config';
}
