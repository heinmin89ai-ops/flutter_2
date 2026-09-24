import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/credit_transactions.dart';
import 'package:pharmacy_pos/core/database/tables/sales.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';
import 'package:pharmacy_pos/features/purchases/data/purchase_repository.dart';
import 'package:pharmacy_pos/features/sales/data/sale_repository.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Schema 3 → 4 upgrade, against a real on-disk database with live debts.
///
/// The two earlier migration tests only have to prove tables and indexes appear.
/// This one has to prove something harder: that a Phase 4 device's cached
/// `customers.current_debt` / `suppliers.current_payable` columns survive the
/// upgrade as the *sum of a new ledger*, because Phase 5's
/// [SaleRepository.recalculateCustomerDebt] and
/// [PurchaseRepository.recalculatePayable] read that ledger, not the old
/// documents. A device that upgraded with a ledger whose sums disagreed with the
/// cached columns would have its debts silently rewritten on the first rebuild.
///
/// So the fixture seeds the awkward case — a credit sale with an interim cash
/// payment and a credit purchase with an interim supplier payment — because
/// Phase 4 recorded those payments by subtracting from the column and leaving no
/// row. The migration has to invent a single balancing `payment_received` for
/// each so `SUM(debt_added) − SUM(payment_received)` reproduces the cached
/// figure exactly.
void main() {
  late Directory tempDir;
  late String path;

  // Day the fixture "happened", and the shape of the seeded debts, both shared
  // with the assertions below so a change here shows up as a failure there.
  // 2026-09-01 — deliberately in the past so the backfilled `created_at` values
  // must match the *document's* date, not "today", for the ageing report to be
  // truthful.
  final seededAt = DateTime.utc(2026, 9, 1, 9, 30);
  // Drift stores `DateTime` as whole **seconds** (the `strftime('%s', …)`
  // DEFAULT in every prior migration fixture proves it), so the seed columns are
  // seconds too. Writing milliseconds here would land on a date in year 58637.
  final seededEpoch = seededAt.millisecondsSinceEpoch ~/ 1000;

  // Two suppliers, both bought on credit.
  //   1 — "Hein Co": 50,000 invoice charged fully on credit, then 20,000 paid in
  //       cash later (an interim payment Phase 4 recorded by subtracting from the
  //       column and leaving no row) → 30,000 payable now.
  //   2 — "Mya Pharma": 12,000 invoice, paid in full at the till, no payable.
  // A customer with an interim cash payment covers the case where the cached
  // column is *less* than the posted debts; a second customer with no payment
  // covers the case where it is equal. Together they force the backfill to
  // distinguish the two, and both are asserted explicitly.
  //
  //   c1 — "U Kyaw":    11,000 voucher on credit, 4,000 paid in cash later → 7,000 debt now.
  //   c2 — "Daw Hla":   9,000 voucher on credit, nothing paid → 9,000 debt now.
  //   c3 — "Ko Win":    walk-in cash customer, no ledger rows, 0 debt.
  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pharmacy_migration_v4');
    path = '${tempDir.path}/pharmacy_pos.db';
    final raw = sqlite3.open(path);
    raw.execute(_phaseThreeSchema);

    raw.execute(
      'INSERT INTO users (id, username, pin_hash, role, is_active, created_at) '
      "VALUES (1, 'owner', 'salt\$hash', 'admin', 1, 0)",
    );
    raw.execute(
      'INSERT INTO license_config (id, activation_key, features_data, '
      "activated_at, updated_at) VALUES (1, 'key-one', '{\"pos\":true}', 0, 0)",
    );
    raw.execute(
      'INSERT INTO medicines (id, trade_name, low_stock_threshold) '
      "VALUES (1, 'Paracetamol 500mg', 20)",
    );
    raw.execute(
      'INSERT INTO unit_conversions '
      '(id, medicine_id, unit_name, conversion_factor, retail_price) '
      "VALUES (1, 1, 'Strip', 10, 1200)",
    );
    // Expiry 2027-01-15, so it is neither expired nor within 60 days of any
    // plausible "today" — the migration does not care, but a stock-count
    // assertion elsewhere in this file keeps the fixture sane.
    raw.execute(
      'INSERT INTO medicine_batches '
      '(id, medicine_id, batch_number, expiry_date, qty_in_smallest_unit, '
      'cost_price, created_at) '
      'VALUES (1, 1, \'X117\', 1781913600, 400, 900, $seededEpoch)',
    );

    // Suppliers + their credit purchases.
    raw.execute(
      "INSERT INTO suppliers (id, name, current_payable, created_at) "
      "VALUES (1, 'Hein Co', 3000000, $seededEpoch)",
    );
    raw.execute(
      "INSERT INTO suppliers (id, name, current_payable, created_at) "
      "VALUES (2, 'Mya Pharma', 0, $seededEpoch)",
    );
    raw.execute(
      'INSERT INTO purchases (id, supplier_id, total_amount, paid_amount, '
      'is_credit, note, created_at) '
      "VALUES (1, 1, 5000000, 0, 1, 'credit', $seededEpoch)",
    );
    // Paid in full: is_credit = 0 so the backfill must skip this entirely —
    // a supplier with no debt and no ledger rows is a distinct case from one
    // whose posted debts net to zero.
    raw.execute(
      'INSERT INTO purchases (id, supplier_id, total_amount, paid_amount, '
      'is_credit, note, created_at) '
      "VALUES (2, 2, 1200000, 1200000, 0, 'settled', $seededEpoch)",
    );
    // Two lines on the first purchase: the header carries the whole
    // total/paid pair and only *one* debt_added row goes into the ledger per
    // document, so the line rows exist purely to prove the migration never
    // touched purchase_items.
    raw.execute(
      'INSERT INTO purchase_items (id, purchase_id, medicine_id, '
      'batch_number, expiry_date, quantity, cost_price, line_total) '
      'VALUES (1, 1, 1, \'X117\', 1781913600, 400, 12500, 5000000)',
    );

    // Customers + their credit vouchers.
    raw.execute(
      "INSERT INTO customers (id, name, credit_limit, current_debt, "
      "is_active, created_at) VALUES (1, 'U Kyaw', 1500000, 700000, 1, "
      '$seededEpoch)',
    );
    raw.execute(
      "INSERT INTO customers (id, name, credit_limit, current_debt, "
      "is_active, created_at) VALUES (2, 'Daw Hla', 2000000, 900000, 1, "
      '$seededEpoch)',
    );
    raw.execute(
      "INSERT INTO customers (id, name, credit_limit, current_debt, "
      "is_active, created_at) VALUES (3, 'Ko Win', 0, 0, 1, $seededEpoch)",
    );
    raw.execute(
      'INSERT INTO sales (id, voucher_no, customer_id, user_id, sale_type, '
      'total_cost, subtotal, discount, total_amount, paid_amount, '
      'change_due, payment_type, is_credit, created_at) '
      "VALUES (1, 'S-20260901-0001', 1, 1, 'retail', 360000, 1100000, 0, "
      '1100000, 0, 0, \'cash\', 1, $seededEpoch)',
    );
    raw.execute(
      'INSERT INTO sales (id, voucher_no, customer_id, user_id, sale_type, '
      'total_cost, subtotal, discount, total_amount, paid_amount, '
      'change_due, payment_type, is_credit, created_at) '
      "VALUES (2, 'S-20260901-0002', 2, 1, 'retail', 540000, 900000, 0, "
      '900000, 0, 0, \'cash\', 1, $seededEpoch)',
    );
    // A settled cash voucher with no customer, the shape the backfill must
    // skip on `is_credit = 0` even though `customer_id` is null.
    raw.execute(
      'INSERT INTO sales (id, voucher_no, customer_id, user_id, sale_type, '
      'total_cost, subtotal, discount, total_amount, paid_amount, '
      'change_due, payment_type, is_credit, created_at) '
      "VALUES (3, 'S-20260901-0003', NULL, 1, 'retail', 90000, 120000, 0, "
      '120000, 120000, 0, \'kpay\', 0, $seededEpoch)',
    );
    raw.execute(
      'INSERT INTO sale_items (id, sale_id, medicine_id, unit_name, '
      'unit_conversion_id, quantity, qty_in_base, unit_price, unit_cost, '
      'line_total, created_at) '
      "VALUES (1, 1, 1, 'Strip', 1, 100, 1000, 11000, 900, 1100000, "
      '$seededEpoch)',
    );
    raw.close();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

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

  test('the fixture is a genuine version-3 database with live debts', () async {
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

    expect(version, 3);
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
        'customers',
        'sales',
        'sale_items',
        'sale_batch_allocations',
      ]),
    );

    final db = open();
    await db.customSelect('SELECT 1 AS one').get();
    expect(
      await names(db, 'table'),
      unorderedEquals([...tables, 'credit_transactions', 'expenses']),
    );
    await db.close();
  });

  group('upgrade to version 4', () {
    late AppDatabase db;

    setUp(() async {
      db = open();
      // Force onUpgrade: schemaVersion reports 4, the file reports 3.
      await db.customSelect('SELECT 1 AS one').get();
    });

    tearDown(() => db.close());

    test('adds every Phase 5 table', () async {
      expect(
        await names(db, 'table'),
        containsAll(['credit_transactions', 'expenses']),
      );
    });

    test('stamps user_version so the next launch skips this step', () async {
      final row = await db.customSelect('PRAGMA user_version').getSingle();
      expect(row.read<int>('user_version'), kSchemaVersion);
    });

    test(
      'the Phase 5 indexes exist — the trap createTable alone walks into',
      () async {
        // Same trap the Phase 3 and Phase 4 migrations pinned. Missing here
        // means every statement screen (party-filtered) and every report query
        // (date-ranged) does a full scan on upgraded devices.
        expect(
          await names(db, 'index'),
          containsAll([
            'idx_credit_txn_party',
            'idx_credit_txn_created',
            'idx_expenses_created',
            'idx_expenses_category',
          ]),
        );
      },
    );

    test('the positive-amount CHECK applies on both new tables', () async {
      // `textEnum` stores the Dart enum's `name` as plain TEXT with **no**
      // SQL-level CHECK — drift validates the enum on the *read* path, not the
      // write. So the only thing worth pinning here is the `CHECK (amount > 0)`
      // on both tables: a 0 or negative movement would be a ledger entry that
      // changes no balance yet still appears on a statement, or an expense that
      // inverts a cost. Each INSERT is executed eagerly so the SQLite error
      // surfaces inside the `expectLater` matcher.
      Future<void> bad(String sql) => db.customStatement(sql);
      await expectLater(
        bad(
          'INSERT INTO credit_transactions (party_type, party_id, kind, '
          "amount, created_at) VALUES ('customer', 1, 'debt_added', 0, 0)",
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        bad(
          'INSERT INTO credit_transactions (party_type, party_id, kind, '
          "amount, created_at) VALUES ('customer', 1, 'payment_received', "
          '-100, 0)',
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        bad(
          'INSERT INTO expenses (category, amount, created_at) '
          "VALUES ('rent', -1, 0)",
        ),
        throwsA(isA<Exception>()),
      );
      // And the valid shape works, which the rejects above would also mask if
      // the constraint were simply "no inserts ever".
      await bad(
        'INSERT INTO credit_transactions (party_type, party_id, kind, '
        "amount, created_at) VALUES ('customer', 1, 'payment_received', "
        '100, 0)',
      );
    });

    test('keeps staff, licence, medicine and the pre-existing stock', () async {
      final user = await db.select(db.users).getSingle();
      expect(user.username, 'owner');
      expect(user.role, UserRole.admin);
      expect(user.pinHash, r'salt$hash');

      final licence = await db.select(db.licenseConfig).getSingle();
      expect(licence.activationKey, 'key-one');

      final medicine = await db.select(db.medicines).getSingle();
      expect(medicine.tradeName, 'Paracetamol 500mg');

      final batch = await db.select(db.medicineBatches).getSingle();
      expect(batch.batchNumber, 'X117');
      expect(batch.qtyInSmallestUnit, 400);

      // The pre-existing documents must survive untouched — the backfill reads
      // them, it never edits them.
      final purchases = await db.select(db.purchases).get();
      expect(purchases, hasLength(2));
      expect(purchases.first.paidAmount, 0);
      final sales = await db.select(db.sales).get();
      expect(sales, hasLength(3));
      final saleItems = await db.select(db.saleItems).get();
      expect(saleItems, hasLength(1));
    });

    test(
      'the ledger backfill reproduces every cached balance exactly',
      () async {
        // The load-bearing assertion of the whole file.
        //
        // Every party's `SUM(debt_added) − SUM(payment_received)` after this
        // upgrade must equal the `current_debt` / `current_payable` the Phase 4
        // device already carried — including for the two that had an interim
        // cash payment (which Phase 4 recorded by *subtracting from the column
        // and leaving no row*), and for the settled purchase and the walk-in
        // cash customer that must have no rows at all.
        //
        // If this test ever fails, Phase 5's `recalculate*` oracles would
        // silently rewrite a customer's debts on their first repair pass.
        final posted = await _postedBalances(db);
        expect(
          posted,
          equals({
            // Party 1 (customer "U Kyaw") posted 11,000 and is now owed only
            // 7,000 → a balancing 4,000 payment_received.
            (PartyType.customer, 1): 700000,
            // Party 2 (customer "Daw Hla") posted 9,000, no payment.
            (PartyType.customer, 2): 900000,
            // Supplier 1 posted 3,000 with 2,000 paid back → 1,000 balance.
            (PartyType.supplier, 1): 3000000,
          }),
        );

        // Compare the ledger's sums with the cached columns row-for-row.
        final customers = await db.select(db.customers).get();
        for (final customer in customers) {
          expect(
            posted[(PartyType.customer, customer.id)] ?? 0,
            customer.currentDebt,
            reason: '${customer.name} ledger sum ≠ cached debt',
          );
        }
        final suppliers = await db.select(db.suppliers).get();
        for (final supplier in suppliers) {
          expect(
            posted[(PartyType.supplier, supplier.id)] ?? 0,
            supplier.currentPayable,
            reason: '${supplier.name} ledger sum ≠ cached payable',
          );
        }
      },
    );

    test('the backfill links each debt_added to its source document', () async {
      // The links are what make Phase 5's write-off screen reverse a specific
      // voucher instead of subtracting a bare number from the balance.
      final rows = await db.select(db.creditTransactions).get();
      final debtBySale = {
        for (final r in rows)
          if (r.kind == TransactionKind.debtAdded && r.linkedSaleId != null)
            r.linkedSaleId!: r,
      };
      expect(debtBySale.keys, unorderedEquals([1, 2]));
      expect(debtBySale[1]!.amount, 1100000);
      expect(debtBySale[1]!.partyId, 1);
      expect(debtBySale[1]!.partyType, PartyType.customer);
      expect(debtBySale[2]!.amount, 900000);
      // Historic rows carry no invented clerk.
      expect(debtBySale[1]!.recordedByUserId, isNull);
      // And keep the document's *own* date, to the second, so an ageing report
      // on an upgraded device is not silently restated to "today". This is the
      // trap a `DateTime.now()` slip in the backfill would leave: the sums
      // still reconcile, but every historic debt looks freshly opened.
      // Compared as an instant, not with `==`, because drift materialises a
      // stored second as a *local* DateTime while [seededAt] is UTC.
      expect(
        debtBySale[1]!.createdAt.millisecondsSinceEpoch,
        seededAt.millisecondsSinceEpoch,
      );

      final debtByPurchase = {
        for (final r in rows)
          if (r.kind == TransactionKind.debtAdded && r.linkedPurchaseId != null)
            r.linkedPurchaseId!: r,
      };
      // Only the credit purchase; the settled one must have posted nothing.
      expect(debtByPurchase.keys, unorderedEquals([1]));
      expect(debtByPurchase[1]!.amount, 5000000);
      expect(debtByPurchase[1]!.partyType, PartyType.supplier);
    });

    test(
      'the balancing payments carry a note explaining their origin',
      () async {
        // A statement screen showing "4,000 paid on 2026-09-01" that nobody
        // recorded would be indistinguishable from a bug. The note is the
        // operator's cue to reconcile it against the shop's own cash book.
        final rows = await db.select(db.creditTransactions).get();
        final balancing = rows
            .where(
              (r) =>
                  r.kind == TransactionKind.paymentReceived && r.note != null,
            )
            .toList();
        expect(balancing, hasLength(2)); // customer 1, supplier 1
        for (final r in balancing) {
          expect(
            r.note,
            contains(
              'Balancing entry created when the credit ledger was added',
            ),
          );
          expect(r.recordedByUserId, isNull);
          expect(r.linkedSaleId, isNull);
          expect(r.linkedPurchaseId, isNull);
        }
        expect(
          balancing.map((r) => (r.partyType, r.amount)).toSet(),
          equals({(PartyType.customer, 400000), (PartyType.supplier, 2000000)}),
        );
      },
    );

    test('the recalculate oracles preserve the migrated balances', () async {
      // The reason the backfill exists: once Phase 5's `recalculateCustomerDebt`
      // reads the ledger, it will overwrite every cached column with the
      // ledger's sum. If those two figures disagreed after migration, the
      // first repair pass would rewrite a customer's debt to the wrong number
      // and the shop would never notice.
      //
      // Corrupt one column first so the test proves the recalculation is a
      // real rebuild *and* that it rebuilds to the true answer.
      await (db.update(db.customers)..where((t) => t.id.equals(1))).write(
        const CustomersCompanion(currentDebt: Value(1)),
      );
      await (db.update(db.suppliers)..where((t) => t.id.equals(1))).write(
        const SuppliersCompanion(currentPayable: Value(1)),
      );

      await SaleRepository(db).recalculateCustomerDebt();
      await PurchaseRepository(db).recalculatePayable();

      final customer = (await (db.select(
        db.customers,
      )..where((t) => t.id.equals(1))).getSingle());
      expect(customer.currentDebt, 700000);
      final supplier = (await (db.select(
        db.suppliers,
      )..where((t) => t.id.equals(1))).getSingle());
      expect(supplier.currentPayable, 3000000);

      // Untouched parties must stay put.
      final untouched = (await (db.select(
        db.customers,
      )..where((t) => t.id.equals(3))).getSingle());
      expect(untouched.currentDebt, 0);
    });

    test('a migrated database can carry a real Phase 5 credit sale', () async {
      // End to end: `completeSale` now posts a `debt_added` row via the ledger
      // service, so an upgraded device's first Phase 5 sale must land beside
      // the backfilled rows and the totals on both sides must stay coherent.
      final userId = (await db.select(db.users).getSingle()).id;
      final medicine = await db.select(db.medicines).getSingle();
      final unit = await db.select(db.unitConversions).getSingle();
      final customer = (await (db.select(
        db.customers,
      )..where((t) => t.id.equals(2))).getSingle());
      final repo = SaleRepository(db);

      final receipt = await repo.completeSale(
        lines: [
          NewSaleLine(
            medicineId: medicine.id,
            unitConversionId: unit.id,
            unitName: unit.unitName,
            conversionFactor: unit.conversionFactor,
            quantity: 10,
            unitPricePya: 1200,
          ),
        ],
        mode: SaleMode.retail,
        discountPya: 0,
        paymentMethod: PaymentMethod.cash,
        receivedPya: 2000,
        customerId: customer.id,
        cashierUserId: userId,
      );

      expect(receipt.creditPya, 10000);
      final refreshed = (await (db.select(
        db.customers,
      )..where((t) => t.id.equals(customer.id))).getSingle());
      expect(refreshed.currentDebt, 900000 + 10000);

      // The statement feed must contain two rows for customer 2: the backfilled
      // 9,000 debt_added, and the new 100 debt_added — no phantom payment here
      // because the cached column already matched the posted debt.
      final rows = await repo.customerLedger(customer.id);
      expect(rows, hasLength(2));
      final fresh = rows.where((r) => r.linkedSaleId == receipt.sale.id);
      expect(
        fresh,
        hasLength(1),
        reason: 'the new sale must have posted exactly one debt_added',
      );
      final entry = fresh.single;
      expect(entry.kind, TransactionKind.debtAdded);
      expect(entry.amount, 10000);
      expect(entry.recordedByUserId, userId);

      // The oracle still returns the same number the incremental path wrote.
      await repo.recalculateCustomerDebt();
      final again = (await (db.select(
        db.customers,
      )..where((t) => t.id.equals(customer.id))).getSingle());
      expect(again.currentDebt, 900000 + 10000);
    });
  });

  test(
    're-opening an already-migrated file does not repeat the backfill',
    () async {
      final first = open();
      await first.customSelect('SELECT 1 AS one').get();
      final entries = await first.select(first.creditTransactions).get();
      await first.close();

      final second = open();
      await second.customSelect('SELECT 1 AS one').get();
      expect(
        await second.select(second.creditTransactions).get(),
        hasLength(entries.length),
        reason: 'a re-run would double every party balance',
      );
      await second.close();
    },
  );
}

/// Reads the ledger and returns `SUM(debt_added) − SUM(payment_received)` per
/// party, keyed on `(party_type, party_id)`.
///
/// Deliberately not `LedgerService.balancesByParty`: this is the migration test,
/// so the helper is hand-rolled SQL rather than the code under repair, and a bug
/// in the service cannot hide itself by matching its own mistake.
Future<Map<(PartyType, int), int>> _postedBalances(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT party_type, party_id, kind, COALESCE(SUM(amount), 0) AS total '
        'FROM credit_transactions GROUP BY party_type, party_id, kind',
        readsFrom: {db.creditTransactions},
      )
      .get();
  final byParty = <(PartyType, int), int>{};
  for (final row in rows) {
    final partyType = PartyType.values.byName(row.read<String>('party_type'));
    final partyId = row.read<int>('party_id');
    final kind = row.read<String>('kind');
    final total = row.read<int>('total');
    final signed = kind == TransactionKind.debtAdded.name ? total : -total;
    byParty[(partyType, partyId)] =
        (byParty[(partyType, partyId)] ?? 0) + signed;
  }
  // Drop zero-net entries so an assertion can compare against a compact set.
  byParty.removeWhere((_, v) => v == 0);
  return byParty;
}

