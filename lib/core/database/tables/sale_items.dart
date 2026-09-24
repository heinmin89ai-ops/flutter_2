import 'package:drift/drift.dart';

import 'medicines.dart';
import 'sales.dart';
import 'unit_conversions.dart';

/// `sale_items` — one product line on a voucher (Module 5).
///
/// The blueprint's column list is `sale_id, medicine_id, batch_id, unit_name,
/// quantity, unit_price, unit_cost`. Two deliberate changes, both made for the
/// same reason `purchase_items` made them in Phase 3:
///
/// 1. **`unit_conversion_id` FK instead of a bare `unit_name`.** A name copied
///    off the hierarchy at sale time goes stale the moment a price is edited,
///    and nothing can join back to "which unit row was this sold as". The
///    integer FK plus the denormalised [unitName] keeps both: the join for
///    reports, the readable string for reprints of a 58 mm voucher.
/// 2. **No single [batchId].** The FEFO rule means one sold line can drain
///    three batches; the split lives in [SaleBatches] (`sale_batch_allocations`)
///    — the same table that makes "which customers got tablets from batch X117"
///    answerable, which is the recall question a pharmacy actually gets asked.
///
/// [quantity] is in the unit named on the line (as entered at the till), while
/// [qtyInBase] freezes the smallest-unit figure the deduction removed. Keeping
/// both is what lets the drawer recount match the paper without re-deriving
/// anything from a hierarchy that may since have changed.
@TableIndex(name: 'idx_sale_items_sale', columns: {#saleId})
@TableIndex(name: 'idx_sale_items_medicine', columns: {#medicineId})
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId => integer()
      .named('sale_id')
      .references(Sales, #id, onDelete: KeyAction.cascade)();

  IntColumn get medicineId => integer()
      .named('medicine_id')
      .references(Medicines, #id, onUpdate: KeyAction.cascade)();

  /// Unit sold in, e.g. "Strip". Denormalised copy for voucher reprint; the
  /// authoritative row is [unitConversionId].
  TextColumn get unitName =>
      text().named('unit_name').withLength(min: 1, max: 24)();

  /// `unit_conversions.id` priced at sale time.
  ///
  /// Not nullable the way purchases' was: a sale line's unit price came *from* a
  /// unit row, so a line without one cannot exist — every medicine on the till
  /// has had its hierarchy configured through `createMedicine`.
  IntColumn get unitConversionId => integer()
      .named('unit_conversion_id')
      .references(UnitConversions, #id, onUpdate: KeyAction.cascade)();

  /// Quantity in [unitName] units, as rung in at the till.
  IntColumn get quantity =>
      integer().customConstraint('NOT NULL CHECK (quantity >= 1)')();

  /// Same quantity expressed in the medicine's smallest unit; what was actually
  /// removed from batches. Always `quantity * factor`, frozen so a later factor
  /// edit cannot rewrite history.
  IntColumn get qtyInBase => integer()
      .named('qty_in_base')
      .customConstraint('NOT NULL CHECK (qty_in_base >= 1)')();

  /// Line unit price in pya, for one [unitName] — the row's `unit_price`.
  IntColumn get unitPrice => integer()
      .named('unit_price')
      .customConstraint('NOT NULL CHECK (unit_price >= 0)')();

  /// Blended cost of one smallest unit across the batches this line consumed
  /// (`sum(qty*cost)/sum(qty)`, rounded half-up), in pya.
  ///
  /// Per-smallest-unit rather than per sold unit, so it is comparable with
  /// `medicine_batches.cost_price` and with the price of any other unit the same
  /// medicine sells in.
  IntColumn get unitCost => integer()
      .named('unit_cost')
      .customConstraint('NOT NULL CHECK (unit_cost >= 0)')();

  /// Line value in pya before any voucher-level discount: `quantity *
  /// unit_price`, frozen like purchases' `line_total`.
  IntColumn get lineTotal => integer()
      .named('line_total')
      .customConstraint('NOT NULL CHECK (line_total >= 0)')();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}

/// `sale_batch_allocations` — which batches actually supplied a sale line, and
/// how much of each.
///
/// This is the audit trail the FEFO rule creates: `sale_items` says "2 Strips of
/// Paracetamol", this says the first strip came from batch X117 expiring in
/// March and half of the second from X120. Without it, a deduction cannot be
/// reversed on a return (Phase 5's credits restock the exact batches taken), a
/// recall cannot name affected customers, and [SaleItems.unitCost]'s blend
/// cannot be verified against the rows it came from.
///
/// One row per (line, batch) pair; a line that consumed nothing errors instead.
@DataClassName('SaleBatch')
@TableIndex(name: 'idx_sale_batch_allocations_sale', columns: {#saleId})
@TableIndex(name: 'idx_sale_batch_allocations_batch', columns: {#batchId})
class SaleBatches extends Table {
  @override
  String get tableName => 'sale_batch_allocations';

  IntColumn get id => integer().autoIncrement()();

  /// Copied onto the row alongside [saleItemId] so the "which sales touched
  /// batch X" recall query is one indexed scan rather than a join through the
  /// line table.
  IntColumn get saleId => integer()
      .named('sale_id')
      .references(Sales, #id, onDelete: KeyAction.cascade)();

  IntColumn get saleItemId => integer()
      .named('sale_item_id')
      .references(SaleItems, #id, onDelete: KeyAction.cascade)();

  /// No FK: the batch must survive the sale and the sale must survive the
  /// batch's stock reaching zero; deleting batch rows is Phase 5's write-off
  /// problem, and history pointing at nothing would be worse than a dangling id
  /// a repair pass can still read.
  IntColumn get batchId => integer().named('batch_id')();

  /// Smallest units taken from this batch for this line.
  IntColumn get quantity =>
      integer().customConstraint('NOT NULL CHECK (quantity >= 1)')();

  /// That batch's cost per smallest unit, in pya, at deduction time.
  IntColumn get unitCost => integer()
      .named('unit_cost')
      .customConstraint('NOT NULL CHECK (unit_cost >= 0)')();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}
