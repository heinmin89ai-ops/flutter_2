import 'package:flutter_riverpod/flutter_riverpod.dart';
// `family` providers have their own type, which the main entry point keeps out of
// the default namespace.
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../data/inventory_repository.dart';

final Provider<InventoryRepository> inventoryRepositoryProvider =
    Provider<InventoryRepository>(
      (ref) => InventoryRepository(ref.watch(appDatabaseProvider)),
    );

/// What the inventory list is currently filtered by.
///
/// Held in a notifier rather than passed as `family` arguments: a search box that
/// rebuilt `Provider.family` on every keystroke leaves one cached provider per
/// prefix typed, and each holds a full result list until it disposes.
class InventoryFilter {
  const InventoryFilter({this.search = '', this.lowStockOnly = false});

  final String search;
  final bool lowStockOnly;

  InventoryFilter copyWith({String? search, bool? lowStockOnly}) =>
      InventoryFilter(
        search: search ?? this.search,
        lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is InventoryFilter &&
      other.search == search &&
      other.lowStockOnly == lowStockOnly;

  @override
  int get hashCode => Object.hash(search, lowStockOnly);
}

class InventoryFilterNotifier extends Notifier<InventoryFilter> {
  @override
  InventoryFilter build() => const InventoryFilter();

  void setSearch(String value) {
    final trimmed = value.trim();
    if (state.search == trimmed) return;
    state = state.copyWith(search: trimmed);
  }

  void setLowStockOnly(bool value) {
    if (state.lowStockOnly == value) return;
    state = state.copyWith(lowStockOnly: value);
  }
}

final NotifierProvider<InventoryFilterNotifier, InventoryFilter>
inventoryFilterProvider =
    NotifierProvider<InventoryFilterNotifier, InventoryFilter>(
      InventoryFilterNotifier.new,
    );

/// Bumped by every screen that writes stock, which is what makes the cached
/// reads below re-run.
///
/// drift can push a `Stream` per query, but that would mean a second API on every
/// repository method for a UI concern; one counter is enough for a till that has
/// exactly one writer.
class InventoryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final NotifierProvider<InventoryRevision, int> inventoryRevisionProvider =
    NotifierProvider<InventoryRevision, int>(InventoryRevision.new);

/// The inventory list, with stock computed from batches.
final FutureProvider<List<InventoryRow>> inventoryListProvider =
    FutureProvider.autoDispose<List<InventoryRow>>((ref) {
      final filter = ref.watch(inventoryFilterProvider);
      ref.watch(inventoryRevisionProvider);
      return ref
          .read(inventoryRepositoryProvider)
          .list(search: filter.search, lowStockOnly: filter.lowStockOnly);
    });

/// The medicine catalogue, for pickers that need names rather than stock.
final FutureProvider<List<Medicine>> medicineCatalogProvider =
    FutureProvider.autoDispose<List<Medicine>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(inventoryRepositoryProvider).catalog();
    });

/// Batches for one medicine, soonest expiry first — the FEFO order Phase 4 sells
/// in.
final FutureProviderFamily<List<StockBatch>, int> medicineBatchesProvider =
    FutureProvider.autoDispose.family<List<StockBatch>, int>((ref, medicineId) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(inventoryRepositoryProvider).batchesFor(medicineId);
    });

/// Batches expiring inside the given window, across all medicines.
final FutureProviderFamily<List<StockBatch>, int> expiringBatchesProvider =
    FutureProvider.autoDispose.family<List<StockBatch>, int>((ref, days) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(inventoryRepositoryProvider).expiringWithin(days);
    });

/// Whether the signed-in user may change stock records.
///
/// Cost prices are gated separately by [maySeeCostPriceProvider]: a cashier is
/// allowed to see that Paracetamol is running low, and not allowed to see what
/// the shop paid for it.
final Provider<bool> canManageInventoryProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.manageInventory)),
);

final Provider<bool> maySeeCostPriceProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.viewCostPrice)),
);
