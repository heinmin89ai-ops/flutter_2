import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../inventory/application/unit_hierarchy.dart';

/// One product line sitting in the till's cart.
///
/// Prices are resolved **at add time and on every unit/quantity/mode change**, by
/// reading `UnitHierarchy.priceFor` — the cart never carries a price it invented,
/// only one that came from a real `unit_conversions` row. [unitName] and
/// [conversionFactor] are kept alongside [unitConversionId] so the line can be
/// priced and converted without re-querying, and so a later catalogue edit cannot
/// silently restate a line the cashier already rung up.
class CartLine {
  const CartLine({
    required this.medicineId,
    required this.tradeName,
    required this.unitConversionId,
    required this.unitName,
    required this.conversionFactor,
    required this.quantity,
    required this.unitPricePya,
    required this.retailPricePya,
    required this.wholesalePricePya,
  });

  final int medicineId;
  final String tradeName;
  final int unitConversionId;
  final String unitName;
  final int conversionFactor;

  /// Count in [unitName] units.
  final int quantity;

  /// Price charged per [unitName], already resolved for the cart's mode.
  final Pya unitPricePya;

  /// The unit's retail and wholesale prices, retained so switching modes or
  /// units re-prices from the source rows rather than a stale guess.
  final Pya retailPricePya;
  final Pya? wholesalePricePya;

  int get qtyInBase => quantity * conversionFactor;

  Pya get lineTotalPya => quantity * unitPricePya;

  CartLine copyWith({
    int? quantity,
    int? unitConversionId,
    String? unitName,
    int? conversionFactor,
    Pya? unitPricePya,
  }) => CartLine(
    medicineId: medicineId,
    tradeName: tradeName,
    unitConversionId: unitConversionId ?? this.unitConversionId,
    unitName: unitName ?? this.unitName,
    conversionFactor: conversionFactor ?? this.conversionFactor,
    quantity: quantity ?? this.quantity,
    unitPricePya: unitPricePya ?? this.unitPricePya,
    retailPricePya: retailPricePya,
    wholesalePricePya: wholesalePricePya,
  );
}

/// The whole cart: its mode, discount, and lines.
class CartState {
  const CartState({
    this.mode = SaleMode.retail,
    this.discountPya = 0,
    this.lines = const [],
  });

  final SaleMode mode;
  final Pya discountPya;
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;

  Pya get subtotalPya => lines.fold<Pya>(0, (sum, l) => sum + l.lineTotalPya);

  /// Discount beyond the subtotal is a form error, not a negative total;
  /// [totalPya] clamps so the UI can still show something while the badge on the
  /// discount field tells the cashier the entry is invalid.
  Pya get totalPya {
    final d = discountPya > subtotalPya ? subtotalPya : discountPya;
    return subtotalPya - d;
  }

  bool get discountExceedsSubtotal => discountPya > subtotalPya;

  CartState copyWith({
    SaleMode? mode,
    Pya? discountPya,
    List<CartLine>? lines,
  }) => CartState(
    mode: mode ?? this.mode,
    discountPya: discountPya ?? this.discountPya,
    lines: lines ?? this.lines,
  );
}

/// Immutable description of a product a customer wants to add.
///
/// The screen resolves the medicine's hierarchy (names, factors, prices) and
/// hands the cart a base-unit default; the cart does not query the database, it
/// only does arithmetic on what it is given. That keeps it a pure [Notifier] —
/// testable without drift, which is the entire reason the pricing lives here
/// rather than in the widget.
class CartAddRequest {
  const CartAddRequest({
    required this.medicineId,
    required this.tradeName,
    required this.units,
    this.preferredUnitName,
  });

  final int medicineId;
  final String tradeName;

  /// The medicine's units, coarsest first, from its [UnitHierarchy]. Must be
  /// non-empty; the caller has already caught [UnitConfigException] if not.
  final List<UnitSpec> units;

  /// Unit to start on, e.g. after a barcode hit that implies "Box". Defaults to
  /// the base (finest) unit when null or unrecognised.
  final String? preferredUnitName;

  UnitSpec get defaultUnit {
    final wanted = preferredUnitName;
    if (wanted == null) return units.last; // coarsest-first ⇒ last is base
    for (final u in units) {
      if (u.name.toLowerCase() == wanted.toLowerCase()) return u;
    }
    return units.last;
  }
}

