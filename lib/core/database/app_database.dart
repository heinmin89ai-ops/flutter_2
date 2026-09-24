import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/customers.dart';
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
const int kSchemaVersion = 3;

/// Highest schema version with a defined `onUpgrade` step.
///
/// Kept separate from [kSchemaVersion] so that bumping the version without
/// writing the migration is a loud failure at runtime rather than a device
/// booting against a stale schema. Update both together when releasing a phase.
const int kHighestDefinedMigration = 3;

/// Offline-first pharmacy database.
///
/// Phase 1 registered [Users] and [LicenseConfig]; Phase 3 added the inventory
/// and purchasing tables; Phase 4 adds the sales side. Remaining modules add
/// their tables in later phases and bump [kSchemaVersion].
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
