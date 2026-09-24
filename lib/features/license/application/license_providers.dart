import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/secure/secure_store.dart';
import '../data/license_repository.dart';
import 'key_codec.dart';

/// Boot state for Module 1.
enum LicenseStatus {
  /// Not yet determined; [LicenseNotifier.load] has not completed.
  unknown,

  /// `license_config` is empty — route to the activation screen.
  notActivated,

  /// Key present and decoded — route to login.
  active,

  /// Row exists but the payload is unreadable or expired.
  invalidKey,
}

class LicenseState {
  const LicenseState({
    required this.status,
    this.features = const {},
    this.message,
  });

  final LicenseStatus status;

  /// Decoded module flags, e.g. `{'pos': true, 'credit': false}`.
  final Map<String, bool> features;

  /// Human-readable reason when [status] is [LicenseStatus.invalidKey].
  final String? message;

  bool get isActivated => status == LicenseStatus.active;

  /// Feature-gate check. A missing key is treated as disabled, so a licence
  /// issued before a module existed cannot accidentally enable it.
  bool featureEnabled(String module) => features[module] ?? false;
}

/// Loads the licence once at startup and drives the boot route.
class LicenseNotifier extends Notifier<LicenseState> {
  @override
  LicenseState build() => const LicenseState(status: LicenseStatus.unknown);

  /// Reads `license_config`; when a row exists, decodes the stored permission
  /// blob into the feature map. Called from the boot screen's `initState`.
  Future<void> load() async {
    final config = await ref.read(licenseRepositoryProvider).current();
    if (config == null) {
      state = const LicenseState(status: LicenseStatus.notActivated);
      return;
    }

    try {
      state = LicenseState(
        status: LicenseStatus.active,
        features: _parseFeatures(config.featuresData),
      );
    } on FormatException catch (e) {
      // A corrupt blob must not brick the app: surface it, and let the
      // activation screen take the key the shop already owns.
      state = LicenseState(
        status: LicenseStatus.invalidKey,
        message:
            'Stored permissions unreadable (${e.message}). '
            'Re-enter your activation key.',
      );
    }
  }

  /// Activate this device. Returns `false` and records the reason on the state
  /// when the key is malformed, mistyped or expired.
  Future<bool> activate(String activationKey) async {
    final Map<String, bool> features;
    try {
      features = ref.read(featureDecoderProvider).decode(activationKey);
    } on ActivationKeyException catch (e) {
      state = LicenseState(
        status: LicenseStatus.invalidKey,
        message: e.message,
      );
      return false;
    }

    final key = activationKey.trim();
    await ref
        .read(licenseRepositoryProvider)
        .activate(
          activationKey: key,
          // Re-encode the decoded map instead of storing the key's substring, so
          // the row stays parseable even if the vendor changes key framing.
          featuresData: jsonEncode(features),
        );
    await ref
        .read(secureStoreProvider)
        .write(key: SecureStore.keyLicenseKey, value: key);

    state = LicenseState(status: LicenseStatus.active, features: features);
    return true;
  }

  Map<String, bool> _parseFeatures(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value == true));
  }
}

final NotifierProvider<LicenseNotifier, LicenseState> licenseProvider =
    NotifierProvider<LicenseNotifier, LicenseState>(LicenseNotifier.new);

final Provider<FeatureDecoder> featureDecoderProvider =
    Provider<FeatureDecoder>((ref) => const PhaseOneFeatureDecoder());

final Provider<LicenseRepository> licenseRepositoryProvider =
    Provider<LicenseRepository>(
      (ref) => LicenseRepository(ref.watch(appDatabaseProvider)),
    );
