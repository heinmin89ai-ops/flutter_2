import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:pharmacy_pos/features/license/data/license_repository.dart';
import 'package:pharmacy_pos/main.dart';

/// End-to-end boot flow: licence gate, then the auth gate.
///
/// Driven through the real `PharmacyApp` router with an in-memory database and
/// an in-memory key-value store, so no platform channels are involved.
/// Test-only credentials service.
///
/// Fixtures hash with 1k iterations for speed, so every read path must be given
/// the same instance: `authProvider` otherwise builds a repository at the
/// production 120k cost, whose `verify` rejects those hashes and silently
/// reports a failed sign-in.
const PasswordService testPasswords = PasswordService(iterations: 1000);

/// A live licence key for the flows under test.
///
/// Signed with the same compile-time secret the app's default decoder uses, so
/// these tests exercise the real verification path rather than a stub.
String licenceKey({
  Map<String, bool> features = const {'retail': true},
  DateTime? expiresAt,
}) => JwtFeatureDecoder.issueKey(
  features: features,
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 365)),
  client: 'Test Pharmacy',
);

/// Riverpod 3 keeps the element type of `overrides` unexported, so the scaffolds
/// below build the list inline and let it be inferred.
///
/// [decoder] is overridden only where an expiry must be judged against a clock
/// other than wall time.
ProviderScope _app(
  AppDatabase db,
  MemoryKeyValueStore store, {
  JwtFeatureDecoder? decoder,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      secureStoreProvider.overrideWithValue(SecureStore(store: store)),
      userRepositoryProvider.overrideWithValue(
        UserRepository(db, passwords: testPasswords),
      ),
      if (decoder != null) featureDecoderProvider.overrideWithValue(decoder),
    ],
    child: const PharmacyApp(),
  );
}

ProviderContainer _container(
  AppDatabase db, {
  MemoryKeyValueStore? store,
  JwtFeatureDecoder? decoder,
}) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      secureStoreProvider.overrideWithValue(
        SecureStore(store: store ?? MemoryKeyValueStore()),
      ),
      userRepositoryProvider.overrideWithValue(
        UserRepository(db, passwords: testPasswords),
      ),
      if (decoder != null) featureDecoderProvider.overrideWithValue(decoder),
    ],
  );
}