/// Riverpod cart controller (Phase 4 brief item 1).
///
/// Holds the active lines, the retail/wholesale mode and the voucher discount,
/// and answers the three arithmetic questions the till asks on every keystroke:
/// what is this line's unit price under the current mode, what does switching the
/// line's unit do to that price, and what is the running total.
///
/// It is a plain [Notifier] over immutable [CartState] — no database, no Flutter.
/// Adding a line resolves prices from the [UnitSpec]s passed in; changing mode
/// re-prices every line from the same rows, so a box rung in at retail and then
/// switched to wholesale updates without a re-scan.
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Add a product, merging into an existing line for the same medicine **and the
  /// same unit** — the two things that together identify "more of what's already
  /// on the ticket". Two lines for the same medicine in different units (a Box and
  /// a Strip of the same paracetamol) stay separate: they are different price
  /// points and, on the FEFO side, are deducted as distinct requests.
  void add(CartAddRequest request) {
    final mode = state.mode;
    final unit = request.defaultUnit;
    final price = mode == SaleMode.wholesale
        ? (unit.wholesalePricePya ?? unit.retailPricePya)
        : unit.retailPricePya;

    final existing = _indexOf(request.medicineId, unit.id);
    final line = CartLine(
      medicineId: request.medicineId,
      tradeName: request.tradeName,
      unitConversionId: unit.id,
      unitName: unit.name,
      conversionFactor: unit.factor,
      quantity: 1 + (existing == -1 ? 0 : state.lines[existing].quantity),
      unitPricePya: price,
      retailPricePya: unit.retailPricePya,
      wholesalePricePya: unit.wholesalePricePya,
    );

    final lines = [...state.lines];
    if (existing == -1) {
      lines.add(line);
    } else {
      lines[existing] = line;
    }
    state = state.copyWith(lines: lines);
  }

  /// Change the quantity of a line, in its current unit.
  void setQuantity(int medicineId, int unitConversionId, int quantity) {
    final index = _indexOf(medicineId, unitConversionId);
    if (index == -1) return;
    if (quantity <= 0) {
      removeAt(index);
      return;
    }
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(quantity: quantity);
    state = state.copyWith(lines: lines);
  }

  /// Sell the same medicine in a different unit (Phase 4 brief item 1's unit
  /// switch). The quantity resets to 1 because "1 Box" and "1 Strip" are not the
  /// same amount of medicine — carrying 3 across would be the 100× bug the whole
  /// smallest-unit design exists to avoid.
  void switchUnit(int medicineId, int fromUnitConversionId, UnitSpec toUnit) {
    final index = _indexOf(medicineId, fromUnitConversionId);
    if (index == -1) return;
    final line = state.lines[index];
    final price = state.mode == SaleMode.wholesale
        ? (toUnit.wholesalePricePya ?? toUnit.retailPricePya)
        : toUnit.retailPricePya;
    final updated = line.copyWith(
      unitConversionId: toUnit.id,
      unitName: toUnit.name,
      conversionFactor: toUnit.factor,
      quantity: 1,
      unitPricePya: price,
    );
    final lines = [...state.lines];
    // If this medicine already has a line in the target unit, fold into it rather
    // than show the same product twice at the same unit.
    final dupe = _indexOf(medicineId, toUnit.id);
    if (dupe != -1 && dupe != index) {
      lines[dupe] = lines[dupe].copyWith(
        quantity: lines[dupe].quantity + updated.quantity,
      );
      lines.removeAt(index);
    } else {
      lines[index] = updated;
    }
    state = state.copyWith(lines: lines);
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: lines);
  }

  void removeLine(int medicineId, int unitConversionId) {
    final index = _indexOf(medicineId, unitConversionId);
    if (index != -1) removeAt(index);
  }

  /// Retail ⇄ wholesale. Re-prices every line from its stored retail/wholesale
  /// figures, because the price a line shows must reflect the mode the voucher is
  /// being rung up under, not the mode active when it was first scanned.
  void setMode(SaleMode mode) {
    if (state.mode == mode) return;
    final lines = [
      for (final line in state.lines)
        line.copyWith(
          unitPricePya: mode == SaleMode.wholesale
              ? (line.wholesalePricePya ?? line.retailPricePya)
              : line.retailPricePya,
        ),
    ];
    state = state.copyWith(mode: mode, lines: lines);
  }

  void setDiscount(Pya discountPya) {
    final clamped = discountPya < 0 ? 0 : discountPya;
    state = state.copyWith(discountPya: clamped);
  }

  void clear() => state = const CartState();

  int _indexOf(int medicineId, int unitConversionId) {
    for (var i = 0; i < state.lines.length; i++) {
      final l = state.lines[i];
      if (l.medicineId == medicineId &&
          l.unitConversionId == unitConversionId) {
        return i;
      }
    }
    return -1;
  }
}

final NotifierProvider<CartController, CartState> cartProvider =
    NotifierProvider<CartController, CartState>(CartController.new);
