import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/secure/secure_store.dart';
import '../data/license_repository.dart';
import 'jwt_decoder.dart';
import 'key_codec.dart';

/// Error key that marks a signature-valid-but-lapsed key. Used to branch the
/// boot route between [LicenseStatus.expired] and [LicenseStatus.invalidKey]
/// without string-matching the (now localised) message.
const String _expiredKey = 'licenseKeyExpired';

/// Boot state for Module 1.
enum LicenseStatus {
  /// Not yet determined; [LicenseNotifier.load] has not completed.
  unknown,

  /// `license_config` is empty — route to the activation screen.
  notActivated,

  /// Key present, signature valid, not expired — route to login.
  active,

  /// Row exists but the key fails verification or has expired.
  invalidKey,

  /// Signature valid but `exp` has passed. Distinct from [invalidKey] because
  /// the shop's data is intact and the fix is a renewed key, not a support call
  /// about a corrupt install.
  expired,
}

class LicenseState {
  const LicenseState({
    required this.status,
    this.features = const {},
    this.message,
    this.messageArgs = const {},
    this.expiresAt,
    this.client,
  });

  final LicenseStatus status;

  /// Decoded module flags, e.g. `{'retail': true, 'credit': false}`.
  final Map<String, bool> features;

  /// Localisation key for the human-readable reason when [status] is not
  /// [LicenseStatus.active]. Resolved at display via `l10n.message(...)`.
  final String? message;

  /// Placeholder arguments for [message], e.g. `{'date': '2026-01-01'}`.
  final Map<String, String> messageArgs;

  /// `exp` from the verified key, or `null` for a perpetual licence.
  final DateTime? expiresAt;

  /// Customer name the licence was issued to, for the dashboard banner.
  final String? client;

  bool get isActivated => status == LicenseStatus.active;

  /// Feature-gate check. A missing key is treated as disabled, so a licence
  /// issued before a module existed cannot accidentally enable it.
  bool featureEnabled(String module) => features[module] ?? false;

  /// Days until [expiresAt], or `null` when perpetual / not active.
  ///
  /// Negative once past due; the dashboard warns inside [expiryWarningWindow]
  /// so a shop is not cut off mid-sale with no notice.
  int? get daysRemaining {
    final expiry = expiresAt;
    if (expiry == null || !isActivated) return null;
    return expiry.difference(DateTime.now()).inDays;
  }

  static const Duration expiryWarningWindow = Duration(days: 21);

  bool get expiringSoon {
    final remaining = daysRemaining;
    return remaining != null && remaining <= expiryWarningWindow.inDays;
  }
}

/// Loads the licence once at startup and drives the boot route.
class LicenseNotifier extends Notifier<LicenseState> {
  @override
  LicenseState build() => const LicenseState(status: LicenseStatus.unknown);

  /// Reads `license_config` and **re-verifies the stored key**.
  ///
  /// Phase 1 decoded the key once at activation and trusted `features_data`
  /// afterwards, which meant an expired licence kept working across restarts and
  /// a hand-edited `features_data` was honoured verbatim. Both are closed here by
  /// treating the persisted `activation_key` as the only source of truth and
  /// re-running signature + expiry checks on every start.
  ///
  /// The stored `features_data` is still written, but only as a display cache —
  /// nothing gates on it.
  Future<void> load() async {
    final config = await ref.read(licenseRepositoryProvider).current();
    if (config == null) {
      state = const LicenseState(status: LicenseStatus.notActivated);
      return;
    }

    final result = ref
        .read(featureDecoderProvider)
        .verifyStored(config.activationKey);

    if (!result.isValid) {
      final error = result.error;
      state = LicenseState(
        status: error?.errorKey == _expiredKey
            ? LicenseStatus.expired
            : LicenseStatus.invalidKey,
        message: error?.errorKey ?? 'licenseStoredKeyInvalid',
        messageArgs: error?.errorArgs ?? const {},
      );
      return;
    }

    final facts = result.facts!;
    state = LicenseState(
      status: LicenseStatus.active,
      features: facts.features,
      expiresAt: facts.expiresAt,
      client: facts.client,
    );
  }

  /// Activate this device. Returns `false` and records the reason on the state
  /// when the key is malformed, mistyped, forged or expired.
  Future<bool> activate(String activationKey) async {
    final LicenceFacts facts;
    try {
      facts = ref.read(featureDecoderProvider).decode(activationKey);
    } on ActivationKeyException catch (e) {
      state = LicenseState(
        status: e.errorKey == _expiredKey
            ? LicenseStatus.expired
            : LicenseStatus.invalidKey,
        message: e.errorKey,
        messageArgs: e.errorArgs,
      );
      return false;
    }

    final key = activationKey.trim();
    await ref
        .read(licenseRepositoryProvider)
        .activate(
          activationKey: key,
          // Cached for display only; `load` re-derives the truth from the key.
          featuresData: jsonEncode(facts.features),
        );
    await ref
        .read(secureStoreProvider)
        .write(key: SecureStore.keyLicenseKey, value: key);

    state = LicenseState(
      status: LicenseStatus.active,
      features: facts.features,
      expiresAt: facts.expiresAt,
      client: facts.client,
    );
    return true;
  }

  /// Clears the local licence so a re-entered key can be tested end to end.
  ///
  /// Sales data is untouched; this only removes the activation row and the
  /// mirrored key. Reached from the licence panel, not the login screen.
  Future<void> deactivate() async {
    await ref.read(licenseRepositoryProvider).clear();
    await ref.read(secureStoreProvider).delete(SecureStore.keyLicenseKey);
    state = const LicenseState(status: LicenseStatus.notActivated);
  }
}

final NotifierProvider<LicenseNotifier, LicenseState> licenseProvider =
    NotifierProvider<LicenseNotifier, LicenseState>(LicenseNotifier.new);

/// The live key format. Swap this one line to move to Ed25519 (see
/// `license_secret.dart`) without touching the boot screen or any consumer.
final Provider<JwtFeatureDecoder> featureDecoderProvider =
    Provider<JwtFeatureDecoder>((ref) => const JwtFeatureDecoder());

final Provider<LicenseRepository> licenseRepositoryProvider =
    Provider<LicenseRepository>(
      (ref) => LicenseRepository(ref.watch(appDatabaseProvider)),
    );
