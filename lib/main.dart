import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/database/app_database.dart';
import 'core/database/tables/credit_transactions.dart';
import 'core/rbac/permission.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/setup_admin_screen.dart';
import 'features/backup/presentation/backup_screen.dart';
import 'features/credit/presentation/party_credit_screen.dart';
import 'features/expenses/presentation/expense_screen.dart';
import 'features/inventory/presentation/add_medicine_screen.dart';
import 'features/inventory/presentation/inventory_list_screen.dart';
import 'features/license/application/license_providers.dart';
import 'features/license/presentation/activation_key_screen.dart';
import 'features/purchases/presentation/add_purchase_screen.dart';
import 'features/reports/presentation/report_dashboard_screen.dart';
import 'features/sales/presentation/pos_screen.dart';
import 'features/shell/presentation/dashboard_screen.dart';
import 'routing/routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PharmacyApp()));
}

class PharmacyApp extends ConsumerWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Pharmacy POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F766E),
        useMaterial3: true,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Re-evaluates the boot / licence / auth gates whenever their inputs change.
///
/// Riverpod state is not a [Listenable], so this bridges the two providers the
/// guards depend on into one notifier the router can subscribe to.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref
      ..listen<LicenseState>(licenseProvider, (_, _) => notifyListeners())
      ..listen<AppUser?>(authProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.boot,
    refreshListenable: refresh,
    redirect: (context, state) => appGuard(
      ref.read(licenseProvider),
      ref.read(authProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.boot,
        builder: (context, state) => const BootGate(),
      ),
      GoRoute(
        path: AppRoutes.activate,
        builder: (context, state) => const ActivationKeyScreen(),
      ),
      GoRoute(
        path: AppRoutes.setupAdmin,
        builder: (context, state) => const SetupAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (context, state) => const InventoryListScreen(),
      ),
      GoRoute(
        path: AppRoutes.addMedicine,
        builder: (context, state) =>
            AddMedicineScreen(existing: state.extra as Medicine?),
      ),
      GoRoute(
        path: AppRoutes.addPurchase,
        builder: (context, state) => const AddPurchaseScreen(),
      ),
      GoRoute(
        path: AppRoutes.pos,
        builder: (context, state) => const POSScreen(),
      ),
      GoRoute(
        path: AppRoutes.customerCredit,
        builder: (context, state) =>
            const PartyCreditScreen(partyType: PartyType.customer),
      ),
      GoRoute(
        path: AppRoutes.supplierCredit,
        builder: (context, state) =>
            const PartyCreditScreen(partyType: PartyType.supplier),
      ),
      GoRoute(
        path: AppRoutes.expenses,
        builder: (context, state) => const ExpenseScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => const ReportDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.backup,
        builder: (context, state) => const BackupScreen(),
      ),
    ],
  );
});

/// Module 1 → Module 2 boot flow, then Phase 3's feature gates.
///
/// `license_config` empty ⇒ activation screen. Present and decodable ⇒ login.
/// Signed in ⇒ home, unless the location is a feature route the role may open.
///
/// A pure function of the two session facts and the location, with the router
/// doing the `read`s — `read`, never `watch`: this runs inside a redirect and
/// must not subscribe the router to anything. Taking values instead of a [Ref]
/// is what lets the route tests assert a typed or bookmarked URL directly,
/// which is the whole point of the permission map below.
String? appGuard(LicenseState license, AppUser? user, String here) {
  // Bootstrap has not answered yet; hold on the splash.
  if (license.status == LicenseStatus.unknown) return AppRoutes.boot;

  if (!license.isActivated) {
    return here == AppRoutes.activate ? null : AppRoutes.activate;
  }

  if (user == null) {
    // Licence is valid but nobody is signed in. The setup screen is the only
    // place allowed to sit outside that; BootGate routes into it.
    return here == AppRoutes.setupAdmin
        ? AppRoutes.setupAdmin
        : AppRoutes.login;
  }

  final required = kRoutePermissions[here];
  if (required != null && !roleHasPermission(user.role, required)) {
    // Sent back to the dashboard rather than shown an error page: a cashier who
    // bookmarked the inventory screen is not attacking the shop, they want the
    // page they were on yesterday, and the dashboard already explains what they
    // may open.
    return AppRoutes.home;
  }

  // A route the role may open stays put; anything else — including a stale
  // `/login` or `/activate` bookmark — lands on the dashboard.
  if (here == AppRoutes.home || required != null) return null;
  return AppRoutes.home;
}

/// Startup screen: loads the licence and restores any saved session, then lets
/// [_guard] advance the app.
class BootGate extends ConsumerStatefulWidget {
  const BootGate({super.key});

  @override
  ConsumerState<BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<BootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final license = ref.read(licenseProvider.notifier);
    await license.load();
    if (!mounted) return;

    if (!ref.read(licenseProvider).isActivated) return; // guard routes onward

    await ref.read(authProvider.notifier).restoreSession();
    if (!mounted) return;
    if (ref.read(authProvider) != null) return;

    // Fresh install: no account exists, so there is nothing to log into.
    final users = await ref.read(userRepositoryProvider).findAll();
    if (!mounted) return;
    if (users.isEmpty) context.go(AppRoutes.setupAdmin);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
