import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../data/expense_repository.dart';

final Provider<ExpenseRepository> expenseRepositoryProvider =
    Provider<ExpenseRepository>(
      (ref) => ExpenseRepository(ref.watch(appDatabaseProvider)),
    );

/// Whether the signed-in user may log an expense.
final Provider<bool> canManageExpensesProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.manageExpenses)),
);

/// Recent expenses, newest first.
final FutureProvider<List<Expense>> expenseListProvider =
    FutureProvider.autoDispose<List<Expense>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(expenseRepositoryProvider).list();
    });

/// Per-category totals, largest first.
final FutureProvider<List<ExpenseCategoryTotal>> expenseTotalsProvider =
    FutureProvider.autoDispose<List<ExpenseCategoryTotal>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(expenseRepositoryProvider).totalsByCategory();
    });
