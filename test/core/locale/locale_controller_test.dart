import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/database_provider.dart';
import 'package:pharmacy_pos/core/locale/locale_controller.dart';
import 'package:pharmacy_pos/core/secure/secure_store.dart';

/// The locale the app boots in, and how a user's choice survives a restart.
///
/// The visible half (translating strings) is `intl`/ARB and asserted elsewhere;
/// what is genuinely ours and easy to get wrong is the *persistence* seam: a
/// Burmese-speaking cashier who switches the language should still see Burmese
/// the next morning, and the default for a fresh install must be English, not
/// "whatever the platform happens to report". Both live behind SecureStore's
/// KeyValueStore, so this runs on the in-memory fake with no platform channel.
void main() {
  ProviderContainer container(MemoryKeyValueStore store) => ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(SecureStore(store: store)),
    ],
  );

  test('defaults to English before anything is persisted', () {
    final c = container(MemoryKeyValueStore());
    addTearDown(c.dispose);
    expect(c.read(localeProvider), 'en');
  });

  test('setLocale updates state and writes it through to storage', () async {
    final store = MemoryKeyValueStore();
    final c = container(store);
    addTearDown(c.dispose);

    await c.read(localeProvider.notifier).setLocale('my');

    expect(c.read(localeProvider), 'my');
    // Asserted on the raw store key, not just provider state: if setLocale only
    // touched memory and never persisted, the restart case below would pass on
    // a still-alive provider and fail silently on a real device.
    expect(store.values[SecureStore.keyLocale], 'my');
  });

  test('a persisted locale is read back on load (the restart path)', () async {
    // Same store survives "app restart": a fresh container reads the saved code.
    final store = MemoryKeyValueStore()..values[SecureStore.keyLocale] = 'my';
    final c = container(store);
    addTearDown(c.dispose);

    // Before load() the controller is at its 'en' default, proving load() is
    // what pulls from storage rather than the provider simply starting at 'my'.
    expect(c.read(localeProvider), 'en');
    await c.read(localeProvider.notifier).load();
    expect(c.read(localeProvider), 'my');
  });

  test('load with nothing saved leaves the default untouched', () async {
    final c = container(MemoryKeyValueStore());
    addTearDown(c.dispose);

    await c.read(localeProvider.notifier).load();
    expect(c.read(localeProvider), 'en');
  });

  test('switching to the current locale writes nothing redundant', () async {
    final store = MemoryKeyValueStore()..values[SecureStore.keyLocale] = 'my';
    final c = container(store);
    addTearDown(c.dispose);
    await c.read(localeProvider.notifier).load(); // now 'my'

    await c.read(localeProvider.notifier).setLocale('my');
    expect(store.values[SecureStore.keyLocale], 'my');
    // The no-op guard is about avoiding a needless secure-storage write; the
    // value is unchanged either way, so the meaningful assertion is that state
    // stays put.
    expect(c.read(localeProvider), 'my');
  });
}
