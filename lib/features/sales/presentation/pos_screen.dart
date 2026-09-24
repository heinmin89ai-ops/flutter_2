import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/money.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/application/unit_hierarchy.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../scanning/application/scan_resolution.dart';
import '../../scanning/presentation/scanner_screen.dart';
import '../application/cart_controller.dart';
import '../application/pos_providers.dart';
import 'checkout_bottom_sheet.dart';

/// Point of sale (Phase 4 brief item 3).
///
/// Layout: a search/scan bar and the product grid on the left, a live cart pane
/// on the right, a Retail/Wholesale switch across the top. The whole screen is a
/// thin view over [cartProvider] — every number a cashier sees is the cart's, and
/// the cart only ever holds prices resolved from real `unit_conversions` rows.
///
/// **Two scanning paths, one resolution.** A Bluetooth/USB barcode gun is a HID
/// keyboard: it types the code and presses Enter, and the search field's submit
/// handler tries an exact barcode match first. Phase 6 added the camera path —
/// the AppBar scanner button opens [ScannerScreen] (`mobile_scanner`) and feeds
/// the raw code through the same exact-barcode decision as [resolveScan], so a
/// camera read and a hardware scan cannot disagree about what a code means. Both
/// remain an *exact* `medicines.barcode` match: the till's `findByBarcode` uses
/// equality, not `LIKE`, because a partial scan adding the wrong product is worse
/// than asking the cashier to search.
class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends ConsumerState<POSScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.read(inventoryRevisionProvider.notifier).bump();
    await ref.read(posCatalogProvider.future);
  }

  /// Enter/scan: an exact barcode wins, otherwise the visible top result is added.
  Future<void> _onSearchSubmitted() async {
    final l10n = AppLocalizations.of(context);
    final code = _search.text.trim();
    if (code.isEmpty) return;
    final matches = _visible(ref.read(posCatalogProvider).value ?? const []);
    if (matches.isEmpty) {
      _toast(l10n.noProductMatches(code));
      return;
    }
    await _add(matches.first);
    _search.clear();
    setState(() => _query = '');
  }

  List<CatalogEntry> _visible(List<CatalogEntry> all) {
    final needle = _query.toLowerCase();
    if (needle.isEmpty) return all;
    return [
      for (final e in all)
        if (e.medicine.tradeName.toLowerCase().contains(needle) ||
            (e.medicine.genericName?.toLowerCase().contains(needle) ?? false) ||
            (e.medicine.barcode?.contains(needle) ?? false))
          e,
    ];
  }

  Future<void> _add(CatalogEntry entry) async {
    if (!entry.sellable) {
      _toast(AppLocalizations.of(context).noUnitsYet(entry.medicine.tradeName));
      return;
    }
    ref
        .read(cartProvider.notifier)
        .add(
          CartAddRequest(
            medicineId: entry.medicine.id,
            tradeName: entry.medicine.tradeName,
            units: entry.hierarchy!.units,
          ),
        );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Handle camera scan result
  Future<void> _handleCameraScan() async {
    final l10n = AppLocalizations.of(context);
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (code == null) return;

    // Use the same resolution logic as keyboard search
    final result = resolveScan(
      code: code,
      findByBarcode: (barcode) {
        final catalog = ref.read(posCatalogProvider).value ?? const [];
        for (final entry in catalog) {
          if (entry.medicine.barcode == barcode) {
            return entry.medicine.id;
          }
        }
        return null;
      },
    );

    switch (result) {
      case ScanResult.addProduct:
        // Find the entry and add to cart
        final catalog = ref.read(posCatalogProvider).value ?? const [];
        for (final entry in catalog) {
          if (entry.medicine.barcode == code) {
            await _add(entry);
            break;
          }
        }
        break;
      case ScanResult.showNotFound:
        _toast(l10n.noProductMatches(code));
        break;
      case ScanResult.ignoreEmpty:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(posCatalogProvider);
    final cart = ref.watch(cartProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pointOfSale),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _handleCameraScan,
            tooltip: l10n.scanBarcode,
          ),
          // Retail / Wholesale switch, the cart's mode. Changing it re-prices
          // every line already on the ticket.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<SaleMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: SaleMode.retail, label: Text(l10n.retail)),
                ButtonSegment(
                  value: SaleMode.wholesale,
                  label: Text(l10n.wholesale),
                ),
              ],
              selected: {cart.mode},
              onSelectionChanged: (s) =>
                  ref.read(cartProvider.notifier).setMode(s.first),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      autofocus: true,
                      // Keep a hardware scanner's Enter from also firing a
                      // system beep; we handle submit ourselves.
                      onSubmitted: (_) => _onSearchSubmitted(),
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
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
                      onChanged: (value) {
                        _search.text = value;
                        setState(() => _query = value.trim());
                      },
                    ),
                  ),
                  Expanded(
                    child: catalog.when(
                      data: (rows) => _Grid(
                        entries: _visible(rows),
                        onAdd: _add,
                        onSearchChanged: (v) => setState(() => _query = v),
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          _Failure(message: '$e', onRetry: _refresh),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 340,
              child: _CartPane(
                cart: cart,
                onCheckout: () => showCheckout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.entries,
    required this.onAdd,
    required this.onSearchChanged,
  });

  final List<CatalogEntry> entries;
  final void Function(CatalogEntry) onAdd;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Nothing matches. Clear the search to see the catalogue.'),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) =>
          _ProductCard(entry: entries[index], onAdd: onAdd),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.entry, required this.onAdd});

  final CatalogEntry entry;
  final void Function(CatalogEntry) onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medicine = entry.medicine;
    final hierarchy = entry.hierarchy;
    final sellable = entry.sellable;
    // Show the base-unit price as the card's headline figure; the exact unit is
    // chosen on the cart line, so this is the "from ___" anchor, not a quote.
    final headline = sellable
        ? '${formatMoney(hierarchy!.priceFor(unit: hierarchy.base, mode: SaleMode.retail))} K / ${hierarchy.base.name}'
        : 'no units set';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: sellable ? () => onAdd(entry) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medicine.tradeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                headline,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: sellable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartPane extends ConsumerWidget {
  const _CartPane({required this.cart, required this.onCheckout});

  final CartState cart;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(cartProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Text(
                    l10n.tapToStart,
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = cart.lines[index];
                    return _CartLineTile(
                      line: line,
                      onQuantity: (qty) => controller.setQuantity(
                        line.medicineId,
                        line.unitConversionId,
                        qty,
                      ),
                      onUnit: (unit) => controller.switchUnit(
                        line.medicineId,
                        line.unitConversionId,
                        unit,
                      ),
                      onRemove: () => controller.removeLine(
                        line.medicineId,
                        line.unitConversionId,
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _money(context, l10n.subtotal, cart.subtotalPya),
              _DiscountRow(
                current: cart.discountPya,
                invalid: cart.discountExceedsSubtotal,
                onChanged: controller.setDiscount,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.total, style: theme.textTheme.titleMedium),
                  Text(
                    '${formatMoney(cart.totalPya)} K',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: cart.isEmpty ? null : onCheckout,
                icon: const Icon(Icons.credit_card),
                label: Text(l10n.checkout),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _money(BuildContext context, String label, Pya pya) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text('${formatMoney(pya)} K'),
        ],
      ),
    );
  }
}

/// One cart line with quantity steppers and the unit switch.
class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onQuantity,
    required this.onUnit,
    required this.onRemove,
  });

  final CartLine line;
  final ValueChanged<int> onQuantity;
  final ValueChanged<UnitSpec> onUnit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(
        line.tradeName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Row(
        children: [
          // Unit switcher: tap to pick Box/Strip/Tablet; price follows.
          InkWell(
            onTap: () => _pickUnit(context),
            child: Row(
              children: [
                Text(
                  '${line.quantity} ${line.unitName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${formatMoney(line.lineTotalPya)} K',
            style: theme.textTheme.titleSmall,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onQuantity(line.quantity - 1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => onQuantity(line.quantity + 1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows this line's medicine units and hands the chosen one back. The unit
  /// list is reconstructed from the line's own frozen fields, so the picker
  /// cannot offer a unit that was never priced onto the ticket.
  Future<void> _pickUnit(BuildContext context) async {
    // The line carries only its current unit; the sibling units come from the
    // catalogue entry the screen resolved. We rebuild the switch options from
    // what the cart already knows is safe to sell, which is the whole point of
    // keeping prices on the line.
    final units = _unitsFor(context, line);
    if (units.length < 2) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('This product has one sellable unit.')),
        );
      return;
    }
    final picked = await showDialog<UnitSpec>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Sell ${line.tradeName} as'),
        children: [
          for (final u in units)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(u),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${u.name}  ·  ${formatMoney(u.retailPricePya)} K'),
              ),
            ),
        ],
      ),
    );
    if (picked != null) onUnit(picked);
  }
}

/// Resolve the full unit list for [line]'s medicine from the live catalogue.
List<UnitSpec> _unitsFor(BuildContext context, CartLine line) {
  final entries = ProviderScope.containerOf(context)
      .read(posCatalogProvider)
      .value;
  if (entries == null) return const [];
  for (final e in entries) {
    if (e.medicine.id == line.medicineId) {
      return e.hierarchy?.units ?? const [];
    }
  }
  return const [];
}

class _DiscountRow extends ConsumerStatefulWidget {
  const _DiscountRow({
    required this.current,
    required this.invalid,
    required this.onChanged,
  });

  final Pya current;
  final bool invalid;
  final ValueChanged<Pya> onChanged;

  @override
  ConsumerState<_DiscountRow> createState() => _DiscountRowState();
}

class _DiscountRowState extends ConsumerState<_DiscountRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current == 0 ? '' : formatMoney(widget.current),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        LengthLimitingTextInputFormatter(12),
      ],
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).discount,
        suffixText: 'K',
        isDense: true,
        errorText: widget.invalid ? 'More than the subtotal' : _error,
      ),
      onChanged: (raw) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          widget.onChanged(0);
          return;
        }
        final pya = kyatToPya(trimmed);
        if (pya == null) {
          setState(() => _error = 'Enter a number');
          return;
        }
        setState(() => _error = null);
        widget.onChanged(pya);
      },
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, maxLines: 4),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
