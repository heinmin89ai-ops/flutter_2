import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money.dart';
import '../../expenses/data/expense_repository.dart';
import '../../inventory/data/inventory_repository.dart';

/// The whole Reporting Dashboard's payload for one calendar day (Module 4).
///
/// Computed as one object rather than four independent providers so the four
/// figures printed side by side are guaranteed to describe the *same* window: a
/// Net Profit that quietly summed sales over today but expenses over yesterday
/// is worse than no report at all, and it is exactly what happens when the date
/// range is rebuilt in two places.
class DailyReport {
  const DailyReport({
    required this.dayStart,
    required this.dayEnd,
    required this.totalSalesPya,
    required this.costOfGoodsSoldPya,
    required this.expensesPya,
    required this.voucherCount,
    required this.receivablePya,
    required this.payablePya,
    required this.lowStock,
    required this.expiringSoon,
  });

  /// Inclusive.
  final DateTime dayStart;

  /// Exclusive — `[dayStart, dayEnd)` is the window every figure covers.
  final DateTime dayEnd;

  /// Gross sales in the window, discounts already applied (`sales.total_amount`).
  final Pya totalSalesPya;

  /// What those sold goods cost the shop, from the batches FEFO actually drew
  /// (`sales.total_cost`).
  final Pya costOfGoodsSoldPya;

  /// Operational expenses booked in the same window.
  final Pya expensesPya;

  final int voucherCount;

  /// Total owed to the shop right now (a point-in-time balance, not a window).
  final Pya receivablePya;

  /// Total the shop owes suppliers right now.
  final Pya payablePya;

  final List<InventoryRow> lowStock;
  final List<StockBatch> expiringSoon;

  /// `totalSalesPya - costOfGoodsSoldPya` — the margin before overheads.
  Pya get grossProfitPya => totalSalesPya - costOfGoodsSoldPya;

  /// The headline figure: `sales − COGS − expenses`, exactly as the blueprint
  /// defines it. Negative on a slow day, which is a real answer, not an error.
  Pya get netProfitPya => grossProfitPya - expensesPya;
}

/// Aggregate read layer for the Admin-only Reporting Dashboard (Module 4).
///
/// Sums sales directly from the `sales` header — `total_amount` and `total_cost`
/// are frozen at save time by `SaleRepository.completeSale`, so the report is a
/// plain range scan, not a re-derivation through `sale_items` and the batch cost
/// snapshot. That is the whole reason Phase 4 stored `total_cost` on the header.
class ReportRepository {
  ReportRepository(this._db)
    : _inventory = InventoryRepository(_db),
      _expenses = ExpenseRepository(_db);

  final AppDatabase _db;
  final InventoryRepository _inventory;
  final ExpenseRepository _expenses;

  /// Days ahead the "expiring soon" alert covers, per the brief.
  static const int kExpiringWindowDays = 60;

  /// Everything the dashboard shows for [day] (defaults to today).
  ///
  /// One call so the screen cannot assemble a half-refreshed board.
  Future<DailyReport> daily({DateTime? day}) async {
    final start = _dayOnly(day ?? DateTime.now());
    final end = start.add(const Duration(days: 1));

    final sales = await _salesWindow(start, end);
    final expensesPya = await _expenses.totalInPeriod(from: start, to: end);
    final receivable = await _sumColumn(
      _db.customers.currentDebt,
      _db.customers,
    );
    final payable = await _sumColumn(
      _db.suppliers.currentPayable,
      _db.suppliers,
    );

    return DailyReport(
      dayStart: start,
      dayEnd: end,
      totalSalesPya: sales.totalPya,
      costOfGoodsSoldPya: sales.costPya,
      expensesPya: expensesPya,
      voucherCount: sales.count,
      receivablePya: receivable,
      payablePya: payable,
      lowStock: await _inventory.lowStock(),
      expiringSoon: await _inventory.expiringWithin(kExpiringWindowDays),
    );
  }

  /// Sales total / cost / count over `[from, to)`.
  Future<_SalesWindow> _salesWindow(DateTime from, DateTime to) async {
    final total = _db.sales.totalAmount.sum();
    final cost = _db.sales.totalCost.sum();
    final count = _db.sales.id.count();
    final row =
        await (_db.selectOnly(_db.sales)
              ..addColumns([total, cost, count])
              ..where(
                _db.sales.createdAt.isBiggerOrEqualValue(from) &
                    _db.sales.createdAt.isSmallerThanValue(to),
              ))
            .getSingle();
    return _SalesWindow(
      totalPya: row.read(total) ?? 0,
      costPya: row.read(cost) ?? 0,
      count: row.read(count) ?? 0,
    );
  }

  Future<Pya> _sumColumn(IntColumn column, TableInfo table) async {
    final sum = column.sum();
    final row = await (_db.selectOnly(table)..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }
}

class _SalesWindow {
  const _SalesWindow({
    required this.totalPya,
    required this.costPya,
    required this.count,
  });

  final Pya totalPya;
  final Pya costPya;
  final int count;
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
