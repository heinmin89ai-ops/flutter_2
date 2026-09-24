import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Schema 1 → 2 upgrade, against a real on-disk database.
///
/// Every other test in this suite starts from `NativeDatabase.memory()`, which
/// only ever exercises `onCreate`. A migration bug is invisible there and
/// catastrophic in the field: the licence row, the admin account and its stored
/// PIN hash have to survive the update, or the till locks itself on the morning of
/// an app update with no network to call for help.
void main() {
  late Directory tempDir;
  late String path;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pharmacy_migration');
    path = '${tempDir.path}/pharmacy_pos.db';
    final raw = sqlite3.open(path);
    raw.execute(_phaseOneSchema);
    // A licence and one admin: the two rows a shop cannot rebuild offline.
    raw.execute(
      'INSERT INTO users (id, username, pin_hash, role, is_active, created_at) '
      "VALUES (1, 'owner', 'salt\$hash', 'admin', 1, 0)",
    );
    raw.execute(
      'INSERT INTO license_config (id, activation_key, features_data, '
      "activated_at, updated_at) VALUES (1, 'key-one', '{\"pos\":true}', 0, 0)",
    );
    raw.close();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  /// Open [path] the way the app does, so the migration runs.
  AppDatabase open() =>
      AppDatabase.forTesting(NativeDatabase.opened(sqlite3.open(path)));

  Future<List<String>> names(AppDatabase db, String type) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = '$type' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return rows.map((row) => row.read<String>('name')).toList();
  }

  test('the fixture is a genuine version-1 database', () {
    final raw = sqlite3.open(path);
    final version = raw
        .prepare('PRAGMA user_version')
        .select()
        .single
        .values
        .single;
    final tables = raw
        .prepare(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .select()
        .map((row) => row['name'])
        .toList();
    raw.close();

    expect(version, 1);
    expect(tables, unorderedEquals(['license_config', 'users']));
  });

  group('upgrade to version 2', () {
    late AppDatabase db;

    setUp(() async {
      db = open();
      // The first query is what forces the upgrade: `schemaVersion` reports 2, the
      // file reports 1, and drift runs onUpgrade between them.
      await db.customSelect('SELECT 1 AS one').get();
    });

    tearDown(() => db.close());

    test('adds every Phase 3 table', () async {
      expect(
        await names(db, 'table'),
        containsAll([
          'medicines',
          'unit_conversions',
          'medicine_batches',
          'suppliers',
          'purchases',
          'purchase_items',
        ]),
      );
    });

    test('stamps user_version so the next launch skips this step', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.read<int>('user_version'), kSchemaVersion);
    });

    test('keeps the licence and the admin account', () async {
      final user = await db.select(db.users).getSingle();
      expect(user.username, 'owner');
      expect(user.role, UserRole.admin);
      // Byte-identical hash: a migrated device must still accept the old PIN.
      expect(user.pinHash, r'salt$hash');
      expect(user.isActive, isTrue);

      final licence = await db.select(db.licenseConfig).getSingle();
      expect(licence.activationKey, 'key-one');
    });

    test(
      'the new tables are writable and the old ones still accept rows',
      () async {
        final medicineId = await db
            .into(db.medicines)
            .insert(MedicinesCompanion.insert(tradeName: 'Paracetamol 500mg'));
        final supplierId = await db
            .into(db.suppliers)
            .insert(SuppliersCompanion.insert(name: 'City Pharma'));
        await db
            .into(db.purchases)
            .insert(
              PurchasesCompanion.insert(
                supplierId: supplierId,
                totalAmount: 1000,
              ),
            );
        expect(
          (await db.select(db.medicines).getSingle()).tradeName,
          'Paracetamol 500mg',
        );
        expect(medicineId, greaterThan(0));

        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                username: 'cashier1',
                pinHash: r'salt$2$hash',
                role: UserRole.cashier,
                createdAt: DateTime(2026, 2, 2),
              ),
            );
        expect(await db.select(db.users).get(), hasLength(2));
      },
    );

    test('foreign keys are enforced on the upgraded connection', () async {
      // `PRAGMA foreign_keys` is per connection and is applied in `beforeOpen`,
      // which runs for a migrated database exactly as it does for a fresh one.
      await expectLater(
        db
            .into(db.purchases)
            .insert(
              PurchasesCompanion.insert(supplierId: 999, totalAmount: 100),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('the Phase 3 indexes exist, including the unique one', () async {
      expect(
        await names(db, 'index'),
        containsAll([
          'idx_medicines_trade_name',
          'idx_unit_conversions_per_medicine',
          'idx_batches_medicine_expiry',
          'idx_purchase_items_purchase',
        ]),
      );
    });

    test('a migrated database can carry a real stock-in', () async {
      // End to end on the upgraded schema: the repository must not notice it is
      // talking to a file that started life at version 1.
      final medicineId = await db
          .into(db.medicines)
          .insert(MedicinesCompanion.insert(tradeName: 'Amoxicillin 250mg'));
      final unitId = await db
          .into(db.unitConversions)
          .insert(
            UnitConversionsCompanion.insert(
              medicineId: medicineId,
              unitName: 'Capsule',
              retailPrice: 300,
            ),
          );
      final supplierId = await db
          .into(db.suppliers)
          .insert(SuppliersCompanion.insert(name: 'City Pharma'));
      await db
          .into(db.medicineBatches)
          .insert(
            MedicineBatchesCompanion.insert(
              medicineId: medicineId,
              batchNumber: 'A-204',
              expiryDate: DateTime(2027, 12, 1),
              qtyInSmallestUnit: 100,
              costPrice: 150,
              purchaseItemId: Value(unitId),
            ),
          );

      final total = db.medicineBatches.qtyInSmallestUnit.sum();
      final row = await (db.selectOnly(
        db.medicineBatches,
      )..addColumns([total])).getSingle();
      expect(row.read(total), 100);
      expect(await db.select(db.suppliers).get(), hasLength(1));
      expect(supplierId, greaterThan(0));
      expect((await db.select(db.users).getSingle()).username, 'owner');
    });
  });

  test(
    're-opening an already-migrated file does not repeat the step',
    () async {
      final first = open();
      await first.customSelect('SELECT 1 AS one').get();
      await first.close();

      final second = open();
      expect(
        await names(second, 'table'),
        containsAll(['medicines', 'suppliers', 'purchase_items']),
      );
      // One user row, not two: nothing re-ran or duplicated the migration.
      expect(await second.select(second.users).get(), hasLength(1));
      await second.close();
    },
  );

  test('a version-1 file with a second licence row cannot be smuggled through', () async {
    // Guards the migration ordering: `license_config`'s CHECK constraint is not
    // rewritten by the upgrade, so the singleton rule still holds afterwards.
    final db = open();
    await db.customSelect('SELECT 1 AS one').get();
    await expectLater(
      db
          .into(db.licenseConfig)
          .insert(
            LicenseConfigCompanion.insert(
              id: const Value(2),
              activationKey: 'key-two',
              featuresData: '{}',
              activatedAt: DateTime(2026, 1, 1),
              updatedAt: DateTime(2026, 1, 1),
            ),
          ),
      throwsA(isA<Exception>()),
    );
    await db.close();
  });
}

/// Phase 1's schema as released: two tables, `user_version = 1`.
///
/// Hand-written rather than generated by running the old build, so this file keeps
/// testing the real upgrade path even after the Dart table definitions evolve —
/// which is the point. It represents the bytes on a customer's device, not what
/// the current code would produce.
const String _phaseOneSchema = '''
CREATE TABLE users (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  pin_hash TEXT NOT NULL,
  role TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL
);
CREATE TABLE license_config (
  id INTEGER NOT NULL CHECK (id = 1),
  activation_key TEXT NOT NULL,
  features_data TEXT NOT NULL,
  activated_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (id)
);
PRAGMA user_version = 1;
''';
