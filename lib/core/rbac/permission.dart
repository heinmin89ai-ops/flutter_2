import '../database/tables/users.dart';

/// Individual capabilities a screen or action can require.
///
/// Deliberately finer-grained than [UserRole]: the blueprint gives Admins the
/// ability to delete transactions and see cost prices, while Cashiers get POS
/// plus read-only basic inventory. Encoding that as one `isAdmin` boolean is the
/// usual mistake — it forces every future nuance into an if-chain at the call
/// site.
enum Permission {
  pos,
  viewInventory,
  manageInventory,
  viewCostPrice,
  managePurchases,
  manageExpenses,
  manageCredit,
  deleteTransaction,
  viewProfitReports,
  manageUsers,
  manageBackup,
}

/// Role → permission map.
///
/// A single source of truth shared by route guards and widget-level visibility,
/// so a feature cannot be hidden in the UI but still reachable by URL.
const Map<UserRole, Set<Permission>> kRolePermissions = {
  UserRole.admin: {
    Permission.pos,
    Permission.viewInventory,
    Permission.manageInventory,
    Permission.viewCostPrice,
    Permission.managePurchases,
    Permission.manageExpenses,
    Permission.manageCredit,
    Permission.deleteTransaction,
    Permission.viewProfitReports,
    Permission.manageUsers,
    Permission.manageBackup,
  },
  UserRole.cashier: {Permission.pos, Permission.viewInventory},
};

/// Whether [role] holds [permission].
bool roleHasPermission(UserRole role, Permission permission) =>
    kRolePermissions[role]?.contains(permission) ?? false;