/// Phase 4's schema as released: twelve tables plus their indexes,
/// `user_version = 3`.
///
/// Hand-written so this file keeps testing the real upgrade path even after the
/// Dart table definitions evolve. It represents the bytes on a customer's device
/// before Phase 5, not what the current code would produce.
const String _phaseThreeSchema = '''
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
CREATE TABLE customers (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT NULL,
  address TEXT NULL,
  credit_limit INTEGER NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
  current_debt INTEGER NOT NULL DEFAULT 0 CHECK (current_debt >= 0),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE INDEX idx_customers_name ON customers (name);
CREATE TABLE sales (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  voucher_no TEXT NOT NULL UNIQUE,
  customer_id INTEGER NULL REFERENCES customers (id) ON DELETE SET NULL,
  user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE SET NULL,
  sale_type TEXT NOT NULL DEFAULT 'retail',
  total_cost INTEGER NOT NULL CHECK (total_cost >= 0),
  subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
  discount INTEGER NOT NULL DEFAULT 0 CHECK (discount >= 0),
  total_amount INTEGER NOT NULL CHECK (total_amount >= 0),
  paid_amount INTEGER NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
  change_due INTEGER NOT NULL DEFAULT 0 CHECK (change_due >= 0),
  payment_type TEXT NOT NULL DEFAULT 'cash' CHECK (payment_type IN ('cash', 'kpay')),
  is_credit INTEGER NOT NULL DEFAULT 0 CHECK ("is_credit" IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE INDEX idx_sales_created ON sales (created_at);
CREATE INDEX idx_sales_customer ON sales (customer_id);
CREATE TABLE sale_items (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  sale_id INTEGER NOT NULL REFERENCES sales (id) ON DELETE CASCADE,
  medicine_id INTEGER NOT NULL REFERENCES medicines (id) ON UPDATE CASCADE,
  unit_name TEXT NOT NULL,
  unit_conversion_id INTEGER NOT NULL REFERENCES unit_conversions (id) ON UPDATE CASCADE,
  quantity INTEGER NOT NULL CHECK (quantity >= 1),
  qty_in_base INTEGER NOT NULL CHECK (qty_in_base >= 1),
  unit_price INTEGER NOT NULL CHECK (unit_price >= 0),
  unit_cost INTEGER NOT NULL CHECK (unit_cost >= 0),
  line_total INTEGER NOT NULL CHECK (line_total >= 0),
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE INDEX idx_sale_items_sale ON sale_items (sale_id);
CREATE INDEX idx_sale_items_medicine ON sale_items (medicine_id);
CREATE TABLE sale_batch_allocations (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  sale_id INTEGER NOT NULL REFERENCES sales (id) ON DELETE CASCADE,
  sale_item_id INTEGER NOT NULL REFERENCES sale_items (id) ON DELETE CASCADE,
  batch_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity >= 1),
  unit_cost INTEGER NOT NULL CHECK (unit_cost >= 0),
  created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
);
CREATE INDEX idx_sale_batch_allocations_sale ON sale_batch_allocations (sale_id);
CREATE INDEX idx_sale_batch_allocations_batch ON sale_batch_allocations (batch_id);
PRAGMA user_version = 3;
''';
