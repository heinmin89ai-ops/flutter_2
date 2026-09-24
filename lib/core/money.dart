/// Money as an integer count of **pya** (1/100 of a kyat).
///
/// Nothing in this app stores currency in a `double`. Binary floating point
/// cannot represent 0.1, so a cart of 10 lines each `0.1` sums to
/// `0.9999999999999999` — and the rounding shows up in a printed receipt, at
/// the worst possible moment. Integer minor units are the standard fix.
///
/// Kyat is chosen as the display unit and pya as the stored one because cost
/// prices genuinely need sub-kyat precision: a 12,050 kyat box of 100 tablets
/// costs 120.5 kyat per tablet. Storing kyat as an integer would force a
/// rounding decision on every stock-in; storing pya leaves the error under
/// 1/100 kyat and only where it is invisible.
///
/// Rules:
///   * columns named `*_price`, `*_cost`, `*_amount`, `*_total` hold pya.
///   * convert at the boundary — parse user input with [kyatToPya], render with
///     [formatMoney]. Nothing in between should multiply or divide by 100.
///   * integer division is only acceptable with an explicit, tested bound on the
///     error. See `PurchaseRepository` for the one place that does it.
typedef Pya = int;

/// Minor units per kyat.
const int kPyaPerKyat = 100;

/// Parses a user-typed kyat amount, e.g. `"1 250.75"` => 125075 pya.
///
/// Returns `null` for anything that is not a plain non-negative number, so
/// forms can show a validation message instead of throwing. Grouping separators
/// (commas, spaces, the usual thousands apostrophe) are tolerated because people
/// type prices the way they read them.
Pya? kyatToPya(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r"[,\s']"), '');
  if (cleaned.isEmpty) return null;
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = match.group(2);
  final pya = fraction == null
      ? 0
      : switch (fraction.length) {
          1 => int.parse(fraction) * 10,
          _ => int.parse(fraction),
        };
  return whole * kPyaPerKyat + pya;
}

/// Renders pya as a grouped kyat string, dropping a zero fractional part.
///
/// `125000` -> `1,250`, `12050` -> `120.50`, `0` -> `0`.
String formatMoney(Pya pya, {String symbol = ''}) {
  final negative = pya < 0;
  final abs = pya.abs();
  final whole = (abs ~/ kPyaPerKyat).toString();
  final grouped = _groupThousands(whole);
  final cents = abs % kPyaPerKyat;
  final body = cents == 0
      ? grouped
      : '$grouped.${cents.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}$symbol$body';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
