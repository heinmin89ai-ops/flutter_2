import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/database_provider.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/core/rbac/permission.dart';
import 'package:pharmacy_pos/core/secure/secure_store.dart';
import 'package:pharmacy_pos/features/auth/application/auth_providers.dart';
import 'package:pharmacy_pos/features/auth/application/password_service.dart';
import 'package:pharmacy_pos/features/auth/data/user_repository.dart';
import 'package:pharmacy_pos/features/license/application/jwt_decoder.dart';
import 'package:pharmacy_pos/features/license/application/license_providers.dart';
import 'package:pharmacy_pos/main.dart';
import 'package:pharmacy_pos/routing/routes.dart';

/// Route-level RBAC for the Phase 3 screens.
///
/// Two layers, because the bug this guards against has two halves. The pure
/// [appGuard] tests state the rule; the widget tests drive the *real* router,
/// which is what catches a guard that denies correctly on paper and then bounces
/// every allowed route back to the dashboard anyway.
///
/// Fixtures hash with 1k iterations, so every read path must share [fast] — the
/// production cost would reject these hashes and report a failed sign-in.
const PasswordService fast = PasswordService(iterations: 1000);

const LicenseState licensed = LicenseState(status: LicenseStatus.active);
const LicenseState unlicensed = LicenseState(
  status: LicenseStatus.notActivated,
);
const LicenseState booting = LicenseState(status: LicenseStatus.unknown);

AppUser user(UserRole role) => AppUser(
  id: role == UserRole.admin ? 1 : 2,
  username: role == UserRole.admin ? 'owner' : 'till1',
  pinHash: r'salt$hash',
  role: role,
  isActive: true,
  createdAt: DateTime(2026),
);

String liveKey() => JwtFeatureDecoder.issueKey(
  features: const {'retail': true},
  expiresAt: DateTime.now().add(const Duration(days: 365)),
  client: 'Test Pharmacy',
);

