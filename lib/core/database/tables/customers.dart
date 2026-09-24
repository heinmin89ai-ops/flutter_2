import 'package:drift/drift.dart';

/// `customers` — a person or shop a sale can be charged to (Module 5/6).
///
/// The Phase 4 brief only needs enough of a customer to attach a credit sale to
/// and to refuse one that would exceed their limit, so this table carries the
/// blueprint's columns plus a soft-delete flag for parity with medicines. Full
/// receivables management —
/// statement history, ageing, partial-payment ledger — stays in Phase 6;
/// inventing those rows here would fork the debt figure from wherever it finally
/// lands.
///
/// [currentDebt] is denormalised for a fast "who owes us" list, exactly like
/// `suppliers.current_payable`, and `SaleRepository.recalculateCustomerDebt` is
/// its repair oracle.
@TableIndex(name: 'idx_customers_name', columns: {#name})
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Not unique: two walk-in customers legitimately share a phone number, and a
  /// duplicate here must not silently merge two debtors into one ledger.
  TextColumn get phone => text().withLength(max: 32).nullable()();

  TextColumn get address => text().withLength(max: 240).nullable()();

  /// Credit ceiling in pya. `0` means "this is a cash customer" — no balance is
  /// ever allowed — rather than a limit of zero kyat that a purchase could
  /// technically fit inside. Kept NOT NULL so the two states ("no limit tracked"
  /// and "no credit allowed") are not conflated by a null check at every call
  /// site; there is deliberately no "unlimited" sentinel in Phase 4.
  IntColumn get creditLimit => integer()
      .named('credit_limit')
      .customConstraint('NOT NULL DEFAULT 0 CHECK (credit_limit >= 0)')();

  /// Outstanding balance owed to the shop, in pya.
  IntColumn get currentDebt => integer()
      .named('current_debt')
      .customConstraint('NOT NULL DEFAULT 0 CHECK (current_debt >= 0)')();

  /// Soft delete, for the same reason medicines are soft-deleted: an old voucher
  /// must still resolve who it was charged to.
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}
