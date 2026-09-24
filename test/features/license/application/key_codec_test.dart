import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/license/application/key_codec.dart';

/// A key decoding to a known feature set, reused across cases.
final String validKey = PhaseOneFeatureDecoder.issueKey({
  'pos': true,
  'reports': true,
  'credit': false,
});

List<String> segments(String key) => key.split('-');

void main() {
  const decoder = PhaseOneFeatureDecoder();

  group('round-trip', () {
    test('issueKey output decodes to the same features', () {
      final features = decoder.decode(validKey);
      expect(features['pos'], isTrue);
      expect(features['reports'], isTrue);
      expect(features['credit'], isFalse);
    });

    test('an expiry in the future is accepted', () {
      final key = PhaseOneFeatureDecoder.issueKey({
        'pos': true,
        'exp': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(decoder.decode(key)['pos'], isTrue);
    });
  });

  group('rejects malformed input', () {
    final cases = <String, String>{
      'empty': '',
      'whitespace only': '   ',
      'two segments': 'PH1-abc',
      'wrong prefix': 'XX1-${segments(validKey)[1]}-00000000',
      'non-hex checksum': '${validKey.split('-').first}-abc-zzzz',
      'unknown prefix': 'ZZZ-AAAA-00000000',
    };
    cases.forEach((label, key) {
      test(label, () {
        expect(
          () => decoder.decode(key),
          throwsA(isA<ActivationKeyException>()),
        );
      });
    });
  });

  test('rejects a single-character mutation in the payload', () {
    final parts = segments(validKey);
    final payload = parts[1];
    final replacement = payload.codeUnitAt(0) == 0x41 ? 'B' : 'A';
    final tampered =
        '${parts[0]}-$replacement${payload.substring(1)}-${parts.last}';

    expect(
      () => decoder.decode(tampered),
      throwsA(
        isA<ActivationKeyException>().having(
          (e) => e.message,
          'message',
          contains('Checksum'),
        ),
      ),
    );
  });

  test('rejects an expired key and names the expiry', () {
    final key = PhaseOneFeatureDecoder.issueKey({
      'pos': true,
      'exp': DateTime(2020, 1, 2).toIso8601String(),
    });
    expect(
      () => decoder.decode(key),
      throwsA(
        isA<ActivationKeyException>().having(
          (e) => e.message,
          'message',
          contains('expired'),
        ),
      ),
    );
  });

  test('surrounding whitespace from a paste is accepted', () {
    expect(decoder.decode('  $validKey\n'), isNotEmpty);
  });

  test('the payload segment is case-sensitive', () {
    // base64url is case-sensitive, so upper-casing the whole key must fail
    // rather than silently decode a different feature map. This is why the
    // activation field does not force upper case as the user types.
    final upper = validKey.toUpperCase();
    expect(() => decoder.decode(upper), throwsA(isA<ActivationKeyException>()));
  });

  test('a key whose payload contains the separator still decodes', () {
    // Regression guard: base64url's alphabet includes '-', so a payload can
    // itself contain the segment separator. The decoder must treat only the
    // first and last segments as fixed and rejoin the middle, rather than
    // assuming exactly three parts. This specific map encodes to a payload
    // containing a '-' (the `a>b` note lands on the 62nd base64url value).
    final key = PhaseOneFeatureDecoder.issueKey({
      'pos': true,
      'pad': 'xx',
      'note': 'a>b',
    });

    expect(segments(key).length, greaterThan(3));
    expect(decoder.decode(key)['pos'], isTrue);
  });

  test('a non-boolean feature value reads as disabled', () {
    final key = PhaseOneFeatureDecoder.issueKey({
      'pos': 'yes',
      'reports': 1,
      'credit': true,
    });
    final features = decoder.decode(key);
    expect(features['pos'], isFalse);
    expect(features['reports'], isFalse);
    expect(features['credit'], isTrue);
  });
}
