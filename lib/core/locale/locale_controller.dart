import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/secure/secure_store.dart';

/// Holds the current locale code ('en' | 'my').
///
/// Defaults to 'en' until [load] reads a persisted value from [SecureStore].
/// [setLocale] persists the change and updates state in one step. The locale is
/// stored in secure storage alongside the licence key and session, so it
/// survives app restarts.
class LocaleController extends Notifier<String> {
  @override
  String build() => 'en';

  /// Reads the persisted locale from secure storage and updates state if found.
  ///
  /// Called during app bootstrap after the store is available. No-op when no
  /// locale has been saved — the default 'en' from [build] is kept.
  Future<void> load() async {
    final saved = await ref.read(secureStoreProvider).readLocale();
    if (saved != null) {
      state = saved;
    }
  }

  /// Changes the locale and persists it to secure storage.
  ///
  /// No-op when [code] matches the current locale, avoiding redundant writes.
  Future<void> setLocale(String code) async {
    if (code == state) return;
    state = code;
    await ref.read(secureStoreProvider).writeLocale(code);
  }
}

final NotifierProvider<LocaleController, String> localeProvider =
    NotifierProvider<LocaleController, String>(LocaleController.new);
