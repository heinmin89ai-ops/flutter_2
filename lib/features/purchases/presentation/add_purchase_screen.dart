import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money.dart';
import '../../../core/presentation/money_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/application/unit_hierarchy.dart';
import '../application/purchase_providers.dart';
import '../data/purchase_repository.dart';

/// Stock-in: one supplier delivery, its lines, and the batches they create.
///
/// The line quantity is entered in the unit the clerk is holding and displayed
/// back converted both ways — `5 Boxes = 500 Tablets` — because a stock-in that
/// silently mixed units is the single most damaging data error this app can make:
/// the shelf then disagrees with the screen and no sale afterwards can be trusted.
class AddPurchaseScreen extends ConsumerStatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  /// Supplier picked from the existing list, or the typed name when none fit.
  int? _supplierId;
  final TextEditingController _newSupplierName = TextEditingController();
  final TextEditingController _referenceNo = TextEditingController();
  final TextEditingController _note = TextEditingController();

  final List<_Line> _lines = <_Line>[];

  Pya? _paidPya;
  bool _busy = false;
  String? _error;

  /// Total of the lines so far, in pya.
  Pya get _total => _lines.fold<Pya>(
    0,
    (sum, line) => sum + (line.quantity ?? 0) * (line.costPya ?? 0),
  );

  Pya get _paid => _paidPya ?? 0;

  @override
  void dispose() {
    _newSupplierName.dispose();
    _referenceNo.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final suppliers = await ref.read(supplierListProvider.future);
    if (!mounted) return;
    final picked = await showModalBottomSheet<Supplier>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              leading: Icon(Icons.local_shipping_outlined),
              title: Text('Choose a supplier'),
            ),
            const Divider(height: 1),
            for (final supplier in suppliers)
              ListTile(
                title: Text(supplier.name),
                subtitle: Text(
                  [
                    if ((supplier.companyName ?? '').isNotEmpty)
                      supplier.companyName!,
                    if ((supplier.phone ?? '').isNotEmpty) supplier.phone!,
                  ].join(' · '),
                ),
                trailing: supplier.currentPayable > 0
                    ? Text(
                        'owes ${formatMoney(supplier.currentPayable)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(supplier),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _supplierId = picked.id;
      _newSupplierName.clear();
    });
  }

  void _addLine() => setState(() => _lines.add(_Line()));

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(purchaseRepositoryProvider);
    try {
      var supplierId = _supplierId;
      if (supplierId == null) {
        // Inline "new supplier": creating it here rather than on a separate
        // screen, and `createSupplier` deduplicates by name so two clerks typing
        // the same wholesaler do not fork the payable into two accounts.
        final created = await repo.createSupplier(
          NewSupplier(name: _newSupplierName.text),
        );
        supplierId = created.id;
      }

      final receipt = await repo.recordPurchase(
        supplierId: supplierId,
        paidAmountPya: _paid,
        referenceNo: _referenceNo.text,
        note: _note.text,
        enteredByUserId: ref.read(currentUserIdProvider),
        lines: [
          for (final line in _lines)
            NewPurchaseLine(
              medicineId: line.medicineId!,
              batchNumber: line.batchNumber ?? '',
              expiryDate: line.expiryDate!,
              quantity: line.quantity!,
              costPricePya: line.costPya ?? 0,
              unitConversionId: line.unit?.id,
              unitName: line.unit?.name,
              conversionFactor: line.unit?.factor ?? 1,
            ),
        ],
      );

      if (!mounted) return;
      ref.read(inventoryRevisionProvider.notifier).bump();
      await _showReceipt(receipt);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on PurchaseRejectException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on UnitConfigException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  String? _validate() {
    final hasExisting = _supplierId != null;
    if (!hasExisting && _newSupplierName.text.trim().isEmpty) {
      return 'Choose a supplier or type a new name.';
    }
    if (_lines.isEmpty) return 'Add at least one medicine line.';
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      final label = 'Line ${index + 1}';
      if (line.medicineId == null) return '$label: pick a medicine.';
      if ((line.batchNumber ?? '').trim().isEmpty) {
        return '$label: the batch number is printed on the carton.';
      }
      if (line.expiryDate == null) return '$label: set the expiry date.';
      if (line.quantity == null || line.quantity! <= 0) {
        return '$label: quantity must be at least 1.';
      }
      if (line.costPya == null) return '$label: set the cost price.';
    }
    if (_paid > _total) {
      return 'Paid ${formatMoney(_paid)} is more than the '
          '${formatMoney(_total)} invoice.';
    }
    return null;
  }

  Future<void> _showReceipt(PurchaseReceipt receipt) async {
    final lines = receipt.lines.fold<Pya>(0, (sum, l) => sum + l.lineTotal);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Stocked in ${formatMoney(lines)} kyat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${receipt.lines.length} line${receipt.lines.length == 1 ? '' : 's'} '
              '· ${receipt.batchesCreated} new batch'
              '${receipt.batchesCreated == 1 ? '' : 'es'}'
              '${receipt.batchesMerged > 0 ? ' · ${receipt.batchesMerged} merged into an existing batch' : ''}',
            ),
            const SizedBox(height: 8),
            Text(
              receipt.amountOwed > 0
                  ? 'Balance of ${formatMoney(receipt.amountOwed)} kyat added to '
                        'the supplier account.'
                  : 'Paid in full — nothing added to the supplier account.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).recordDelivery)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Text('Supplier', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _supplierId == null ? _pickSupplier : null,
                  icon: const Icon(Icons.search),
                  label: Text(
                    _supplierId == null
                        ? 'Choose existing'
                        : 'Selected (#$_supplierId)',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _newSupplierName,
                  enabled: _supplierId == null,
                  decoration: const InputDecoration(
                    labelText: 'or new supplier name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ),
            ],
          ),
          if (_supplierId != null)
            TextButton(
              onPressed: () => setState(() => _supplierId = null),
              child: const Text('Enter a different supplier'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _referenceNo,
            decoration: const InputDecoration(
              labelText: 'Invoice / GRN number (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Lines', style: theme.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Add line'),
              ),
            ],
          ),
          for (var index = 0; index < _lines.length; index++)
            _PurchaseLineTile(
              key: ValueKey(_lines[index].keyForForm),
              row: _lines[index],
              index: index,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() => _lines.removeAt(index)),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBox(message: _error!),
          ],
          const SizedBox(height: 24),
          _Totals(
            totalPya: _total,
            paidPya: _paidPya,
            onPaid: (value) {
              setState(() {
                _paidPya = value;
                _error = null;
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Save and add to stock'),
          ),
        ),
      ),
    );
  }
}

