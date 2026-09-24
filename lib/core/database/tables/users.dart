import 'package:drift/drift.dart';

/// Roles recognised by the RBAC layer.
///
/// Stored in SQL as the lower-case enum name (`admin` / `cashier`), which keeps
/// the `users.role` column readable when inspected with a raw SQLite client.
enum UserRole { admin, cashier }

/// `users` — local authentication identities (Module 2).
///
/// Rows are soft-deleted via [isActive] rather than removed: a cashier's sales
/// history must keep resolving to a name after they leave the shop.
@DataClassName('AppUser')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Login handle. Case-insensitive uniqueness so `Nay` and `nay` cannot both
  /// exist and confuse a cashier at the till.
  TextColumn get username =>
      text().withLength(min: 3, max: 32).customConstraint('NOT NULL UNIQUE')();

  /// `salt$derivedKey`, PBKDF2-HMAC-SHA256. Never the secret itself.
  TextColumn get pinHash => text().named('pin_hash')();

  TextColumn get role => textEnum<UserRole>()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true)).named('is_active')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  String get tableName => 'users';
}