void main() {
  group('appGuard — the rule', () {
    test('waits on the splash while boot is unresolved', () {
      expect(appGuard(booting, null, AppRoutes.inventory), AppRoutes.boot);
    });

    test('sends everyone to activation when the device is unlicensed', () {
      expect(
        appGuard(unlicensed, user(UserRole.admin), AppRoutes.inventory),
        AppRoutes.activate,
      );
      expect(appGuard(unlicensed, null, AppRoutes.home), AppRoutes.activate);
      expect(appGuard(unlicensed, null, AppRoutes.activate), isNull);
    });

    test('refuses a feature route before there is a session', () {
      for (final route in kRoutePermissions.keys) {
        expect(
          appGuard(licensed, null, route),
          AppRoutes.login,
          reason: '$route must not open without a session',
        );
      }
    });

    test('the owner may open every Phase 3 route and stay on it', () {
      for (final route in [
        AppRoutes.home,
        AppRoutes.inventory,
        AppRoutes.addMedicine,
        AppRoutes.addPurchase,
      ]) {
        expect(
          appGuard(licensed, user(UserRole.admin), route),
          isNull,
          reason: '$route should stay put for the owner',
        );
      }
    });

    test('a cashier may read stock but not write it', () {
      final cashier = user(UserRole.cashier);

      expect(appGuard(licensed, cashier, AppRoutes.inventory), isNull);
      expect(
        appGuard(licensed, cashier, AppRoutes.addMedicine),
        AppRoutes.home,
      );
      expect(
        appGuard(licensed, cashier, AppRoutes.addPurchase),
        AppRoutes.home,
      );
    });

    test('a signed-in user is pulled off every non-feature bookmark', () {
      final owner = user(UserRole.admin);

      expect(appGuard(licensed, owner, AppRoutes.login), AppRoutes.home);
      expect(appGuard(licensed, owner, AppRoutes.activate), AppRoutes.home);
      expect(appGuard(licensed, owner, '/no-such-screen'), AppRoutes.home);
    });
  });

  test('every feature route names exactly one permission', () {
    // The dashboard renders its links from `permissionProvider` and the router
    // enforces this map. A route added without an entry here is reachable by URL
    // by anyone, which is the failure this test exists to catch.
    expect(kRoutePermissions.keys.toList(), [
      AppRoutes.inventory,
      AppRoutes.addMedicine,
      AppRoutes.addPurchase,
    ]);
    expect(kRoutePermissions[AppRoutes.inventory], Permission.viewInventory);
    expect(
      kRoutePermissions[AppRoutes.addMedicine],
      Permission.manageInventory,
    );
    expect(
      kRoutePermissions[AppRoutes.addPurchase],
      Permission.managePurchases,
    );
  });

  test('no permission is both implied and contradicted by a route entry', () {
    // Reading stock is weaker than editing it; if those ever collapse onto the
    // same grant, the cashier test above stops proving anything.
    expect(
      roleHasPermission(UserRole.cashier, Permission.viewInventory),
      isTrue,
    );
    expect(
      roleHasPermission(UserRole.cashier, Permission.manageInventory),
      isFalse,
    );
    expect(
      roleHasPermission(UserRole.cashier, Permission.managePurchases),
      isFalse,
    );
  });

  group('the real router', () {
    late AppDatabase db;
    late MemoryKeyValueStore store;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = MemoryKeyValueStore();
    });

    tearDown(() => db.close());

    ProviderScope app() => ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureStoreProvider.overrideWithValue(SecureStore(store: store)),
        userRepositoryProvider.overrideWithValue(
          UserRepository(db, passwords: fast),
        ),
      ],
      child: const PharmacyApp(),
    );

    /// Activate, then create the owner account through the real first-run screen.
    Future<void> startAsOwner(WidgetTester tester) async {
      await tester.pumpWidget(app());
      await _settle(tester);

      await tester.enterText(find.byType(TextField), liveKey());
      await tester.tap(find.text('Activate'));
      await _settle(tester);
      expect(find.text('Create the owner account'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'owner');
      await tester.enterText(fields.at(1), 'long-enough');
      await tester.enterText(fields.at(2), 'long-enough');
      await tester.tap(find.text('Create account'));
      await _settle(tester);
      expect(find.textContaining('Signed in as owner'), findsOneWidget);
    }

    /// Sign in an existing account by name through the login screen.
    Future<void> signIn(WidgetTester tester, String username) async {
      await tester.enterText(find.byType(TextField).at(0), username);
      await tester.enterText(find.byType(TextField).at(1), 'long-enough');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await _settle(tester);
      expect(find.textContaining('Signed in as $username'), findsOneWidget);
    }

    /// Ask the live router for a route, the way a bookmark or QR-code deep link
    /// would — not by tapping a button the app chose to show.
    Future<void> open(WidgetTester tester, String route) async {
      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).push(route);
      await _settle(tester);
    }

    testWidgets('the dashboard offers the owner all three Phase 3 screens', (
      tester,
    ) async {
      await startAsOwner(tester);

      expect(find.widgetWithText(OutlinedButton, 'Inventory'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Add medicine'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Record a delivery'),
        findsOneWidget,
      );
    });

    testWidgets('opening the inventory list actually shows the list', (
      tester,
    ) async {
      // Regression: the guard once bounced every signed-in location back to the
      // dashboard, so an allowed route looked protected and behaved broken.
      await startAsOwner(tester);
      await open(tester, AppRoutes.inventory);

      // The search box and empty state only exist on the list screen itself.
      expect(find.text('No medicines yet.'), findsOneWidget);
      expect(find.text('Search name, generic or barcode'), findsOneWidget);
      expect(find.textContaining('Signed in as owner'), findsNothing);
    });

    testWidgets('the catalogue and stock-in editors open for the owner', (
      tester,
    ) async {
      await startAsOwner(tester);
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;

      await open(tester, AppRoutes.addMedicine);
      expect(find.text('Save medicine'), findsOneWidget);
      expect(find.text('Low-stock alert at (optional)'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await _settle(tester);

      await open(tester, AppRoutes.addPurchase);
      expect(find.text('Save and add to stock'), findsOneWidget);
      expect(find.text('Invoice / GRN number (optional)'), findsOneWidget);
    });

    testWidgets('a cashier may open the list but not the editors', (
      tester,
    ) async {
      await startAsOwner(tester);
      await UserRepository(db, passwords: fast).create(
        username: 'till1',
        secret: 'long-enough',
        role: UserRole.cashier,
      );
      await signOutThroughUi(tester);
      await signIn(tester, 'till1');

      expect(find.widgetWithText(OutlinedButton, 'Inventory'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Record a delivery'),
        findsNothing,
      );
      expect(find.widgetWithText(OutlinedButton, 'Add medicine'), findsNothing);

      // The route is denied even though nothing on screen advertised it.
      await open(tester, AppRoutes.addPurchase);
      expect(find.textContaining('Signed in as till1'), findsOneWidget);
      expect(find.text('Save and add to stock'), findsNothing);
    });
  });
}

/// Sign out through the app bar, so the session lands back on the login screen
/// without reaching for the provider container.
Future<void> signOutThroughUi(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Sign out'));
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  // Fixed pumps rather than pumpAndSettle: the boot splash spins indefinitely.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}
