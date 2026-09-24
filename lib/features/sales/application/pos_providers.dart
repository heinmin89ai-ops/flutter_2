import 'package:flutter_riverpod/flutter_riverpod.dart';
// `family` providers keep their own type out of the default namespace.
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/application/unit_hierarchy.dart';
import '../../inventory/data/inventory_repository.dart';
import '../data/sale_repository.dart';

final Provider<SaleRepository> saleRepositoryProvider =
    Provider<SaleRepository>(
      (ref) => SaleRepository(ref.watch(appDatabaseProvider)),
    );

/// Whether the signed-in user may open the till.
///
/// The blueprint's one hard rule about cashiers is "POS plus read-only inventory",
/// so this is the permission that gates the whole feature; a user without it never
/// sees the POS route and the guard bounces a typed URL.
final Provider<bool> canUsePosProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.pos)),
);

/// Whether the cashier may put a sale on credit.
///
/// Held separately from [canUsePosProvider]: the blueprint gives credit
/// management to the admin, so a cashier can ring a sale but not open a debtor.
/// The POS uses this to hide the "on credit" option, and `SaleRepository` is the
/// authority that still refuses the balance server-side regardless of the UI.
final Provider<bool> canSellOnCreditProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.manageCredit)),
);

/// The signed-in cashier to attribute a voucher to.
///
/// Reuses the same source `currentUserIdProvider` reads for purchases, but is a
/// sale's NOT NULL column, so the POS refuses to check out while it is null
/// rather than inserting a traceability-less voucher.
final Provider<int?> currentCashierIdProvider = Provider<int?>(
  (ref) => ref.watch(authProvider)?.id,
);

/// Catalogue products with their units, for the POS grid.
///
/// A `family` on the search string is deliberately avoided here (see the note in
/// `inventory_providers.dart`): the screen reads this whole cached catalogue and
/// filters in Dart per keystroke. The till's product set is the active catalogue,
/// which is small enough that a substring scan beats a re-query, and this avoids
/// leaving one cached provider per prefix typed.
final FutureProvider<List<CatalogEntry>> posCatalogProvider =
    FutureProvider.autoDispose<List<CatalogEntry>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(inventoryRepositoryProvider).catalogWithUnits();
    });

/// A single medicine's unit hierarchy, for the till's unit switch.
///
/// The cart needs the concrete `UnitSpec` list (names, factors, both prices) to
/// price a Box/Strip/Tablet switch, so this surfaces the repository's memoised
/// hierarchy as provider state. Throws [UnitConfigException] through the
/// AsyncValue when a medicine's units are misconfigured — the screen shows that
/// rather than letting a broken product into the cart.
final FutureProviderFamily<UnitHierarchy, int> posHierarchyProvider =
    FutureProvider.autoDispose.family<UnitHierarchy, int>((ref, medicineId) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(inventoryRepositoryProvider).hierarchyFor(medicineId);
    });

/// Customers for the credit-sale picker.
final FutureProvider<List<Customer>> customerListProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(saleRepositoryProvider).customers();
    });

/// Recent vouchers for the till's history sheet.
final FutureProvider<List<Sale>> recentSalesProvider =
    FutureProvider.autoDispose<List<Sale>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(saleRepositoryProvider).recentSales();
    });
