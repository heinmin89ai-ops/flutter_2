import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import '../secure/secure_store.dart';

/// Single app-wide database handle.
///
/// Lazy: the first read opens the file. Overriding this provider with
/// `AppDatabase.forTesting(NativeDatabase.memory())` is how every repository
/// test swaps in an in-memory database without touching production code.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final Provider<SecureStore> secureStoreProvider = Provider<SecureStore>(
  (ref) => SecureStore(),
);
