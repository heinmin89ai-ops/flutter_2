import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';

/// In-memory database per test case.
///
/// `beforeOpen` still runs, so the pragmas are exercised against a real SQLite
/// engine rather than asserted by inspection.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<String>> tableNames() async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return rows.map((row) => row.read<String>('name')).toList();
  }

  LicenseConfigCompanion licenseRow({int id = 1, required String key}) {
    return LicenseConfigCompanion.insert(
      id: Value(id),
      activationKey: key,
      featuresData: '{"pos":true}',
      activatedAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  Insertable<AppUser> userRow(String name, {UserRole role = UserRole.admin}) {
    return UsersCompanion.insert(
      username: name,
      pinHash: 'salt\$hash',
      role: role,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('creates the Phase 1 tables', () async {
    expect(await tableNames(), containsAll(['users', 'license_config']));
  });

  group('users', () {
    // Case-insensitive uniqueness is a Dart-side concern (see
    // `UserRepository.findByUsername`); the SQL UNIQUE is byte-exact, which this
    // test pins so the split stays deliberate rather than accidental.
    test('rejects a duplicate username', () async {
      await db.into(db.users).insert(userRow('admin'));
      expect(
        () => db.into(db.users).insert(userRow('admin')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('stores the role as its lower-case name', () async {
      await db
          .into(db.users)
          .insert(userRow('cashier1', role: UserRole.cashier));

      final raw = await db.customSelect('SELECT role FROM users').getSingle();
      expect(raw.read<String>('role'), 'cashier');
    });

    test('is_active defaults to true for soft-delete semantics', () async {
      await db
          .into(db.users)
          .insert(userRow('cashier2', role: UserRole.cashier));
      expect((await db.select(db.users).getSingle()).isActive, isTrue);
    });

    test('rejects a username below the column minimum length', () async {
      expect(
        () => db.into(db.users).insert(userRow('ab')),
        // drift validates withLength in Dart, so the insert never reaches SQLite.
        throwsA(isA<InvalidDataException>()),
      );
    });

    test('accepts a differing-case username at the SQL level', () async {
      await db.into(db.users).insert(userRow('Admin'));
      await db.into(db.users).insert(userRow('admin'));
      expect(await db.select(db.users).get(), hasLength(2));
    });
  });

  group('license_config singleton', () {
    test('accepts id = 1', () async {
      await db.into(db.licenseConfig).insert(licenseRow(key: 'PH1-old-0000'));
      expect(await db.select(db.licenseConfig).get(), hasLength(1));
    });

    test('the CHECK constraint rejects id = 2', () async {
      expect(
        () => db
            .into(db.licenseConfig)
            .insert(licenseRow(id: 2, key: 'PH1-x-0000')),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'insertOrReplace keeps the table at one row on re-activation',
      () async {
        for (final key in ['PH1-old-0000', 'PH1-new-0000']) {
          await db
              .into(db.licenseConfig)
              .insert(licenseRow(key: key), mode: InsertMode.insertOrReplace);
        }

        final rows = await db.select(db.licenseConfig).get();
        expect(rows, hasLength(1));
        expect(rows.single.activationKey, 'PH1-new-0000');
      },
    );
  });

  test('foreign_keys pragma is ON for the connection', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.read<int>('foreign_keys'), 1);
  });

  // journal_mode is asserted manually against a file-backed database only: an
  // in-memory SQLite reports `memory` and cannot switch to WAL, so a test here
  // would be testing the fixture rather than the pragma.
}
