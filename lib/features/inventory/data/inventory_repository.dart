import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money.dart';
import '../application/unit_hierarchy.dart';

/// A medicine joined to its live stock total.
///
/// [stockInBase] is a `SUM` over batches, so it is always consistent with the
/// batch rows — there is no cached column here to go stale.
class InventoryRow {
  const InventoryRow({
    required this.medicine,
    required this.stockInBase,
    required this.batchCount,
    required this.expiringBatchCount,
    this.nearestExpiry,
    this.stockValuePya = 0,
    this.hierarchy,
  });

  final Medicine medicine;
  final int stockInBase;

  /// Batches with stock remaining; 0 means the item has never been stocked.
  final int batchCount;

  /// Batches expiring inside the alert window, for the list badge.
  final int expiringBatchCount;

  final DateTime? nearestExpiry;

  /// `SUM(qty * cost_price)` over this medicine's batches, in pya.
  ///
  /// Computed in the same grouped query as the quantity, so it cannot disagree
  /// with it. This is the stock-valuation figure Phase 7's reports run on, and the only
  /// cost number the inventory list is allowed to show.
  final Pya stockValuePya;

  /// The medicine's units, resolved in the same pass as the list so the screen
  /// can render `2 Boxes, 3 Strips` without a query per row. `null` when no
  /// smallest unit is configured, which [Medicine]s created through
  /// [createMedicine] cannot be — only through an older database.
  final UnitHierarchy? hierarchy;

  bool get neverStocked => batchCount == 0;
  bool get outOfStock => stockInBase <= 0;

  /// Stock in the units the shop thinks in.
  ///
  /// Falls back to the bare piece count rather than throwing: the list has to
  /// open even when one row's configuration is broken, and the number is still
  /// worth seeing.
  String get stockLabel {
    final units = hierarchy;
    if (units == null) return '$stockInBase pieces';
    return units.formatStock(stockInBase);
  }

  String get baseUnitName => hierarchy?.base.name ?? 'pieces';

  /// Whether stock is at or below this medicine's own threshold.
  ///
  /// A `null` threshold means the shop never asked to be warned, which is not the
  /// same as a threshold of zero — `0` means "warn when it runs out".
  bool get isLow {
    final threshold = medicine.lowStockThreshold;
    if (threshold == null) return false;
    return stockInBase <= threshold;
  }
}

/// A catalogue product with its unit hierarchy, for the POS grid.
///
/// The till prices each card off [hierarchy]'s base (or first) unit; a `null`
/// hierarchy means the product has no valid units configured and cannot be sold,
/// which the grid shows rather than hiding.
class CatalogEntry {
  const CatalogEntry({required this.medicine, this.hierarchy});

  final Medicine medicine;
  final UnitHierarchy? hierarchy;

  bool get sellable => hierarchy != null;
}

/// A batch with its medicine's unit hierarchy resolved.
class StockBatch {
  const StockBatch({
    required this.batch,
    required this.hierarchy,
    this.tradeName,
  });

  final MedicineBatch batch;
  final UnitHierarchy hierarchy;

  /// Denormalised for the cross-medicine expiry alert, where the caller has no
  /// medicine row at hand.
  final String? tradeName;

  int get qtyInBase => batch.qtyInSmallestUnit;

  String get humanQuantity => hierarchy.formatStock(qtyInBase);

  bool get isExpired => _dayOnly(batch.expiryDate).isBefore(_today());

  /// Days until expiry; negative once past.
  int get daysToExpiry =>
      _dayOnly(batch.expiryDate).difference(_today()).inDays;

  Pya get remainingValuePya => qtyInBase * batch.costPrice;
}

/// Alert thresholds required by Module 3: 30 / 60 / 90 days.
const List<int> kExpiryWarningWindows = [30, 60, 90];

/// Data access for `medicines`, `unit_conversions` and `medicine_batches`.
///
/// Caches each medicine's [UnitHierarchy]: [hierarchyFor] is called once per
/// stock-in line and once per batch list, and re-querying three rows every time
/// would dominate this screen's query count. Cleared by every write that can
/// change units.
class InventoryRepository {
  InventoryRepository(this._db);

  final AppDatabase _db;

  final Map<int, UnitHierarchy> _hierarchies = {};

