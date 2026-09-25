import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/l10n/l10n_bridge.dart';
import '../../../core/money.dart';
import '../../../core/presentation/money_field.dart';
import '../../scanning/presentation/scanner_screen.dart';
import '../application/inventory_providers.dart';
import '../application/unit_hierarchy.dart';
import '../data/inventory_repository.dart';

/// Add / edit a medicine together with its whole packaging hierarchy.
///
/// Units belong on this screen rather than a second step because a medicine
/// without a factor-1 unit cannot hold stock at all — every stock-in and every
/// sale would fail on `hierarchyFor`. [InventoryRepository.createMedicine] writes
/// the product and its units in one transaction, so the broken in-between state is
/// not reachable from here.
///
/// With [existing] set, the same form edits that product: descriptive fields and
/// prices through the repository, while unit rows already in the database keep
/// their identity ([_UnitRow.existingId]) instead of being re-inserted.
class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key, this.existing});

  final Medicine? existing;

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _tradeName = TextEditingController(
    text: widget.existing?.tradeName ?? '',
  );
  late final TextEditingController _genericName = TextEditingController(
    text: widget.existing?.genericName ?? '',
  );
  late final TextEditingController _category = TextEditingController(
    text: widget.existing?.category ?? '',
  );
  late final TextEditingController _shelf = TextEditingController(
    text: widget.existing?.shelfLocation ?? '',
  );
  late final TextEditingController _barcode = TextEditingController(
    text: widget.existing?.barcode ?? '',
  );

  /// Null until the unit rows are loaded (edit mode) or the form is prefilled.
  final List<_UnitRow> _units = <_UnitRow>[];

  final TextEditingController _threshold = TextEditingController();

  int? _lowStockThreshold;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _lowStockThreshold = widget.existing?.lowStockThreshold;
    final threshold = _lowStockThreshold;
    if (threshold != null) _threshold.text = '$threshold';

    if (_isEdit) {
      _loadUnits();
    } else {
      // The three-level hierarchy a pharmacy actually stocks — tablets inside
      // strips inside cartons — prefilled so the common case is just typing
      // prices. Order matters: coarsest first, factor 1 last.
      _units
        ..add(_UnitRow(unitName: 'Box', factor: 100))
        ..add(_UnitRow(unitName: 'Strip', factor: 10))
        ..add(_UnitRow(unitName: 'Tablet', factor: 1));
    }
  }

  Future<void> _loadUnits() async {
    final rows = await ref
        .read(inventoryRepositoryProvider)
        .unitsFor(widget.existing!.id);
    if (!mounted) return;
    setState(() {
      _units
        ..clear()
        ..addAll(
          rows.map(
            (row) => _UnitRow(
              unitName: row.unitName,
              factor: row.conversionFactor,
              existingId: row.id,
              retailPya: row.retailPrice,
              wholesalePya: row.wholesalePrice,
            ),
          ),
        );
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _tradeName,
      _genericName,
      _category,
      _shelf,
      _barcode,
      _threshold,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<NewUnit> get _pendingUnits => [
    for (final unit in _units)
      NewUnit(
        name: unit.unitName,
        factor: unit.factor,
        // A blank retail price is caught by [_unitError] before this is used;
        // defaulting here keeps the repository's non-null contract intact rather
        // than teaching it about half-filled forms.
        retailPricePya: unit.retailPya ?? 0,
        wholesalePricePya: unit.wholesalePya,
      ),
  ];

  /// The hierarchy rules the repository will enforce, checked here first so the
  /// clerk sees the problem next to the field that caused it instead of after a
  /// failed save.
  String? _unitError() {
    final l10n = context.l10n;
    if (_units.isEmpty) return l10n.invAddAtLeastOneUnit;
    for (final unit in _units) {
      if (unit.unitName.trim().isEmpty) return l10n.invEveryUnitNeedsName;
      if (unit.factor < 1) {
        return l10n.invUnitMustHoldWholePieces(unit.unitName);
      }
      if (unit.retailPya == null) {
        return l10n.invRetailPriceForUnit(unit.unitName);
      }
    }
    try {
      UnitHierarchy.from([
        for (final entry in _pendingUnits.indexed)
          UnitSpec(
            id: entry.$1,
            name: entry.$2.name,
            factor: entry.$2.factor,
            retailPricePya: entry.$2.retailPricePya,
            wholesalePricePya: entry.$2.wholesalePricePya,
          ),
      ]);
    } on UnitConfigException catch (e) {
      return l10n.describe(e);
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final unitProblem = _unitError();
    if (unitProblem != null) {
      setState(() => _error = unitProblem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(inventoryRepositoryProvider);
    try {
      if (!_isEdit) {
        await repo.createMedicine(
          tradeName: _tradeName.text,
          genericName: _genericName.text,
          category: _category.text,
          shelfLocation: _shelf.text,
          barcode: _barcode.text,
          lowStockThreshold: _lowStockThreshold,
          units: _pendingUnits,
        );
      } else {
        await repo.updateMedicine(
          medicineId: widget.existing!.id,
          tradeName: _tradeName.text,
          genericName: _genericName.text,
          category: _category.text,
          shelfLocation: _shelf.text,
          // `Value(...)` even when null: clearing the alert is a real instruction
          // here, not "leave the column alone".
          lowStockThreshold: Value(_lowStockThreshold),
        );
        await repo.updateUnitPrices([
          for (final unit in _units)
            if (unit.existingId != null)
              UnitPriceEdit(
                unitId: unit.existingId!,
                retailPricePya: unit.retailPya ?? 0,
                wholesalePricePya: unit.wholesalePya,
              ),
        ]);
      }
    } on MedicineConflictException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Both flavours (name required, barcode taken) carry localisation keys
        // now, so one resolver call renders them.
        _error = context.l10n.describe(e);
      });
      return;
    }
    if (!mounted) return;

    ref.read(inventoryRevisionProvider.notifier).bump();
    Navigator.of(context).pop();
  }

  void _addUnit() {
    setState(
      () => _units.insert(
        0,
        // Inserted at the top because the list is coarsest-first, and a new
        // package is nearly always bigger than the ones already there.
        _UnitRow(unitName: '', factor: _units.isEmpty ? 1 : 10),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );
    if (code != null) {
      _barcode.text = code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? l10n.invEditMedicineTitle : l10n.invAddMedicineTitle,
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _field(
              controller: _tradeName,
              label: l10n.invTradeName,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.invTradeNameRequired
                  : null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _genericName,
              label: l10n.invGenericNameOptional,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(controller: _category, label: l10n.invCategory),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _shelf,
                    label: l10n.invShelfLocation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: l10n.invBarcode,
                helperText: l10n.invBarcodeHelper,
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                  tooltip: l10n.scanBarcode,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _threshold,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.invLowStockAlertAt,
                helperText: l10n.invLowStockAlertHelper,
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) =>
                  _lowStockThreshold = int.tryParse(value.trim()),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.invUnitsSection,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addUnit,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.invAddUnit),
                ),
              ],
            ),
            Text(l10n.invUnitsSectionHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (var index = 0; index < _units.length; index++)
              _UnitTile(
                key: ValueKey(_units[index].tileKey),
                row: _units[index],
                isBase: _units[index].factor == 1,
                removable: _units.length > 1,
                onRemove: () => setState(() => _units.removeAt(index)),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(message: _error!),
            ],
          ],
        ),
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
                : Text(_isEdit ? l10n.invSaveChanges : l10n.invSaveMedicine),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? helper,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    validator: validator,
  );
}

