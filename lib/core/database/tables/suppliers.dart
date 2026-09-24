import 'package:drift/drift.dart';

/// `suppliers` — wholesalers the shop buys from (Module 4).
///
/// Soft-delete semantics are handled at the repository level rather than with
/// `isActive` here: a supplier with purchases must never disappear from a
/// payable report, so deletion is refused outright instead of flagged. That is
/// stricter than `users` and `medicines`, and correct because unlike a medicine
/// there is no search value in keeping a retired supplier visible.
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Person to call. Displayed first on the purchase form.
  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get phone => text().withLength(max: 32).nullable()();

  TextColumn get companyName =>
      text().named('company_name').withLength(max: 120).nullable()();

  /// Amount still owed, in pya. Never negative.
  ///
  /// **Derived, denormalised state.** Every credit purchase adds
  /// `total - paid`, every payment subtracts it, and both happen inside the same
  /// SQLite transaction as the rows that caused them. It is kept here rather than
  /// computed with a SUM over `purchases` because the payable list is sorted and
  /// filtered by debt, and a shop with 50,000 purchase rows should not pay that
  /// aggregation on every screen open.
  ///
  /// The cost of denormalising is that a bug can make it lie, so
  /// `PurchaseRepository.recalculatePayable` exists to rebuild it from the
  /// purchases table, and a test asserts the two agree.
  ///
  /// `DEFAULT 0` is spelled inside the constraint rather than via `withDefault`:
  /// a `customConstraint` **replaces** drift's own column constraints instead of
  /// appending to them, so combining the two produces a NOT NULL column with no
  /// default — and the first supplier insert, which does not set a debt, fails.
  IntColumn get currentPayable => integer()
      .named('current_payable')
      .customConstraint('NOT NULL DEFAULT 0 CHECK (current_payable >= 0)')();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}
