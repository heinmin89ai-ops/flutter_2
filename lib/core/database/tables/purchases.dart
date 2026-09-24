import 'package:drift/drift.dart';

import 'suppliers.dart';
import 'users.dart';

/// `purchases` — one stock-in event, i.e. one supplier invoice (Module 4).
///
/// The header row. Line items live in `purchase_items`; the stock itself is
/// created in `medicine_batches` by the same transaction.
@TableIndex(name: 'idx_purchases_supplier', columns: {#supplierId})
@TableIndex(name: 'idx_purchases_created', columns: {#createdAt})
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get supplierId => integer()
      .named('supplier_id')
      .references(Suppliers, #id, onUpdate: KeyAction.cascade)();

  /// Supplier's own invoice/grn number.
  ///
  /// Not in the blueprint's column list, but without it a shop cannot tie a
  /// payable back to the paper document when the wholesaler's rep comes to
  /// collect. Nullable and non-unique: many shops receive unlabeled deliveries.
  TextColumn get referenceNo =>
      text().named('reference_no').withLength(max: 60).nullable()();

  /// Invoice value in pya, summed from the lines at save time.
  ///
  /// Stored rather than derived because it is the number the two parties agreed
  /// to; a later price edit on a medicine must not silently rewrite a historic
  /// debt. `PurchaseRepository` recomputes the line sum and refuses the save if
  /// it disagrees with what was entered.
  IntColumn get totalAmount => integer()
      .named('total_amount')
      .customConstraint('NOT NULL CHECK (total_amount >= 0)')();

  /// Cash already handed over, in pya.
  ///
  /// `customConstraint` replaces drift's own constraints rather than adding to
  /// them, so `NOT NULL DEFAULT 0` is spelled out here as well.
  ///
  /// The cross-column `paid_amount <= total_amount` check is legal in SQLite and
  /// is worth having: an overpayment silently becomes a negative payable, which
  /// the `suppliers` CHECK then rejects at commit time with a message that points
  /// at the wrong table. Catching it here names the actual mistake.
  IntColumn get paidAmount => integer()
      .named('paid_amount')
      .customConstraint(
        'NOT NULL DEFAULT 0 CHECK (paid_amount >= 0 AND '
        'paid_amount <= total_amount)',
      )();

  /// Whether any balance went onto the supplier's account.
  ///
  /// Derived from the amounts at save time rather than trusted from the UI:
  /// `is_credit == (total - paid > 0)`. Kept as a column because the payable list
  /// filters on it constantly.
  BoolColumn get isCredit =>
      boolean().named('is_credit').withDefault(const Constant(false))();

  /// Staff member who entered the delivery, for correcting a bad stock-in.
  IntColumn get enteredByUserId => integer()
      .named('entered_by_user_id')
      .nullable()
      .references(Users, #id, onDelete: KeyAction.setNull)();

  TextColumn get note => text().withLength(max: 280).nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}
