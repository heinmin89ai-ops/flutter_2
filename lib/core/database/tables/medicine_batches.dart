import 'package:drift/drift.dart';

import 'medicines.dart';

/// `medicine_batches` — physical stock, one row per batch (Module 3).
///
/// This table **is** the stock. Total stock for a medicine is
/// `SUM(qty_in_smallest_unit)` over its batches, computed rather than stored —
/// see `InventoryRepository.stockForMedicine`. The Phase 3 brief's
/// "current total stock (calculated dynamically)" is exactly this, and it is the
/// only version that cannot drift out of sync with reality.
///
/// Cost price lives here per batch, not on the medicine, because the same
/// paracetamol genuinely arrives at different prices. Profit in Phase 7 is
/// `sale price - unit_cost of the batch actually consumed`, which is only
/// computable if the cost was recorded at batch level.
// FEFO and stock queries both lead with medicine, then expiry; the second index
// serves the "expiring soon" scan, which does not filter by medicine at all.
@DataClassName('MedicineBatch')
@TableIndex(
  name: 'idx_batches_medicine_expiry',
  columns: {#medicineId, #expiryDate},
)
@TableIndex(name: 'idx_batches_expiry', columns: {#expiryDate})
class MedicineBatches extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get medicineId => integer()
      .named('medicine_id')
      .references(Medicines, #id, onDelete: KeyAction.cascade)();

  /// As printed on the carton. Not unique: the same batch number legitimately
  /// arrives twice, and stock-in must not fail because of it — quantities simply
  /// merge into the matching batch (see `PurchaseRepository`).
  TextColumn get batchNumber =>
      text().named('batch_number').withLength(min: 1, max: 48)();

  /// Expiry date, day precision. FEFO ordering (Phase 4) sorts on this.
  ///
  /// Stored as a date at local midnight: both write paths drop any time component
  /// before inserting, so "expired today" is decided consistently rather than
  /// depending on the hour the clerk saved at.
  DateTimeColumn get expiryDate => dateTime().named('expiry_date')();

  /// Remaining quantity in the medicine's smallest unit. Never negative.
  ///
  /// The name spells out the unit because mixing units here is the failure mode
  /// that turns a till's stock negative: a sale of "2 boxes" must be recorded as
  /// 200 tablets against this column, not 2.
  IntColumn get qtyInSmallestUnit => integer()
      .named('qty_in_smallest_unit')
      .customConstraint('NOT NULL CHECK (qty_in_smallest_unit >= 0)')();

  /// Cost per **smallest unit**, in pya. See the note on the table.
  IntColumn get costPrice => integer()
      .named('cost_price')
      .customConstraint('NOT NULL CHECK (cost_price >= 0)')();

  /// Supplier and purchase that created this batch, for stock traceability.
  ///
  /// Recall on a bad batch needs "which customers got tablets from batch X117"
  /// — without the link, that question is unanswerable offline.
  IntColumn get purchaseItemId =>
      integer().named('purchase_item_id').nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}