  // ---------------------------------------------------------------- queries

  /// Inventory list with computed stock.
  ///
  /// [search] matches trade name, generic name or barcode. A `LIKE` rather than a
  /// Dart scan because this table reaches tens of thousands of rows in a real
  /// pharmacy, unlike `users`.
  ///
  /// Stock and expiry counts are aggregated in two grouped queries and joined in
  /// Dart. The alternative — a correlated subquery per medicine — runs the SUM
  /// once per row on every screen open.
  Future<List<InventoryRow>> list({
    String search = '',
    bool lowStockOnly = false,
    bool includeInactive = false,
    int expiryWarningDays = 30,
  }) async {
    final needle = search.trim().toLowerCase();

    final medicineQuery = _db.select(_db.medicines);
    if (!includeInactive) {
      medicineQuery.where((t) => t.isActive.equals(true));
    }
    if (needle.isNotEmpty) {
      medicineQuery.where(
        (t) =>
            t.tradeName.lower().like('%$needle%') |
            t.genericName.lower().like('%$needle%') |
            t.barcode.like('%$needle%'),
      );
    }
    medicineQuery.orderBy([(t) => OrderingTerm(expression: t.tradeName)]);

    final medicines = await medicineQuery.get();
    if (medicines.isEmpty) return const [];

    final stock = await _stockSummary();
    final expiry = await _expirySummary(expiryWarningDays);
    // One pass over `unit_conversions` for the whole list, rather than one
    // hierarchy query per row: 400 medicines would otherwise mean 400 queries on
    // every screen open.
    final units = await _hierarchiesForAll();

    final rows = <InventoryRow>[];
    for (final medicine in medicines) {
      final totals = stock[medicine.id];
      final expiring = expiry[medicine.id];
      final row = InventoryRow(
        medicine: medicine,
        stockInBase: totals?.qty ?? 0,
        batchCount: totals?.batches ?? 0,
        stockValuePya: totals?.valuePya ?? 0,
        expiringBatchCount: expiring?.count ?? 0,
        nearestExpiry: expiring?.nearest,
        hierarchy: units[medicine.id],
      );
      if (lowStockOnly && !row.isLow) continue;
      rows.add(row);
    }
    return rows;
  }

