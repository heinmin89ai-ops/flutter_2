import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/sales/application/fefo_allocator.dart';

/// Days from today at local midnight — the precision expiry is stored at.
DateTime _inDays(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: days));
}

FefoBatch _batch(int id, int available, int cost, {int expires = 100}) =>
    FefoBatch(
      batchId: id,
      available: available,
      costPya: cost,
      expiryDate: _inDays(expires),
    );

void main() {
  group('allocateFefo — happy paths', () {
    test(
      'one batch with enough stock is fully used and nothing else touched',
      () {
        final result = allocateFefo(
          batches: [_batch(1, 100, 120)],
          qtyInBase: 40,
        );

        expect(result.qtyInBase, 40);
        expect(result.allocations, hasLength(1));
        expect(result.allocations.single.batchId, 1);
        expect(result.allocations.single.quantity, 40);
        expect(result.totalCostPya, 40 * 120);
        expect(result.blendedUnitCostPya, 120);
      },
    );

    test('drains the earliest batch first, then the next', () {
      // Soonest expiry first — the caller's contract, matching
      // InventoryRepository.batchesFor.
      final result = allocateFefo(
        batches: [
          _batch(2, 30, 100, expires: 30), // earliest
          _batch(1, 50, 150, expires: 300), // later
        ],
        qtyInBase: 70,
      );

      expect(result.allocations.map((a) => a.batchId), [2, 1]);
      expect(result.allocations.map((a) => a.quantity), [30, 40]);
      // 30 @ 100 + 40 @ 150 = 9,000.
      expect(result.totalCostPya, 9000);
    });

    test('depleting a batch exactly does not touch the next', () {
      final result = allocateFefo(
        batches: [_batch(2, 30, 100), _batch(1, 50, 150)],
        qtyInBase: 30,
      );
      expect(result.allocations, hasLength(1));
      expect(result.allocations.single.batchId, 2);
      expect(result.allocations.single.quantity, 30);
    });

    test('a three-way split sums correctly', () {
      final result = allocateFefo(
        batches: [_batch(3, 10, 90), _batch(2, 20, 110), _batch(1, 100, 200)],
        qtyInBase: 55,
      );
      expect(result.allocations.map((a) => a.quantity), [10, 20, 25]);
      // 900 + 2200 + 5000 = 8100 across 55 units.
      expect(result.totalCostPya, 8100);
      expect(result.blendedUnitCostPya, 147); // 8100/55 = 147.27 -> 147 half-up
    });

    test('empty batches are skipped, never allocated zero', () {
      final result = allocateFefo(
        batches: [_batch(5, 0, 100), _batch(4, 5, 100), _batch(3, 50, 120)],
        qtyInBase: 12,
      );
      expect(result.allocations.every((a) => a.quantity > 0), isTrue);
      expect(result.allocations.map((a) => a.batchId), [4, 3]);
    });

    test('blended cost rounds half-up, matching the purchase-side rule', () {
      // 10 units: 5 @ 100 and 5 @ 101 => 1005/10 = 100.5 -> 101, not 100.
      final result = allocateFefo(
        batches: [_batch(2, 5, 100), _batch(1, 5, 101)],
        qtyInBase: 10,
      );
      expect(result.totalCostPya, 1005);
      expect(result.blendedUnitCostPya, 101);
    });
  });

  group('allocateFefo — rejection', () {
    test('a shortage names both numbers and never allocates', () {
      expect(
        () => allocateFefo(
          batches: [_batch(2, 30, 100), _batch(1, 10, 100)],
          qtyInBase: 50,
        ),
        throwsA(
          isA<FefoShortageException>()
              .having((e) => e.requested, 'requested', 50)
              .having((e) => e.available, 'available', 40)
              .having((e) => e.shortfall, 'shortfall', 10),
        ),
      );
    });

    test(
      'a zero or negative quantity is a programming error, not a shortage',
      () {
        for (final qty in [0, -5]) {
          expect(
            () => allocateFefo(batches: [_batch(1, 100, 100)], qtyInBase: qty),
            throwsA(isA<ArgumentError>()),
          );
        }
      },
    );

    test('exact-to-the-unit availability succeeds', () {
      final result = allocateFefo(
        batches: [_batch(2, 30, 100), _batch(1, 10, 100)],
        qtyInBase: 40,
      );
      expect(result.allocations.map((a) => a.quantity), [30, 10]);
    });
  });
}
