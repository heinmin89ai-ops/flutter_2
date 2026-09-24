import 'package:drift/drift.dart';

/// `medicines` — one row per product, independent of how it is packaged (Module 3).
///
/// Deliberately holds **no** stock or price columns: stock lives in
/// `medicine_batches` (because it is per-batch and per-expiry) and prices live in
/// `unit_conversions` (because they are per-unit). Putting a `stock_qty` column
/// here would be the single most common bug in this kind of app — it drifts out
/// of step with the batches the moment two sales overlap.
///
/// The generic-name index is a plain one rather than partial-over-active: the
/// medicine list has to show deactivated items to explain old vouchers, so the
/// filter used by the screens is not the filter worth indexing.
@TableIndex(name: 'idx_medicines_trade_name', columns: {#tradeName})
@TableIndex(name: 'idx_medicines_generic_name', columns: {#genericName})
@TableIndex(name: 'idx_medicines_active', columns: {#isActive})
class Medicines extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// What the shop and the customer call it. Indexed for the POS search box.
  TextColumn get tradeName =>
      text().named('trade_name').withLength(min: 1, max: 120)();

  /// Active ingredient; nullable because many imported items list none.
  TextColumn get genericName =>
      text().named('generic_name').withLength(max: 120).nullable()();

  TextColumn get category => text().withLength(max: 60).nullable()();

  /// Physical shelf/aisle label, so staff can find the item without searching.
  TextColumn get shelfLocation =>
      text().named('shelf_location').withLength(max: 40).nullable()();

  /// EAN/UPC as printed. Nullable and unique where present: most local
  /// re-packaged medicines have no scannable code at all.
  TextColumn get barcode => text().withLength(max: 48).nullable().unique()();

  /// Smallest-unit quantity below which the item counts as low stock.
  ///
  /// `null` disables the alert for this item. Part of Module 3's alerting
  /// requirement, which has nowhere else sane to live: it is a property of the
  /// product, not of any batch.
  IntColumn get lowStockThreshold =>
      integer().named('low_stock_threshold').nullable()();

  /// Soft delete.
  ///
  /// A medicine sold last year must stay resolvable so old vouchers and profit
  /// reports still read correctly; hard-deleting it would orphan history that
  /// cannot be rebuilt offline.
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}