/// One editable unit of the hierarchy.
///
/// Plain mutable state rather than a controller per field: the prices arrive
/// already parsed as [Pya] from [MoneyField], and `null` genuinely means "left
/// blank", which no text value expresses.
class _UnitRow {
  _UnitRow({
    required this.unitName,
    required this.factor,
    this.existingId,
    this.retailPya,
    this.wholesalePya,
  });

  /// Identifies the tile widget across rebuilds so editing one field does not
  /// reassign the text of another.
  final Object tileKey = Object();

  String unitName;
  int factor;

  /// `unit_conversions.id` when this row came from the database; `null` for a
  /// newly typed unit. Price edits skip nulls because there is no row yet.
  final int? existingId;

  Pya? retailPya;
  Pya? wholesalePya;
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({
    super.key,
    required this.row,
    required this.isBase,
    required this.removable,
    required this.onRemove,
  });

  final _UnitRow row;
  final bool isBase;
  final bool removable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: row.unitName,
                    decoration: InputDecoration(
                      labelText: l10n.invUnitName,
                      hintText: l10n.invUnitNameHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => row.unitName = value,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    initialValue: '${row.factor}',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isBase ? l10n.invEquals : l10n.invHolds,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        row.factor = int.tryParse(value.trim()) ?? 0,
                  ),
                ),
                if (removable)
                  IconButton(
                    tooltip: l10n.invRemoveThisUnit,
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoneyField(
                    label: l10n.retail,
                    suffix: 'K',
                    initialPya: row.retailPya,
                    allowEmpty: false,
                    onChanged: (value) => row.retailPya = value,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MoneyField(
                    label: l10n.wholesale,
                    suffix: 'K',
                    initialPya: row.wholesalePya,
                    onChanged: (value) => row.wholesalePya = value,
                  ),
                ),
              ],
            ),
            if (isBase)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.invSmallestUnitNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
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
