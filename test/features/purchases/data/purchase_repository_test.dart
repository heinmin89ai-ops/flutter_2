import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/core/money.dart';
import 'package:pharmacy_pos/features/inventory/data/inventory_repository.dart';
import 'package:pharmacy_pos/features/purchases/data/purchase_repository.dart';

/// Days from today at local midnight — the precision expiry is stored at.
DateTime _inDays(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: days));
}

void main() {
  late AppDatabase db;
  late InventoryRepository inventory;
  late PurchaseRepository purchases;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inventory = InventoryRepository(db);
    purchases = PurchaseRepository(db);
  });

  tearDown(() => db.close());

  late Medicine para;
  late int boxId;
  late int stripId;
  late int tabletId;
  late Supplier supplier;

  Future<void> seed() async {
    para = await inventory.createMedicine(
      tradeName: 'Paracetamol 500mg',
      units: const [
        NewUnit(name: 'Box', factor: 100, retailPricePya: 15000),
        NewUnit(name: 'Strip', factor: 10, retailPricePya: 1600),
        NewUnit(name: 'Tablet', factor: 1, retailPricePya: 200),
      ],
    );
    final units = await inventory.unitsFor(para.id);
    boxId = units.firstWhere((u) => u.unitName == 'Box').id;
    stripId = units.firstWhere((u) => u.unitName == 'Strip').id;
    tabletId = units.firstWhere((u) => u.unitName == 'Tablet').id;
    supplier = await purchases.createSupplier(
      const NewSupplier(name: 'AA Pharma', phone: '09-123'),
    );
  }

  Future<PurchaseReceipt> stockIn({
    required List<NewPurchaseLine> lines,
    required Pya paidPya,
    int? supplierId,
  }) {
    return purchases.recordPurchase(
      supplierId: supplierId ?? supplier.id,
      lines: lines,
      paidAmountPya: paidPya,
    );
  }

  Future<List<MedicineBatch>> batchesOf(int medicineId) => (db.select(
    db.medicineBatches,
  )..where((t) => t.medicineId.equals(medicineId))).get();

  Future<Supplier> reload(int id) async => (await purchases.supplierById(id))!;

  /// A real `users` row, because `purchases.entered_by_user_id` is a foreign key.
  Future<int> seedClerk() async {
    final existing = await db.select(db.users).getSingleOrNull();
    if (existing != null) return existing.id;
    return db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            username: 'clerk',
            pinHash: r'salt$hash',
            role: UserRole.cashier,
            createdAt: DateTime.now(),
          ),
        );
  }

  setUp(seed);

  group('stock-in creates batches', () {
    test('one line becomes one batch holding the converted quantity', () async {
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            unitConversionId: boxId,
            unitName: 'Box',
            conversionFactor: 100,
            batchNumber: 'P-101',
            expiryDate: _inDays(400),
            quantity: 5,
            costPricePya: 12000,
          ),
        ],
        paidPya: 60000,
      );

      final batch = (await batchesOf(para.id)).single;
      // 5 boxes -> 500 tablets: stock is stored in the smallest unit only.
      expect(batch.qtyInSmallestUnit, 500);
      expect(batch.batchNumber, 'P-101');
      expect(batch.expiryDate, _inDays(400));
      expect(batch.costPrice, 120);
      expect(await inventory.stockForMedicine(para.id), 500);
    });

    test('the invoice line keeps the unit the clerk counted in', () async {
      final receipt = await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            unitConversionId: stripId,
            unitName: 'Strip',
            conversionFactor: 10,
            batchNumber: 'P-102',
            expiryDate: _inDays(300),
            quantity: 30,
            costPricePya: 1450,
          ),
        ],
        paidPya: 43500,
      );

      final line = receipt.lines.single;
      expect(line.quantity, 30);
      expect(line.unitConversionId, stripId);
      expect(line.lineTotal, 43500);
      // ...while the batch it created is in tablets: 30 x 10 = 300 at 145 pya.
      expect((await batchesOf(para.id)).single.qtyInSmallestUnit, 300);
      expect((await batchesOf(para.id)).single.costPrice, 145);
    });

    test(
      'a cost that does not divide evenly rounds half-up, not down',
      () async {
        await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              unitConversionId: stripId,
              unitName: 'Strip',
              conversionFactor: 10,
              batchNumber: 'P-103',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 1205,
            ),
          ],
          paidPya: 1205,
        );

        // 120.5 pya per tablet -> 121; plain `~/` would have stored 120 and
        // inflated every later profit figure.
        expect((await batchesOf(para.id)).single.costPrice, 121);
      },
    );

    test('a factor-1 line stores quantity and cost unchanged', () async {
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            unitConversionId: tabletId,
            unitName: 'Tablet',
            conversionFactor: 1,
            batchNumber: 'P-104',
            expiryDate: _inDays(300),
            quantity: 250,
            costPricePya: 130,
          ),
        ],
        paidPya: 32500,
      );

      final batch = (await batchesOf(para.id)).single;
      expect(batch.qtyInSmallestUnit, 250);
      expect(batch.costPrice, 130);
    });

    test('multiple lines each create their own batch', () async {
      final amox = await inventory.createMedicine(
        tradeName: 'Amoxicillin 500mg',
        units: const [NewUnit(name: 'Capsule', factor: 1, retailPricePya: 400)],
      );
      final receipt = await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            unitConversionId: boxId,
            unitName: 'Box',
            conversionFactor: 100,
            batchNumber: 'P-105',
            expiryDate: _inDays(300),
            quantity: 2,
            costPricePya: 12000,
          ),
          NewPurchaseLine(
            medicineId: amox.id,
            batchNumber: 'A-77',
            expiryDate: _inDays(120),
            quantity: 100,
            costPricePya: 300,
          ),
        ],
        paidPya: 54000,
      );

      expect(receipt.batchesCreated, 2);
      expect(receipt.batchesMerged, 0);
      expect(await batchesOf(para.id), hasLength(1));
      expect(await batchesOf(amox.id), hasLength(1));
    });

    test('a batch row remembers which invoice line filled it', () async {
      final receipt = await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            unitConversionId: boxId,
            unitName: 'Box',
            conversionFactor: 100,
            batchNumber: 'P-106',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 12000,
          ),
        ],
        paidPya: 12000,
      );

      // Recall on a bad batch needs "which delivery put this on the shelf".
      final batch = (await batchesOf(para.id)).single;
      expect(batch.purchaseItemId, receipt.lines.single.id);
    });

    test('expiry is stored at day precision regardless of the hour', () async {
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-107',
            expiryDate: DateTime.now().add(const Duration(days: 90)),
            quantity: 10,
            costPricePya: 100,
          ),
        ],
        paidPya: 1000,
      );

      final batch = (await batchesOf(para.id)).single;
      expect(batch.expiryDate.hour, 0);
      expect(batch.expiryDate.minute, 0);
    });
  });

  group('repeated batch numbers', () {
    test(
      'merge into the existing batch with a weighted-average cost',
      () async {
        await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'X117',
              expiryDate: _inDays(300),
              quantity: 100,
              costPricePya: 100,
            ),
          ],
          paidPya: 10000,
        );
        final receipt = await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'X117',
              expiryDate: _inDays(300),
              quantity: 100,
              costPricePya: 140,
            ),
          ],
          paidPya: 14000,
        );

        final batch = (await batchesOf(para.id)).single;
        expect(receipt.batchesMerged, 1);
        expect(receipt.batchesCreated, 0);
        expect(batch.qtyInSmallestUnit, 200);
        // The old lot's cost is kept in the average, not overwritten.
        expect(batch.costPrice, 120);
      },
    );

    test(
      'merging keeps the purchase-item link from the first delivery',
      () async {
        final first = await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'X118',
              expiryDate: _inDays(300),
              quantity: 10,
              costPricePya: 100,
            ),
          ],
          paidPya: 1000,
        );
        await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'X118',
              expiryDate: _inDays(300),
              quantity: 10,
              costPricePya: 120,
            ),
          ],
          paidPya: 1200,
        );

        final batch = (await batchesOf(para.id)).single;
        expect(batch.purchaseItemId, first.lines.single.id);
      },
    );

    test('the same number with a different expiry stays two batches', () async {
      // Physically different stock — FEFO has to be able to tell them apart.
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'X119',
            expiryDate: _inDays(60),
            quantity: 10,
            costPricePya: 100,
          ),
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'X119',
            expiryDate: _inDays(600),
            quantity: 10,
            costPricePya: 130,
          ),
        ],
        paidPya: 2300,
      );

      final batches = await batchesOf(para.id);
      expect(batches, hasLength(2));
      expect(batches.map((b) => b.costPrice), containsAll([100, 130]));
    });

    test(
      'matching ignores case and stray spaces in the batch number',
      () async {
        await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'x120 ',
              expiryDate: _inDays(300),
              quantity: 10,
              costPricePya: 100,
            ),
          ],
          paidPya: 1000,
        );
        final receipt = await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'X120',
              expiryDate: _inDays(300),
              quantity: 10,
              costPricePya: 100,
            ),
          ],
          paidPya: 1000,
        );

        expect(receipt.batchesMerged, 1);
        expect(await batchesOf(para.id), hasLength(1));
      },
    );
  });

  group('payables', () {
    test('an unpaid balance lands on the supplier account', () async {
      final receipt = await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-200',
            expiryDate: _inDays(300),
            quantity: 5,
            costPricePya: 12000,
          ),
        ],
        paidPya: 20000,
      );

      expect(receipt.amountOwed, 40000);
      expect(receipt.purchase.isCredit, isTrue);
      expect(receipt.wasOnCredit, isTrue);
      expect((await reload(supplier.id)).currentPayable, 40000);
    });

    test('a fully paid invoice is not a credit', () async {
      final receipt = await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-201',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 12000,
          ),
        ],
        paidPya: 12000,
      );

      expect(receipt.purchase.isCredit, isFalse);
      expect(receipt.amountOwed, 0);
      expect((await reload(supplier.id)).currentPayable, 0);
    });

    test('payables accumulate across invoices', () async {
      for (var i = 0; i < 3; i++) {
        await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'P-21$i',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 10000,
            ),
          ],
          paidPya: 4000,
        );
      }
      expect((await reload(supplier.id)).currentPayable, 18000);

      final owing = await purchases.withPayable();
      expect(owing.map((s) => s.id), [supplier.id]);
    });

    test('a payment reduces the balance', () async {
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-202',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 12000,
          ),
        ],
        paidPya: 2000,
      );
      await purchases.recordSupplierPayment(
        supplierId: supplier.id,
        amountPya: 5000,
      );

      expect((await reload(supplier.id)).currentPayable, 5000);
    });

    test('overpaying is refused and leaves the balance alone', () async {
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-203',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 12000,
          ),
        ],
        paidPya: 0,
      );

      expect(
        () => purchases.recordSupplierPayment(
          supplierId: supplier.id,
          amountPya: 12001,
        ),
        throwsA(
          isA<PurchaseRejectException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the outstanding balance'),
          ),
        ),
      );
      expect((await reload(supplier.id)).currentPayable, 12000);
    });

    test('a zero or negative payment is refused', () async {
      for (final amount in [0, -500]) {
        expect(
          () => purchases.recordSupplierPayment(
            supplierId: supplier.id,
            amountPya: amount,
          ),
          throwsA(isA<PurchaseRejectException>()),
        );
      }
    });

    test('recalculatePayable rebuilds the cached figure exactly', () async {
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-204',
            expiryDate: _inDays(300),
            quantity: 2,
            costPricePya: 12000,
          ),
        ],
        paidPya: 9000,
      );
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-205',
            expiryDate: _inDays(200),
            quantity: 1,
            costPricePya: 5000,
          ),
        ],
        paidPya: 5000,
      );

      // Corrupt the denormalised column the way a bug in a later phase might.
      final owedExpr =
          db.purchases.totalAmount.sum() - db.purchases.paidAmount.sum();
      final truth =
          await (db.selectOnly(db.purchases)
                ..addColumns([owedExpr])
                ..where(db.purchases.supplierId.equals(supplier.id)))
              .getSingle();
      final expected = truth.read(owedExpr)!;
      expect(expected, 15000);

      await (db.update(db.suppliers)..where((t) => t.id.equals(supplier.id)))
          .write(const SuppliersCompanion(currentPayable: Value(999)));
      expect((await reload(supplier.id)).currentPayable, 999);

      await purchases.recalculatePayable();
      expect((await reload(supplier.id)).currentPayable, expected);
    });

    test('recalculatePayable zeroes a supplier with no invoices', () async {
      final fresh = await purchases.createSupplier(
        const NewSupplier(name: 'Never Used'),
      );
      await (db.update(db.suppliers)..where((t) => t.id.equals(fresh.id)))
          .write(const SuppliersCompanion(currentPayable: Value(500)));

      await purchases.recalculatePayable();
      expect((await reload(fresh.id)).currentPayable, 0);
    });

    test(
      'recalculatePayable leaves correct balances and stock untouched',
      () async {
        await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'P-206',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 12000,
            ),
          ],
          paidPya: 7000,
        );
        final before = await batchesOf(para.id);

        await purchases.recalculatePayable();

        expect((await reload(supplier.id)).currentPayable, 5000);
        final after = await batchesOf(para.id);
        expect(after.single.qtyInSmallestUnit, before.single.qtyInSmallestUnit);
      },
    );
  });

  group('suppliers', () {
    test('a blank name is refused', () async {
      expect(
        () => purchases.createSupplier(const NewSupplier(name: '   ')),
        throwsA(isA<PurchaseRejectException>()),
      );
    });

    test(
      'the same name in another case returns the existing supplier',
      () async {
        final again = await purchases.createSupplier(
          const NewSupplier(name: '  aa PHARMA '),
        );

        expect(again.id, supplier.id);
        expect(await purchases.suppliers(), hasLength(1));
      },
    );

    test('a genuinely new name creates a second account', () async {
      await purchases.createSupplier(
        const NewSupplier(name: 'BB Distributors'),
      );
      expect(await purchases.suppliers(), hasLength(2));
    });

    test('search matches name, company and phone', () async {
      await purchases.createSupplier(
        const NewSupplier(name: 'City Pharma', companyName: 'City Wholesale'),
      );

      expect((await purchases.suppliers(search: 'aa ')).map((s) => s.name), [
        'AA Pharma',
      ]);
      expect((await purchases.suppliers(search: 'wholesa')).length, 1);
      expect((await purchases.suppliers(search: '09-123')).length, 1);
    });

    test('an unknown supplier cannot be bought from', () async {
      expect(
        () => stockIn(
          supplierId: 999,
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'P-207',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 100,
            ),
          ],
          paidPya: 0,
        ),
        throwsA(isA<PurchaseRejectException>()),
      );
    });
  });

  group('rejected invoices', () {
    test('an empty line list is refused', () async {
      expect(
        () => stockIn(lines: const [], paidPya: 0),
        throwsA(
          isA<PurchaseRejectException>().having(
            (e) => e.message,
            'message',
            contains('at least one medicine line'),
          ),
        ),
      );
    });

    test('a line with no batch number is refused', () async {
      expect(
        () => stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: '  ',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 100,
            ),
          ],
          paidPya: 100,
        ),
        throwsA(isA<PurchaseRejectException>()),
      );
    });

    test('a zero or negative quantity is refused', () async {
      for (final qty in [0, -3]) {
        expect(
          () => stockIn(
            lines: [
              NewPurchaseLine(
                medicineId: para.id,
                batchNumber: 'P-208',
                expiryDate: _inDays(300),
                quantity: qty,
                costPricePya: 100,
              ),
            ],
            paidPya: 100,
          ),
          throwsA(isA<PurchaseRejectException>()),
        );
      }
    });

    test('a line that adds no pieces is refused via its factor', () async {
      expect(
        () => stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'P-209',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 100,
              conversionFactor: 0,
            ),
          ],
          paidPya: 100,
        ),
        throwsA(isA<PurchaseRejectException>()),
      );
    });

    test('a delivery that has already expired is refused', () async {
      expect(
        () => stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'OLD',
              expiryDate: _inDays(-1),
              quantity: 5,
              costPricePya: 100,
            ),
          ],
          paidPya: 500,
        ),
        throwsA(
          isA<PurchaseRejectException>().having(
            (e) => e.message,
            'message',
            allOf(contains('OLD'), contains('write-off')),
          ),
        ),
      );
    });

    test('one expired line rejects the whole invoice', () async {
      expect(
        () => stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'GOOD',
              expiryDate: _inDays(300),
              quantity: 5,
              costPricePya: 100,
            ),
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'ROTTEN',
              expiryDate: _inDays(-5),
              quantity: 5,
              costPricePya: 100,
            ),
          ],
          paidPya: 1000,
        ),
        throwsA(isA<PurchaseRejectException>()),
      );
      expect(await db.select(db.purchases).get(), isEmpty);
      expect(await db.select(db.medicineBatches).get(), isEmpty);
    });

    test('the same batch twice on one invoice is refused', () async {
      expect(
        () => stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'DUP',
              expiryDate: _inDays(300),
              quantity: 5,
              costPricePya: 100,
            ),
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'dup',
              expiryDate: _inDays(300),
              quantity: 7,
              costPricePya: 110,
            ),
          ],
          paidPya: 1270,
        ),
        throwsA(
          isA<PurchaseRejectException>().having(
            (e) => e.message,
            'message',
            contains('appears twice'),
          ),
        ),
      );
    });

    test('paying more than the invoice total is refused', () async {
      expect(
        () => stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'P-210',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 1000,
            ),
          ],
          paidPya: 1001,
        ),
        throwsA(
          isA<PurchaseRejectException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the invoice total'),
          ),
        ),
      );
      // Rejected before the transaction, so no orphan header row.
      expect(await db.select(db.purchases).get(), isEmpty);
      expect(await batchesOf(para.id), isEmpty);
    });

    test('a negative paid amount is refused', () async {
      expect(
        () => stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'P-211',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 1000,
            ),
          ],
          paidPya: -100,
        ),
        throwsA(isA<PurchaseRejectException>()),
      );
    });

    test('a rejected invoice does not touch the payable either', () async {
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-212',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 1000,
          ),
        ],
        paidPya: 400,
      );
      final before = (await reload(supplier.id)).currentPayable;

      await expectLater(
        stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'BAD',
              expiryDate: _inDays(-1),
              quantity: 1,
              costPricePya: 1000,
            ),
          ],
          paidPya: 0,
        ),
        throwsA(isA<PurchaseRejectException>()),
      );
      expect((await reload(supplier.id)).currentPayable, before);
    });
  });

  group('receipt and history', () {
    test('the receipt echoes what was stored, including the header', () async {
      final receipt = await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            unitConversionId: boxId,
            unitName: 'Box',
            conversionFactor: 100,
            batchNumber: 'P-220',
            expiryDate: _inDays(300),
            quantity: 3,
            costPricePya: 12000,
          ),
        ],
        paidPya: 16000,
      );

      expect(receipt.purchase.supplierId, supplier.id);
      expect(receipt.purchase.totalAmount, 36000);
      expect(receipt.purchase.paidAmount, 16000);
      expect(receipt.lines, hasLength(1));
      expect(receipt.amountOwed, 20000);
      expect(receipt.purchase.id, greaterThan(0));
    });

    test('reference number and note are stored; blanks become NULL', () async {
      final clerk = await seedClerk();
      final bare = await purchases.recordPurchase(
        supplierId: supplier.id,
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-221',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 100,
          ),
        ],
        paidAmountPya: 100,
        referenceNo: '   ',
        note: ' ',
      );
      expect(bare.purchase.referenceNo, isNull);
      expect(bare.purchase.note, isNull);

      final stamped = await purchases.recordPurchase(
        supplierId: supplier.id,
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-222',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 100,
          ),
        ],
        paidAmountPya: 100,
        referenceNo: 'GRN-0091',
        note: '2 cartons damaged',
        enteredByUserId: clerk,
      );

      expect(stamped.purchase.referenceNo, 'GRN-0091');
      expect(stamped.purchase.note, '2 cartons damaged');
      // Who entered it, so a bad stock-in can be traced back to a person.
      expect(stamped.purchase.enteredByUserId, clerk);
      expect(
        (await purchases.itemsForPurchase(stamped.purchase.id)),
        hasLength(1),
      );
    });

    test(
      'itemsForPurchase and recentPurchases read the invoice back',
      () async {
        await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'P-223',
              expiryDate: _inDays(300),
              quantity: 2,
              costPricePya: 500,
            ),
          ],
          paidPya: 1000,
        );
        final second = await stockIn(
          lines: [
            NewPurchaseLine(
              medicineId: para.id,
              batchNumber: 'P-224',
              expiryDate: _inDays(300),
              quantity: 1,
              costPricePya: 700,
            ),
          ],
          paidPya: 700,
        );

        final recent = await purchases.recentPurchases();
        expect(recent, hasLength(2));
        // Newest first — the stock-in list shows today's deliveries on top.
        expect(recent.first.id, second.purchase.id);
        expect(
          (await purchases.itemsForPurchase(second.purchase.id))
              .single
              .batchNumber,
          'P-224',
        );
      },
    );

    test('recentPurchases can be scoped to one supplier', () async {
      final other = await purchases.createSupplier(
        const NewSupplier(name: 'BB Distributors'),
      );
      await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-225',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 100,
          ),
        ],
        paidPya: 100,
      );
      await purchases.recordPurchase(
        supplierId: other.id,
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-226',
            expiryDate: _inDays(300),
            quantity: 1,
            costPricePya: 100,
          ),
        ],
        paidAmountPya: 100,
      );

      expect(
        await purchases.recentPurchases(supplierId: other.id),
        hasLength(1),
      );
    });

    test('line totals are stored, not recomputed from later prices', () async {
      final receipt = await stockIn(
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-227',
            expiryDate: _inDays(300),
            quantity: 4,
            costPricePya: 12000,
          ),
        ],
        paidPya: 48000,
      );
      expect(receipt.lines.single.lineTotal, 48000);

      // Restating the shop's selling prices must not restate history.
      await inventory.updateUnitPrices([
        UnitPriceEdit(unitId: boxId, retailPricePya: 1),
      ]);
      final line = (await purchases.itemsForPurchase(receipt.purchase.id))
          .single;
      expect(line.lineTotal, 48000);
      expect((await db.select(db.purchases).getSingle()).totalAmount, 48000);
    });
  });
}
