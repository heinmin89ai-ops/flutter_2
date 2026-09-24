import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money.dart';
import '../../../routing/routes.dart';
import '../application/inventory_providers.dart';
import '../data/inventory_repository.dart';

/// Bottom sheet listing one medicine's batches, soonest expiry first.
///
/// Opened from the inventory list. Read-only in Phase 3 by design: adjusting a
/// batch is a stock-take action, which belongs to the same review as the
/// write-off voucher in Phase 5 — a correction with no paper trail behind it is
/// how shrinkage becomes invisible.
Future<void> showMedicineBatches(BuildContext context, Medicine medicine) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BatchesSheet(medicine: medicine),
    );

class _BatchesSheet extends ConsumerWidget {
  const _BatchesSheet({required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(medicineBatchesProvider(medicine.id));
    final theme = Theme.of(context);
    final canEdit = ref.watch(canManageInventoryProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    medicine.tradeName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (canEdit)
                  TextButton(
                    onPressed: () =>
                        context.push(AppRoutes.addMedicine, extra: medicine),
                    child: const Text('Edit'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: batches.when(
              data: (rows) => rows.isEmpty
                  ? ListView(
                      controller: controller,
                      children: [
                        const SizedBox(height: 60),
                        const Icon(Icons.inbox_outlined, size: 40),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'No stock. Record a delivery to add batches.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: rows.length + 1,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => index == rows.length
                          ? _Totals(rows: rows)
                          : _BatchTile(item: rows[index]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({required this.item});

  final StockBatch item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = item.batch;
    final days = item.daysToExpiry;
    final expiryColour = item.isExpired
        ? theme.colorScheme.error
        : days <= 90
        ? theme.colorScheme.tertiary
        : theme.colorScheme.onSurfaceVariant;

    return ListTile(
      dense: true,
      title: Text('Batch ${batch.batchNumber}'),
      subtitle: Text(
        '${_ymd(batch.expiryDate)} · ${batch.qtyInSmallestUnit} '
        '${item.hierarchy.base.name.toLowerCase()} · cost '
        '${formatMoney(batch.costPrice)} K',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(item.humanQuantity, style: theme.textTheme.titleSmall),
          Text(
            item.isExpired ? 'expired' : '$days days left',
            style: theme.textTheme.bodySmall?.copyWith(color: expiryColour),
          ),
        ],
      ),
    );
  }
}

/// `YYYY-MM-DD`, no locale package.
///
/// `intl` is deliberately not a dependency yet: the brief defers Burmese date
/// formatting to Phase 6's reports, and adding a localisation surface just to
/// render an ISO date would be untested code for a format nobody reads locally.
String _ymd(DateTime value) {
  final text = value.toIso8601String();
  return text.length >= 10 ? text.substring(0, 10) : text;
}

class _Totals extends StatelessWidget {
  const _Totals({required this.rows});

  final List<StockBatch> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = rows.fold<int>(0, (sum, b) => sum + b.qtyInBase);
    final value = rows.fold<Pya>(0, (sum, b) => sum + b.remainingValuePya);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${rows.length} batch${rows.length == 1 ? '' : 'es'} · '
            '$total in stock',
            style: theme.textTheme.titleSmall,
          ),
          Text(
            'Costed at ${formatMoney(value)} kyat. FEFO sells the '
            'earliest expiry first.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
