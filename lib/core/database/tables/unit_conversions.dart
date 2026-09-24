import 'package:drift/drift.dart';

import 'medicines.dart';

/// `unit_conversions` — one row per sellable unit of a medicine (Module 3).
///
/// The packaging hierarchy `1 Box = 10 Strips = 100 Tablets` is stored as three
/// rows, one per unit, each carrying how many **smallest units** one of it
/// contains:
///
/// | unit_name | conversion_factor | retail_price (pya) |
/// |---|---|---|
/// | Tablet | 1     | 120 |
/// | Strip  | 10    | 1,150 |
/// | Box    | 100   | 11,200 |
///
/// The smallest unit is therefore the row where [conversionFactor] is 1, and it
/// always exists — [UnitHierarchy.base] is how it is found. Storing the base as a
/// real row rather than as an extra `base_unit_name` column on `medicines` keeps
/// one rule ("every price and every factor lives in this table") true for every
/// unit, so POS pricing has no special case for single-tablet sales.
///
/// Prices are per-unit and are **not** derived from each other: a shop discounts
/// the box below 100 × the tablet price on purpose. Deriving would erase real
/// margin data and break profit reporting.
// A medicine cannot have two rows for the same unit name: the POS picker, the
// purchase lines and the hierarchy validator all key on (medicine, unit).
@TableIndex(
  name: 'idx_unit_conversions_per_medicine',
  columns: {#medicineId, #unitName},
  unique: true,
)
class UnitConversions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get medicineId => integer()
      .named('medicine_id')
      .references(Medicines, #id, onDelete: KeyAction.cascade)();

  /// Display name exactly as the shop says it: "Tablet", "Strip", "Box", "Bottle".
  TextColumn get unitName =>
      text().named('unit_name').withLength(min: 1, max: 24)();

  /// How many smallest units one of this unit contains. Always >= 1.
  ///
  /// An integer, never a double: half-tablets are not a thing, and a float factor
  /// would make `qty * factor` non-integral, which cannot be stored in a batch.
  IntColumn get conversionFactor => integer()
      .named('conversion_factor')
      .customConstraint('NOT NULL DEFAULT 1 CHECK (conversion_factor >= 1)')();

  /// Selling price for one of this unit, in pya.
  IntColumn get retailPrice => integer()
      .named('retail_price')
      .customConstraint('NOT NULL CHECK (retail_price >= 0)')();

  /// Wholesale price for one of this unit, in pya; `null` means the shop does not
  /// run a wholesale price for this unit and POS falls back to [retailPrice].
  ///
  /// Nullable rather than defaulted to 0, because 0 is a legal price and a
  /// sentinel-zero would silently give away stock.
  IntColumn get wholesalePrice => integer()
      .named('wholesale_price')
      .nullable()
      .customConstraint(
        'CHECK (wholesale_price IS NULL OR wholesale_price >= 0)',
      )();

  /// Ordering for the unit picker, coarsest first (Box, Strip, Tablet).
  IntColumn get displayOrder =>
      integer().named('display_order').withDefault(const Constant(0))();
}
