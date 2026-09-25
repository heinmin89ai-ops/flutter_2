import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n_bridge.dart';
import '../../../core/money.dart';
import '../../../core/presentation/money_field.dart';
import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../application/expense_providers.dart';
import '../data/expense_repository.dart';

/// Daily operating expenses (Phase 5 brief item 1, Expenses half).
///
/// Rent, electricity, staff — money the shop spends that is neither stock nor a
/// supplier payable. The table doc on `expenses` explains why these are decoupled
/// from inventory; on screen that means a dead-simple add form over a running
/// list, and the *only* place they reach the P&L is [netProfitPya] on the report.
class ExpenseScreen extends ConsumerStatefulWidget {
  const ExpenseScreen({super.key});

  @override
  ConsumerState<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends ConsumerState<ExpenseScreen> {
  Future<void> _addExpense() async {
    final repo = ref.read(expenseRepositoryProvider);
    final suggestions = await repo.categories();
    if (!mounted) return;

    String category = suggestions.firstOrNull ?? '';
    final categoryField = TextEditingController(text: category);
    final note = TextEditingController();
    Pya? amount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.expNewExpense),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyField(
                label: l10n.expAmount,
                suffix: 'K',
                allowEmpty: false,
                autofocus: true,
                onChanged: (value) => amount = value,
              ),
              const SizedBox(height: 12),
              _CategoryField(
                controller: categoryField,
                suggestions: suggestions,
                onChanged: (value) => category = value,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.expNoteOptional,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    final typed = amount;
    if (confirmed != true || typed == null) return;
    try {
      await repo.create(
        category: category,
        amountPya: typed,
        note: note.text,
        enteredByUserId: ref.read(authProvider)?.id,
      );
      ref.read(inventoryRevisionProvider.notifier).bump();
    } on ExpenseRejectException catch (e) {
      if (mounted) _toast(context.l10n.describe(e));
    }
  }

  Future<void> _delete(Expense expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.expDeleteTitle),
          content: Text(
            '${formatMoney(expense.amount)} K · ${expense.category}. '
            '${l10n.expCannotUndo}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    await ref.read(expenseRepositoryProvider).delete(expense.id);
    ref.read(inventoryRevisionProvider.notifier).bump();
    if (!mounted) return;
    _toast(context.l10n.expDeleted);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = ref.watch(expenseListProvider);
    final totals = ref.watch(expenseTotalsProvider);
    final mayManage = ref.watch(canManageExpensesProvider);
    final mayDelete = ref.watch(
      permissionProvider(Permission.deleteTransaction),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.expenses)),
      floatingActionButton: mayManage
          ? FloatingActionButton(
              onPressed: _addExpense,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: totals.maybeWhen(
              data: (cats) => Text(
                cats.isEmpty
                    ? l10n.expNoExpensesRecorded
                    : cats
                          .take(3)
                          .map(
                            (c) => '${c.category} ${formatMoney(c.totalPya)}',
                          )
                          .join('   ·   '),
                style: theme.textTheme.bodySmall,
              ),
              orElse: () => const Text(' '),
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(child: Text(l10n.expNoExpensesYet));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = rows[index];
                    return ListTile(
                      title: Text(e.category),
                      subtitle: Text(
                        [
                          _ymd(e.createdAt),
                          if ((e.note ?? '').isNotEmpty) e.note!,
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${formatMoney(e.amount)} K',
                            style: theme.textTheme.titleMedium,
                          ),
                          if (mayManage && mayDelete)
                            IconButton(
                              tooltip: l10n.delete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(e),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Category field with a dropdown of previously-used categories.
///
/// Free text, not a fixed enum: the set of things a pharmacy spends money on is
/// its own, and forcing a shared vocabulary makes clerks file electricity under
/// "other" and loses the breakdown that made the expense report worth building.
class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.controller,
    required this.suggestions,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (field) => field.text.isEmpty
          ? suggestions
          : suggestions.where(
              (s) => s.toLowerCase().contains(field.text.toLowerCase()),
            ),
      onSelected: (value) {
        controller.text = value;
        onChanged(value);
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        // Reuse the controller we were handed so the parent's `category` stays in
        // sync whether the clerk typed or picked a suggestion.
        if (textController != controller) {
          textController.text = controller.text;
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            labelText: context.l10n.expCategory,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );
      },
    );
  }
}

String _ymd(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
