import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/rbac/permission.dart';
import '../../auth/application/auth_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../data/purchase_repository.dart';

final Provider<PurchaseRepository> purchaseRepositoryProvider =
    Provider<PurchaseRepository>(
      (ref) => PurchaseRepository(ref.watch(appDatabaseProvider)),
    );

/// Whether the signed-in user may record a delivery.
///
/// Separate from `manageInventory` on purpose: adding a medicine to the
/// catalogue and accepting stock from a wholesaler create different
/// responsibilities, and the blueprint gives the second one to the owner.
final Provider<bool> canRecordPurchasesProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.managePurchases)),
);

final Provider<bool> canManageSuppliersProvider = Provider<bool>(
  (ref) => ref.watch(permissionProvider(Permission.manageCredit)),
);

/// Suppliers for the purchase form's picker.
final FutureProvider<List<Supplier>> supplierListProvider =
    FutureProvider.autoDispose<List<Supplier>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(purchaseRepositoryProvider).suppliers();
    });

/// Suppliers with an outstanding balance, largest first.
final FutureProvider<List<Supplier>> payableListProvider =
    FutureProvider.autoDispose<List<Supplier>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(purchaseRepositoryProvider).withPayable();
    });

/// Recent stock-ins, newest first.
final FutureProvider<List<Purchase>> recentPurchasesProvider =
    FutureProvider.autoDispose<List<Purchase>>((ref) {
      ref.watch(inventoryRevisionProvider);
      return ref.read(purchaseRepositoryProvider).recentPurchases();
    });

/// The signed-in staff member to attribute a purchase to.
final Provider<int?> currentUserIdProvider = Provider<int?>(
  (ref) => ref.watch(authProvider)?.id,
);
