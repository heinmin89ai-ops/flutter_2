/// Multi-unit arithmetic for the packaging hierarchy (Module 3).
///
/// Pure Dart with no drift or Flutter imports on purpose: this is the code that
/// decides how many tablets a customer actually receives, and it must be testable
/// without a database or a widget tree.
///
/// The rule the whole app follows: **stock is stored in the smallest unit only.**
/// Boxes, strips and bottles exist at the edges — when a clerk types a quantity
/// or reads a stock level — and are converted at that boundary.
library;

import '../../../core/l10n/l10n_bridge.dart';

/// One sellable unit of a medicine, as configured in `unit_conversions`.
class UnitSpec {
  const UnitSpec({
    required this.id,
    required this.name,
    required this.factor,
    required this.retailPricePya,
    this.wholesalePricePya,
  });

  /// `unit_conversions.id`, so a sale line can reference the exact row priced.
  final int id;

  /// Display name: "Tablet", "Strip", "Box".
  final String name;

  /// Smallest units contained in one of this unit. `1` for the base unit.
  final int factor;

  /// Retail price for one of this unit, in pya.
  final int retailPricePya;

  /// Wholesale price, or `null` when the shop runs none for this unit.
  final int? wholesalePricePya;

  bool get isBase => factor == 1;
}

/// A medicine's configured units, with the smallest-unit invariant enforced once.
///
/// Constructed from the database rows; every conversion the app performs goes
/// through an instance of this, so an unconfigured medicine fails here with a
/// clear message instead of producing silently wrong quantities later.
class UnitHierarchy {
  UnitHierarchy._(this._units, this._base);

  /// Builds a hierarchy from [units].
  ///
  /// Throws [UnitConfigException] when the list is empty or contains no base unit.
  /// The second condition is the one that bites in practice: a shop that configures
  /// only "Box" (factor 100) has no unit for its batches to be counted in, and
  /// every stock figure would be off by 100×.
  factory UnitHierarchy.from(List<UnitSpec> units) {
    if (units.isEmpty) {
      throw const UnitConfigException(
        errorKey: 'invNoUnitsConfigured',
        debugMessage: 'This medicine has no units configured. Add at least the smallest unit.',
      );
    }
    final bases = units.where((u) => u.isBase).toList();
    if (bases.isEmpty) {
      final factors = units.map((u) => u.factor).join(', ');
      throw UnitConfigException(
        errorKey: 'invNoSmallestUnit',
        debugMessage:
            'No smallest unit: every configured unit converts to more than one piece '
            '(factors: $factors). Add the single-piece unit with factor 1.',
      );
    }
    if (bases.length > 1) {
      final names = bases.map((u) => u.name).join(', ');
      throw UnitConfigException(
        errorKey: 'invMoreThanOneSmallestUnit',
        errorArgs: {'names': names},
        debugMessage:
            'More than one smallest unit is configured '
            '($names); exactly one is required.',
      );
    }
    final names = units.map((u) => u.name.toLowerCase()).toSet();
    if (names.length != units.length) {
      throw const UnitConfigException(
        errorKey: 'invDuplicateUnitNames',
        debugMessage:
            'Unit names must differ per medicine; two units share a name.',
      );
    }
    return UnitHierarchy._(List.unmodifiable(units), bases.single);
  }

  final List<UnitSpec> _units;
  final UnitSpec _base;

  /// All units, coarsest first — the order a picker should show them.
  List<UnitSpec> get units {
    final sorted = [..._units]..sort((a, b) => b.factor.compareTo(a.factor));
    return sorted;
  }

  /// The smallest unit; batches and stock are always counted in it.
  UnitSpec get base => _base;

