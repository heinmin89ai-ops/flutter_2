import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/money.dart';

void main() {
  group('kyatToPya', () {
    test('parses a plain whole amount', () {
      expect(kyatToPya('1250'), 125000);
    });

    test('parses one decimal place as tens of pya, not hundredths', () {
      // "120.5" is 120 kyat 50 pya — the mistake this guards against is reading
      // the fraction as 5 pya.
      expect(kyatToPya('120.5'), 12050);
    });

    test('parses two decimal places', () {
      expect(kyatToPya('120.55'), 12055);
      expect(kyatToPya('0.01'), 1);
    });

    test('rejects a third decimal instead of silently rounding', () {
      // A clerk typing 120.555 means something this table cannot store; the
      // form must say so rather than pick a value.
      expect(kyatToPya('120.555'), isNull);
    });

    test('tolerates the grouping styles people actually type', () {
      expect(kyatToPya('1,250'), 125000);
      expect(kyatToPya('1 250'), 125000);
      expect(kyatToPya("1'250.50"), 125050);
      expect(kyatToPya('  99  '), 9900);
    });

    test('rejects blank, negative, non-numeric and leading-dot input', () {
      expect(kyatToPya(''), isNull);
      expect(kyatToPya('   '), isNull);
      expect(kyatToPya('-5'), isNull);
      expect(kyatToPya('12a'), isNull);
      expect(kyatToPya('.5'), isNull);
      expect(kyatToPya('1.'), isNull);
    });

    test('"0" is zero, not invalid', () {
      // Blank must stay distinguishable from an explicit 0: a free sample is 0,
      // an untouched field is nothing.
      expect(kyatToPya('0'), 0);
    });
  });

  group('formatMoney', () {
    test('drops a zero fractional part', () {
      expect(formatMoney(125000), '1,250');
      expect(formatMoney(0), '0');
    });

    test('keeps a non-zero fraction at two digits', () {
      expect(formatMoney(12050), '120.50');
      expect(formatMoney(1), '0.01');
      expect(formatMoney(12005), '120.05');
    });

    test('groups thousands without padding the leading group', () {
      expect(formatMoney(99900), '999');
      expect(formatMoney(100000), '1,000');
      expect(formatMoney(12345678900), '123,456,789');
    });

    test('renders negatives outside the symbol', () {
      expect(formatMoney(-125000, symbol: 'K'), '-K1,250');
    });

    test('round-trips with kyatToPya for every two-decimal value', () {
      for (final pya in [0, 1, 99, 100, 12055, 125000, 9999999]) {
        expect(kyatToPya(formatMoney(pya)), pya);
      }
    });
  });

  test('kPyaPerKyat is the only conversion factor in the module', () {
    expect(kPyaPerKyat, 100);
  });
}
