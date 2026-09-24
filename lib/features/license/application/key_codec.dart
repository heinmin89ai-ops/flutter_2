/// Contract between a vendor key and the rest of the app.
///
/// Kept separate from any one key format on purpose: Phase 1 shipped a
/// checksum-only key, Phase 2 verifies an HS256 JWT, and the plan for a paid
/// product is Ed25519 so the app cannot mint licences. Each swap is one class
/// plus one provider override; nothing outside this file and
/// `license_providers.dart` knows which format is live.
library;

/// What a licence key grants, independent of how it was encoded.
class LicenceFacts {
  const LicenceFacts({
    required this.features,
    this.expiresAt,
    this.client,
    this.holder,
  });

  /// Module flags, e.g. `{'retail': true, 'wholesale': false}`.
  final Map<String, bool> features;

  /// `exp` claim, or `null` for a perpetual licence.
  final DateTime? expiresAt;

  /// Human-readable customer name from the `client` claim.
  final String? client;

  /// Stable customer identifier from the `sub` claim.
  final String? holder;

  bool featureEnabled(String module) => features[module] ?? false;
}

abstract interface class FeatureDecoder {
  /// Returns the permission facts encoded in [activationKey].
  ///
  /// Implementations must verify integrity *and* expiry, and throw
  /// [ActivationKeyException] otherwise. Called on every app start, not only at
  /// activation, so an expired key stops working after a restart.
  LicenceFacts decode(String activationKey);
}

class ActivationKeyException implements Exception {
  const ActivationKeyException(this.message);

  final String message;

  @override
  String toString() => 'ActivationKeyException: $message';
}
