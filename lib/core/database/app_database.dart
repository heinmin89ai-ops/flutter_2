import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/credit_transactions.dart';
import 'tables/customers.dart';
import 'tables/expenses.dart';
import 'tables/license_config.dart';
import 'tables/medicines.dart';
import 'tables/medicine_batches.dart';
import 'tables/purchase_items.dart';
import 'tables/purchases.dart';
import 'tables/sale_items.dart';
import 'tables/sales.dart';
import 'tables/suppliers.dart';
import 'tables/unit_conversions.dart';
import 'tables/users.dart';

part 'app_database.g.dart';

/// Current schema version.
///
/// Bump by exactly one per phase and add a matching `up` step in
/// [migration]. Never rewrite an already-released step: a device that skips a
/// migration cannot be repaired without a Phase 8 cloud restore, which does not
/// exist yet.
const int kSchemaVersion = 4;

/// Highest schema version with a defined `onUpgrade` step.
///
/// Kept separate from [kSchemaVersion] so that bumping the version without
/// writing the migration is a loud failure at runtime rather than a device
/// booting against a stale schema. Update both together when releasing a phase.
const int kHighestDefinedMigration = 4;

/// Offline-first pharmacy database.
///
/// Phase 1 registered [Users] and [LicenseConfig]; Phase 3 added the inventory
/// and purchasing tables; Phase 4 added the sales side; Phase 5 adds the
/// receivable/payable ledger ([CreditTransactions]) and operational
/// [Expenses] — the two tables Module 6 needs to compute a true net profit.
@DriftDatabase(
  tables: [
    Users,
    LicenseConfig,
    Medicines,
    UnitConversions,
    MedicineBatches,
    Suppliers,
    Purchases,
    PurchaseItems,
    Customers,
    Sales,
    SaleItems,
    SaleBatches,
    CreditTransactions,
    Expenses,
  ],
)
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
      // One block per released step, never rewritten. A device that skipped a
      // version must still land on the current schema.
      if (from < 2) {
        await _createPhase3Tables(m);
      }
      if (from < 3) {
        await _createPhase4Tables(m);
      }
      if (from < 4) {
        await _createPhase5Tables(m);
      }
      // Anything beyond the defined steps must not boot against a stale schema.
      if (!_coversUpgrade(from, to)) {
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

  /// Phase 3: inventory and purchasing.
  ///
  /// Creation order follows the foreign keys — parents before children — so the
  /// statements stay valid even if `foreign_keys` were somehow off on this
  /// connection.
  ///
  /// The indexes are created explicitly because drift models an `@TableIndex` as
  /// a *separate* schema entity: `createTable` emits only the `CREATE TABLE`, and
  /// `createAll` picks indexes up afterwards from `allSchemaEntities`. A migration
  /// that calls `createTable` per table alone therefore produces an upgraded
  /// database with **no** indexes at all, and the POS search plus the FEFO scan
  /// would do a full table walk on every keystroke — on the devices of exactly the
  /// customers with the most rows. `migration_v1_to_v2_test.dart` pins this.
  Future<void> _createPhase3Tables(Migrator m) async {
    await m.createTable(medicines);
    await m.createTable(unitConversions);
    await m.createTable(suppliers);
    await m.createTable(purchases);
    await m.createTable(purchaseItems);
    await m.createTable(medicineBatches);

    await m.createIndex(idxMedicinesTradeName);
    await m.createIndex(idxMedicinesGenericName);
    await m.createIndex(idxMedicinesActive);
    await m.createIndex(idxUnitConversionsPerMedicine);
    await m.createIndex(idxBatchesMedicineExpiry);
    await m.createIndex(idxBatchesExpiry);
    await m.createIndex(idxPurchasesSupplier);
    await m.createIndex(idxPurchasesCreated);
    await m.createIndex(idxPurchaseItemsPurchase);
    await m.createIndex(idxPurchaseItemsMedicine);
  }

  /// Phase 4: sales, customers and the FEFO batch audit trail.
  ///
  /// Same explicit-index rule as [_createPhase3Tables]: `Migrator.createTable`
  /// does not emit the `@TableIndex` entities, so a device upgrading from v2
  /// would otherwise get the sales tables with none of their indexes — the exact
  /// rows that grow fastest on a busy till. `migration_v2_to_v3_test.dart` pins
  /// this too.
  Future<void> _createPhase4Tables(Migrator m) async {
    await m.createTable(customers);
    await m.createTable(sales);
    await m.createTable(saleItems);
    await m.createTable(saleBatches);

    await m.createIndex(idxCustomersName);
    await m.createIndex(idxSalesCreated);
    await m.createIndex(idxSalesCustomer);
    await m.createIndex(idxSaleItemsSale);
    await m.createIndex(idxSaleItemsMedicine);
    await m.createIndex(idxSaleBatchAllocationsSale);
    await m.createIndex(idxSaleBatchAllocationsBatch);
  }

  /// Phase 5: the receivable/payable ledger and operational expenses.
  ///
  /// Same explicit-index rule as the earlier steps. Beyond creating the tables,
  /// this upgrade **backfills the ledger from the balances a Phase 4 device
  /// already carries**, which is what lets Phase 5's `recalculate*` oracles become
  /// genuine ledger recomputations instead of the header-only approximations they
  /// were (see [_backfillCreditLedger]).
  Future<void> _createPhase5Tables(Migrator m) async {
    await m.createTable(creditTransactions);
    await m.createTable(expenses);

    await m.createIndex(idxCreditTxnParty);
    await m.createIndex(idxCreditTxnCreated);
    await m.createIndex(idxExpensesCreated);
    await m.createIndex(idxExpensesCategory);

    await _backfillCreditLedger();
  }

  /// Rebuild `credit_transactions` so every party's ledger sums to the balance
  /// their row already reports.
  ///
  /// Through Phase 3 and 4 the *only* store of "who owes what" was the
  /// denormalised `suppliers.current_payable` / `customers.current_debt` column,
  /// updated incrementally: a credit document added its unpaid remainder, and a
  /// later cash payment subtracted from the number without a trace. So the cached
  /// column is authoritative and the *payments* are the missing history. For each
  /// party we write one `debt_added` per original unpaid remainder (linked to its
  /// purchase/voucher and stamped to that document's date), then — when the column
  /// now sits below the sum of those posted debts — a single balancing
  /// `payment_received` covering the difference. After this,
  /// `SUM(debt_added) − SUM(payment_received)` equals the cached balance exactly,
  /// so the ledger and the column cannot disagree from here on: the invariant
  /// Phase 4's oracle could not keep, and the reason `docs/PHASE4_SALES.md`
  /// recorded the debt-oracle limitation.
  ///
  /// A no-op on a fresh install (no rows) and on a device with no payments yet.
  /// Historic rows carry `recorded_by = NULL` rather than an invented clerk, and
  /// `created_at` keeps the document's own date so an ageing report stays truthful.
  Future<void> _backfillCreditLedger() async {
    final creditPurchases = await (select(
      purchases,
    )..where((t) => t.isCredit.equals(true))).get();
    await _backfillParty(
      partyType: PartyType.supplier,
      posted: [
        for (final p in creditPurchases)
          if (p.totalAmount - p.paidAmount > 0)
            _PostedDebt(
              partyId: p.supplierId,
              amount: p.totalAmount - p.paidAmount,
              createdAt: p.createdAt,
              purchaseId: p.id,
            ),
      ],
      current: {
        for (final s in await select(suppliers).get()) s.id: s.currentPayable,
      },
    );

    final creditSales = await (select(
      sales,
    )..where((t) => t.isCredit.equals(true))).get();
    await _backfillParty(
      partyType: PartyType.customer,
      posted: [
        // A voucher's customer id is required for a credit sale, but the column
        // is nullable for `SET NULL`; guard anyway so a null never becomes a
        // party id of 0.
        for (final v in creditSales)
          if (v.customerId != null && v.totalAmount - v.paidAmount > 0)
            _PostedDebt(
              partyId: v.customerId!,
              amount: v.totalAmount - v.paidAmount,
              createdAt: v.createdAt,
              saleId: v.id,
            ),
      ],
      current: {
        for (final c in await select(customers).get()) c.id: c.currentDebt,
      },
    );
  }

  /// Insert one party's `debt_added` rows plus any balancing `payment_received`.
  Future<void> _backfillParty({
    required PartyType partyType,
    required List<_PostedDebt> posted,
    required Map<int, int> current,
  }) async {
    final postedByParty = <int, int>{};
    for (final d in posted) {
      postedByParty[d.partyId] = (postedByParty[d.partyId] ?? 0) + d.amount;
      await into(creditTransactions).insert(
        CreditTransactionsCompanion.insert(
          partyType: partyType,
          partyId: d.partyId,
          kind: TransactionKind.debtAdded,
          amount: d.amount,
          linkedSaleId: Value(d.saleId),
          linkedPurchaseId: Value(d.purchaseId),
          createdAt: Value(d.createdAt),
        ),
      );
    }
    // Any shortfall between what was posted and what the column now reports was a
    // cash payment that left no row. Represent it once so the sums match. A
    // balance above the posted total is impossible under the incremental writes
    // (payments only ever reduce), so it is ignored rather than turned into a
    // phantom negative payment.
    for (final entry in postedByParty.entries) {
      final balance = current[entry.key] ?? 0;
      final paid = entry.value - balance;
      if (paid <= 0) continue;
      await into(creditTransactions).insert(
        CreditTransactionsCompanion.insert(
          partyType: partyType,
          partyId: entry.key,
          kind: TransactionKind.paymentReceived,
          amount: paid,
          note: const Value(
            'Balancing entry created when the credit ledger was added; '
            'represents payments recorded before this upgrade.',
          ),
        ),
      );
    }
  }

  /// Whether every step between [from] (exclusive) and [to] (inclusive) exists.
  ///
  /// [kHighestDefinedMigration] is the guard: bumping `kSchemaVersion` without
  /// adding a step makes every upgrade fail loudly instead of booting a device
  /// against a half-migrated schema.
  static bool _coversUpgrade(int from, int to) =>
      to <= kHighestDefinedMigration && from < to;

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

/// One credit-document's unpaid remainder, as the ledger backfill sees it.
///
/// Not a public type — only [_backfillParty] reads it.
class _PostedDebt {
  const _PostedDebt({
    required this.partyId,
    required this.amount,
    required this.createdAt,
    this.saleId,
    this.purchaseId,
  });

  final int partyId;
  final int amount;
  final DateTime createdAt;
  final int? saleId;
  final int? purchaseId;
}
