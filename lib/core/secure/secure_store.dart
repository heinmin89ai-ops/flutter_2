import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value surface [SecureStore] depends on.
///
/// Exists so the boot flow can be tested without a platform channel: an
/// in-memory implementation stands in for the device keystore.
abstract interface class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write({required String key, required String value});

  Future<void> delete(String key);
}

class _FlutterSecureKeyValueStore implements KeyValueStore {
  const _FlutterSecureKeyValueStore();

  /// flutter_secure_storage 11 encrypts by default (AES-GCM data key wrapped by
  /// an Android Keystore RSA key), so no legacy `encryptedSharedPreferences`
  /// flag is needed or accepted.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Wrapper over the platform secure storage.
///
/// Scope: the licence key and the logged-in session only. Database rows are not
/// covered — encryption at rest (SQLCipher) is deferred to Phase 7, so cost
/// prices and customer debts live in a plain SQLite file until then.
class SecureStore {
  SecureStore({KeyValueStore? store})
    : _store = store ?? const _FlutterSecureKeyValueStore();

  final KeyValueStore _store;

  static const String keyLicenseKey = 'license.activation_key';
  static const String keySessionUser = 'auth.session.user_id';

  Future<String?> read(String key) => _store.read(key);

  Future<void> write({required String key, required String value}) =>
      _store.write(key: key, value: value);

  Future<void> delete(String key) => _store.delete(key);

  Future<void> clearSession() => delete(keySessionUser);

  Future<int?> readSessionUserId() async {
    final raw = await read(keySessionUser);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> writeSessionUserId(int userId) =>
      write(key: keySessionUser, value: userId.toString());
}

/// In-memory [KeyValueStore] for tests.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
