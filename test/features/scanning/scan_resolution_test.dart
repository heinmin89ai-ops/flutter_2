import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/scanning/application/scan_resolution.dart';

/// The pure decision a camera scan hands back.
///
/// The `MobileScanner` widget itself can't run under `flutter test` (no camera,
/// no platform channel), so what is worth proving is the *resolution*: given a
/// raw code and an exact-barcode lookup, does the app add the right product,
/// show "not found", or quietly ignore a blank read? A hardware HID scanner
/// (Phase 4's keyboard path) and the camera must land on the same three answers.
void main() {
  // A stub lookup: only these codes resolve, to the ids paired here.
  int? findBarcode(String code) => switch (code) {
    '8801234567890' => 42,
    '123' => 7,
    _ => null,
  };

  test('an exact barcode hit resolves to add', () {
    expect(
      resolveScan(code: '8801234567890', findByBarcode: findBarcode),
      ScanResult.addProduct,
    );
  });

  test('surrounding whitespace is trimmed before matching', () {
    // Real scanners and copy-paste routinely add a trailing newline/space; a
    // strict-match that ignores this drops every scan into "not found".
    expect(
      resolveScan(code: '  123\n', findByBarcode: findBarcode),
      ScanResult.addProduct,
    );
  });

  test('an unknown code resolves to not-found', () {
    expect(
      resolveScan(code: '0000000000', findByBarcode: findBarcode),
      ScanResult.showNotFound,
    );
  });

  test(
    'a blank or whitespace-only read is ignored, not reported as missing',
    () {
      // Accidental empty captures happen; telling the user "not found" for a
      // blank read is noise. Ignoring lets them scan again.
      expect(
        resolveScan(code: '', findByBarcode: findBarcode),
        ScanResult.ignoreEmpty,
      );
      expect(
        resolveScan(code: '   ', findByBarcode: findBarcode),
        ScanResult.ignoreEmpty,
      );
    },
  );

  test('a blank code never calls the lookup', () {
    // Guards the ordering inside resolveScan: empty must short-circuit before
    // any database hit, otherwise every empty capture is a wasted query.
    var lookedUp = false;
    resolveScan(
      code: '  ',
      findByBarcode: (code) {
        lookedUp = true;
        return null;
      },
    );
    expect(lookedUp, isFalse);
  });
}
