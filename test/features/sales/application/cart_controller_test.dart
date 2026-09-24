import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';
import 'package:pharmacy_pos/features/sales/application/cart_controller.dart';

// A paracetamol priced per the Phase 3 fixtures: Box 150, Strip 16, Tablet 2
// at retail; wholesale only defined on the box and strip.
const List<UnitSpec> _paraUnits = [
  UnitSpec(
    id: 3,
    name: 'Box',
    factor: 100,
    retailPricePya: 15000,
    wholesalePricePya: 12000,
  ),
  UnitSpec(
    id: 2,
    name: 'Strip',
    factor: 10,
    retailPricePya: 1600,
    wholesalePricePya: 1450,
  ),
  UnitSpec(id: 1, name: 'Tablet', factor: 1, retailPricePya: 200),
];

CartAddRequest _para({String? unit}) => CartAddRequest(
  medicineId: 10,
  tradeName: 'Paracetamol 500mg',
  units: _paraUnits,
  preferredUnitName: unit,
);

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  CartState cart() => container.read(cartProvider);
  CartController controller() => container.read(cartProvider.notifier);

  group('add & default unit', () {
    test('defaults to the base unit and prices it at retail', () {
      controller().add(_para());
      final line = cart().lines.single;
      expect(line.unitName, 'Tablet');
      expect(line.unitPricePya, 200);
      expect(line.quantity, 1);
      expect(line.qtyInBase, 1);
    });

    test('honours a preferred unit when named', () {
      controller().add(_para(unit: 'Box'));
      final line = cart().lines.single;
      expect(line.unitName, 'Box');
      expect(line.unitPricePya, 15000);
      expect(line.qtyInBase, 100);
    });

    test('a repeat add of the same medicine+unit bumps quantity', () {
      controller()
        ..add(_para(unit: 'Strip'))
        ..add(_para(unit: 'Strip'));
      final line = cart().lines.single;
      expect(line.quantity, 2);
      expect(line.lineTotalPya, 3200);
    });

    test('the same medicine in two units stays two lines', () {
      controller()
        ..add(_para(unit: 'Box'))
        ..add(_para(unit: 'Strip'));
      expect(cart().lines, hasLength(2));
    });
  });

  group('unit switching (Phase 4 brief item 1)', () {
    test(
      'switching a line to a coarser unit re-prices and resets qty to 1',
      () {
        controller().add(_para(unit: 'Tablet'));
        final strip = _paraUnits.firstWhere((u) => u.name == 'Strip');
        controller().switchUnit(10, 1, strip);

        final line = cart().lines.single;
        expect(line.unitName, 'Strip');
        expect(line.unitPricePya, 1600);
        // Quantity deliberately does NOT carry across: 5 tablets != 5 strips.
        expect(line.quantity, 1);
        expect(line.qtyInBase, 10);
      },
    );

    test('switching into a unit the medicine already has folds the lines', () {
      controller()
        ..add(_para(unit: 'Strip'))
        ..add(_para(unit: 'Tablet'));
      final strip = _paraUnits.firstWhere((u) => u.name == 'Strip');
      // Move the tablet line onto strips; a strip line already exists.
      controller().switchUnit(10, 1, strip);

      final strips = cart().lines.where((l) => l.unitName == 'Strip').toList();
      expect(strips, hasLength(1));
      expect(strips.single.quantity, 2); // 1 existing + 1 from the switch
      expect(cart().lines, hasLength(1));
    });
  });

  group('retail / wholesale', () {
    test('a box added at wholesale uses the wholesale price', () {
      controller().setMode(SaleMode.wholesale);
      controller().add(_para(unit: 'Box'));
      expect(cart().lines.single.unitPricePya, 12000);
    });

    test('switching mode re-prices existing lines without a re-scan', () {
      controller().add(_para(unit: 'Box'));
      expect(cart().lines.single.unitPricePya, 15000);

      controller().setMode(SaleMode.wholesale);
      expect(cart().lines.single.unitPricePya, 12000);

      controller().setMode(SaleMode.retail);
      expect(cart().lines.single.unitPricePya, 15000);
    });

    test('a unit with no wholesale price falls back to retail on a wholesale '
        'mode switch', () {
      controller().add(_para(unit: 'Tablet')); // tablets: retail only
      controller().setMode(SaleMode.wholesale);
      expect(cart().lines.single.unitPricePya, 200); // unchanged, not 0
    });
  });

  group('totals', () {
    test('subtotal sums the lines', () {
      controller()
        ..add(_para(unit: 'Box'))
        ..add(_para(unit: 'Strip'));
      expect(cart().subtotalPya, 15000 + 1600);
    });

    test('discount lowers the total', () {
      controller().add(_para(unit: 'Box'));
      controller().setDiscount(1000); // 10.00 kyat off
      expect(cart().discountPya, 1000);
      expect(cart().totalPya, 14000);
    });

    test(
      'a discount larger than the subtotal clamps the total, not negative',
      () {
        controller().add(_para(unit: 'Tablet')); // 200
        controller().setDiscount(5000);
        expect(cart().discountExceedsSubtotal, isTrue);
        expect(cart().totalPya, 0);
      },
    );

    test('a negative discount is floored at zero', () {
      controller().add(_para(unit: 'Tablet'));
      controller().setDiscount(-500);
      expect(cart().discountPya, 0);
    });
  });

  group('mutations', () {
    test('setQuantity to zero removes the line', () {
      controller().add(_para(unit: 'Strip'));
      controller().setQuantity(10, 2, 0);
      expect(cart().isEmpty, isTrue);
    });

    test('removeLine drops one line by id', () {
      controller()
        ..add(_para(unit: 'Box'))
        ..add(_para(unit: 'Tablet'));
      controller().removeLine(10, 1); // the tablet line
      expect(cart().lines, hasLength(1));
      expect(cart().lines.single.unitName, 'Box');
    });

    test('clear resets mode, discount and lines together', () {
      controller().setMode(SaleMode.wholesale);
      controller().add(_para(unit: 'Box'));
      controller().setDiscount(500);
      controller().clear();
      expect(cart().isEmpty, isTrue);
      expect(cart().mode, SaleMode.retail);
      expect(cart().discountPya, 0);
    });
  });
}