  UnitSpec? byId(int id) {
    for (final unit in _units) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  /// Case-insensitive lookup by display name.
  ///
  /// Case-insensitive because clerks type "box" and "Box" in the same session and
  /// neither should be a hard error.
  UnitSpec? byName(String name) {
    final needle = name.trim().toLowerCase();
    for (final unit in _units) {
      if (unit.name.toLowerCase() == needle) return unit;
    }
    return null;
  }

  /// Converts a quantity entered in [unit] into smallest units.
  ///
  /// Exact integer multiplication — no rounding is possible in this direction,
  /// which is why storing in the smallest unit was chosen.
  int toBase({required UnitSpec unit, required int quantity}) {
    _requirePositive(quantity);
    return unit.factor * quantity;
  }

  /// Convenience form for callers that only have the unit name.
  int toBaseByName({required String unitName, required int quantity}) {
    final unit = byName(unitName);
    if (unit == null) {
      throw UnitConfigException(
        errorKey: 'invUnknownUnit',
        errorArgs: {'name': unitName},
        debugMessage: 'Unknown unit "$unitName" for this medicine.',
      );
    }
    return toBase(unit: unit, quantity: quantity);
  }

  /// Largest whole number of [unit]s contained in [baseQty] smallest units.
  ///
  /// Truncating: 250 tablets is 2 boxes, not 2.5. The remainder is what
  /// [decompose] reports alongside it.
  int wholeUnits({required UnitSpec unit, required int baseQty}) {
    _requireNonNegative(baseQty);
    return baseQty ~/ unit.factor;
  }

  /// Splits [baseQty] smallest units into the biggest-units-first breakdown.
  ///
  /// `1234` with Box(100)/Strip(10)/Tablet(1) -> `12 Boxes, 3 Strips, 4 Tablets`.
  /// Greedy from coarsest, which is what a shopkeeper counts out loud.
  ///
  /// Zero-count units are dropped, so a full box reads "1 Box" rather than
  /// "1 Box, 0 Strips, 0 Tablets". A quantity of 0 returns an empty list; callers
  /// that must show something render "out of stock" themselves.
  List<UnitAmount> decompose(int baseQty) {
    _requireNonNegative(baseQty);
    final result = <UnitAmount>[];
    var remaining = baseQty;
    for (final unit in units) {
      if (remaining == 0) break;
      final count = remaining ~/ unit.factor;
      if (count == 0) continue;
      remaining -= count * unit.factor;
      result.add(UnitAmount(unit: unit, quantity: count));
    }
    return result;
  }

  /// Human-readable stock string, e.g. `2 Boxes, 3 Strips`.
  ///
  /// Zero-count units are dropped, so a full box reads "1 Box" rather than
  /// "1 Box, 0 Strips, 0 Tablets". A quantity of 0 renders as `0 <base unit>`.
  String formatStock(int baseQty) {
    final parts = decompose(baseQty);
    if (parts.isEmpty) return '0 ${_pluralise(_base.name, 0)}';
    return parts
        .map((p) => '${p.quantity} ${_pluralise(p.unit.name, p.quantity)}')
        .join(', ');
  }

  /// Price for one of [unit] under [mode], in pya.
  ///
  /// Wholesale falls back to retail when the unit has no wholesale price, rather
  /// than throwing — a shop that only wholesales boxes and never loose tablets has
  /// legitimately left the tablet row blank.
  int priceFor({required UnitSpec unit, required SaleMode mode}) =>
      mode == SaleMode.wholesale
      ? (unit.wholesalePricePya ?? unit.retailPricePya)
      : unit.retailPricePya;

  /// Plural form of a unit name.
  ///
  /// "Box" is the commonest coarse unit in a pharmacy and appending a bare "s"
  /// renders "2 Boxs" on the stock screen. Words ending in a sibilant take "-es";
  /// everything else takes "-s". Consonant-y ("Baby" -> "Babys") is left alone
  /// because unit names are short, shop-chosen words and no real one ends that way.
  static String _pluralise(String name, int count) {
    if (count == 1) return name;
    final lower = name.toLowerCase();
    final sibilant =
        lower.endsWith('s') ||
        lower.endsWith('x') ||
        lower.endsWith('z') ||
        lower.endsWith('ch') ||
        lower.endsWith('sh');
    return sibilant ? '${name}es' : '${name}s';
  }

  static void _requirePositive(int value) {
    if (value <= 0) {
      throw UnitConfigException(
        errorKey: 'invQuantityAtLeast1',
        errorArgs: {'value': '$value'},
        debugMessage: 'Quantity must be at least 1, got $value.',
      );
    }
  }

  static void _requireNonNegative(int value) {
    if (value < 0) {
      throw UnitConfigException(
        errorKey: 'invQuantityNotNegative',
        errorArgs: {'value': '$value'},
        debugMessage: 'Quantity cannot be negative, got $value.',
      );
    }
  }
}

/// A whole number of one unit, as produced by `decompose`.
class UnitAmount {
  const UnitAmount({required this.unit, required this.quantity});

  final UnitSpec unit;
  final int quantity;
}

/// Pricing mode for a sale line.
enum SaleMode {
  retail,
  wholesale;

  /// Parses the stored/UI value, defaulting to retail on anything unrecognised so
  /// a bad string can never silently select the cheaper price list.
  static SaleMode parse(Object? raw) =>
      raw?.toString().toLowerCase() == 'wholesale' ? wholesale : retail;
}

class UnitConfigException implements LocalizedError {
  const UnitConfigException({
    required this.errorKey,
    required this.debugMessage,
    this.errorArgs = const {},
  });

  @override
  final String errorKey;

  @override
  final Map<String, String> errorArgs;

  @override
  final String debugMessage;

  /// English text, kept for callers outside the localisation path (logs and
  /// legacy display fallbacks).
  String get message => debugMessage;

  @override
  String toString() => 'UnitConfigException: $debugMessage';
}
