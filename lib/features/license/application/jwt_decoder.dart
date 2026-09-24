import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'key_codec.dart';
import 'license_secret.dart';

/// Decodes and *verifies* a vendor licence key in JWT form (Phase 2).
///
/// ```
/// base64url({"alg":"HS256","typ":"JWT"}) "."
/// base64url({"iss","sub","client","iat","exp","features":{...}}) "."
/// base64url(HMAC-SHA256(header "." payload, kLicenseSecret))
/// ```
///
/// Unlike [PhaseOneFeatureDecoder] the trailing segment is a real signature, so
/// editing the payload to grant extra modules invalidates the key. Expiry comes
/// from the standard `exp` claim as a NumericDate (seconds since the Unix
/// epoch), which is what `tools/license_generator.py` writes.
///
/// Verification is repeated on every app start, not just at activation, because
/// the raw key is persisted in `license_config.activation_key`. See
/// `LicenseNotifier.load`.
class JwtFeatureDecoder implements FeatureDecoder {
  const JwtFeatureDecoder({this.secret = kLicenseSecret, this.now});

  final String secret;

  /// Injectable clock so expiry is testable without waiting a year.
  final DateTime? now;

  static const String issuer = 'pharmacy-pos';

  @override
  LicenceFacts decode(String activationKey) {
    // A JWT contains no whitespace, so stripping it is free and saves the common
    // support ticket where a key wrapped across two lines in an email pastes in
    // with a newline in the middle.
    final segments = activationKey.replaceAll(RegExp(r'\s'), '').split('.');
    if (segments.length != 3) {
      throw const ActivationKeyException(
        'Key must be a JWT: three dot-separated segments.',
      );
    }
    final headerSegment = segments[0];
    final payloadSegment = segments[1];
    final signatureSegment = segments[2];

    final Map<String, dynamic> header = _decodeJson(headerSegment, 'Header');
    final algorithm = header['alg'];
    // Checked before any signature work: accepting `alg: none`, or letting a
    // forged header pick the algorithm, is the classic JWT bypass.
    if (algorithm != 'HS256') {
      throw ActivationKeyException(
        'Unsupported key algorithm ${algorithm == null ? '(missing)' : '"$algorithm"'}.',
      );
    }

    final expected = base64Url
        .encode(_hmac('$headerSegment.$payloadSegment'))
        .replaceAll('=', '');
    if (!_constantTimeEquals(expected, signatureSegment)) {
      throw const ActivationKeyException(
        'Signature mismatch — key mistyped, altered, or issued with a different secret.',
      );
    }

    final Map<String, dynamic> claims = _decodeJson(payloadSegment, 'Payload');

    final issued = claims['iss'];
    if (issued != null && issued != issuer) {
      throw ActivationKeyException('Key issued by unknown vendor "$issued".');
    }

    final expiry = _readExpiry(claims['exp']);
    if (expiry != null && (now ?? DateTime.now()).isAfter(expiry)) {
      throw ActivationKeyException(
        'Key expired on ${expiry.toIso8601String().split('T').first}.',
      );
    }

    final rawFeatures = claims['features'];
    if (rawFeatures is! Map) {
      throw const ActivationKeyException('Key carries no features claim.');
    }

    return LicenceFacts(
      features: rawFeatures.map(
        (key, value) => MapEntry(key.toString(), value == true),
      ),
      expiresAt: expiry,
      client: claims['client']?.toString(),
      holder: claims['sub']?.toString(),
    );
  }

  /// Re-checks a key that is already stored: signature *and* expiry, without
  /// trusting anything previously decoded from it.
  ///
  /// Returns `null` when the key is no longer acceptable, with the reason as the
  /// message. This is the path that closes the Phase 1 gap where an expired
  /// licence kept working forever because `exp` was only read at activation.
  LicenceDecodeResult verifyStored(String activationKey) {
    try {
      return LicenceDecodeResult.success(decode(activationKey));
    } on ActivationKeyException catch (error) {
      return LicenceDecodeResult.failure(error.message);
    }
  }

