import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Data access for `license_config`.
///
/// Owns the singleton write path so no caller can accidentally insert a second
/// row; the SQL `CHECK (id = 1)` is the backstop.
class LicenseRepository {
  const LicenseRepository(this._db);

  /// The only permitted primary key for this table.
  static const int singletonId = 1;

  final AppDatabase _db;

  /// The stored licence, or `null` when the device has never been activated.
  Future<LicenseConfigData?> current() {
    return (_db.select(_db.licenseConfig)..limit(1)).getSingleOrNull();
  }

  /// Activate or re-activate this device with [activationKey].
  ///
  /// [featuresData] is the raw JSON the vendor key decoded to; it is stored
  /// verbatim so a later decode can be re-run without the original key.
  ///
  /// `insertOrReplace` rather than update-then-insert: on a re-activation the
  /// row already exists and `activated_at` must move to now, since a shop that
  /// reinstalls has not "kept" the licence continuously.
  Future<void> activate({
    required String activationKey,
    required String featuresData,
  }) {
    final now = DateTime.now();
    return _db
        .into(_db.licenseConfig)
        .insert(
          LicenseConfigCompanion.insert(
            id: const Value(singletonId),
            activationKey: activationKey,
            featuresData: featuresData,
            activatedAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Replace the permission payload after an offline renewal, keeping the
  /// original [LicenseConfigData.activatedAt] intact.
  Future<void> updateFeatures({required String featuresData}) async {
    final existing = await current();
    if (existing == null) {
      throw StateError('Cannot update features before activation.');
    }
    await (_db.update(
      _db.licenseConfig,
    )..where((t) => t.id.equals(singletonId))).write(
      LicenseConfigCompanion(
        featuresData: Value(featuresData),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Stream for any UI that must react to a licence being revoked or renewed
  /// while the app is running.
  Stream<LicenseConfigData?> watch() {
    return (_db.select(_db.licenseConfig)..limit(1)).watchSingleOrNull();
  }
}
