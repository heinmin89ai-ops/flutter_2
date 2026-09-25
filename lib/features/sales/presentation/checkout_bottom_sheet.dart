import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/sales.dart';
import '../../../core/l10n/l10n_bridge.dart';
import '../../../core/money.dart';
import '../../../core/presentation/money_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/application/unit_hierarchy.dart';
import '../application/cart_controller.dart';
import '../application/pos_providers.dart';
import '../data/printer_service.dart';
import '../data/sale_repository.dart';

/// Checkout (Phase 4 brief item 3): received amount, Cash/KPay, change, and the
/// sale commit.
///
/// This is where the cart's arithmetic becomes a voucher. It deliberately owns
/// the *payment* decisions the cart does not — method, how much was handed over,
/// whether a balance goes on credit to a customer — because those are the fields
/// a shop argues about at closing, so they are captured here, on one screen, and
/// handed to `SaleRepository.completeSale` which is the only thing allowed to
/// write a sale.
Future<void> showCheckout(BuildContext context) {
  final cart = ProviderScope.containerOf(context).read(cartProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CheckoutSheet(initialMode: cart.mode),
  );
}

class _CheckoutSheet extends ConsumerStatefulWidget {
  const _CheckoutSheet({required this.initialMode});

  final SaleMode initialMode;

  @override
  ConsumerState<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<_CheckoutSheet> {
  PaymentMethod _method = PaymentMethod.cash;
  Pya? _receivedPya;
  Customer? _customer;
  bool _busy = false;
  String? _error;

  /// Cash tendered, defaulting to the exact total so the common "counted the
  /// notes, gives exactly" flow needs no typing.
  Pya get _received => _receivedPya ?? _total;

  Pya get _total => ref.read(cartProvider).totalPya;

  Pya get _shortfall {
    final due = _total - _received;
    return due > 0 ? due : 0;
  }

  Pya get _change => _received > _total ? _received - _total : 0;

  bool get _isCredit => _shortfall > 0;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final mayCredit = ref.watch(canSellOnCreditProvider);

    // Keyboard padding so the amount field is not hidden on a phone till.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.checkout, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                // The mode is named through `l10n` rather than `cart.mode.name`:
                // an enum's `name` is English by construction, so printing it
                // would leak "wholesale" onto a Burmese till.
                cart.isEmpty
                    ? l10n.saleCartEmpty
                    : '${l10n.saleCartLines(cart.lineCount)}'
                          ' · ${cart.mode == SaleMode.wholesale ? l10n.wholesale : l10n.retail}'
                          ' · ${l10n.total} ${formatMoney(_total)} K',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _PaymentMethodToggle(
                method: _method,
                onChanged: (m) => setState(() {
                  _method = m;
                  // A wallet payment is never tendered-with-change; reset so the
                  // received figure cannot linger and mis-report the drawer.
                  _receivedPya = null;
                }),
              ),
              const SizedBox(height: 16),
              MoneyField(
                label: l10n.saleReceivedLabel,
                suffix: 'K',
                allowEmpty: true,
                onChanged: (pya) => setState(() => _receivedPya = pya),
              ),
              const SizedBox(height: 12),
              _Totals(
                total: _total,
                received: _received,
                change: _change,
                shortfall: _shortfall,
              ),
              if (mayCredit)
                _CreditPicker(
                  enabled: _isCredit,
                  customer: _customer,
                  onPick: () => _pickCustomer(),
                  onClear: () => setState(() => _customer = null),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (cart.isEmpty || _busy) ? null : _commit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _submitLabel {
    final l10n = context.l10n;
    if (_isCredit) {
      return l10n.saleChargeOnCredit(formatMoney(_shortfall));
    }
    return l10n.saleCompleteSale;
  }

  Future<void> _pickCustomer() async {
    final l10n = context.l10n;
    final customers = await ref.read(customerListProvider.future);
    if (!mounted) return;
    if (customers.isEmpty) {
      setState(() => _error = l10n.saleNoCustomersYet(l10n.customerCredit));
      return;
    }
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l10n.saleChargeThisSaleTo),
            ),
            const Divider(height: 1),
            for (final c in customers)
              ListTile(
                title: Text(c.name),
                subtitle: Text(
                  l10n.saleDebtAndLimit(
                    formatMoney(c.currentDebt),
                    formatMoney(c.creditLimit),
                  ),
                ),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _customer = picked);
  }

