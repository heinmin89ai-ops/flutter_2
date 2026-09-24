import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/auth/application/password_service.dart';

/// RFC-style interoperability vectors.
///
/// Reference values computed with Python's `hashlib.pbkdf2_hmac('sha256', ...)`,
/// salt = `bytes(range(16))`, dklen = 32, then base64url-encoded without padding
/// to match `PasswordService`'s storage format.
///
/// This is the test that matters: it proves the hand-written derivation loop
/// matches a known-good implementation rather than merely being self-consistent.
void main() {
  const salt = 'AAECAwQFBgcICQoLDA0ODw';

  const vectors = <({String secret, int iterations, String derived})>[
    (
      secret: 'vector-secret',
      iterations: 1000,
      derived: 'KdeVawi4POsStkykhitCn4YmnwXouCa2aWb_2aCZdc0',
    ),
    (
      secret: 'vector-secret',
      iterations: 120000,
      derived: 'I403yfdobi-SCKX0481rhQcxYIgs3wUmtC_4lBMry6o',
    ),
  ];

  for (final v in vectors) {
    test('verifies the reference vector at ${v.iterations} iterations', () {
      final service = PasswordService(iterations: v.iterations);
      expect(service.verify(v.secret, '$salt\$${v.derived}'), isTrue);
    });
  }

  test('a vector record rejects a different secret', () {
    const service = PasswordService(iterations: 1000);
    final stored =
        '$salt\$'
        'KdeVawi4POsStkykhitCn4YmnwXouCa2aWb_2aCZdc0';
    expect(service.verify('wrong-secret', stored), isFalse);
    // Case-sensitive: PBKDF2 is over exact bytes, no normalisation.
    expect(service.verify('Vector-Secret', stored), isFalse);
  });

  test('round-trips its own output at the default cost', () {
    const service = PasswordService();
    final stored = service.hash('pharmacy-owner-pin');
    expect(service.verify('pharmacy-owner-pin', stored), isTrue);
    expect(service.verify('Pharmacy-owner-pin', stored), isFalse);
  });
}
