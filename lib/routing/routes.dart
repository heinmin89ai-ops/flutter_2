import '../core/rbac/permission.dart';

/// Named route paths.
///
/// Constants rather than literals so a redirect typo fails at compile time
/// instead of producing a 404 at runtime on a shop's till.
abstract final class AppRoutes {
  static const String boot = '/';
  static const String activate = '/activate';
  static const String setupAdmin = '/setup-admin';
  static const String login = '/login';
  static const String home = '/home';

  // Phase 3 — inventory and purchasing.
  static const String inventory = '/inventory';
  static const String addMedicine = '/inventory/add';
  static const String addPurchase = '/purchases/add';

  // Phase 4 — point of sale.
  static const String pos = '/pos';

  // Added in later phases:
  // static const String reports = '/reports';       // Phase 6
}

/// The permission each feature route requires, at the exact level of what it does.
///
/// Living next to the paths so a new route and its guard are written in the same
/// file — an unlisted route is reachable by URL, which is the one mistake this
/// table exists to prevent. The router's redirect is what enforces it; a screen
/// hiding a button is only the visual half.
///
/// Adding a medicine and adding stock are separate grants: `manageInventory` owns
/// the catalogue, `managePurchases` owns what arrived and what is owed for it.
const Map<String, Permission> kRoutePermissions = {
  AppRoutes.inventory: Permission.viewInventory,
  AppRoutes.addMedicine: Permission.manageInventory,
  AppRoutes.addPurchase: Permission.managePurchases,
  AppRoutes.pos: Permission.pos,
};