void main() {
  late AppDatabase db;
  late MemoryKeyValueStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = MemoryKeyValueStore();
  });

  tearDown(() => db.close());

  Future<void> pumpApp(
    WidgetTester tester, {
    JwtFeatureDecoder? decoder,
  }) async {
    await tester.pumpWidget(_app(db, store, decoder: decoder));
    // Fixed pumps rather than pumpAndSettle: the boot splash runs an
    // indeterminate circular progress animation that never settles.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> activate(WidgetTester tester, String key) async {
    await tester.enterText(find.byType(TextField), key);
    await tester.tap(find.text('Activate'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  group('boot', () {
    testWidgets('an unactivated device lands on the activation screen', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.text('Activate your licence'), findsOneWidget);
    });

    testWidgets('a key with a bad signature is refused and nothing is stored', (
      tester,
    ) async {
      await pumpApp(tester);
      // Well-formed JWT shape with the signature swapped: this is what a
      // hand-edited key looks like, and it must not reach the database.
      final tampered = licenceKey().split('.');
      await activate(tester, '${tampered[0]}.${tampered[1]}.${tampered[2]}XX');

      expect(find.textContaining('Signature mismatch'), findsOneWidget);
      expect(await LicenseRepository(db).current(), isNull);
    });

    testWidgets('an expired key is refused at activation', (tester) async {
      await pumpApp(tester);
      await activate(
        tester,
        licenceKey(expiresAt: DateTime.now().subtract(const Duration(days: 1))),
      );

      expect(find.textContaining('expired'), findsOneWidget);
      expect(await LicenseRepository(db).current(), isNull);
    });

    testWidgets('a valid key persists the licence and opens first-run setup', (
      tester,
    ) async {
      final key = licenceKey();
      await pumpApp(tester);
      await activate(tester, key);

      final stored = await LicenseRepository(db).current();
      expect(stored, isNotNull);
      expect(stored!.activationKey, key);
      // A freshly activated device has no accounts, so login would be a dead
      // end; the guard must route to account creation instead.
      expect(find.text('Create the owner account'), findsOneWidget);
    });

    testWidgets('after setup the created admin can sign in and reach home', (
      tester,
    ) async {
      await pumpApp(tester);
      await activate(tester, licenceKey());

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'owner');
      await tester.enterText(fields.at(1), 'long-enough');
      await tester.enterText(fields.at(2), 'long-enough');
      await tester.tap(find.text('Create account'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(find.textContaining('Signed in as owner'), findsOneWidget);
      expect(find.textContaining('Role: admin'), findsOneWidget);
    });

    testWidgets('a signed-in session is restored on the next launch', (
      tester,
    ) async {
      await pumpApp(tester);
      await activate(tester, licenceKey());

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'owner');
      await tester.enterText(fields.at(1), 'long-enough');
      await tester.enterText(fields.at(2), 'long-enough');
      await tester.tap(find.text('Create account'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.textContaining('Signed in as owner'), findsOneWidget);

      // Rebuild the app against the same database and key-value store.
      await pumpApp(tester);
      expect(
        find.textContaining('Signed in as owner'),
        findsOneWidget,
        reason: 'session should survive an app restart',
      );
    });

    testWidgets('signing out returns to the login screen', (tester) async {
      await pumpApp(tester);
      await activate(tester, licenceKey());

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'owner');
      await tester.enterText(fields.at(1), 'long-enough');
      await tester.enterText(fields.at(2), 'long-enough');
      await tester.tap(find.text('Create account'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      await tester.tap(find.byTooltip('Sign out'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      // The login heading and its submit button share the label 'Sign in', so
      // identify the screen by what only it has: no session to end, and no
      // signed-in banner.
      expect(find.byTooltip('Sign out'), findsNothing);
      expect(find.textContaining('Signed in as owner'), findsNothing);
      expect(find.text('PIN or password'), findsOneWidget);
    });

    testWidgets('a deactivated account cannot sign back in', (tester) async {
      final container = _container(db, store: store);
      addTearDown(container.dispose);

      final admin = await UserRepository(
        db,
        passwords: const PasswordService(iterations: 1000),
      ).create(username: 'owner', secret: 'long-enough', role: UserRole.admin);
      await LicenseRepository(
        db,
      ).activate(activationKey: licenceKey(), featuresData: '{"retail":true}');

      final auth = container.read(authProvider.notifier);
      expect(
        (await auth.signIn(username: 'ghost', secret: 'long-enough')).message,
        'Username or PIN is incorrect.',
      );

      await (db.update(db.users)..where((t) => t.id.equals(admin.id))).write(
        UsersCompanion(isActive: const Value(false)),
      );
      expect(
        (await auth.signIn(username: 'owner', secret: 'long-enough')).message,
        'This account has been disabled.',
      );
    });
  });

  group('licence state', () {
    test('load reports notActivated for an empty license_config', () async {
      final container = _container(db, store: store);
      addTearDown(container.dispose);

      await container.read(licenseProvider.notifier).load();
      expect(
        container.read(licenseProvider).status,
        LicenseStatus.notActivated,
      );
    });

    test(
      'load re-verifies the stored key instead of trusting the cached blob',
      () async {
        // The cached features_data says the shop is licensed; the key does not
        // verify. The key wins — this is the tamper path Phase 1 left open.
        await LicenseRepository(db).activate(
          activationKey: 'a.b.c',
          featuresData: '{"retail":true,"wholesale":true}',
        );

        final container = _container(db, store: store);
        addTearDown(container.dispose);

        await container.read(licenseProvider.notifier).load();
        final state = container.read(licenseProvider);
        expect(state.status, LicenseStatus.invalidKey);
        expect(state.isActivated, isFalse);
        expect(state.features, isEmpty);
      },
    );

    test('an expired key stops working after a restart', () async {
      // Written while still valid, then re-checked against a clock past `exp`.
      final key = licenceKey(expiresAt: DateTime.utc(2026, 6, 1));
      await LicenseRepository(db)
          .activate(activationKey: key, featuresData: '{"retail":true}');

      final container = _container(
        db,
        store: store,
        decoder: JwtFeatureDecoder(now: DateTime.utc(2027, 1, 1)),
      );
      addTearDown(container.dispose);

      await container.read(licenseProvider.notifier).load();
      final state = container.read(licenseProvider);
      expect(state.status, LicenseStatus.expired);
      expect(state.isActivated, isFalse);
      expect(state.message, contains('expired'));
    });

    test('a live key exposes expiry and client to the dashboard', () async {
      await LicenseRepository(db).activate(
        activationKey: licenceKey(features: {'retail': true}),
        featuresData: '{"retail":true}',
      );

      final container = _container(db, store: store);
      addTearDown(container.dispose);

      await container.read(licenseProvider.notifier).load();
      final state = container.read(licenseProvider);
      expect(state.status, LicenseStatus.active);
      expect(state.client, 'Test Pharmacy');
      expect(state.featureEnabled('retail'), isTrue);
      expect(state.expiresAt, isNotNull);
      expect(state.daysRemaining, greaterThan(300));
    });

    test('a key inside the warning window reports expiringSoon', () async {
      await LicenseRepository(db).activate(
        activationKey: licenceKey(
          expiresAt: DateTime.now().add(const Duration(days: 9)),
        ),
        featuresData: '{"retail":true}',
      );

      final container = _container(db, store: store);
      addTearDown(container.dispose);

      await container.read(licenseProvider.notifier).load();
      expect(container.read(licenseProvider).expiringSoon, isTrue);
    });

    test('an absent feature key reads as disabled', () async {
      await LicenseRepository(db).activate(
        activationKey: licenceKey(features: {'retail': true}),
        featuresData: '{"retail":true}',
      );

      final container = _container(db, store: store);
      addTearDown(container.dispose);

      await container.read(licenseProvider.notifier).load();
      final state = container.read(licenseProvider);
      expect(state.featureEnabled('retail'), isTrue);
      expect(state.featureEnabled('credit'), isFalse);
    });

    test(
      'deactivate clears the licence and returns to the activation gate',
      () async {
        final container = _container(db, store: store);
        addTearDown(container.dispose);

        await container.read(licenseProvider.notifier).activate(licenceKey());
        expect(container.read(licenseProvider).isActivated, isTrue);
        expect(store.values, contains(SecureStore.keyLicenseKey));

        await container.read(licenseProvider.notifier).deactivate();
        expect(
          container.read(licenseProvider).status,
          LicenseStatus.notActivated,
        );
        expect(await LicenseRepository(db).current(), isNull);
        expect(store.values, isNot(contains(SecureStore.keyLicenseKey)));
      },
    );
  });

  group('permissions', () {
    Future<void> signInAs(UserRole role) async {
      final container = _container(db, store: store);
      addTearDown(container.dispose);

      await UserRepository(db, passwords: testPasswords).create(
        username: role == UserRole.admin ? 'owner' : 'till1',
        secret: 'long-enough',
        role: role,
      );
      await container
          .read(authProvider.notifier)
          .signIn(
            username: role == UserRole.admin ? 'owner' : 'till1',
            secret: 'long-enough',
          );

      expect(
        container.read(permissionProvider(Permission.pos)),
        isTrue,
        reason: 'both roles may use the POS',
      );
      expect(
        container.read(permissionProvider(Permission.viewCostPrice)),
        role == UserRole.admin,
      );
      expect(
        container.read(permissionProvider(Permission.viewProfitReports)),
        role == UserRole.admin,
      );
    }

    test(
      'an admin holds cost prices and reports',
      () => signInAs(UserRole.admin),
    );

    test(
      'a cashier is denied cost prices and reports',
      () => signInAs(UserRole.cashier),
    );

    test('permission checks fail closed when signed out', () async {
      final container = _container(db, store: store);
      addTearDown(container.dispose);

      for (final permission in Permission.values) {
        expect(
          container.read(permissionProvider(permission)),
          isFalse,
          reason: '$permission must be denied with no session',
        );
      }
    });

    test('signOut clears the session and the stored user id', () async {
      final store = MemoryKeyValueStore();
      final container = _container(db, store: store);
      addTearDown(container.dispose);

      await UserRepository(
        db,
        passwords: testPasswords,
      ).create(username: 'owner', secret: 'long-enough', role: UserRole.admin);
      await container
          .read(authProvider.notifier)
          .signIn(username: 'owner', secret: 'long-enough');
      expect(store.values, contains(SecureStore.keySessionUser));

      await container.read(authProvider.notifier).signOut();
      expect(container.read(authProvider), isNull);
      expect(store.values, isNot(contains(SecureStore.keySessionUser)));
    });
  });
}
