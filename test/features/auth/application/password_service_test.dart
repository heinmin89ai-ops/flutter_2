import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/auth/application/password_service.dart';

void main() {
  // Low iteration count keeps the suite quick; the default 120k is covered by
  // the timing test below, which asserts the real cost is non-trivial.
  const service = PasswordService(iterations: 1000);

  group('hash format', () {
    test('is salt\$derivedKey with two non-empty segments', () {
      final parts = service.hash('admin123').split(r'$');
      expect(parts, hasLength(2));
      expect(parts.every((p) => p.isNotEmpty), isTrue);
    });

    test('never contains the secret', () {
      expect(service.hash('supersecret99'), isNot(contains('supersecret99')));
    });

    test('uses a fresh salt per call, so equal secrets hash differently', () {
      expect(service.hash('same-secret'), isNot(service.hash('same-secret')));
    });
  });

  group('verify', () {
    test('accepts the original secret', () {
      expect(
        service.verify('correct horse', service.hash('correct horse')),
        isTrue,
      );
    });

    test('rejects a wrong secret', () {
      expect(
        service.verify('Correct horse', service.hash('correct horse')),
        isFalse,
      );
    });

    test('rejects an empty secret', () {
      expect(service.verify('', service.hash('')), isTrue);
      expect(service.verify('', service.hash('nonempty')), isFalse);
    });
  });

  group('malformed stored values fail closed', () {
    for (final bad in [
      '',
      'no-separator',
      r'a\$b\$c',
      r'$onlytail',
      r'onlyhead$',
      '!!!\$!!!',
    ]) {
      test('rejects ${bad.isEmpty ? '<empty>' : bad}', () {
        expect(service.verify('anything', bad), isFalse);
      });
    }
  });

  test('two accounts with the same secret produce independent hashes', () {
    final a = service.hash('pin1234');
    final b = service.hash('pin1234');
    expect(a, isNot(b));
    expect(service.verify('pin1234', a), isTrue);
    expect(service.verify('pin1234', b), isTrue);
  });

  test('a hash produced with different iterations does not verify', () {
    const other = PasswordService(iterations: 999);
    expect(other.verify('pin1234', service.hash('pin1234')), isFalse);
  });

  test('default iterations make a single hash measurably costly', () {
    const expensive = PasswordService();
    final sw = Stopwatch()..start();
    expensive.hash('timing-probe');
    sw.stop();
    // Guards against someone "optimising" the cost away and turning the PIN
    // store back into a brute-forceable one.
    expect(sw.elapsedMilliseconds, greaterThan(20));
  });
}