  /// The active catalogue, trade-name order — no stock aggregation.
  ///
  /// The purchase form needs to name products, and computing `SUM` over every
  /// batch to draw a picker of names would make a 20-second screen open into a
  /// full inventory recount.
  Future<List<Medicine>> catalog() =>
      (_db.select(_db.medicines)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm(expression: t.tradeName)]))
          .get();

  /// The active catalogue with each medicine's units resolved, in one pass.
  ///
  /// The POS grid needs a price and the unit list per product. Doing it row by
  /// row through [hierarchyFor] would fire one `unit_conversions` query per
  /// medicine on first paint — hundreds of queries on a real till — so this
  /// reuses [_hierarchiesForAll]'s single grouped read. A medicine with no valid
  /// units gets a `null` [CatalogEntry.hierarchy] and is shown as unpriced
  /// rather than dropped: hiding a product a shop stocks is worse than showing
  /// it without a price, which points the cashier at the configuration to fix.
  Future<List<CatalogEntry>> catalogWithUnits() async {
    final medicines = await catalog();
    if (medicines.isEmpty) return const [];
    final units = await _hierarchiesForAll();
    return [
      for (final medicine in medicines)
        CatalogEntry(medicine: medicine, hierarchy: units[medicine.id]),
    ];
  }

  Future<Medicine?> medicineById(int id) => (_db.select(
    _db.medicines,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Exact barcode lookup — a scanner delivers a complete code, so `LIKE` would
  /// only add false positives.
  Future<Medicine?> findByBarcode(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return Future.value();
    return (_db.select(
      _db.medicines,
    )..where((t) => t.barcode.equals(trimmed))).getSingleOrNull();
  }

  /// Units configured for [medicineId], coarsest first.
  Future<List<UnitConversion>> unitsFor(int medicineId) {
    final query = _db.select(_db.unitConversions)
      ..where((t) => t.medicineId.equals(medicineId))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.conversionFactor,
          mode: OrderingMode.desc,
        ),
      ]);
    return query.get();
  }

  /// The medicine's unit hierarchy, memoised per medicine.
  ///
  /// Throws [UnitConfigException] when the medicine has no units, which is the
  /// state reached by creating a medicine and abandoning the unit form. Callers
  /// that must degrade gracefully catch it and route to unit setup.
  Future<UnitHierarchy> hierarchyFor(int medicineId) async {
    final cached = _hierarchies[medicineId];
    if (cached != null) return cached;
    final rows = await unitsFor(medicineId);
    final hierarchy = UnitHierarchy.from(
      rows
          .map(
            (r) => UnitSpec(
              id: r.id,
              name: r.unitName,
              factor: r.conversionFactor,
              retailPricePya: r.retailPrice,
              wholesalePricePya: r.wholesalePrice,
            ),
          )
          .toList(),
    );
    _hierarchies[medicineId] = hierarchy;
    return hierarchy;
  }

  void clearHierarchyCache({int? medicineId}) {
    if (medicineId == null) {
      _hierarchies.clear();
    } else {
      _hierarchies.remove(medicineId);
    }
  }

  /// Total stock in smallest units. `0` when the medicine has no batches.
  Future<int> stockForMedicine(int medicineId) async {
    final total = _db.medicineBatches.qtyInSmallestUnit.sum();
    final row =
        await (_db.selectOnly(_db.medicineBatches)
              ..addColumns([total])
              ..where(_db.medicineBatches.medicineId.equals(medicineId)))
            .getSingle();
    return row.read(total) ?? 0;
  }

  /// Batches holding stock, soonest expiry first — the order Phase 4's FEFO
  /// deduction consumes them in.
  Future<List<StockBatch>> batchesFor(
    int medicineId, {
    bool includeDepleted = false,
  }) async {
    final query = _db.select(_db.medicineBatches)
      ..where((t) => t.medicineId.equals(medicineId))
      ..orderBy([(t) => OrderingTerm(expression: t.expiryDate)]);
    if (!includeDepleted) {
      query.where((t) => t.qtyInSmallestUnit.isBiggerThanValue(0));
    }
    final rows = await query.get();
    if (rows.isEmpty) return const [];
    final hierarchy = await hierarchyFor(medicineId);
    return [
      for (final batch in rows) StockBatch(batch: batch, hierarchy: hierarchy),
    ];
  }

  /// Batches expiring within [days], across all medicines, soonest first.
  ///
  /// Already-expired stock is excluded: those rows are a write-off problem, not an
  /// upcoming one, and mixing them in buries the actionable list.
  Future<List<StockBatch>> expiringWithin(int days) async {
    final today = _today();
    final cutoff = today.add(Duration(days: days));
    final rows =
        await (_db.select(_db.medicineBatches)
              ..where(
                (t) =>
                    t.expiryDate.isBiggerOrEqualValue(today) &
                    t.expiryDate.isSmallerOrEqualValue(cutoff) &
                    t.qtyInSmallestUnit.isBiggerThanValue(0),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.expiryDate)]))
            .get();
    if (rows.isEmpty) return const [];

    // One hierarchy lookup per distinct medicine rather than per batch.
    final hierarchies = <int, UnitHierarchy>{};
    final result = <StockBatch>[];
    for (final batch in rows) {
      final UnitHierarchy hierarchy;
      if (hierarchies.containsKey(batch.medicineId)) {
        hierarchy = hierarchies[batch.medicineId]!;
      } else {
        try {
          hierarchy = await hierarchyFor(batch.medicineId);
        } on UnitConfigException {
          // A medicine whose units were removed must not break the whole alert
          // list; its batches are simply not shown with a unit breakdown.
          continue;
        }
        hierarchies[batch.medicineId] = hierarchy;
      }
      final medicine = await medicineById(batch.medicineId);
      result.add(
        StockBatch(
          batch: batch,
          hierarchy: hierarchy,
          tradeName: medicine?.tradeName,
        ),
      );
    }
    return result;
  }

  /// Medicines at or below their low-stock threshold.
  Future<List<InventoryRow>> lowStock() => list(lowStockOnly: true);

  // ---------------------------------------------------------------- writes

  /// Create a medicine together with its unit rows in one transaction.
  ///
  /// Units are part of the same call rather than a second screen because a
  /// medicine without a base unit cannot hold stock at all — every stock-in and
  /// every sale would fail on [hierarchyFor]. Making them separable creates a
  /// broken state the rest of the app would have to defend against everywhere.
  ///
  /// Throws [MedicineConflictException] when [barcode] is taken, and
  /// [UnitConfigException] when [units] has no factor-1 entry.
  Future<Medicine> createMedicine({
    required String tradeName,
    required List<NewUnit> units,
    String? genericName,
    String? category,
    String? shelfLocation,
    String? barcode,
    int? lowStockThreshold,
  }) async {
    final trimmedName = tradeName.trim();
    if (trimmedName.isEmpty) {
      throw const MedicineConflictException('');
    }
    // Validated before opening the transaction so a rejected form costs no work.
    UnitHierarchy.from([
      for (final unit in units)
        UnitSpec(
          id: 0,
          name: unit.name,
          factor: unit.factor,
          retailPricePya: unit.retailPricePya,
          wholesalePricePya: unit.wholesalePricePya,
        ),
    ]);

    final normalisedBarcode = _blankToNull(barcode);
    if (normalisedBarcode != null) {
      final clash = await findByBarcode(normalisedBarcode);
      if (clash != null) {
        throw MedicineConflictException(
          'Barcode $normalisedBarcode is already on ${clash.tradeName}.',
        );
      }
    }

    late int id;
    await _db.transaction(() async {
      id = await _db
          .into(_db.medicines)
          .insert(
            MedicinesCompanion.insert(
              tradeName: trimmedName,
              genericName: Value(_blankToNull(genericName)),
              category: Value(_blankToNull(category)),
              shelfLocation: Value(_blankToNull(shelfLocation)),
              barcode: Value(normalisedBarcode),
              lowStockThreshold: Value(lowStockThreshold),
              createdAt: Value(DateTime.now()),
            ),
          );
      // Coarsest unit first in the picker, matching `UnitHierarchy.units`.
      var order = units.length;
      for (final unit in units) {
        await _db
            .into(_db.unitConversions)
            .insert(
              UnitConversionsCompanion.insert(
                medicineId: id,
                unitName: unit.name.trim(),
                conversionFactor: Value(unit.factor),
                retailPrice: unit.retailPricePya,
                wholesalePrice: Value(unit.wholesalePricePya),
                displayOrder: Value(order--),
              ),
            );
      }
    });
    clearHierarchyCache(medicineId: id);
    return (await medicineById(id))!;
  }

  /// Update a medicine's descriptive fields.
  ///
  /// Prices are deliberately not accepted here — they go through
  /// [updateUnitPrices], so editing a name or shelf cannot accidentally restate
  /// pricing as a side effect.
  ///
  /// [lowStockThreshold] is a drift [Value] rather than a plain `int?` because
  /// "leave it alone", "set it to 40" and "remove the alert" are three different
  /// instructions and `null` can only mean two of them. A `null` inside `Value`
  /// clears the alert.
  Future<void> updateMedicine({
    required int medicineId,
    String? tradeName,
    String? genericName,
    String? category,
    String? shelfLocation,
    Value<int?> lowStockThreshold = const Value.absent(),
  }) async {
    if (tradeName != null && tradeName.trim().isEmpty) {
      throw const MedicineConflictException('');
    }
    // `write` with a where clause rather than `replace`: replace re-validates the
    // whole row and demands every required column, which a partial edit by
    // definition does not carry.
    await (_db.update(
      _db.medicines,
    )..where((t) => t.id.equals(medicineId))).write(
      MedicinesCompanion(
        tradeName: tradeName == null
            ? const Value.absent()
            : Value(tradeName.trim()),
        genericName: genericName == null
            ? const Value.absent()
            : Value(_blankToNull(genericName)),
        category: category == null
            ? const Value.absent()
            : Value(_blankToNull(category)),
        shelfLocation: shelfLocation == null
            ? const Value.absent()
            : Value(_blankToNull(shelfLocation)),
        lowStockThreshold: lowStockThreshold,
      ),
    );
  }

  /// Replace prices on existing unit rows.
  ///
  /// Takes explicit edits rather than a full unit list so a caller cannot
  /// silently drop a unit: any unit absent from [edits] keeps its old price.
  Future<void> updateUnitPrices(List<UnitPriceEdit> edits) async {
    if (edits.isEmpty) return;
    await _db.transaction(() async {
      for (final edit in edits) {
        final existing = await (_db.select(
          _db.unitConversions,
        )..where((t) => t.id.equals(edit.unitId))).getSingleOrNull();
        if (existing == null) {
          throw StateError('Unit ${edit.unitId} no longer exists.');
        }
        await (_db.update(
          _db.unitConversions,
        )..where((t) => t.id.equals(edit.unitId))).write(
          UnitConversionsCompanion(
            retailPrice: Value(edit.retailPricePya),
            wholesalePrice: Value(edit.wholesalePricePya),
          ),
        );
        clearHierarchyCache(medicineId: existing.medicineId);
      }
    });
  }

  /// Soft delete.
  ///
  /// A hard delete would cascade through `unit_conversions` and
  /// `medicine_batches` (both `ON DELETE CASCADE`) and destroy the trail behind a
  /// "remove from list" button. [allowWithStock] exists because a shop doing a
  /// genuine clearance does need to remove an item that still has stock; the
  /// screen must ask before setting it.
  Future<void> deactivateMedicine({
    required int medicineId,
    bool allowWithStock = false,
  }) async {
    if (!allowWithStock && await stockForMedicine(medicineId) > 0) {
      throw const MedicineInUseException(
        'This medicine still has stock. Write it off or transfer it first.',
      );
    }
    await (_db.update(_db.medicines)..where((t) => t.id.equals(medicineId)))
        .write(MedicinesCompanion(isActive: const Value(false)));
  }

  /// Manual batch adjustment for stock-taking and write-offs.
  ///
  /// [deltaInBase] is signed and in smallest units; the batch's cost per unit is
  /// deliberately left alone. A write-off removes value at the recorded cost,
  /// which is the correct accounting, and a found-stock correction has no cost to
  /// blend against. Refuses to drive a batch negative: the column's `CHECK` would
  /// reject it anyway, but the exception here names the batch so the clerk knows
  /// which line to re-count.
  Future<void> adjustBatch({
    required int batchId,
    required int deltaInBase,
  }) async {
    if (deltaInBase == 0) return;
    final batch = await (_db.select(
      _db.medicineBatches,
    )..where((t) => t.id.equals(batchId))).getSingleOrNull();
    if (batch == null) {
      throw StateError('Batch $batchId not found.');
    }
    final next = batch.qtyInSmallestUnit + deltaInBase;
    if (next < 0) {
      throw MedicineInUseException(
        'Only ${batch.qtyInSmallestUnit} left in batch ${batch.batchNumber}; '
        'cannot remove ${-deltaInBase}.',
      );
    }
    await (_db.update(_db.medicineBatches)..where((t) => t.id.equals(batchId)))
        .write(MedicineBatchesCompanion(qtyInSmallestUnit: Value(next)));
  }

  // ------------------------------------------------------------- internals

  /// medicine id -> hierarchy for every medicine that has units.
  ///
  /// Invalid configurations are dropped rather than thrown: one medicine whose
  /// units were half-deleted must not stop the inventory list from opening.
  /// Also refills the memo so a following [hierarchyFor] is free.
  Future<Map<int, UnitHierarchy>> _hierarchiesForAll() async {
    final rows = await _db.select(_db.unitConversions).get();
    final grouped = <int, List<UnitSpec>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(row.medicineId, () => [])
          .add(
            UnitSpec(
              id: row.id,
              name: row.unitName,
              factor: row.conversionFactor,
              retailPricePya: row.retailPrice,
              wholesalePricePya: row.wholesalePrice,
            ),
          );
    }
    final result = <int, UnitHierarchy>{};
    grouped.forEach((medicineId, specs) {
      try {
        final hierarchy = UnitHierarchy.from(specs);
        result[medicineId] = hierarchy;
        _hierarchies[medicineId] = hierarchy;
      } on UnitConfigException {
        // Reported through `InventoryRow.hierarchy == null` and by
        // `hierarchyFor`, which is where an action actually needs the units.
      }
    });
    return result;
  }

  /// medicine id -> (total qty, batch count, stock value) in one grouped pass.
  Future<Map<int, _StockTotals>> _stockSummary() async {
    final qty = _db.medicineBatches.qtyInSmallestUnit.sum();
    final count = _db.medicineBatches.id.count();
    // Multiplying two columns of the same row is exact integer arithmetic, so the
    // valuation is as trustworthy as the quantity beside it.
    final value =
        (_db.medicineBatches.qtyInSmallestUnit * _db.medicineBatches.costPrice)
            .sum();
    final rows =
        await (_db.selectOnly(_db.medicineBatches)
              ..addColumns([_db.medicineBatches.medicineId, qty, count, value])
              ..where(
                _db.medicineBatches.qtyInSmallestUnit.isBiggerThanValue(0),
              )
              ..groupBy([_db.medicineBatches.medicineId]))
            .get();
    return {
      for (final row in rows)
        row.read(_db.medicineBatches.medicineId)!: _StockTotals(
          qty: row.read(qty) ?? 0,
          batches: row.read(count) ?? 0,
          valuePya: row.read(value) ?? 0,
        ),
    };
  }

  /// medicine id -> (batches expiring soon, nearest expiry) in one grouped pass.
  Future<Map<int, _ExpiryTotals>> _expirySummary(int days) async {
    final cutoff = _today().add(Duration(days: days));
    final count = _db.medicineBatches.id.count();
    final nearest = _db.medicineBatches.expiryDate.min();
    final rows =
        await (_db.selectOnly(_db.medicineBatches)
              ..addColumns([_db.medicineBatches.medicineId, count, nearest])
              ..where(
                _db.medicineBatches.qtyInSmallestUnit.isBiggerThanValue(0) &
                    _db.medicineBatches.expiryDate.isSmallerOrEqualValue(
                      cutoff,
                    ),
              )
              ..groupBy([_db.medicineBatches.medicineId]))
            .get();
    return {
      for (final row in rows)
        row.read(_db.medicineBatches.medicineId)!: _ExpiryTotals(
          count: row.read(count) ?? 0,
          nearest: row.read(nearest),
        ),
    };
  }
}

