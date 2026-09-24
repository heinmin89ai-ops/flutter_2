import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/license/application/jwt_decoder.dart';
import 'package:pharmacy_pos/features/license/application/key_codec.dart';
import 'package:pharmacy_pos/features/license/application/license_secret.dart';

/// Fixed clock so expiry assertions do not drift as real time passes.
final DateTime now = DateTime.utc(2026, 9, 24);
final DateTime future = DateTime.utc(2028, 1, 1);
final DateTime past = DateTime.utc(2024, 1, 1);

String key(Map<String, bool> features, {DateTime? expiresAt}) =>
    JwtFeatureDecoder.issueKey(
      features: features,
      expiresAt: expiresAt,
      issuedAt: now,
    );

void main() {
  JwtFeatureDecoder decoder({DateTime? at}) =>
      JwtFeatureDecoder(now: at ?? now);

  group('round trip', () {
    test('a signed key decodes to the features it carried', () {
      final facts = decoder().decode(key({'retail': true, 'wholesale': false}));
      expect(facts.features['retail'], isTrue);
      expect(facts.features['wholesale'], isFalse);
    });

    test('carries the client name and expiry through to the caller', () {
      final source = JwtFeatureDecoder.issueKey(
        features: {'retail': true},
        expiresAt: future,
        client: 'Hein Pharmacy',
        sub: 'hein-01',
        issuedAt: now,
      );
      final facts = decoder().decode(source);
      expect(facts.client, 'Hein Pharmacy');
      expect(facts.holder, 'hein-01');
      expect(facts.expiresAt, isNotNull);
      expect(facts.expiresAt!.toUtc(), future);
    });

    test('a key with no exp claim is perpetual, not rejected', () {
      final facts = decoder().decode(key({'retail': true}));
      expect(facts.expiresAt, isNull);
    });

    test('a non-boolean feature value reads as disabled', () {
      // Forged-looking payloads must not become `true` through a truthy cast.
      final source = _rawKey(
        '{"iss":"pharmacy-pos","features":{"retail":"yes","wholesale":1,'
        '"credit":true}}',
      );
      final facts = decoder().decode(source);
      expect(facts.features['retail'], isFalse);
      expect(facts.features['wholesale'], isFalse);
      expect(facts.features['credit'], isTrue);
    });
  });

  group('rejects tampering', () {
    test('editing the payload to grant a module invalidates the signature', () {
      final valid = key({'retail': true});
      final parts = valid.split('.');
      final forged = _b64(
        '{"iss":"pharmacy-pos","features":{"retail":true,"wholesale":true}}',
      );
      expect(
        () => decoder().decode('${parts[0]}.$forged.${parts[2]}'),
        throwsA(_rejected('Signature mismatch')),
      );
    });

    test('a key signed with another secret is refused', () {
      final foreign = JwtFeatureDecoder.issueKey(
        features: {'retail': true},
        secret: 'not-the-app-secret',
        issuedAt: now,
      );
      expect(
        () => decoder().decode(foreign),
        throwsA(_rejected('Signature mismatch')),
      );
    });

    test('flipping one signature character is refused', () {
      final parts = key({'retail': true}).split('.');
      final sig = parts[2];
      final flipped =
          sig.substring(0, sig.length - 1) + (sig.endsWith('A') ? 'B' : 'A');
      expect(
        () => decoder().decode('${parts[0]}.${parts[1]}.$flipped'),
        throwsA(isA<ActivationKeyException>()),
      );
    });

    test(
      'an empty signature is refused even though it is trivially unsigned',
      () {
        final parts = key({'retail': true}).split('.');
        expect(
          () => decoder().decode('${parts[0]}.${parts[1]}.'),
          throwsA(isA<ActivationKeyException>()),
        );
      },
    );

    test('a two-segment key is refused', () {
      final parts = key({'retail': true}).split('.');
      expect(
        () => decoder().decode('${parts[0]}.${parts[1]}'),
        throwsA(_rejected('three dot-separated segments')),
      );
    });

    test('a Phase 1 checksum key is refused, not silently accepted', () {
      expect(
        () => decoder().decode('PH1-eyJwb3MiOnRydWV9-00c8e1a2'),
        throwsA(isA<ActivationKeyException>()),
      );
    });
  });

  group('alg confusion', () {
    test('"alg":"none" with an empty signature is refused', () {
      final header = _b64('{"alg":"none","typ":"JWT"}');
      final payload = _b64('{"iss":"pharmacy-pos","features":{"retail":true}}');
      expect(
        () => decoder().decode('$header.$payload.'),
        throwsA(_rejected('Unsupported key algorithm')),
      );
    });

    test('a header claiming RS256 is refused before any signature work', () {
      final valid = key({'retail': true}).split('.');
      final header = _b64('{"alg":"RS256","typ":"JWT"}');
      expect(
        () => decoder().decode('$header.${valid[1]}.${valid[2]}'),
        throwsA(_rejected('Unsupported key algorithm')),
      );
    });

    test('a header with no alg is refused', () {
      final valid = key({'retail': true}).split('.');
      expect(
        () => decoder().decode(
          '${_b64('{"typ":"JWT"}')}.${valid[1]}.${valid[2]}',
        ),
        throwsA(_rejected('Unsupported key algorithm')),
      );
    });
  });

  group('expiry', () {
    test('an expired key is refused and names the date', () {
      expect(
        () => decoder().decode(key({'retail': true}, expiresAt: past)),
        throwsA(_rejected('expired')),
      );
    });

    test('expiry is judged against the injected clock', () {
      final source = key({'retail': true}, expiresAt: future);
      // Same key: valid before future, refused after it.
      expect(
        decoder(at: DateTime.utc(2027)).decode(source).features['retail'],
        isTrue,
      );
      expect(
        () => decoder(at: DateTime.utc(2029)).decode(source),
        throwsA(_rejected('expired')),
      );
    });

    test('a non-numeric, non-ISO exp claim is refused rather than ignored', () {
      final source = _rawKey(
        '{"iss":"pharmacy-pos","exp":"sometime next year",'
        '"features":{"retail":true}}',
      );
      expect(
        () => decoder().decode(source),
        throwsA(_rejected('Unreadable expiry')),
      );
    });
  });

  group('issuer', () {
    test('a key from another vendor is refused', () {
      final source = _rawKey(
        '{"iss":"someone-else","features":{"retail":true}}',
      );
      expect(
        () => decoder().decode(source),
        throwsA(_rejected('unknown vendor')),
      );
    });
  });

  group('shape', () {
    test('a payload with no features claim is refused', () {
      expect(
        () => decoder().decode(_rawKey('{"iss":"pharmacy-pos"}')),
        throwsA(_rejected('no features')),
      );
    });

    test('garbage in the header segment is refused', () {
      expect(
        () => decoder().decode('not-base64!!!.eyJhIjoxfQ.abc'),
        throwsA(isA<ActivationKeyException>()),
      );
    });

    test('whitespace from a paste is ignored', () {
      final source = key({'retail': true});
      expect(decoder().decode('  $source\n'), isA<LicenceFacts>());
      // A key wrapped across two lines in an email is the common case.
      expect(
        decoder().decode('${source.substring(0, 40)}\n${source.substring(40)}'),
        isA<LicenceFacts>(),
      );
    });
  });

  group('verifyStored', () {
    test('reports success with facts for a live key', () {
      final result = decoder().verifyStored(
        key({'retail': true}, expiresAt: future),
      );
      expect(result.isValid, isTrue);
      expect(result.facts!.featureEnabled('retail'), isTrue);
    });

    test('returns the reason instead of throwing, for an expired key', () {
      final result = decoder().verifyStored(
        key({'retail': true}, expiresAt: past),
      );
      expect(result.isValid, isFalse);
      expect(result.reason, contains('expired'));
    });

    test('returns the reason for a forged key', () {
      final result = decoder().verifyStored('a.b.c');
      expect(result.isValid, isFalse);
      expect(result.reason, isNotEmpty);
    });
  });

  group('cross-language vectors', () {
    // Produced by tools/license_generator.py with the development secret, so
    // these assert that the Dart and Python signing paths agree byte for byte.
    // A key generated on the vendor machine must be accepted by the app.
    const issued =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJjbGllbnQiOiJIZWluIFBoYXJtYWN5LCBZYW5nb24iLCJleHAiOjE4OTM0NTYwMDAs'
        'ImZlYXR1cmVzIjp7ImNsb3VkX2JhY2t1cCI6ZmFsc2UsInJldGFpbCI6dHJ1ZSwid2hv'
        'bGVzYWxlIjp0cnVlfSwiaWF0IjoxNzkwMDAwMDAwLCJpc3MiOiJwaGFybWFjeS1wb3Mi'
        'LCJzdWIiOiJoZWluLXBoYXJtYWN5In0.'
        'eiqK2BVp1SSXYequM9ROtIMRTxmK2dnvLPsswOcIpZY';

    test('a Python-generated key verifies and decodes as expected', () {
      final facts = const JwtFeatureDecoder().decode(issued);
      expect(facts.client, 'Hein Pharmacy, Yangon');
      expect(facts.holder, 'hein-pharmacy');
      expect(facts.featureEnabled('retail'), isTrue);
      expect(facts.featureEnabled('wholesale'), isTrue);
      expect(facts.featureEnabled('cloud_backup'), isFalse);
      // 1893456000 => 2030-01-01T00:00:00Z
      expect(facts.expiresAt!.toUtc(), DateTime.utc(2030, 1, 1));
    });

    test('Dart issues a byte-identical key for the same claims', () {
      final dartKey = JwtFeatureDecoder.issueKey(
        features: {'retail': true, 'wholesale': true, 'cloud_backup': false},
        expiresAt: DateTime.utc(2030, 1, 1),
        client: 'Hein Pharmacy, Yangon',
        sub: 'hein-pharmacy',
        issuedAt: DateTime.fromMillisecondsSinceEpoch(1790000000 * 1000),
      );
      final pythonSegments = issued.split('.');
      final dartSegments = dartKey.split('.');
      // Header and claims must match exactly; the signature follows from them.
      expect(dartSegments[0], pythonSegments[0]);
      expect(dartSegments[1], pythonSegments[1]);
      expect(dartSegments[2], pythonSegments[2]);
    });

    test('a Python-generated expired key is rejected by Dart', () {
      const expired =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJjbGllbnQiOiJIZWluIFBoYXJtYWN5LCBZYW5nb24iLCJleHAiOjE1MDAwMDAwMDAs'
          'ImZlYXR1cmVzIjp7ImNsb3VkX2JhY2t1cCI6ZmFsc2UsInJldGFpbCI6dHJ1ZSwid2hv'
          'bGVzYWxlIjp0cnVlfSwiaWF0IjoxNzkwMDAwMDAwLCJpc3MiOiJwaGFybWFjeS1wb3Mi'
          'LCJzdWIiOiJoZWluLXBoYXJtYWN5In0.'
          '5Qu5TAY57ldQb_vlIbSRj9csKbRCRJICztQt9cc-_7M';
      expect(
        () => const JwtFeatureDecoder().decode(expired),
        throwsA(_rejected('expired')),
      );
    });
  });

  group('secret wiring', () {
    test('the default decoder uses the compile-time secret', () {
      // Guards against a refactor that drops the default and silently verifies
      // against an empty string, which would accept nothing in production.
      expect(const JwtFeatureDecoder().secret, kLicenseSecret);
      expect(kLicenseSecret, isNotEmpty);
    });
  });
}

Matcher _rejected(String fragment) => isA<ActivationKeyException>().having(
  (e) => e.message,
  'message',
  contains(fragment),
);

String _b64(String json) =>
    base64Url.encode(utf8.encode(json)).replaceAll('=', '');

/// Builds a correctly-signed key around an arbitrary claims JSON, so a test can
/// probe how the decoder handles a specific claim shape.
String _rawKey(String claimsJson) {
  final header = _b64('{"alg":"HS256","typ":"JWT"}');
  final payload = _b64(claimsJson);
  final signature = base64Url
      .encode(
        Hmac(
          sha256,
          utf8.encode(kLicenseSecret),
        ).convert(utf8.encode('$header.$payload')).bytes,
      )
      .replaceAll('=', '');
  return '$header.$payload.$signature';
}
