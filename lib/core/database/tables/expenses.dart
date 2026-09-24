import 'package:drift/drift.dart';

/// `expenses` — one operational cost (Module 4's Expenses half).
///
/// Deliberately *not* linked to a supplier or a stock movement: electricity,
/// staff salary and rent are not purchases, and forcing them through `purchases`
/// would pollute the payable ledger and the batch stock trail with rows that
/// neither touch goods nor create stock. [netProfit] in the report subtracts
/// these from (sales − COGS) exactly as the blueprint specifies.
///
/// [amount] is the expense value in pya, positive. There is no soft-delete here:
/// a wrong expense is corrected by a `deleteTransaction` (an admin-only,
/// audited removal) rather than a hidden flag, because unlike a medicine or a
/// customer nothing downstream resolves back to an expense row.
@TableIndex(name: 'idx_expenses_created', columns: {#createdAt})
@TableIndex(name: 'idx_expenses_category', columns: {#category})
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Free-text cost bucket ("Electricity", "Salary", "Rent").
  ///
  /// Not an enum: what counts as an expense differs per shop and a closed list
  /// would need a schema change to add one. Grouped by for the report's per-
  /// category breakdown.
  TextColumn get category => text().withLength(min: 1, max: 60)();

  /// The amount spent, in pya. Positive by construction.
  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount > 0)')();

  TextColumn get note => text().withLength(max: 240).nullable()();

  /// Who logged it, for the daily-close reconciliation.
  IntColumn get enteredByUserId =>
      integer().named('entered_by_user_id').nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  String get tableName => 'expenses';
}
