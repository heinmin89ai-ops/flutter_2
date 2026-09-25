import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/money.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';
import 'package:pharmacy_pos/features/inventory/data/inventory_repository.dart';

/// Days from today, at local midnight — the precision expiry is stored at.
DateTime _inDays(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: days));
}

void main() {
  late AppDatabase db;
  late InventoryRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = InventoryRepository(db);
  });

  tearDown(() => db.close());

  /// The brief's packaging shape: 1 Box = 10 Strips = 100 Tablets.
  Future<Medicine> paracetamol({int? lowStockThreshold, String? barcode}) {
    return repo.createMedicine(
      tradeName: 'Paracetamol 500mg',
      genericName: 'Paracetamol',
      category: 'Analgesic',
      shelfLocation: 'A-1',
      barcode: barcode,
      lowStockThreshold: lowStockThreshold,
      units: const [
        NewUnit(name: 'Box', factor: 100, retailPricePya: 12000),
        NewUnit(name: 'Strip', factor: 10, retailPricePya: 1300),
        NewUnit(name: 'Tablet', factor: 1, retailPricePya: 150),
      ],
    );
  }

  /// Add stock straight to a batch, bypassing Phase 4's purchase path.
  Future<int> addBatch(
    int medicineId, {
    required String batch,
    required DateTime expiry,
    required int qty,
    required Pya costPya,
  }) {
    return db
        .into(db.medicineBatches)
        .insert(
          MedicineBatchesCompanion.insert(
            medicineId: medicineId,
            batchNumber: batch,
            expiryDate: expiry,
            qtyInSmallestUnit: qty,
            costPrice: costPya,
          ),
        );
  }

  group('createMedicine', () {
    test('stores the medicine and every unit row', () async {
      final medicine = await paracetamol();

      expect(medicine.tradeName, 'Paracetamol 500mg');
      expect(medicine.genericName, 'Paracetamol');
      expect(await repo.unitsFor(medicine.id), hasLength(3));
    });
    test('trims the name and turns a blank barcode into NULL', () async {
      final medicine = await repo.createMedicine(
        tradeName: '  Ibuprofen  ',
        barcode: '   ',
        units: const [NewUnit(name: 'Tablet', factor: 1, retailPricePya: 200)],
      );

      expect(medicine.tradeName, 'Ibuprofen');
      expect(medicine.barcode, isNull);
      expect(await repo.findByBarcode(''), isNull);
    });

    test('orders units coarsest first for the picker', () async {
      final medicine = await paracetamol();

      final rows = await repo.unitsFor(medicine.id);
      expect(rows.map((r) => r.unitName), ['Box', 'Strip', 'Tablet']);
    });

    test('refuses a unit set with no smallest unit', () async {
      expect(
        () => repo.createMedicine(
          tradeName: 'Broken',
          units: const [NewUnit(name: 'Box', factor: 100, retailPricePya: 1)],
        ),
        throwsA(isA<UnitConfigException>()),
      );
      // Rejected before the transaction opened, so nothing was written.
      expect(await repo.catalog(), isEmpty);
    });

    test('refuses a blank trade name', () async {
      expect(
        () => repo.createMedicine(
          tradeName: '   ',
          units: const [NewUnit(name: 'Tablet', factor: 1, retailPricePya: 1)],
        ),
        throwsA(isA<MedicineConflictException>()),
      );
    });

    test('refuses a barcode already on another medicine', () async {
      await paracetamol(barcode: '8851234567');

      expect(
        () => repo.createMedicine(
          tradeName: 'Copycat',
          barcode: '8851234567',
          units: const [NewUnit(name: 'Tablet', factor: 1, retailPricePya: 1)],
        ),
        throwsA(isA<MedicineConflictException>()),
      );
      expect(await repo.catalog(), hasLength(1));
    });

    test('two medicines may both have no barcode', () async {
      await paracetamol();
      await repo.createMedicine(
        tradeName: 'Vitamin C',
        units: const [NewUnit(name: 'Tablet', factor: 1, retailPricePya: 100)],
      );
      expect(await repo.catalog(), hasLength(2));
    });
  });

  group('hierarchyFor', () {
    test('resolves the configured units and memoises them', () async {
      final medicine = await paracetamol();

      final first = await repo.hierarchyFor(medicine.id);
      expect(first.base.name, 'Tablet');
      expect(first.byName('Box')!.factor, 100);

      // Second call must not re-read the table: deleting the rows behind its
      // back still returns the cached hierarchy.
      await db.delete(db.unitConversions).go();
      expect(identical(await repo.hierarchyFor(medicine.id), first), isTrue);
    });

    test('a price edit drops the cached hierarchy', () async {
      final medicine = await paracetamol();
      final before = await repo.hierarchyFor(medicine.id);
      final box = before.byId(
        (await repo.unitsFor(medicine.id))
            .firstWhere((u) => u.unitName == 'Box')
            .id,
      )!;
      expect(box.retailPricePya, 12000);

      final rows = await repo.unitsFor(medicine.id);
      await repo.updateUnitPrices([
        UnitPriceEdit(unitId: rows.first.id, retailPricePya: 11500),
      ]);

      expect((await repo.unitsFor(medicine.id)).first.retailPrice, 11500);
      final after = await repo.hierarchyFor(medicine.id);
      expect(after.byId(rows.first.id)!.retailPricePya, 11500);
    });

    test('throws for a medicine with no units at all', () async {
      final medicine = await paracetamol();
      await db.delete(db.unitConversions).go();
      repo.clearHierarchyCache();

      expect(
        () => repo.hierarchyFor(medicine.id),
        throwsA(isA<UnitConfigException>()),
      );
    });
  });

  group('stock is computed, never stored', () {
    test('sums across batches and ignores depleted ones', () async {
      final medicine = await paracetamol();
      await addBatch(
        medicine.id,
        batch: 'A1',
        expiry: _inDays(300),
        qty: 500,
        costPya: 120,
      );
      await addBatch(
        medicine.id,
        batch: 'A2',
        expiry: _inDays(600),
        qty: 30,
        costPya: 130,
      );
      await addBatch(
        medicine.id,
        batch: 'OLD',
        expiry: _inDays(10),
        qty: 0,
        costPya: 100,
      );

      expect(await repo.stockForMedicine(medicine.id), 530);
    });

    test(
      'a medicine with no batches reads as zero rather than missing',
      () async {
        await paracetamol();
        final rows = await repo.list();

        expect(rows.single.stockInBase, 0);
        expect(rows.single.neverStocked, isTrue);
        expect(rows.single.outOfStock, isTrue);
        expect(rows.single.stockLabel, '0 Tablets');
      },
    );

    test(
      'the list reports quantity, batch count and stock value together',
      () async {
        final medicine = await paracetamol();
        // 500 x 120 + 30 x 130 = 63,900 pya of stock on the shelf.
        await addBatch(
          medicine.id,
          batch: 'A1',
          expiry: _inDays(300),
          qty: 500,
          costPya: 120,
        );
        await addBatch(
          medicine.id,
          batch: 'A2',
          expiry: _inDays(600),
          qty: 30,
          costPya: 130,
        );

        final row = (await repo.list()).single;
        expect(row.stockInBase, 530);
        expect(row.batchCount, 2);
        expect(row.stockValuePya, 63900);
      },
    );

    test('stockLabel breaks the total into the shop\'s own units', () async {
      final medicine = await paracetamol();
      await addBatch(
        medicine.id,
        batch: 'A1',
        expiry: _inDays(300),
        qty: 1234,
        costPya: 120,
      );

      expect(
        (await repo.list()).single.stockLabel,
        '12 Boxes, 3 Strips, 4 Tablets',
      );
    });

    test('there is no cached stock column to go stale', () async {
      // The one regression test for the design decision: `medicines` must not
      // grow a stock column, or it and the batches will disagree under load.
      final columns = await db
          .customSelect('PRAGMA table_info(medicines)')
          .get();
      final names = columns.map((r) => r.read<String>('name')).toSet();

      expect(names.contains('stock_qty'), isFalse);
      expect(names.contains('current_stock'), isFalse);
    });
  });

  group('list filters', () {
    test(
      'searches trade name, generic name and barcode case-insensitively',
      () async {
        await paracetamol(barcode: '8851234567');
        await repo.createMedicine(
          tradeName: 'Vitamin C',
          units: const [
            NewUnit(name: 'Tablet', factor: 1, retailPricePya: 100),
          ],
        );

        expect(
          (await repo.list(search: 'PARA')).single.medicine.tradeName,
          'Paracetamol 500mg',
        );
        expect((await repo.list(search: 'amol')).length, 1);
        expect(
          (await repo.list(search: '567')).single.medicine.tradeName,
          'Paracetamol 500mg',
        );
        expect(await repo.list(search: 'nothing'), isEmpty);
      },
    );

    test(
      'lowStockOnly keeps only items at or below their own threshold',
      () async {
        final warned = await paracetamol(lowStockThreshold: 500);
        await addBatch(
          warned.id,
          batch: 'A1',
          expiry: _inDays(300),
          qty: 500,
          costPya: 120,
        );
        await repo.createMedicine(
          tradeName: 'Never Warn',
          units: const [NewUnit(name: 'Tablet', factor: 1, retailPricePya: 1)],
        );

        final rows = await repo.list(lowStockOnly: true);
        expect(rows.map((r) => r.medicine.tradeName), ['Paracetamol 500mg']);
      },
    );

    test(
      'a null threshold is "no alert", a zero threshold is "warn when empty"',
      () async {
        final noAlert = await paracetamol();
        await addBatch(
          noAlert.id,
          batch: 'A1',
          expiry: _inDays(300),
          qty: 0,
          costPya: 120,
        );
        expect(await repo.lowStock(), isEmpty);

        await (db.update(db.medicines)..where((t) => t.id.equals(noAlert.id)))
            .write(const MedicinesCompanion(lowStockThreshold: Value(0)));
        expect((await repo.lowStock()).single.medicine.id, noAlert.id);
      },
    );

    test('hides deactivated medicines unless asked', () async {
      final medicine = await paracetamol();
      await repo.deactivateMedicine(medicineId: medicine.id);

      expect(await repo.list(), isEmpty);
      expect(await repo.catalog(), isEmpty);
      expect(
        (await repo.list(includeInactive: true)).single.medicine.isActive,
        isFalse,
      );
    });
  });

  group('expiry alerts', () {
    test(
      'counts batches inside the window and reports the nearest date',
      () async {
        final medicine = await paracetamol();
        await addBatch(
          medicine.id,
          batch: 'SOON',
          expiry: _inDays(10),
          qty: 20,
          costPya: 120,
        );
        await addBatch(
          medicine.id,
          batch: 'LATER',
          expiry: _inDays(200),
          qty: 20,
          costPya: 120,
        );

        final row = (await repo.list(expiryWarningDays: 30)).single;
        expect(row.expiringBatchCount, 1);
        expect(row.nearestExpiry, _inDays(10));
      },
    );

    test('a 90-day window catches what a 30-day one misses', () async {
      final medicine = await paracetamol();
      await addBatch(
        medicine.id,
        batch: 'MID',
        expiry: _inDays(60),
        qty: 20,
        costPya: 120,
      );

      expect(
        (await repo.list(expiryWarningDays: 30)).single.expiringBatchCount,
        0,
      );
      expect(
        (await repo.list(expiryWarningDays: 60)).single.expiringBatchCount,
        1,
      );
    });

    test(
      'expiringWithin spans medicines, soonest first, excluding dead stock',
      () async {
        final fast = await paracetamol();
        final slow = await repo.createMedicine(
          tradeName: 'Amoxicillin',
          units: const [
            NewUnit(name: 'Capsule', factor: 1, retailPricePya: 400),
          ],
        );
        await addBatch(
          fast.id,
          batch: 'P2',
          expiry: _inDays(25),
          qty: 40,
          costPya: 120,
        );
        await addBatch(
          fast.id,
          batch: 'P1',
          expiry: _inDays(5),
          qty: 40,
          costPya: 120,
        );
        await addBatch(
          fast.id,
          batch: 'GONE',
          expiry: _inDays(3),
          qty: 0,
          costPya: 120,
        );
        await addBatch(
          slow.id,
          batch: 'X1',
          expiry: _inDays(12),
          qty: 8,
          costPya: 300,
        );

        final found = await repo.expiringWithin(30);
        expect(found.map((b) => b.batch.batchNumber), ['P1', 'X1', 'P2']);
        expect(found.first.tradeName, 'Paracetamol 500mg');
        expect(found.first.daysToExpiry, 5);
        expect(found.first.isExpired, isFalse);
      },
    );

    test('a batch that expired today still reads as expired', () async {
      final medicine = await paracetamol();
      await addBatch(
        medicine.id,
        batch: 'BAD',
        expiry: _inDays(-1),
        qty: 10,
        costPya: 120,
      );

      final batch = (await repo.batchesFor(
        medicine.id,
        includeDepleted: true,
      )).single;
      expect(batch.isExpired, isTrue);
      expect(batch.daysToExpiry, -1);
      // Not part of the *upcoming* alert list: it is a write-off now.
      expect(await repo.expiringWithin(30), isEmpty);
    });

    test('remaining value is quantity x that batch\'s own cost', () async {
      final medicine = await paracetamol();
      await addBatch(
        medicine.id,
        batch: 'A1',
        expiry: _inDays(300),
        qty: 30,
        costPya: 137,
      );

      final batch = (await repo.batchesFor(medicine.id)).single;
      expect(batch.remainingValuePya, 4110);
      expect(batch.humanQuantity, '3 Strips');
    });
  });

  group('batchesFor', () {
    test(
      'returns soonest expiry first — the order Phase 4 deducts in',
      () async {
        final medicine = await paracetamol();
        await addBatch(
          medicine.id,
          batch: 'LATE',
          expiry: _inDays(900),
          qty: 5,
          costPya: 120,
        );
        await addBatch(
          medicine.id,
          batch: 'SOON',
          expiry: _inDays(20),
          qty: 5,
          costPya: 120,
        );

        final batches = await repo.batchesFor(medicine.id);
        expect(batches.map((b) => b.batch.batchNumber), ['SOON', 'LATE']);
      },
    );

    test(
      'hides depleted batches unless the caller asks for the full history',
      () async {
        final medicine = await paracetamol();
        await addBatch(
          medicine.id,
          batch: 'USED',
          expiry: _inDays(20),
          qty: 0,
          costPya: 120,
        );
        await addBatch(
          medicine.id,
          batch: 'LIVE',
          expiry: _inDays(20),
          qty: 4,
          costPya: 120,
        );

        expect(
          (await repo.batchesFor(medicine.id)).map((b) => b.batch.batchNumber),
          ['LIVE'],
        );
        expect(
          await repo.batchesFor(medicine.id, includeDepleted: true),
          hasLength(2),
        );
      },
    );
  });

  group('adjustBatch', () {
    test('adds and removes in smallest units', () async {
      final medicine = await paracetamol();
      final id = await addBatch(
        medicine.id,
        batch: 'A1',
        expiry: _inDays(300),
        qty: 100,
        costPya: 120,
      );

      await repo.adjustBatch(batchId: id, deltaInBase: 50);
      expect(await repo.stockForMedicine(medicine.id), 150);

      await repo.adjustBatch(batchId: id, deltaInBase: -150);
      expect(await repo.stockForMedicine(medicine.id), 0);
    });

    test(
      'leaves the batch cost alone — a write-off removes value at cost',
      () async {
        final medicine = await paracetamol();
        final id = await addBatch(
          medicine.id,
          batch: 'A1',
          expiry: _inDays(300),
          qty: 100,
          costPya: 120,
        );

        await repo.adjustBatch(batchId: id, deltaInBase: -60);
        expect(
          (await db.select(db.medicineBatches).getSingle()).costPrice,
          120,
        );
      },
    );

    test('refuses to drive a batch negative and says which one', () async {
      final medicine = await paracetamol();
      final id = await addBatch(
        medicine.id,
        batch: 'B-77',
        expiry: _inDays(300),
        qty: 10,
        costPya: 120,
      );

      expect(
        () => repo.adjustBatch(batchId: id, deltaInBase: -11),
        throwsA(
          isA<MedicineInUseException>().having(
            (e) => e.debugMessage,
            'message',
            contains('B-77'),
          ),
        ),
      );
      expect(await repo.stockForMedicine(medicine.id), 10);
    });

    test('a zero delta is a no-op, not an error', () async {
      final medicine = await paracetamol();
      final id = await addBatch(
        medicine.id,
        batch: 'A1',
        expiry: _inDays(300),
        qty: 10,
        costPya: 120,
      );

      await repo.adjustBatch(batchId: id, deltaInBase: 0);
      expect(await repo.stockForMedicine(medicine.id), 10);
    });
  });

  group('updateMedicine', () {
    test('changes only the fields it is given', () async {
      final medicine = await paracetamol(lowStockThreshold: 40);

      await repo.updateMedicine(medicineId: medicine.id, shelfLocation: 'C-9');

      final saved = (await repo.medicineById(medicine.id))!;
      expect(saved.shelfLocation, 'C-9');
      expect(saved.tradeName, 'Paracetamol 500mg');
      expect(saved.lowStockThreshold, 40);
    });

    test(
      'an absent threshold keeps it and a null one inside Value clears it',
      () async {
        final medicine = await paracetamol(lowStockThreshold: 40);

        await repo.updateMedicine(medicineId: medicine.id, category: 'Fever');
        expect((await repo.medicineById(medicine.id))!.lowStockThreshold, 40);

        await repo.updateMedicine(
          medicineId: medicine.id,
          lowStockThreshold: const Value(null),
        );
        expect(
          (await repo.medicineById(medicine.id))!.lowStockThreshold,
          isNull,
        );
      },
    );

    test(
      'a blank generic name clears the column rather than storing ""',
      () async {
        final medicine = await paracetamol();

        await repo.updateMedicine(medicineId: medicine.id, genericName: '  ');
        expect((await repo.medicineById(medicine.id))!.genericName, isNull);
      },
    );

    test('renaming to a blank name is refused and changes nothing', () async {
      final medicine = await paracetamol();

      await expectLater(
        repo.updateMedicine(medicineId: medicine.id, tradeName: '   '),
        throwsA(isA<MedicineConflictException>()),
      );
      expect(
        (await repo.medicineById(medicine.id))!.tradeName,
        'Paracetamol 500mg',
      );
    });
  });

  group('deactivateMedicine', () {
    test('is refused while stock remains, and the row survives', () async {
      final medicine = await paracetamol();
      await addBatch(
        medicine.id,
        batch: 'A1',
        expiry: _inDays(300),
        qty: 5,
        costPya: 120,
      );

      expect(
        () => repo.deactivateMedicine(medicineId: medicine.id),
        throwsA(isA<MedicineInUseException>()),
      );
      expect((await repo.medicineById(medicine.id))!.isActive, isTrue);
    });

    test('succeeds once the stock is gone', () async {
      final medicine = await paracetamol();
      final id = await addBatch(
        medicine.id,
        batch: 'A1',
        expiry: _inDays(300),
        qty: 5,
        costPya: 120,
      );
      await repo.adjustBatch(batchId: id, deltaInBase: -5);

      await repo.deactivateMedicine(medicineId: medicine.id);
      expect((await repo.medicineById(medicine.id))!.isActive, isFalse);
    });

    test('clearing an item with stock must be an explicit override', () async {
      final medicine = await paracetamol();
      await addBatch(
        medicine.id,
        batch: 'A1',
        expiry: _inDays(300),
        qty: 5,
        costPya: 120,
      );

      await repo.deactivateMedicine(
        medicineId: medicine.id,
        allowWithStock: true,
      );
      expect((await repo.medicineById(medicine.id))!.isActive, isFalse);
      // The stock itself is untouched — Phase 5's write-off owns removing it.
      expect(await repo.stockForMedicine(medicine.id), 5);
    });
  });

  group('blendUnitCost', () {
    test('weights the two lots by quantity', () {
      // 100 @ 120 and 100 @ 140 -> 130.
      expect(
        blendUnitCost(
          existingQty: 100,
          existingCostPya: 120,
          addedQty: 100,
          addedCostPya: 140,
        ),
        130,
      );
      // 300 @ 100 and 100 @ 200 -> 125.
      expect(
        blendUnitCost(
          existingQty: 300,
          existingCostPya: 100,
          addedQty: 100,
          addedCostPya: 200,
        ),
        125,
      );
    });

    test('rounds half-up rather than truncating', () {
      // 100 @ 100 plus 50 @ 100 -> 100; 1 @ 0 plus 2 @ 1 -> 0.666 -> 1.
      expect(
        blendUnitCost(
          existingQty: 1,
          existingCostPya: 0,
          addedQty: 2,
          addedCostPya: 1,
        ),
        1,
      );
      // 0.333 must not round up to 1.
      expect(
        blendUnitCost(
          existingQty: 2,
          existingCostPya: 0,
          addedQty: 1,
          addedCostPya: 1,
        ),
        0,
      );
    });

    test('an unchanged lot keeps its cost exactly', () {
      expect(
        blendUnitCost(
          existingQty: 480,
          existingCostPya: 137,
          addedQty: 0,
          addedCostPya: 999,
        ),
        137,
      );
    });
  });
}
