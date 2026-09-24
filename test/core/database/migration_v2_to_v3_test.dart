import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/sales.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';
import 'package:pharmacy_pos/features/sales/data/sale_repository.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Schema 2 → 3 upgrade, against a real on-disk database.
///
/// Same reasoning as `migration_v1_to_v2_test.dart`: every other test starts from
/// `NativeDatabase.memory()`, which only ever runs `onCreate`. A till upgrading
/// from a Phase 3 build must gain the sales tables *and* their indexes, and the
/// medicine, batch, licence and staff rows already on it must survive byte for
/// byte — those batches are the stock the first sale of the day deducts from.
void main() {
  late Directory tempDir;
  late String path;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pharmacy_migration_v3');
    path = '${tempDir.path}/pharmacy_pos.db';
    final raw = sqlite3.open(path);
    raw.execute(_phaseTwoSchema);
    // The three rows a shop cannot rebuild offline: staff, licence, and the
    // batch the POS is about to sell from.
    raw.execute(
      'INSERT INTO users (id, username, pin_hash, role, is_active, created_at) '
      "VALUES (1, 'owner', 'salt\$hash', 'admin', 1, 0)",
    );
    raw.execute(
      'INSERT INTO license_config (id, activation_key, features_data, '
      "activated_at, updated_at) VALUES (1, 'key-one', '{\"pos\":true}', 0, 0)",
    );
    raw.execute(
      'INSERT INTO medicines (id, trade_name) VALUES (1, \'Paracetamol 500mg\')',
    );
    raw.execute(
      'INSERT INTO unit_conversions '
      '(id, medicine_id, unit_name, conversion_factor, retail_price) '
      'VALUES (1, 1, \'Tablet\', 1, 120)',
    );
    raw.execute(
      'INSERT INTO medicine_batches '
      '(id, medicine_id, batch_number, expiry_date, qty_in_smallest_unit, '
      'cost_price) VALUES (1, 1, \'X117\', 1893456000, 100, 90)',
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

  test('the fixture is a genuine version-2 database', () async {
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

    expect(version, 2);
    expect(
      tables,
      unorderedEquals([
        'license_config',
        'users',
        'medicines',
        'unit_conversions',
        'medicine_batches',
        'suppliers',
        'purchases',
        'purchase_items',
      ]),
    );

    // And the upgrade really does produce the current schema's table set.
    final db = open();
    await db.customSelect('SELECT 1 AS one').get();
    expect(
      await names(db, 'table'),
      unorderedEquals([
        ...tables,
        'customers',
        'sales',
        'sale_items',
        // Not `sale_batches`: the Dart class name's plural would be that, and
        // the table overrides it — this fixture asserts the real SQL name.
        'sale_batch_allocations',
        // Opening the v2 file now runs the *whole* chain to kSchemaVersion (4),
        // not just v3, so Phase 5's two tables land here too. Their own upgrade
        // is pinned by migration_v3_to_v4_test.dart; this is the table set.
        'credit_transactions',
        'expenses',
      ]),
    );
    await db.close();
  });

  group('upgrade to version 3', () {
    late AppDatabase db;

    setUp(() async {
      db = open();
      // First query forces the upgrade: `schemaVersion` reports 3, the file
      // reports 2, and drift runs onUpgrade between them.
      await db.customSelect('SELECT 1 AS one').get();
    });

    tearDown(() => db.close());

    test('adds every Phase 4 table', () async {
      expect(
        await names(db, 'table'),
        containsAll([
          'customers',
          'sales',
          'sale_items',
          'sale_batch_allocations',
        ]),
      );
    });

    test('stamps user_version so the next launch skips this step', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.read<int>('user_version'), kSchemaVersion);
    });

    test(
      'the Phase 4 indexes exist — the trap createTable alone walks into',
      () async {
        // `Migrator.createTable` does not emit `@TableIndex` entities. A
        // migration that forgot the explicit `createIndex` calls still passes
        // every insert test above; it just makes the voucher lookup and the
        // batch-recall scan do a full table walk on every upgraded till.
        expect(
          await names(db, 'index'),
          containsAll([
            'idx_customers_name',
            'idx_sales_created',
            'idx_sales_customer',
            'idx_sale_items_sale',
            'idx_sale_items_medicine',
            'idx_sale_batch_allocations_sale',
            'idx_sale_batch_allocations_batch',
          ]),
        );
      },
    );

    test('the voucher_no UNIQUE and payment_type CHECK survive', () async {
      // Two hand-written traps, both invisible unless the constraint is asserted
      // on the upgraded file rather than the fresh one.
      final userId = (await db.select(db.users).getSingle()).id;
      Future<void> insertSale(String voucher) => db
          .into(db.sales)
          .insert(
            SalesCompanion.insert(
              voucherNo: voucher,
              userId: userId,
              totalCost: 0,
              subtotal: 100,
              totalAmount: 100,
            ),
          );

      await insertSale('S-20260924-0001');
      await expectLater(
        insertSale('S-20260924-0001'),
        throwsA(isA<Exception>()),
      );

      // DEFAULT 'cash' must apply when payment_type is not supplied, and the
      // CHECK must reject a value the enum does not know.
      final row = await db.select(db.sales).getSingle();
      expect(row.paymentType, 'cash');
      await expectLater(
        db.customStatement(
          "UPDATE sales SET payment_type = 'wire' WHERE voucher_no = "
          "'S-20260924-0001'",
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('the customer credit CHECK and DEFAULT apply', () async {
      final id = await db
          .into(db.customers)
          .insert(CustomersCompanion.insert(name: 'U Kyaw'));
      final customer = await (db.select(
        db.customers,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(customer.creditLimit, 0);
      expect(customer.currentDebt, 0);
      expect(customer.isActive, isTrue);

      await expectLater(
        db.customStatement('UPDATE customers SET current_debt = -1'),
        throwsA(isA<Exception>()),
      );
    });

    test('keeps staff, licence and the pre-existing stock', () async {
      final user = await db.select(db.users).getSingle();
      expect(user.username, 'owner');
      expect(user.role, UserRole.admin);
      // Byte-identical hash: a migrated device must still accept the old PIN.
      expect(user.pinHash, r'salt$hash');

      final licence = await db.select(db.licenseConfig).getSingle();
      expect(licence.activationKey, 'key-one');

      final batch = await db.select(db.medicineBatches).getSingle();
      expect(batch.batchNumber, 'X117');
      expect(batch.qtyInSmallestUnit, 100);
    });

    test('a migrated database can carry a real FEFO sale', () async {
      // End to end on the upgraded schema: `SaleRepository` must not notice it
      // is talking to a file that started life at version 2. Selling the whole
      // 100-tablet batch proves the deduction writes against the migrated
      // `medicine_batches`, not a rebuilt copy of it.
      final userId = (await db.select(db.users).getSingle()).id;
      final medicine = await db.select(db.medicines).getSingle();
      final unit = await db.select(db.unitConversions).getSingle();
      final repo = SaleRepository(db);

      final receipt = await repo.completeSale(
        lines: [
          NewSaleLine(
            medicineId: medicine.id,
            unitConversionId: unit.id,
            unitName: unit.unitName,
            conversionFactor: unit.conversionFactor,
            quantity: 100,
            unitPricePya: 120,
          ),
        ],
        mode: SaleMode.retail,
        discountPya: 0,
        paymentMethod: PaymentMethod.cash,
        receivedPya: 12000,
        cashierUserId: userId,
      );

      expect(receipt.totalPya, 12000);
      expect(receipt.allocations, hasLength(1));
      expect(receipt.allocations.single.quantity, 100);
      final batch = await db.select(db.medicineBatches).getSingle();
      expect(batch.qtyInSmallestUnit, 0);
      expect(receipt.sale.voucherNo, startsWith('S-'));
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
        containsAll(['customers', 'sales', 'sale_batch_allocations']),
      );
      // One user row, not two: nothing re-ran or duplicated the migration.
      expect(await second.select(second.users).get(), hasLength(1));
      await second.close();
    },
  );
}

/// Phase 3's schema as released: eight tables plus their indexes, `user_version
/// = 2`.
///
/// Hand-written rather than generated by running the old build, so this file keeps
/// testing the real upgrade path even after the Dart table definitions evolve —
/// which is the point. It represents the bytes on a customer's device, not what
/// the current code would produce.
const String _phaseTwoSchema = '''
CREATE TABLE users (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  pin_hash TEXT NOT NULL,
  role TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)),
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
CREATE TABLE medicines (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  trade_name TEXT NOT NULL,
  generic_name TEXT NULL,
  category TEXT NULL,
  shelf_location TEXT NULL,
  barcode TEXT NULL UNIQUE,
  low_stock_threshold INTEGER NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE INDEX idx_medicines_trade_name ON medicines (trade_name);
CREATE INDEX idx_medicines_generic_name ON medicines (generic_name);
CREATE INDEX idx_medicines_active ON medicines (is_active);
CREATE TABLE unit_conversions (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  medicine_id INTEGER NOT NULL REFERENCES medicines (id) ON DELETE CASCADE,
  unit_name TEXT NOT NULL,
  conversion_factor INTEGER NOT NULL DEFAULT 1 CHECK (conversion_factor >= 1),
  retail_price INTEGER NOT NULL CHECK (retail_price >= 0),
  wholesale_price INTEGER NULL CHECK (wholesale_price IS NULL OR wholesale_price >= 0),
  display_order INTEGER NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX idx_unit_conversions_per_medicine ON unit_conversions (medicine_id, unit_name);
CREATE TABLE suppliers (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NULL,
  company_name TEXT NULL,
  current_payable INTEGER NOT NULL DEFAULT 0 CHECK (current_payable >= 0),
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE TABLE purchases (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  supplier_id INTEGER NOT NULL REFERENCES suppliers (id) ON UPDATE CASCADE,
  reference_no TEXT NULL,
  total_amount INTEGER NOT NULL CHECK (total_amount >= 0),
  paid_amount INTEGER NOT NULL DEFAULT 0 CHECK (paid_amount >= 0 AND paid_amount <= total_amount),
  is_credit INTEGER NOT NULL DEFAULT 0 CHECK ("is_credit" IN (0, 1)),
  entered_by_user_id INTEGER NULL REFERENCES users (id) ON DELETE SET NULL,
  note TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE INDEX idx_purchases_supplier ON purchases (supplier_id);
CREATE INDEX idx_purchases_created ON purchases (created_at);
CREATE TABLE purchase_items (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  purchase_id INTEGER NOT NULL REFERENCES purchases (id) ON DELETE CASCADE,
  medicine_id INTEGER NOT NULL REFERENCES medicines (id) ON UPDATE CASCADE,
  unit_conversion_id INTEGER NULL REFERENCES unit_conversions (id) ON UPDATE CASCADE,
  batch_number TEXT NOT NULL,
  expiry_date INTEGER NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity >= 1),
  cost_price INTEGER NOT NULL CHECK (cost_price >= 0),
  line_total INTEGER NOT NULL CHECK (line_total >= 0)
);
CREATE INDEX idx_purchase_items_purchase ON purchase_items (purchase_id);
CREATE INDEX idx_purchase_items_medicine ON purchase_items (medicine_id);
CREATE TABLE medicine_batches (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  medicine_id INTEGER NOT NULL REFERENCES medicines (id) ON DELETE CASCADE,
  batch_number TEXT NOT NULL,
  expiry_date INTEGER NOT NULL,
  qty_in_smallest_unit INTEGER NOT NULL CHECK (qty_in_smallest_unit >= 0),
  cost_price INTEGER NOT NULL CHECK (cost_price >= 0),
  purchase_item_id INTEGER NULL,
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE INDEX idx_batches_medicine_expiry ON medicine_batches (medicine_id, expiry_date);
CREATE INDEX idx_batches_expiry ON medicine_batches (expiry_date);
PRAGMA user_version = 2;
''';