/// Weighted-average unit cost after adding stock, rounded half-up to the pya.
///
/// Shared by `InventoryRepository` and `PurchaseRepository` so the two merge
/// paths cannot disagree about how a repeated batch is costed.
///
/// Integer division alone would bias every blend downward and quietly inflate
/// reported margin. The numerator is exact integer arithmetic, so the only error
/// is the final rounding: under half a pya per unit.
Pya blendUnitCost({
  required int existingQty,
  required Pya existingCostPya,
  required int addedQty,
  required Pya addedCostPya,
}) {
  final totalQty = existingQty + addedQty;
  if (totalQty <= 0) return addedCostPya;
  final numerator = (existingQty * existingCostPya) + (addedQty * addedCostPya);
  return (numerator * 2 + totalQty) ~/ (2 * totalQty);
}

/// A unit as entered on the add-medicine form.
class NewUnit {
  const NewUnit({
    required this.name,
    required this.factor,
    required this.retailPricePya,
    this.wholesalePricePya,
  });

  final String name;
  final int factor;
  final Pya retailPricePya;
  final Pya? wholesalePricePya;
}

/// A price change targeting one existing `unit_conversions` row.
class UnitPriceEdit {
  const UnitPriceEdit({
    required this.unitId,
    required this.retailPricePya,
    this.wholesalePricePya,
  });

  final int unitId;
  final Pya retailPricePya;
  final Pya? wholesalePricePya;
}

class MedicineConflictException implements Exception {
  const MedicineConflictException(this.detail);

  final String detail;

  @override
  String toString() => detail.isEmpty
      ? 'A medicine name is required.'
      : 'Medicine conflict: $detail';
}

class MedicineInUseException implements Exception {
  const MedicineInUseException(this.message);

  final String message;

  @override
  String toString() => 'MedicineInUseException: $message';
}

class _StockTotals {
  const _StockTotals({
    required this.qty,
    required this.batches,
    required this.valuePya,
  });

  final int qty;
  final int batches;
  final Pya valuePya;
}

class _ExpiryTotals {
  const _ExpiryTotals({required this.count, this.nearest});

  final int count;
  final DateTime? nearest;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