  DateTime? _readExpiry(Object? raw) {
    if (raw == null) return null; // Perpetual licence; the vendor opted out.
    if (raw is int) return _fromEpoch(raw);
    if (raw is double) return _fromEpoch(raw.toInt());
    final parsed = int.tryParse(raw.toString());
    if (parsed != null) return _fromEpoch(parsed);
    // Tolerate an ISO string so a hand-issued key is not a brick.
    final iso = DateTime.tryParse(raw.toString());
    if (iso != null) return iso;
    throw const ActivationKeyException('Unreadable expiry claim in key.');
  }

  static DateTime _fromEpoch(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

  List<int> _hmac(String message) =>
      Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(message)).bytes;

  Map<String, dynamic> _decodeJson(String segment, String label) {
    final List<int> bytes;
    try {
      bytes = base64Url.decode(base64Url.normalize(segment));
    } on FormatException {
      throw ActivationKeyException('$label segment is not valid base64url.');
    }
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw ActivationKeyException('$label must decode to a JSON object.');
      }
      return decoded;
    } on FormatException {
      throw ActivationKeyException('$label is not valid JSON.');
    } on UnsupportedError {
      throw ActivationKeyException('$label is not valid UTF-8.');
    }
  }

  /// Length-checked byte comparison.
  ///
  /// `==` on Dart strings already bails on the first difference, which leaks how
  /// many leading characters of a correct signature were guessed. For an HMAC
  /// check that is a real, if slow, oracle.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Issues a key signed with [secret].
  ///
  /// Vendor issuance happens through `tools/license_generator.py`; this exists so
  /// tests and the demo build can produce keys the decoder accepts, and so the
  /// Dart and Python signing paths can be cross-checked against each other.
  static String issueKey({
    required Map<String, bool> features,
    DateTime? expiresAt,
    String client = 'Test Pharmacy',
    String sub = 'test-pharmacy',
    String secret = kLicenseSecret,
    DateTime? issuedAt,
  }) {
    final claims = <String, Object>{
      'iss': issuer,
      'sub': sub,
      'client': client,
      'iat': (issuedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
      'features': features,
    };
    if (expiresAt != null) {
      claims['exp'] = expiresAt.millisecondsSinceEpoch ~/ 1000;
    }
    final header = _encode({'alg': 'HS256', 'typ': 'JWT'});
    final payload = _encode(claims);
    final signature = base64Url
        .encode(
          Hmac(
            sha256,
            utf8.encode(secret),
          ).convert(utf8.encode('$header.$payload')).bytes,
        )
        .replaceAll('=', '');
    return '$header.$payload.$signature';
  }

  static String _encode(Map<String, Object?> value) =>
      base64Url.encode(utf8.encode(_canonicalJson(value))).replaceAll('=', '');

  /// JSON with object keys in sorted order, at every depth.
  ///
  /// The vendor tool (`tools/license_generator.py`) signs a sorted encoding, and
  /// an HMAC covers the exact bytes of the payload. Without matching that order
  /// here, the same claims would produce a different signature in Dart than in
  /// Python, so a key issued on the vendor machine would fail to verify in the
  /// app. Sorting also makes issuance stable if a key is ever re-issued.
  static String _canonicalJson(Map<String, Object?> value) {
    final keys = value.keys.toList()..sort();
    final parts = keys.map((key) {
      final child = value[key];
      final encoded = child is Map<String, Object?>
          ? _canonicalJson(child)
          : jsonEncode(child);
      return '${jsonEncode(key)}:$encoded';
    });
    return '{${parts.join(',')}}';
  }
}

/// Outcome of re-verifying a stored key, so the boot flow can distinguish
/// "not activated" from "expired" without catching exceptions in a redirect.
class LicenceDecodeResult {
  const LicenceDecodeResult._({this.facts, this.reason});

  const LicenceDecodeResult.success(LicenceFacts facts) : this._(facts: facts);

  const LicenceDecodeResult.failure(String reason) : this._(reason: reason);

  final LicenceFacts? facts;
  final String? reason;

  bool get isValid => facts != null;
}
