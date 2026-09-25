import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_bridge.dart';
import '../../../core/money.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/data/inventory_repository.dart';
import '../application/report_providers.dart';
import '../data/report_repository.dart';

/// Admin-only profit dashboard (Phase 5 brief item 2).
///
/// The four figures the brief names — today's total sales, net profit, low-stock
/// alerts and stock expiring within 60 days — come from a *single*
/// [DailyReport] rather than four providers. That is deliberate: they all share
/// one `[dayStart, dayEnd)` window, and assembling them separately is how a
/// report ends up printing today's sales next to yesterday's expenses. The
/// repository already guarantees the four describe the same day, so this screen
/// only ever renders that one object.
///
/// Reached only through a route the guard gates on `viewProfitReports`, so a
/// cashier never sees it at all; the dashboard's own link is hidden by the same
/// permission.
class ReportDashboardScreen extends ConsumerWidget {
  const ReportDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(dailyReportProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitleToday)),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(inventoryRevisionProvider.notifier).bump(),
        child: report.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('$e')),
            ],
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatBand(
                children: [
                  _StatTile(
                    label: l10n.reportSalesToday,
                    value: '${formatMoney(data.totalSalesPya)} K',
                    caption: l10n.reportVoucherCount(data.voucherCount),
                  ),
                  _StatTile(
                    label: l10n.reportNetProfit,
                    value: '${formatMoney(data.netProfitPya)} K',
                    caption: l10n.reportNetProfitFormula,
                    emphasis: data.netProfitPya >= 0
                        ? Emphasis.good
                        : Emphasis.bad,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatBand(
                children: [
                  _StatTile(
                    label: l10n.reportReceivable,
                    value: '${formatMoney(data.receivablePya)} K',
                    caption: l10n.reportReceivableCaption,
                  ),
                  _StatTile(
                    label: l10n.reportPayable,
                    value: '${formatMoney(data.payablePya)} K',
                    caption: l10n.reportPayableCaption,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ProfitBreakdown(report: data),
              const SizedBox(height: 20),
              _AlertSection(
                icon: Icons.warning_amber_rounded,
                title: l10n.reportLowStock,
                count: data.lowStock.length,
                empty: l10n.reportLowStockEmpty,
                items: [
                  for (final r in data.lowStock) _lowStockLine(context, r),
                ],
              ),
              const SizedBox(height: 12),
              _AlertSection(
                icon: Icons.event_busy_outlined,
                title: l10n.reportExpiringWithinDays(
                  ReportRepository.kExpiringWindowDays,
                ),
                count: data.expiringSoon.length,
                empty: l10n.reportExpiringEmpty,
                items: [
                  for (final b in data.expiringSoon) _expiringLine(context, b),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lowStockLine(BuildContext context, InventoryRow row) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.medicine.tradeName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            row.stockLabel,
            style: TextStyle(
              color: row.outOfStock ? theme.colorScheme.error : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expiringLine(BuildContext context, StockBatch batch) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final days = batch.daysToExpiry;
    final label = batch.isExpired
        ? l10n.reportExpiredDaysAgo(-days)
        : l10n.reportDaysLeft(days);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              batch.tradeName ?? l10n.reportBatchNumber(batch.batch.id),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(batch.humanQuantity, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: batch.isExpired
                  ? theme.colorScheme.error
                  : theme.colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The arithmetic behind the net-profit headline, shown rather than hidden.
///
/// An owner who sees "Net profit 14,200 K" and does not trust it is the owner who
/// stops using the report. Laying sales, COGS and expenses out as a subtracted
/// ladder lets them check the number against their own rough figures in seconds.
class _ProfitBreakdown extends StatelessWidget {
  const _ProfitBreakdown({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reportProfitBuildTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _line(context, l10n.reportTotalSales, report.totalSalesPya, positive: true),
            _line(context, l10n.reportMinusCostOfGoods, -report.costOfGoodsSoldPya),
            _line(context, l10n.reportMinusExpenses, -report.expensesPya),
            const Divider(),
            _line(
              context,
              l10n.reportNetProfit,
              report.netProfitPya,
              emphasise: true,
              positive: report.netProfitPya >= 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    Pya amount, {
    bool emphasise = false,
    bool positive = false,
  }) {
    final theme = Theme.of(context);
    final colour = emphasise
        ? (positive ? theme.colorScheme.primary : theme.colorScheme.error)
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasise ? theme.textTheme.titleMedium : null,
            ),
          ),
          Text(
            '${formatMoney(amount)} K',
            style: TextStyle(
              color: colour,
              fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

enum Emphasis { none, good, bad }

class _StatBand extends StatelessWidget {
  const _StatBand({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.caption,
    this.emphasis = Emphasis.none,
  });

  final String label;
  final String value;
  final String caption;
  final Emphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (emphasis) {
      Emphasis.good => theme.colorScheme.primary,
      Emphasis.bad => theme.colorScheme.error,
      Emphasis.none => theme.colorScheme.onSurface,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertSection extends StatelessWidget {
  const _AlertSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.empty,
    required this.items,
  });

  final IconData icon;
  final String title;
  final int count;
  final String empty;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
                const Spacer(),
                Text(
                  '$count',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: count == 0
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(empty, style: theme.textTheme.bodySmall)
            else
              ...items.take(8),
            if (items.length > 8)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  context.l10n.reportAndMoreCount(items.length - 8),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