/// One editable delivery line.
class _Line {
  int? medicineId;
  String? tradeName;

  /// Selected selling unit; `null` means "counted in the smallest unit", which is
  /// what the repository's factor-1 default expresses.
  UnitSpec? unit;

  List<UnitSpec> get availableUnits => _units;
  final List<UnitSpec> _units = <UnitSpec>[];

  int? quantity;
  Pya? costPya;
  String? batchNumber;
  DateTime? expiryDate;

  /// Stable widget identity so a rebuild does not shuffle typed text between rows.
  final Object keyForForm = Object();

  void setUnits(List<UnitSpec> units) {
    _units
      ..clear()
      ..addAll(units);
    if (unit == null && units.isNotEmpty) unit = units.first;
  }
}

class _PurchaseLineTile extends ConsumerStatefulWidget {
  const _PurchaseLineTile({
    super.key,
    required this.row,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final _Line row;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  ConsumerState<_PurchaseLineTile> createState() => _PurchaseLineTileState();
}

class _PurchaseLineTileState extends ConsumerState<_PurchaseLineTile> {
  bool _loadingUnits = false;

  /// Load the medicine's units, defaulting the line to the biggest package.
  ///
  /// A delivery almost always arrives in cartons, so "Box" is both the likely
  /// choice and the one that makes the typed number match the piece of paper.
  Future<void> _loadUnits(int medicineId) async {
    setState(() {
      _loadingUnits = true;
      widget.row.quantity = null;
    });
    try {
      final hierarchy = await ref
          .read(inventoryRepositoryProvider)
          .hierarchyFor(medicineId);
      widget.row.setUnits(hierarchy.units);
    } on UnitConfigException {
      // No usable hierarchy: fall back to counting pieces, which is what the
      // repository's factor-1 line means.
      widget.row.setUnits(const []);
    }
    if (!mounted) return;
    setState(() => _loadingUnits = false);
    widget.onChanged();
  }

  Future<void> _pickMedicine() async {
    // Only the catalogue is needed here, not the stock figures: the picker takes
    // `Medicine` rows so this screen does not pay for two grouped aggregation
    // queries over every batch just to choose a line.
    final medicines = await ref.read(medicineCatalogProvider.future);
    if (!mounted) return;
    final picked = await showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MedicinePicker(medicines: medicines),
    );
    if (picked == null || !mounted) return;
    setState(() {
      widget.row
        ..medicineId = picked.id
        ..tradeName = picked.tradeName
        ..unit = null;
    });
    await _loadUnits(picked.id);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    // Cartons print a month and a year ("09/27"), not a day. Defaulting to the
    // first of the picked month is the conservative reading: an earlier expiry
    // brings stock onto the FEFO and alert lists sooner, whereas picking the last
    // day would hide expiring tablets for up to a month.
    final picked = await showDatePicker(
      context: context,
      initialDate:
          widget.row.expiryDate ?? DateTime(now.year + 1, now.month, 1),
      firstDate: now,
      lastDate: DateTime(now.year + 15),
      helpText: 'Batch expiry date',
    );
    if (picked == null) return;
    final startOfMonth = DateTime(picked.year, picked.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      // Clamped, not merely normalised: a batch expiring later this month would
      // otherwise land on the 1st — already past — and the repository would
      // refuse a genuine delivery as expired. Today is the earliest date the
      // guard accepts, and it still puts the stock on the expiry alert list
      // straight away, which is the conservative end the picker aims at.
      widget.row.expiryDate = startOfMonth.isBefore(today)
          ? today
          : startOfMonth;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = widget.row;
    final units = row.availableUnits;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text(
                    '${widget.index + 1}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMedicine,
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(
                      row.tradeName ?? 'Choose medicine',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove line',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (_loadingUnits)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (row.medicineId != null && !_loadingUnits) ...[
              const SizedBox(height: 12),
              TextField(
                onSubmitted: (value) {
                  row.batchNumber = value;
                  widget.onChanged();
                },
                onChanged: (value) => row.batchNumber = value,
                decoration: const InputDecoration(
                  labelText: 'Batch number',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickExpiry,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        row.expiryDate == null
                            ? 'Expiry'
                            : _ymd(row.expiryDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (units.length > 1)
                    SizedBox(
                      width: 130,
                      child: DropdownButtonFormField<UnitSpec>(
                        initialValue: row.unit,
                        isDense: true,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final unit in units)
                            DropdownMenuItem(
                              value: unit,
                              child: Text(
                                unit.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => row.unit = value);
                          widget.onChanged();
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        row.quantity = int.tryParse(value.trim());
                        widget.onChanged();
                      },
                      decoration: InputDecoration(
                        labelText: 'Qty',
                        suffixText: row.unit?.name ?? 'pcs',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MoneyField(
                      label:
                          'Cost per ${row.unit?.name.toLowerCase() ?? 'piece'}',
                      suffix: 'K',
                      onChanged: (value) {
                        row.costPya = value;
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
              if (row.unit != null &&
                  row.unit!.factor > 1 &&
                  row.quantity != null &&
                  row.quantity! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Adds ${row.quantity! * row.unit!.factor} '
                    '${row.unit!.name.toLowerCase()}s to stock.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              if (row.unit == null && row.quantity != null && row.quantity! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Adds ${row.quantity!} pieces to stock.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MedicinePicker extends StatelessWidget {
  const _MedicinePicker({required this.medicines});

  final List<Medicine> medicines;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Which medicine arrived?')),
          const Divider(height: 1),
          Flexible(
            child: medicines.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Add a medicine first.'),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: medicines.length,
                    itemBuilder: (context, index) => ListTile(
                      dense: true,
                      title: Text(medicines[index].tradeName),
                      subtitle: medicines[index].genericName == null
                          ? null
                          : Text(medicines[index].genericName!),
                      onTap: () => Navigator.of(context).pop(medicines[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.totalPya,
    required this.paidPya,
    required this.onPaid,
  });

  final Pya totalPya;
  final Pya? paidPya;
  final ValueChanged<Pya?> onPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paid = paidPya ?? 0;
    final balance = totalPya - paid;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Invoice total', style: theme.textTheme.titleSmall),
              ),
              Text(
                '${formatMoney(totalPya)} K',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          MoneyField(
            label: 'Paid now',
            suffix: 'K',
            onChanged: onPaid,
            helper:
                'Leave blank or short to put the balance on the supplier '
                'account.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  balance > 0 ? 'Added to payable' : 'Balance',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${formatMoney(balance.abs())} K',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: balance > 0
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

String _ymd(DateTime value) {
  final text = value.toIso8601String();
  return text.length >= 10 ? text.substring(0, 10) : text;
}
