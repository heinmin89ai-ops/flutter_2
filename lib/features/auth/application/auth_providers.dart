import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/rbac/permission.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/tables/users.dart';
import '../data/user_repository.dart';

final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>(
      (ref) => UserRepository(ref.watch(appDatabaseProvider)),
    );

/// The signed-in user, or `null` at the login screen.
///
/// The session is restored from secure storage on startup so a cashier is not
/// asked for a PIN again every time the app relaunches after a printer error.
class AuthNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  Future<AuthResult> signIn({
    required String username,
    required String secret,
  }) async {
    final repo = ref.read(userRepositoryProvider);
    final outcome = await repo.authenticate(username: username, secret: secret);
    if (outcome != AuthOutcome.success) {
      return AuthResult(outcome: outcome, messageKey: _messageKey(outcome));
    }

    // Re-read to get the row. Safe because the row cannot be deleted by anyone
    // other than this same single-threaded isolate.
    final user = await repo.findByUsername(username);
    if (user == null) {
      return const AuthResult(
        outcome: AuthOutcome.invalidCredentials,
        messageKey: 'authAccountNotFound',
      );
    }

    state = user;
    await ref.read(secureStoreProvider).writeSessionUserId(user.id);
    return AuthResult(outcome: outcome, user: user);
  }

  Future<void> restoreSession() async {
    final userId = await ref.read(secureStoreProvider).readSessionUserId();
    if (userId == null) return;
    final user = await ref.read(userRepositoryProvider).findById(userId);
    // A soft-deleted session must not restore.
    if (user != null && user.isActive) state = user;
  }

  Future<void> signOut() async {
    state = null;
    await ref.read(secureStoreProvider).clearSession();
  }

  static String _messageKey(AuthOutcome outcome) => switch (outcome) {
    AuthOutcome.success => '',
    AuthOutcome.invalidCredentials => 'authInvalidCredentials',
    AuthOutcome.inactive => 'authAccountDisabled',
  };
}

class AuthResult {
  const AuthResult({required this.outcome, this.user, this.messageKey = ''});

  final AuthOutcome outcome;
  final AppUser? user;

  /// Localisation key for the failure, resolved at display time via
  /// `l10n.message(messageKey)`. Empty on success.
  final String messageKey;

  bool get isSuccess => outcome == AuthOutcome.success;
}

final NotifierProvider<AuthNotifier, AppUser?> authProvider =
    NotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

/// Current role, or `null` when signed out.
final Provider<UserRole?> currentUserRoleProvider = Provider<UserRole?>(
  (ref) => ref.watch(authProvider)?.role,
);

/// Whether the signed-in user may exercise a permission.
///
/// Denies every permission when signed out, so guards fail closed instead of
/// requiring a null-handling branch at each call site.
///
/// The licence is a second independent gate handled per-feature as modules land
/// (Phase 2+): a role may allow `manageCredit` while the shop's key has the
/// credit module switched off.
final permissionProvider = Provider.family<bool, Permission>((ref, permission) {
  final role = ref.watch(currentUserRoleProvider);
  return role != null && roleHasPermission(role, permission);
});
