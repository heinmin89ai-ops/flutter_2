import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';

/// Box(100) / Strip(10) / Tablet(1) — the shape from the Phase 3 brief.
UnitHierarchy tabletHierarchy() => UnitHierarchy.from([
  const UnitSpec(id: 3, name: 'Box', factor: 100, retailPricePya: 12000),
  const UnitSpec(id: 2, name: 'Strip', factor: 10, retailPricePya: 1300),
  const UnitSpec(id: 1, name: 'Tablet', factor: 1, retailPricePya: 150),
]);

void main() {
  group('construction', () {
    test('rejects an empty unit list', () {
      expect(
        () => UnitHierarchy.from(const []),
        throwsA(
          isA<UnitConfigException>().having(
            (e) => e.message,
            'message',
            contains('no units configured'),
          ),
        ),
      );
    });

    test('rejects a hierarchy with no factor-1 base unit', () {
      // The state that bites in practice: a shop that only configures "Box".
      expect(
        () => UnitHierarchy.from(const [
          UnitSpec(id: 1, name: 'Box', factor: 100, retailPricePya: 12000),
        ]),
        throwsA(
          isA<UnitConfigException>().having(
            (e) => e.message,
            'message',
            contains('No smallest unit'),
          ),
        ),
      );
    });

    test('rejects two base units', () {
      expect(
        () => UnitHierarchy.from(const [
          UnitSpec(id: 1, name: 'Tablet', factor: 1, retailPricePya: 150),
          UnitSpec(id: 2, name: 'Piece', factor: 1, retailPricePya: 150),
        ]),
        throwsA(
          isA<UnitConfigException>().having(
            (e) => e.message,
            'message',
            contains('More than one smallest unit'),
          ),
        ),
      );
    });

    test('rejects duplicate names that differ only by case', () {
      expect(
        () => UnitHierarchy.from(const [
          UnitSpec(id: 1, name: 'box', factor: 100, retailPricePya: 12000),
          UnitSpec(id: 2, name: 'Box', factor: 1, retailPricePya: 150),
        ]),
        throwsA(isA<UnitConfigException>()),
      );
    });
  });

  group('lookup and ordering', () {
    test('units are exposed coarsest first regardless of input order', () {
      final reversed = UnitHierarchy.from([
        const UnitSpec(id: 1, name: 'Tablet', factor: 1, retailPricePya: 150),
        const UnitSpec(id: 2, name: 'Strip', factor: 10, retailPricePya: 1300),
        const UnitSpec(id: 3, name: 'Box', factor: 100, retailPricePya: 12000),
      ]);
      expect(reversed.units.map((u) => u.name), ['Box', 'Strip', 'Tablet']);
    });

    test('base is the factor-1 unit', () {
      expect(tabletHierarchy().base.name, 'Tablet');
      expect(tabletHierarchy().base.isBase, isTrue);
    });

    test('byName is case-insensitive and ignores stray spaces', () {
      final h = tabletHierarchy();
      expect(h.byName('box')!.factor, 100);
      expect(h.byName('  STRIP ')!.factor, 10);
      expect(h.byName('Ampoule'), isNull);
    });

    test('byId finds the configured row so a sale can reference it', () {
      expect(tabletHierarchy().byId(2)!.name, 'Strip');
      expect(tabletHierarchy().byId(99), isNull);
    });
  });

  group('toBase', () {
    test('multiplies exactly, both directions of entry', () {
      final h = tabletHierarchy();
      final box = h.byName('Box')!;
      expect(h.toBase(unit: box, quantity: 5), 500);
      expect(h.toBaseByName(unitName: 'strip', quantity: 3), 30);
    });

    test('refuses zero and negative quantities', () {
      final h = tabletHierarchy();
      final box = h.byName('Box')!;
      expect(
        () => h.toBase(unit: box, quantity: 0),
        throwsA(isA<UnitConfigException>()),
      );
      expect(
        () => h.toBase(unit: box, quantity: -2),
        throwsA(isA<UnitConfigException>()),
      );
    });

    test('an unknown unit name fails instead of assuming pieces', () {
      expect(
        () => tabletHierarchy().toBaseByName(unitName: 'Bottle', quantity: 1),
        throwsA(isA<UnitConfigException>()),
      );
    });
  });

  group('decompose and formatStock', () {
    test('greedy biggest-units-first breakdown', () {
      expect(
        tabletHierarchy()
            .decompose(1234)
            .map((a) => '${a.quantity} ${a.unit.name}'),
        ['12 Box', '3 Strip', '4 Tablet'],
      );
    });

    test('exact multiples drop the smaller units entirely', () {
      // "1 Box", not "1 Box, 0 Strip, 0 Tablet" — what a shopkeeper says out loud.
      expect(tabletHierarchy().formatStock(100), '1 Box');
    });

    test('a remainder below the middle unit skips it', () {
      expect(tabletHierarchy().formatStock(105), '1 Box, 5 Tablets');
    });

    test('zero renders as the base unit rather than an empty string', () {
      expect(tabletHierarchy().formatStock(0), '0 Tablets');
    });

    test('only a count of 1 keeps the unit name singular', () {
      expect(tabletHierarchy().formatStock(111), '1 Box, 1 Strip, 1 Tablet');
      expect(tabletHierarchy().formatStock(112), '1 Box, 1 Strip, 2 Tablets');
    });

    test('a sibilant ending takes -es, not a bare -s', () {
      // "2 Boxs" on the stock screen is the kind of detail that makes a shop
      // manager distrust the whole app.
      expect(tabletHierarchy().formatStock(200), '2 Boxes');
      final mixed = UnitHierarchy.from([
        const UnitSpec(id: 1, name: 'Ampoule', factor: 1, retailPricePya: 900),
        const UnitSpec(id: 2, name: 'Patch', factor: 5, retailPricePya: 4000),
        const UnitSpec(id: 3, name: 'Glass', factor: 20, retailPricePya: 15000),
      ]);
      expect(mixed.formatStock(50), '2 Glasses, 2 Patches');
      expect(mixed.formatStock(3), '3 Ampoules');
    });

    test('negative base quantities are refused', () {
      expect(
        () => tabletHierarchy().decompose(-1),
        throwsA(isA<UnitConfigException>()),
      );
    });

    test('wholeUnits truncates rather than rounding', () {
      final h = tabletHierarchy();
      expect(h.wholeUnits(unit: h.byName('Box')!, baseQty: 250), 2);
    });
  });

  group('pricing', () {
    test('retail always reads the retail column', () {
      final h = tabletHierarchy();
      expect(h.priceFor(unit: h.base, mode: SaleMode.retail), 150);
    });

    test('wholesale falls back to retail when no wholesale price exists', () {
      final h = UnitHierarchy.from([
        const UnitSpec(id: 1, name: 'Tablet', factor: 1, retailPricePya: 150),
        const UnitSpec(
          id: 3,
          name: 'Box',
          factor: 100,
          retailPricePya: 12000,
          wholesalePricePya: 11000,
        ),
      ]);
      expect(h.priceFor(unit: h.byId(3)!, mode: SaleMode.wholesale), 11000);
      expect(h.priceFor(unit: h.byId(1)!, mode: SaleMode.wholesale), 150);
    });

    test(
      'an unrecognised mode parses to retail, never to the cheaper list',
      () {
        expect(SaleMode.parse('WHOLESALE'), SaleMode.wholesale);
        expect(SaleMode.parse('whole-sale'), SaleMode.retail);
        expect(SaleMode.parse(null), SaleMode.retail);
      },
    );
  });
}
