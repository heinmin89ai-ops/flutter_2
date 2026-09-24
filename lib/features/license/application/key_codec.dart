import 'dart:convert';

/// Decodes a vendor activation key into a module-permission map.
///
/// Interface-first on purpose. A locally-stored, locally-decoded permission blob
/// is tamperable — editing the JSON on a rooted device unlocks paid modules — so
/// Phase 1 wraps the decoder behind [FeatureDecoder] to let an HMAC-verified or
/// signed implementation replace it in Phase 7 without touching the boot screen
/// or any feature-flag consumer.
abstract interface class FeatureDecoder {
  /// Returns the permission map encoded in [activationKey].
  ///
  /// Throws [ActivationKeyException] if the key is malformed or expired.
  Map<String, bool> decode(String activationKey);
}

class ActivationKeyException implements Exception {
  const ActivationKeyException(this.message);

  final String message;

  @override
  String toString() => 'ActivationKeyException: $message';
}

/// Key format implemented in Phase 1:
///
/// ```
/// PH1-<base64url(json)>-<checksum-hex>
/// ```
///
/// base64url's own alphabet contains `-`, so the payload may itself hold
/// separators. The decoder therefore treats only the *first* and *last*
/// segments as fixed and rejoins everything between them as the payload, rather
/// than assuming exactly three parts.
///
/// Example payload: `{"pos":true,"reports":true,"credit":false,"exp":"2027-01-01"}`
///
/// The trailing checksum catches typos at the activation field, which is the
/// failure this actually sees in a shop. It is **not** a signature — anyone can
/// produce a valid checksum for forged features. Treat Phase 1 licensing as
/// convenience, not protection, until a signed decoder lands.
class PhaseOneFeatureDecoder implements FeatureDecoder {
  const PhaseOneFeatureDecoder();

  static const String prefix = 'PH1';

  @override
  Map<String, bool> decode(String activationKey) {
    // Trim only. The payload is base64url and therefore case-sensitive; a
    // toUpperCase() here would silently reject every correctly issued key.
    final parts = activationKey.trim().split('-');

    if (parts.length < 3 || parts.first.toUpperCase() != prefix) {
      throw const ActivationKeyException(
        'Key must look like PH1-<payload>-<checksum>.',
      );
    }

    // Rejoin the middle: the payload may legitimately contain '-'.
    final payload = parts.sublist(1, parts.length - 1).join('-');
    final checksum = int.tryParse(parts.last, radix: 16);
    if (checksum == null) {
      throw const ActivationKeyException('Invalid checksum segment.');
    }
    if (checksumOf(payload) != checksum) {
      throw const ActivationKeyException(
        'Checksum mismatch — key mistyped or corrupted.',
      );
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      ) as Map<String, dynamic>;
    } on FormatException {
      throw const ActivationKeyException('Payload is not valid base64/JSON.');
    }

    _validateExpiry(decoded['exp']);

    return decoded.map((key, value) => MapEntry(key, value == true));
  }

  void _validateExpiry(Object? raw) {
    if (raw == null) return;
    final expiry = DateTime.tryParse(raw.toString());
    if (expiry == null) {
      throw const ActivationKeyException('Unreadable expiry date in key.');
    }
    if (expiry.isBefore(DateTime.now())) {
      throw ActivationKeyException(
        'Key expired on ${expiry.toIso8601String()}.',
      );
    }
  }

  /// Fletcher-16 over the payload bytes. Cheap and adequate for typo detection.
  static int checksumOf(String input) {
    var sum1 = 0;
    var sum2 = 0;
    for (final byte in utf8.encode(input)) {
      sum1 = (sum1 + byte) % 65535;
      sum2 = (sum2 + sum1) % 65535;
    }
    return (sum2 << 16) | sum1;
  }

  /// Builds a key the decoder accepts.
  ///
  /// Test and demo helper only — vendor issuance is out of scope for Phase 1.
  static String issueKey(Map<String, Object> features) {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode(features)))
        .replaceAll('=', '');
    final checksum = checksumOf(payload).toRadixString(16).padLeft(8, '0');
    return '$prefix-$payload-$checksum';
  }
}
