import 'package:drift/drift.dart';

import 'medicines.dart';
import 'purchases.dart';
import 'unit_conversions.dart';

/// `purchase_items` — one line on a supplier invoice (Module 4).
///
/// Each line carries batch number, expiry, quantity and cost, and is what
/// creates a `medicine_batches` row. The brief's "Stock-In Logic" requirement —
/// saving a purchase must automatically insert batches — is implemented by
/// `PurchaseRepository.recordPurchase`, which writes these rows and the batch
/// rows in one transaction.
///
/// **The unit question.** The blueprint's column list has `quantity` with no unit.
/// A quantity is meaningless without one: "Paracetamol, 5" is 5 boxes or 5
/// tablets, and the difference is 100× the stock. So [quantity] is stored in the
/// unit pointed at by [unitConversionId] — the row carrying the name and factor
/// the clerk was holding when they counted the carton — while the batch itself is
/// written in smallest units. Keeping both views is what lets the invoice be
/// reconciled against paper while stock stays internally consistent.
@TableIndex(name: 'idx_purchase_items_purchase', columns: {#purchaseId})
@TableIndex(name: 'idx_purchase_items_medicine', columns: {#medicineId})
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get purchaseId => integer()
      .named('purchase_id')
      .references(Purchases, #id, onDelete: KeyAction.cascade)();

  IntColumn get medicineId => integer()
      .named('medicine_id')
      .references(Medicines, #id, onUpdate: KeyAction.cascade)();

  /// Unit the quantity was received in, e.g. "Box".
  ///
  /// FK to `unit_conversions` so a line cannot name a unit the medicine does not
  /// sell in. Nullable only so a shop can record a bulk buy in smallest units
  /// without having configured the hierarchy yet.
  IntColumn get unitConversionId => integer()
      .named('unit_conversion_id')
      .nullable()
      .references(UnitConversions, #id, onUpdate: KeyAction.cascade)();

  TextColumn get batchNumber =>
      text().named('batch_number').withLength(min: 1, max: 48)();

  DateTimeColumn get expiryDate => dateTime().named('expiry_date')();

  /// Quantity in that unit. At least 1 — a zero line is a data-entry
  /// mistake, and allowing it makes `total_amount` disagree with the paper invoice.
  IntColumn get quantity =>
      integer().customConstraint('NOT NULL CHECK (quantity >= 1)')();

  /// Cost per unit as entered on the line's `unit_conversion_id` row, in pya
  /// (the carton price, not per tablet).
  IntColumn get costPrice => integer()
      .named('cost_price')
      .customConstraint('NOT NULL CHECK (cost_price >= 0)')();

  /// Line value in pya: `quantity * cost_price`, stored so a later unit edit
  /// cannot rewrite history.
  IntColumn get lineTotal => integer()
      .named('line_total')
      .customConstraint('NOT NULL CHECK (line_total >= 0)')();
}
