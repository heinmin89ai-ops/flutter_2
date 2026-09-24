import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money.dart';

/// A single expense category's total over a window, for the report's breakdown.
class ExpenseCategoryTotal {
  const ExpenseCategoryTotal({
    required this.category,
    required this.totalPya,
    required this.entryCount,
  });

  final String category;
  final Pya totalPya;
  final int entryCount;
}

/// Data access for `expenses` (Module 4's Expenses half).
///
/// Expenses are deliberately decoupled from stock and suppliers — see the table
/// doc on `expenses`. This repository owns the only writes to that table and the
/// period sums the profit report needs. There is no soft-delete: a wrong expense
/// is removed through [delete], which is gated by [Permission.deleteTransaction]
/// at the route/widget layer and logged by who removed it.
class ExpenseRepository {
  ExpenseRepository(this._db);

  final AppDatabase _db;

  /// Log one expense.
  ///
  /// [category] is trimmed and required; [amountPya] must be positive so the
  /// ledger's `CHECK (amount > 0)` is never the thing that rejects the form.
  Future<Expense> create({
    required String category,
    required Pya amountPya,
    String? note,
    int? enteredByUserId,
    DateTime? at,
  }) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) {
      throw const ExpenseRejectException('An expense needs a category.');
    }
    if (amountPya <= 0) {
      throw const ExpenseRejectException('Amount must be greater than zero.');
    }
    final now = at ?? DateTime.now();
    final id = await _db
        .into(_db.expenses)
        .insert(
          ExpensesCompanion.insert(
            category: trimmed,
            amount: amountPya,
            note: Value(_blankToNull(note)),
            enteredByUserId: Value(enteredByUserId),
            createdAt: Value(now),
          ),
        );
    return (await byId(id))!;
  }

  Future<Expense?> byId(int id) => (_db.select(
    _db.expenses,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Expenses newest first, optionally narrowed to a period and a category.
  ///
  /// [from] is inclusive and [to] is exclusive, matching [totalInPeriod] so the
  /// list a screen shows and the figure it prints beside it are the same set of
  /// rows.
  Future<List<Expense>> list({
    String search = '',
    DateTime? from,
    DateTime? to,
    String? category,
    int limit = 100,
  }) async {
    final query = _db.select(_db.expenses)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    if (from != null) {
      query.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) query.where((t) => t.createdAt.isSmallerThanValue(to));
    if (category != null && category.trim().isNotEmpty) {
      query.where((t) => t.category.equals(category.trim()));
    }
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      query.where(
        (t) =>
            t.category.lower().like('%$needle%') |
            t.note.lower().like('%$needle%'),
      );
    }
    return query.get();
  }

  /// Sum of expenses in `[from, to)`.
  ///
  /// The profit report calls this for the same window it sums sales over, so the
  /// two halves of `net = sales − cogs − expenses` cover identical dates.
  Future<Pya> totalInPeriod({
    required DateTime from,
    required DateTime to,
  }) async {
    final sum = _db.expenses.amount.sum();
    final row =
        await (_db.selectOnly(_db.expenses)
              ..addColumns([sum])
              ..where(
                _db.expenses.createdAt.isBiggerOrEqualValue(from) &
                    _db.expenses.createdAt.isSmallerThanValue(to),
              ))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  /// Per-category totals over all time, largest first — the report's breakdown.
  Future<List<ExpenseCategoryTotal>> totalsByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final sum = _db.expenses.amount.sum();
    final count = _db.expenses.id.count();
    final query = _db.selectOnly(_db.expenses)
      ..addColumns([_db.expenses.category, sum, count])
      ..groupBy([_db.expenses.category])
      ..orderBy([OrderingTerm(expression: sum, mode: OrderingMode.desc)]);
    if (from != null) {
      query.where(_db.expenses.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      query.where(_db.expenses.createdAt.isSmallerThanValue(to));
    }
    final rows = await query.get();
    return [
      for (final row in rows)
        ExpenseCategoryTotal(
          category: row.read(_db.expenses.category)!,
          totalPya: row.read(sum) ?? 0,
          entryCount: row.read(count) ?? 0,
        ),
    ];
  }

  /// Distinct categories already used, for the expense form's suggestions.
  Future<List<String>> categories() async {
    final rows =
        await (_db.selectOnly(_db.expenses, distinct: true)
              ..addColumns([_db.expenses.category])
              ..orderBy([OrderingTerm(expression: _db.expenses.category)]))
            .get();
    return [
      for (final row in rows)
        if (row.read(_db.expenses.category) case final String c) c,
    ];
  }

  /// Remove one expense row.
  ///
  /// A hard delete: nothing downstream resolves back to an expense (unlike a
  /// ledger row, which is why that one is only reversible, not deletable). The
  /// caller is responsible for the [Permission.deleteTransaction] gate.
  Future<void> delete(int id) =>
      (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

class ExpenseRejectException implements Exception {
  const ExpenseRejectException(this.message);

  final String message;

  @override
  String toString() => 'ExpenseRejectException: $message';
}
