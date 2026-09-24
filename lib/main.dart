import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/database/app_database.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/setup_admin_screen.dart';
import 'features/license/application/license_providers.dart';
import 'features/license/presentation/activation_key_screen.dart';
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
    redirect: (context, state) => _guard(ref, state.matchedLocation),
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
    ],
  );
});

/// Module 1 → Module 2 boot flow.
///
/// `license_config` empty ⇒ activation screen. Present and decodable ⇒ login.
/// Signed in ⇒ home. `read`, never `watch`: this runs inside a redirect and must
/// not subscribe the router to anything.
String? _guard(Ref ref, String here) {
  final license = ref.read(licenseProvider);

  // Bootstrap has not answered yet; hold on the splash.
  if (license.status == LicenseStatus.unknown) return AppRoutes.boot;

  if (!license.isActivated) {
    return here == AppRoutes.activate ? null : AppRoutes.activate;
  }

  final user = ref.read(authProvider);
  if (user != null) {
    return here == AppRoutes.home ? null : AppRoutes.home;
  }

  // Licence is valid but nobody is signed in. The setup screen is the only
  // place allowed to sit outside that; BootGate routes into it.
  return here == AppRoutes.setupAdmin ? AppRoutes.setupAdmin : AppRoutes.login;
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