  /// Builds sale lines from the cart and commits. Kept in the sheet so the money
  /// the customer sees is exactly the money handed to the repository.
  Future<void> _commit() async {
    final l10n = context.l10n;
    final cart = ref.read(cartProvider);
    final cashierId = ref.read(currentCashierIdProvider);
    if (cashierId == null) {
      setState(() => _error = l10n.saleSessionExpired);
      return;
    }
    if (_isCredit && _customer == null) {
      setState(() => _error = l10n.saleChooseCustomerForBalance);
      return;
    }
    if (_isCredit && _method == PaymentMethod.kpay) {
      setState(() => _error = l10n.saleKpayFullPayment);
      return;
    }

    final lines = [
      for (final l in cart.lines)
        NewSaleLine(
          medicineId: l.medicineId,
          unitConversionId: l.unitConversionId,
          unitName: l.unitName,
          conversionFactor: l.conversionFactor,
          quantity: l.quantity,
          unitPricePya: l.unitPricePya,
        ),
    ];

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final customerName = _isCredit ? _customer?.name : null;
      final receipt = await ref
          .read(saleRepositoryProvider)
          .completeSale(
            lines: lines,
            mode: cart.mode,
            discountPya: cart.discountPya,
            paymentMethod: _method,
            receivedPya: _received,
            customerId: _isCredit ? _customer?.id : null,
            cashierUserId: cashierId,
          );
      // The shelf changed; make every cached read re-run before any screen can
      // show a stale stock figure.
      ref.read(inventoryRevisionProvider.notifier).bump();
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      // Show the confirmation from this (still live) context while the cart is
      // already cleared, then dismiss the sheet underneath it. Popping first
      // would leave us calling showDialog on a defunct context. The customer
      // name was resolved above because `_isCredit` reads the cart, which is
      // now empty.
      await _showConfirmation(receipt, cart, customerName: customerName);
      if (mounted) Navigator.of(context).pop();
    } on SaleRejectException catch (e) {
      // `describe` resolves the exception's `sale*` key in the cashier's language;
      // `e.message` would have pinned the refusal to English.
      if (mounted) setState(() => _error = l10n.describe(e));
    } on SaleShortageException catch (e) {
      if (mounted) setState(() => _error = l10n.describe(e));
    } catch (e) {
      if (mounted) {
        setState(() => _error = l10n.saleCouldNotComplete(l10n.describe(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showConfirmation(
    SaleReceipt receipt,
    CartState cart, {
    String? customerName,
  }) async {
    final l10n = context.l10n;
    final cashier = ref.read(authProvider);
    final nameById = <int, String>{
      for (final l in cart.lines) l.medicineId: l.tradeName,
    };
    final printer = const PrinterService();
    final lines = printer.buildLines(
      receipt.lines,
      // The cart is already cleared by the time the voucher is built, so a line
      // whose product name was never cached falls back to a named id.
      (id) => nameById[id] ?? l10n.saleItemFallback('$id'),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _SaleConfirmedDialog(
        receipt: receipt,
        cashierName: cashier?.username ?? l10n.saleStaff,
        customerName: customerName,
        lines: lines,
      ),
    );
  }
}

/// Every word the PDF voucher prints, resolved here rather than in
/// [PrinterService]: the service renders bytes with no locale in hand, so the
/// sheet that owns the `BuildContext` supplies the strings and the service stays
/// free of a translation dependency, exactly as it stays free of the name join.
VoucherLabels _voucherLabels(AppLocalizations l10n) => VoucherLabels(
  voucher: l10n.saleVoucher,
  date: l10n.saleVoucherDateLabel,
  customer: l10n.saleVoucherCustomerLabel,
  cashier: l10n.saleVoucherCashierLabel,
  type: l10n.saleVoucherTypeLabel,
  subtotal: l10n.subtotal,
  discount: l10n.discount,
  total: l10n.total,
  cash: l10n.saleCash,
  // A product name, not a translatable word — same in both locales.
  kpay: 'KPay',
  change: l10n.saleChange,
  balanceDue: l10n.saleVoucherBalanceDue,
  itemHeader: l10n.saleVoucherItemHeader,
  qtyHeader: l10n.saleVoucherQtyHeader,
  priceHeader: l10n.saleVoucherPriceHeader,
  thankYou: l10n.saleVoucherThankYou,
);

class _PaymentMethodToggle extends StatelessWidget {
  const _PaymentMethodToggle({required this.method, required this.onChanged});

  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PaymentMethod>(
      segments: [
        ButtonSegment(
          value: PaymentMethod.cash,
          label: Text(context.l10n.saleCash),
          icon: const Icon(Icons.payments_outlined),
        ),
        ButtonSegment(
          value: PaymentMethod.kpay,
          // Brand name — deliberately not localised.
          label: const Text('KPay'),
          icon: const Icon(Icons.qr_code_2),
        ),
      ],
      selected: {method},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.total,
    required this.received,
    required this.change,
    required this.shortfall,
  });

  final Pya total;
  final Pya received;
  final Pya change;
  final Pya shortfall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _line(theme, l10n.total, '${formatMoney(total)} K', bold: true),
          if (shortfall > 0)
            _line(
              theme,
              l10n.saleBalanceOnCredit,
              '${formatMoney(shortfall)} K',
              tone: theme.colorScheme.error,
            )
          else
            _line(theme, l10n.saleChange, '${formatMoney(change)} K'),
        ],
      ),
    );
  }

