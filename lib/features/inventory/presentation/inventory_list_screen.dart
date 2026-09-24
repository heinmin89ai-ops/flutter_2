import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../routing/routes.dart';
import '../application/inventory_providers.dart';
import '../data/inventory_repository.dart';
import 'medicine_batches_sheet.dart';

/// Inventory list with dynamically computed stock.
///
/// Two things this screen is deliberately not:
///   * a place that adds numbers to rows it was given — the stock figure comes
///     from `SUM` over batches in the repository, so what is shown is what a
///     stock-take would find;
///   * a place that shows cost prices by default. [maySeeCostPriceProvider]
///     decides, because a cashier standing at this screen has no business knowing
///     what the shop paid.
class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(inventoryRevisionProvider.notifier).bump();
    await ref.read(inventoryListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageInventoryProvider);
    final state = ref.watch(inventoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Show only low stock',
            onPressed: () => ref
                .read(inventoryFilterProvider.notifier)
                .setLowStockOnly(
                  !ref.read(inventoryFilterProvider).lowStockOnly,
                ),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.addMedicine),
              icon: const Icon(Icons.add),
              label: const Text('Medicine'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search name, generic or barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          ref
                              .read(inventoryFilterProvider.notifier)
                              .setSearch('');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) =>
                  ref.read(inventoryFilterProvider.notifier).setSearch(value),
            ),
          ),
          Expanded(
            child: state.when(
              data: (rows) => _List(rows: rows, canManage: canManage),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  _Failure(message: '$error', onRetry: _refresh),
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.rows, required this.canManage});

  final List<InventoryRow> rows;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      final filtering = ref.watch(inventoryFilterProvider);
      return _Empty(
        hasFilter: filtering.search.isNotEmpty || filtering.lowStockOnly,
        canManage: canManage,
      );
    }

    final maySeeCost = ref.watch(maySeeCostPriceProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(inventoryRevisionProvider.notifier).bump();
        await ref.read(inventoryListProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final row = rows[index];
          return _InventoryTile(row: row, maySeeCost: maySeeCost);
        },
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.row, required this.maySeeCost});

  final InventoryRow row;
  final bool maySeeCost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicine = row.medicine;
    final alerts = <Widget>[
      if (row.isLow) const _Badge(text: 'LOW', tone: BadgeTone.warning),
      if (row.expiringBatchCount > 0)
        _Badge(
          text: '${row.expiringBatchCount} expiring',
          tone: BadgeTone.danger,
        ),
      if (row.neverStocked)
        const _Badge(text: 'NO STOCK', tone: BadgeTone.neutral),
    ];

    return ListTile(
      onTap: () => showMedicineBatches(context, medicine),
      title: Text(medicine.tradeName),
      subtitle: _Subtitle(
        genericName: medicine.genericName,
        detail: _detailLine(row, maySeeCost),
        alerts: alerts,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            row.stockLabel,
            textAlign: TextAlign.end,
            style: theme.textTheme.titleSmall?.copyWith(
              color: row.outOfStock
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(row.baseUnitName, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  /// One line: where it sits, what kind of thing it is, what it is worth.
  ///
  /// The value is the batch-weighted stock valuation, not an averaged guess, and
  /// it only renders for roles holding `viewCostPrice` — a cashier at this screen
  /// has no business seeing what the shop paid.
  static String _detailLine(InventoryRow row, bool maySeeCost) {
    final parts = <String>[
      if ((row.medicine.shelfLocation ?? '').isNotEmpty)
        'Shelf ${row.medicine.shelfLocation}',
      if ((row.medicine.category ?? '').isNotEmpty) row.medicine.category!,
      if (maySeeCost && !row.outOfStock)
        'stock value ${formatMoney(row.stockValuePya)} K',
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

/// Generic name, then detail, then alert badges.
class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.genericName,
    required this.detail,
    required this.alerts,
  });

  final String? genericName;
  final String detail;
  final List<Widget> alerts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (genericName != null && genericName!.isNotEmpty)
          Text(
            genericName!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        Text(detail, style: theme.textTheme.bodySmall),
        if (alerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 6, children: alerts),
          ),
      ],
    );
  }
}

enum BadgeTone { neutral, warning, danger }

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.tone});

  final String text;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (tone) {
      BadgeTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      BadgeTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      BadgeTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hasFilter, required this.canManage});

  final bool hasFilter;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(
          hasFilter
              ? Icons.filter_alt_off_outlined
              : Icons.inventory_2_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(
          hasFilter ? 'Nothing matches this filter.' : 'No medicines yet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          hasFilter
              ? 'Clear the search box to see the full list.'
              : canManage
              ? 'Add the first one, then record a delivery to put stock on the '
                    'shelf.'
              : 'Ask the owner to add medicines and record a delivery.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'The inventory could not be read.',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, maxLines: 4),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => onRetry(),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
