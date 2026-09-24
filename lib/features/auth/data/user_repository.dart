import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/users.dart';
import '../application/password_service.dart';

/// Result of a credential check, kept deliberately coarse.
///
/// The screen must not be able to tell "no such user" from "wrong PIN" — that
/// distinction is exactly what an offline attacker probing the till uses.
enum AuthOutcome { success, invalidCredentials, inactive }

/// Data access for `users`, plus the hashing boundary.
class UserRepository {
  UserRepository(this._db, {this._passwords = const PasswordService()});

  final AppDatabase _db;
  final PasswordService _passwords;

  /// All users, active first, for the admin user list.
  Future<List<AppUser>> findAll() {
    final query = _db.select(_db.users)
      ..orderBy([
        (t) => OrderingTerm(expression: t.isActive, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.username),
      ]);
    return query.get();
  }

  Future<AppUser?> findById(int id) {
    return (_db.select(
      _db.users,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Case-insensitive lookup. SQLite `=` is case-sensitive, so the comparison is
  /// done on the Dart side of a `LIKE`-free scan over a table with a handful of
  /// rows — cheaper and clearer than a `collate NOCASE` column here.
  Future<AppUser?> findByUsername(String username) async {
    final all = await _db.select(_db.users).get();
    final wanted = username.trim().toLowerCase();
    for (final user in all) {
      if (user.username.toLowerCase() == wanted) return user;
    }
    return null;
  }

  /// Verify credentials without leaking which half failed.
  Future<AuthOutcome> authenticate({
    required String username,
    required String secret,
  }) async {
    final user = await findByUsername(username);
    if (user == null) {
      // Burn the same work as a real verification so timing does not reveal
      // whether the account exists.
      _passwords.verify(secret, _decoyHash);
      return AuthOutcome.invalidCredentials;
    }
    if (!user.isActive) return AuthOutcome.inactive;
    return _passwords.verify(secret, user.pinHash)
        ? AuthOutcome.success
        : AuthOutcome.invalidCredentials;
  }

  /// Create a user. Throws [UserConflictException] if the handle is taken.
  Future<AppUser> create({
    required String username,
    required String secret,
    required UserRole role,
  }) async {
    final trimmed = username.trim();
    if (await findByUsername(trimmed) != null) {
      throw UserConflictException(trimmed);
    }
    final id = await _db
        .into(_db.users)
        .insert(
          UsersCompanion.insert(
            username: trimmed,
            pinHash: _passwords.hash(secret),
            role: role,
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(id))!;
  }

  /// Rotate a secret, or repair a forgotten cashier PIN from the admin screen.
  Future<void> setSecret({required int userId, required String newSecret}) {
    return (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(pinHash: Value(_passwords.hash(newSecret))),
    );
  }

  /// Soft delete. A hard delete would orphan every sale the cashier rang up.
  ///
  /// Refuses to deactivate the last active admin: a shop with no reachable
  /// admin cannot manage users or see cost prices, and an offline device has no
  /// recovery path.
  Future<void> setActive({required int userId, required bool isActive}) async {
    if (!isActive) {
      final target = await findById(userId);
      if (target != null &&
          target.role == UserRole.admin &&
          target.isActive &&
          !await hasOtherActiveAdmin(exceptUserId: userId)) {
        throw LastAdminException();
      }
    }
    await (_db.update(_db.users)..where((t) => t.id.equals(userId))).write(
      UsersCompanion(isActive: Value(isActive)),
    );
  }

  /// Whether an active admin exists besides [exceptUserId].
  ///
  /// Counted in Dart: `users` holds a handful of staff per shop, and filtering
  /// here avoids a second SQL shape to keep in sync with [hasActiveAdmin].
  Future<bool> hasOtherActiveAdmin({required int exceptUserId}) async {
    final admins =
        await (_db.select(_db.users)..where(
              (t) =>
                  t.role.equals(UserRole.admin.name) & t.isActive.equals(true),
            ))
            .get();
    return admins.any((u) => u.id != exceptUserId);
  }

  /// Whether any admin is still active.
  ///
  /// Used by the user list to decide whether the deactivate action is offered
  /// at all; [setActive] enforces the same rule independently so a stale UI
  /// cannot bypass it.
  Future<bool> hasActiveAdmin() async {
    final total = _db.users.id.count();
    final row =
        await (_db.selectOnly(_db.users)
              ..addColumns([total])
              ..where(
                _db.users.role.equals(UserRole.admin.name) &
                    _db.users.isActive.equals(true),
              ))
            .getSingle();
    return (row.read(total) ?? 0) > 0;
  }

  /// Change the current user's own secret, requiring the old one.
  Future<AuthOutcome> changeSecret({
    required int userId,
    required String currentSecret,
    required String newSecret,
  }) async {
    final user = await findById(userId);
    if (user == null || !_passwords.verify(currentSecret, user.pinHash)) {
      return AuthOutcome.invalidCredentials;
    }
    await setSecret(userId: userId, newSecret: newSecret);
    return AuthOutcome.success;
  }

  Stream<List<AppUser>> watchAll() => _db.select(_db.users).watch();
}

/// Thrown when deactivating the only remaining active admin.
class LastAdminException implements Exception {
  @override
  String toString() => 'Cannot deactivate the last active admin account.';
}

class UserConflictException implements Exception {
  const UserConflictException(this.username);

  final String username;

  @override
  String toString() => 'Username "$username" is already taken.';
}

/// Validly-formed hash of a value no user can type, used to equalise the cost of
/// a failed lookup against a failed verification.
const String _decoyHash =
    'c2FsdHNhbHRzYWx0c2FsdA'
    r'$'
    'ZHVtbXlkdW1teWR1bW15ZHVtbXlkdW1teWR1bW15ZHVtbXlkdW1teQ';