  Widget _line(
    ThemeData theme,
    String label,
    String value, {
    bool bold = false,
    Color? tone,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style:
                (bold
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      fontWeight: bold ? FontWeight.w700 : null,
                      color: tone,
                    ),
          ),
        ],
      ),
    );
  }
}

class _CreditPicker extends StatelessWidget {
  const _CreditPicker({
    required this.enabled,
    required this.customer,
    required this.onPick,
    required this.onClear,
  });

  final bool enabled;
  final Customer? customer;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          enabled ? Icons.warning_amber_rounded : Icons.person_outline,
          color: enabled ? theme.colorScheme.error : null,
        ),
        title: Text(
          customer?.name ??
              (enabled ? l10n.salePickACustomer : l10n.salePaidInFull),
        ),
        subtitle: enabled && customer != null
            ? Text(l10n.saleCarriesBalance(customer!.name))
            : null,
        trailing: customer != null
            ? IconButton(
                tooltip: l10n.saleClear,
                icon: const Icon(Icons.close),
                onPressed: onClear,
              )
            : (enabled
                  ? TextButton(onPressed: onPick, child: Text(l10n.saleChoose))
                  : null),
      ),
    );
  }
}

/// Post-sale confirmation with the voucher number and a print/share action.
class _SaleConfirmedDialog extends ConsumerStatefulWidget {
  const _SaleConfirmedDialog({
    required this.receipt,
    required this.cashierName,
    required this.customerName,
    required this.lines,
  });

  final SaleReceipt receipt;
  final String cashierName;
  final String? customerName;
  final List<ReceiptLine> lines;

  @override
  ConsumerState<_SaleConfirmedDialog> createState() =>
      _SaleConfirmedDialogState();
}

class _SaleConfirmedDialogState extends ConsumerState<_SaleConfirmedDialog> {
  bool _printing = false;
  String? _note;

  Future<void> _print() async {
    final l10n = context.l10n;
    setState(() {
      _printing = true;
      _note = null;
    });
    try {
      final voucher = await const PrinterService().renderVoucher(
        receipt: widget.receipt,
        lines: widget.lines,
        cashierName: widget.cashierName,
        labels: _voucherLabels(l10n),
        shopName: l10n.saleVoucherShopName,
        customerName: widget.customerName,
      );
      // The renderer produced real PDF bytes; handing them to a share sheet or a
      // thermal/`printing` plugin is the on-device wiring deferred in
      // docs/PHASE4_SALES.md. The voucher number and byte length prove the render
      // path is live and complete.
      if (!mounted) return;
      setState(
        () => _note = l10n.saleVoucherReady(
          voucher.fileName,
          '${voucher.bytes.length}',
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _note = l10n.saleVoucherBuildFailed(l10n.describe(e)));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final sale = widget.receipt.sale;
    return AlertDialog(
      title: Text(l10n.saleConfirmedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.saleVoucherNumber(sale.voucherNo),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(l10n.saleTotalAmount(formatMoney(widget.receipt.totalPya))),
          if (widget.receipt.changePya > 0)
            Text(l10n.saleChangeAmount(formatMoney(widget.receipt.changePya))),
          if (widget.receipt.creditPya > 0)
            Text(
              l10n.saleOnCreditAmount(formatMoney(widget.receipt.creditPya)),
            ),
          if (_note != null) ...[
            const SizedBox(height: 8),
            Text(_note!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.saleNewSale),
        ),
        FilledButton.icon(
          onPressed: _printing ? null : _print,
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(l10n.saleVoucher),
        ),
      ],
    );
  }
}
