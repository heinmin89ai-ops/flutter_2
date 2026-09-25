import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/credit_transactions.dart';
import '../../../core/l10n/l10n_bridge.dart';
import '../../../core/money.dart';
import '../../../core/presentation/money_field.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../application/credit_providers.dart';
import '../data/credit_repository.dart';

/// Receivables / payables list (Phase 5 brief item 1).
///
/// One screen serves both directions of Module 6's ledger: a customer list whose
/// balances are money coming *in*, and a supplier list whose balances are money
/// going *out*. Everything about them is the same shape — a list of parties with
/// an outstanding balance, a statement per party, and a cash payment entry — so
/// the two routes differ only in the [PartyType] they pass and the nouns they
/// print. Forking them into two files is how the two drift apart and one of them
/// stops posting to the ledger.
///
/// The balances come from the materialised `current_debt` / `current_payable`
/// columns, which the v3→4 migration and both `recalculate*` oracles keep equal to
/// the `credit_transactions` sums; this screen never re-adds a ledger by hand.
class PartyCreditScreen extends ConsumerStatefulWidget {
  const PartyCreditScreen({super.key, required this.partyType});

  final PartyType partyType;

  @override
  ConsumerState<PartyCreditScreen> createState() => _PartyCreditScreenState();
}

class _PartyCreditScreenState extends ConsumerState<PartyCreditScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  PartyType get _type => widget.partyType;

  /// The screen's whole vocabulary, keyed on direction.
  ({String title, String partyWord, String balanceWord, String totalWord})
  get _labels => switch (_type) {
    PartyType.customer => (
      title: context.l10n.creditCustomerTitle,
      partyWord: context.l10n.creditWordCustomer,
      balanceWord: context.l10n.creditOwes,
      totalWord: context.l10n.creditTotalReceivable,
    ),
    PartyType.supplier => (
      title: context.l10n.creditSupplierTitle,
      partyWord: context.l10n.creditWordSupplier,
      balanceWord: context.l10n.creditIsOwed,
      totalWord: context.l10n.creditTotalPayable,
    ),
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(inventoryRevisionProvider.notifier).bump();
    await ref.read(
      _type == PartyType.customer ? debtorsProvider : payablesProvider.future,
    );
  }

  Future<void> _openStatement(PartyBalance party) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            PartyStatementScreen(partyType: _type, party: party),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _type == PartyType.customer
        ? debtorsProvider
        : payablesProvider;
    final rows = ref.watch(provider);
    final labels = _labels;
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(labels.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.creditSearchHint(labels.partyWord),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: rows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.describe(e))),
              data: (parties) {
                final shown = _filter(parties);
                if (shown.isEmpty) {
                  return Center(
                    child: Text(
                      parties.isEmpty
                          ? _type == PartyType.customer
                                ? l10n.creditNobodyOwesShop
                                : l10n.creditShopOwesNobody
                          : l10n.creditNoMatches(labels.partyWord, _query),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: shown.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    // The totals live inside the same list so the figure is never
                    // cut off by a scroll, and it is the *filtered* set's total —
                    // searching a name then shows what that search owes.
                    if (index == 0) {
                      return _TotalHeader(
                        label: _query.isEmpty
                            ? labels.totalWord
                            : l10n.creditTotalForSearch(labels.totalWord),
                        totalPya: shown.fold<Pya>(
                          0,
                          (sum, p) => sum + p.balancePya,
                        ),
                        theme: theme,
                      );
                    }
                    final party = shown[index - 1];
                    return ListTile(
                      title: Text(party.name),
                      subtitle: Text(
                        [
                          if ((party.phone ?? '').isNotEmpty) party.phone!,
                          l10n.creditBalanceLine(
                            labels.balanceWord,
                            formatMoney(party.balancePya),
                          ),
                        ].join(' · '),
                      ),
                      trailing: _OverLimitPill(party: party),
                      onTap: () => _openStatement(party),
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

  List<PartyBalance> _filter(List<PartyBalance> parties) {
    final needle = _query.toLowerCase();
    if (needle.isEmpty) return parties;
    return [
      for (final p in parties)
        if (p.name.toLowerCase().contains(needle) ||
            (p.phone?.contains(needle) ?? false))
          p,
    ];
  }
}

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({
    required this.label,
    required this.totalPya,
    required this.theme,
  });

  final String label;
  final Pya totalPya;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        '${formatMoney(totalPya)} K',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Marks a customer past their agreed ceiling, the fact Module 6 exists to catch.
class _OverLimitPill extends StatelessWidget {
  const _OverLimitPill({required this.party});

  final PartyBalance party;

  @override
  Widget build(BuildContext context) {
    final used = party.utilisation;
    if (used == null) return const SizedBox.shrink();
    final over = used > 1.0;
    final scheme = Theme.of(context).colorScheme;
    final tone = over ? scheme.errorContainer : scheme.surfaceContainerHighest;
    final onTone = over ? scheme.onErrorContainer : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${(used * 100).round()}%',
        style: TextStyle(color: onTone, fontSize: 12),
      ),
    );
  }
}

/// One party's statement and its payment entry.
///
/// Reached from the list; the parent bumps the revision counter on return so the
/// balances shown there are the post-payment ones.
class PartyStatementScreen extends ConsumerStatefulWidget {
  const PartyStatementScreen({
    super.key,
    required this.partyType,
    required this.party,
  });

  final PartyType partyType;
  final PartyBalance party;

  @override
  ConsumerState<PartyStatementScreen> createState() =>
      _PartyStatementScreenState();
}

class _PartyStatementScreenState extends ConsumerState<PartyStatementScreen> {
  bool _busy = false;

  Future<void> _recordPayment() async {
    Pya? amount;
    final note = TextEditingController();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.creditRecordPaymentTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.partyType == PartyType.customer
                  ? l10n.creditCustomerOwesNow(
                      widget.party.name,
                      formatMoney(widget.party.balancePya),
                    )
                  : l10n.creditSupplierOwedNow(
                      widget.party.name,
                      formatMoney(widget.party.balancePya),
                    ),
            ),
            const SizedBox(height: 12),
            MoneyField(
              label: l10n.creditAmountReceived,
              suffix: 'K',
              allowEmpty: false,
              autofocus: true,
              onChanged: (value) => amount = value,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: l10n.creditReferenceNote,
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
            child: Text(l10n.record),
          ),
        ],
      ),
    );
    final typed = amount;
    if (confirmed != true || typed == null) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(creditRepositoryProvider);
      if (widget.partyType == PartyType.customer) {
        await repo.recordCustomerPayment(
          customerId: widget.party.id,
          amountPya: typed,
          recordedByUserId: ref.read(authProvider)?.id,
          note: note.text,
        );
      } else {
        await repo.recordSupplierPayment(
          supplierId: widget.party.id,
          amountPya: typed,
          recordedByUserId: ref.read(authProvider)?.id,
          note: note.text,
        );
      }
      ref.read(inventoryRevisionProvider.notifier).bump();
      if (!mounted) return;
      _toast(context.l10n.creditPaymentRecorded);
      await _reload();
    } on CreditRejectException catch (e) {
      if (mounted) _toast(context.l10n.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    await ref.read(
      statementProvider((widget.partyType, widget.party.id)).future,
    );
  }

  Future<void> _reverse(StatementEntry entry) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.creditReversePaymentTitle),
        content: Text(
          l10n.creditReversePaymentBody(
            formatMoney(entry.transaction.amount),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.creditReverse),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(creditRepositoryProvider)
          .reversePayment(
            transactionId: entry.transaction.id,
            performedByUserId: ref.read(authProvider)?.id,
          );
      ref.read(inventoryRevisionProvider.notifier).bump();
      if (!mounted) return;
      _toast(context.l10n.creditPaymentReversed);
      await _reload();
    } on CreditRejectException catch (e) {
      if (mounted) _toast(context.l10n.describe(e));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // The live balance is re-read through the statement provider rather than the
    // [widget.party] snapshot the route was pushed with, so a payment recorded
    // here updates the header without a pop.
    final statement = ref.watch(
      statementProvider((widget.partyType, widget.party.id)),
    );
    final mayReverse = ref.watch(canDeleteTransactionProvider);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.party.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _recordPayment,
        icon: const Icon(Icons.payments_outlined),
        label: Text(l10n.creditRecordPayment),
      ),
      body: statement.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.describe(e))),
        data: (entries) {
          final remaining = entries.isEmpty
              ? widget.party.balancePya
              : entries.last.runningBalancePya;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              ListTile(
                title: Text(l10n.creditOutstanding,
                    style: theme.textTheme.titleSmall),
                trailing: Text(
                  '${formatMoney(remaining)} K',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(l10n.creditStatement),
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.creditNoLedgerActivity),
                ),
              for (final entry in entries.reversed)
                _StatementTile(
                  entry: entry,
                  mayReverse: mayReverse,
                  onReverse: () => _reverse(entry),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatementTile extends StatelessWidget {
  const _StatementTile({
    required this.entry,
    required this.mayReverse,
    required this.onReverse,
  });

  final StatementEntry entry;
  final bool mayReverse;
  final VoidCallback onReverse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final txn = entry.transaction;
    final isDebt = txn.kind == TransactionKind.debtAdded;
    final colour = isDebt
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return ListTile(
      dense: true,
      leading: Icon(
        isDebt ? Icons.add_circle_outline : Icons.check_circle_outline,
        color: colour,
      ),
      title: Text(isDebt ? l10n.creditDebtAdded : l10n.creditPaymentReceived),
      subtitle: Text(_subtitle(txn.createdAt, txn.note)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${entry.signedAmountPya >= 0 ? '+' : '−'}'
            '${formatMoney(entry.signedAmountPya.abs())} K',
            style: theme.textTheme.titleSmall?.copyWith(color: colour),
          ),
          // Only a payment can be reversed, and only by the delete-transaction
          // role — the repository refuses a `debt_added` regardless, so this is
          // the visual half of a rule the data layer already holds.
          if (mayReverse && !isDebt)
            IconButton(
              tooltip: l10n.creditReversePaymentTooltip,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.undo),
              onPressed: onReverse,
            ),
        ],
      ),
    );
  }

  String _subtitle(DateTime when, String? note) {
    final stamp =
        '${when.year}-${_two(when.month)}-${_two(when.day)} '
        '${_two(when.hour)}:${_two(when.minute)}';
    return note == null || note.isEmpty ? stamp : '$stamp · $note';
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
