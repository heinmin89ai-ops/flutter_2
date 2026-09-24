import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/core/rbac/permission.dart';
import 'package:pharmacy_pos/features/auth/application/password_service.dart';
import 'package:pharmacy_pos/features/auth/data/user_repository.dart';

/// Low iteration count keeps the suite fast; correctness of the derivation
/// itself is covered by `pbkdf2_vectors_test.dart`.
const PasswordService fast = PasswordService(iterations: 1000);

void main() {
  late AppDatabase db;
  late UserRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = UserRepository(db, passwords: fast);
  });

  tearDown(() => db.close());

  /// Force a role/active change past the guard, to set up a scenario the guard
  /// itself would refuse to produce.
  Future<void> forceSetActive(int userId, bool active) {
    return (db.update(db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(isActive: Value(active)),
    );
  }

  group('authenticate', () {
    test('accepts a correct username and secret', () async {
      await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      expect(
        await repo.authenticate(username: 'owner', secret: 'long-enough'),
        AuthOutcome.success,
      );
    });

    test('rejects a wrong secret', () async {
      await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      expect(
        await repo.authenticate(username: 'owner', secret: 'nope'),
        AuthOutcome.invalidCredentials,
      );
    });

    test('does not reveal whether the account exists', () async {
      await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      // Both failures return the same coarse outcome, so the screen cannot leak
      // which half was wrong.
      expect(
        await repo.authenticate(username: 'ghost', secret: 'whatever'),
        AuthOutcome.invalidCredentials,
      );
      expect(
        await repo.authenticate(username: 'owner', secret: 'whatever'),
        AuthOutcome.invalidCredentials,
      );
    });

    test('matches username case-insensitively', () async {
      await repo.create(
        username: 'Owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      expect(
        await repo.authenticate(username: 'owner', secret: 'long-enough'),
        AuthOutcome.success,
      );
    });

    test(
      'rejects a soft-deleted account without deleting their history',
      () async {
        final created = await repo.create(
          username: 'cashier1',
          secret: 'long-enough',
          role: UserRole.cashier,
        );
        await repo.setActive(userId: created.id, isActive: false);

        expect(
          await repo.authenticate(username: 'cashier1', secret: 'long-enough'),
          AuthOutcome.inactive,
        );
        // The row survives so past sales still resolve to a name.
        expect(await repo.findById(created.id), isNotNull);
      },
    );

    test('never stores the secret in the row', () async {
      await repo.create(
        username: 'owner',
        secret: 'super-secret-99',
        role: UserRole.admin,
      );
      final stored = (await db.select(db.users).getSingle()).pinHash;
      expect(stored, isNot(contains('super-secret-99')));
      expect(stored.split(r'$'), hasLength(2));
    });

    test('two accounts may share the same secret', () async {
      await repo.create(
        username: 'staff-a',
        secret: 'same-pass',
        role: UserRole.cashier,
      );
      await repo.create(
        username: 'staff-b',
        secret: 'same-pass',
        role: UserRole.cashier,
      );
      expect(await repo.findAll(), hasLength(2));
      final hashes = (await db.select(db.users).get())
          .map((u) => u.pinHash)
          .toSet();
      // Distinct salts, so identical secrets must not produce identical hashes.
      expect(hashes, hasLength(2));
    });

    test('a corrupt stored hash fails closed rather than throwing', () async {
      final user = await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      await (db.update(db.users)..where((t) => t.id.equals(user.id))).write(
        const UsersCompanion(pinHash: Value('not-a-hash')),
      );

      expect(
        await repo.authenticate(username: 'owner', secret: 'long-enough'),
        AuthOutcome.invalidCredentials,
      );
    });
  });

  group('last-admin guard', () {
    test('hasActiveAdmin is false on an empty table', () async {
      expect(await repo.hasActiveAdmin(), isFalse);
    });

    test('a cashier never satisfies the admin requirement', () async {
      await repo.create(
        username: 'cashier1',
        secret: 'long-enough',
        role: UserRole.cashier,
      );
      expect(await repo.hasActiveAdmin(), isFalse);
    });

    test(
      'deactivating the only admin is refused and leaves it active',
      () async {
        final admin = await repo.create(
          username: 'owner',
          secret: 'long-enough',
          role: UserRole.admin,
        );

        expect(
          () => repo.setActive(userId: admin.id, isActive: false),
          throwsA(isA<LastAdminException>()),
        );
        expect((await repo.findById(admin.id))!.isActive, isTrue);
        expect(await repo.hasActiveAdmin(), isTrue);
      },
    );

    test(
      'deactivating the last admin twice does not succeed the second time',
      () async {
        // Guards against a check-then-write race reading the row as already
        // inactive and letting the update through.
        final admin = await repo.create(
          username: 'owner',
          secret: 'long-enough',
          role: UserRole.admin,
        );
        for (var attempt = 0; attempt < 2; attempt++) {
          expect(
            () => repo.setActive(userId: admin.id, isActive: false),
            throwsA(isA<LastAdminException>()),
          );
        }
      },
    );

    test('a second admin may deactivate the first', () async {
      final first = await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      await repo.create(
        username: 'second-owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );

      await repo.setActive(userId: first.id, isActive: false);

      expect((await repo.findById(first.id))!.isActive, isFalse);
      expect(await repo.hasActiveAdmin(), isTrue);
    });

    test('an already-inactive admin may be left inactive', () async {
      final admin = await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      final other = await repo.create(
        username: 'second-owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      await forceSetActive(admin.id, false);

      // Re-applying isActive: false to a row that is already inactive is not
      // the dangerous case, and must not throw.
      await repo.setActive(userId: admin.id, isActive: false);
      expect((await repo.findById(admin.id))!.isActive, isFalse);

      // With only `other` left active, that one is now protected.
      expect(
        () => repo.setActive(userId: other.id, isActive: false),
        throwsA(isA<LastAdminException>()),
      );
    });

    test('reactivating an admin is always allowed', () async {
      final admin = await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      await forceSetActive(admin.id, false);
      expect(await repo.hasActiveAdmin(), isFalse);

      await repo.setActive(userId: admin.id, isActive: true);
      expect(await repo.hasActiveAdmin(), isTrue);
    });

    test('a cashier may be deactivated freely', () async {
      final cashier = await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      final second = await repo.create(
        username: 'cashier1',
        secret: 'long-enough',
        role: UserRole.cashier,
      );
      await repo.setActive(userId: second.id, isActive: false);
      expect((await repo.findById(cashier.id))!.isActive, isTrue);
    });
  });

  group('create', () {
    test('rejects a conflicting username', () async {
      await repo.create(
        username: 'owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      expect(
        () => repo.create(
          username: 'owner',
          secret: 'other-one',
          role: UserRole.cashier,
        ),
        throwsA(isA<UserConflictException>()),
      );
    });

    test('treats a differing-case name as the same conflict', () async {
      await repo.create(
        username: 'Owner',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      expect(
        () => repo.create(
          username: 'owner',
          secret: 'other-one',
          role: UserRole.cashier,
        ),
        throwsA(isA<UserConflictException>()),
      );
    });

    test('trims surrounding whitespace from the username', () async {
      final user = await repo.create(
        username: '  owner  ',
        secret: 'long-enough',
        role: UserRole.admin,
      );
      expect(user.username, 'owner');
    });
  });

  test(
    'setSecret invalidates the old secret and activates the new one',
    () async {
      final user = await repo.create(
        username: 'owner',
        secret: 'first-pass',
        role: UserRole.admin,
      );
      await repo.setSecret(userId: user.id, newSecret: 'second-pass');

      expect(
        await repo.authenticate(username: 'owner', secret: 'first-pass'),
        AuthOutcome.invalidCredentials,
      );
      expect(
        await repo.authenticate(username: 'owner', secret: 'second-pass'),
        AuthOutcome.success,
      );
    },
  );

  test('changeSecret requires the current secret', () async {
    final user = await repo.create(
      username: 'owner',
      secret: 'first-pass',
      role: UserRole.admin,
    );

    expect(
      await repo.changeSecret(
        userId: user.id,
        currentSecret: 'wrong',
        newSecret: 'third-pass',
      ),
      AuthOutcome.invalidCredentials,
    );
    expect(
      await repo.authenticate(username: 'owner', secret: 'third-pass'),
      AuthOutcome.invalidCredentials,
    );

    expect(
      await repo.changeSecret(
        userId: user.id,
        currentSecret: 'first-pass',
        newSecret: 'third-pass',
      ),
      AuthOutcome.success,
    );
    expect(
      await repo.authenticate(username: 'owner', secret: 'third-pass'),
      AuthOutcome.success,
    );
  });

  test('findAll lists active staff ahead of deactivated ones', () async {
    final gone = await repo.create(
      username: 'zed-cashier',
      secret: 'long-enough',
      role: UserRole.cashier,
    );
    await repo.create(
      username: 'owner',
      secret: 'long-enough',
      role: UserRole.admin,
    );
    await repo.setActive(userId: gone.id, isActive: false);

    final names = (await repo.findAll()).map((u) => u.username).toList();
    expect(names.first, 'owner');
    expect(names, hasLength(2));
  });

  group('RBAC map', () {
    test('cashier holds only POS and inventory read', () {
      expect(kRolePermissions[UserRole.cashier], {
        Permission.pos,
        Permission.viewInventory,
      });
    });

    test('cashier is denied cost prices, reports, credit and user admin', () {
      for (final denied in [
        Permission.viewCostPrice,
        Permission.viewProfitReports,
        Permission.manageCredit,
        Permission.manageUsers,
        Permission.deleteTransaction,
        Permission.manageInventory,
        Permission.manageBackup,
      ]) {
        expect(
          roleHasPermission(UserRole.cashier, denied),
          isFalse,
          reason: 'cashier must not hold $denied',
        );
      }
    });

    test('admin holds every permission in the enum', () {
      for (final permission in Permission.values) {
        expect(
          roleHasPermission(UserRole.admin, permission),
          isTrue,
          reason: 'admin is missing $permission',
        );
      }
    });
  });
}
