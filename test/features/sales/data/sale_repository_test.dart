import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/sales.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/core/money.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';
import 'package:pharmacy_pos/features/inventory/data/inventory_repository.dart';
import 'package:pharmacy_pos/features/purchases/data/purchase_repository.dart';
import 'package:pharmacy_pos/features/sales/data/sale_repository.dart';

DateTime _inDays(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: days));
}

void main() {
  late AppDatabase db;
  late InventoryRepository inventory;
  late PurchaseRepository purchases;
  late SaleRepository sales;

  late Medicine para;
  late int boxId;
  late int stripId;
  late int tabletId;
  late int cashierId;

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
    cashierId = await db
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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inventory = InventoryRepository(db);
    purchases = PurchaseRepository(db);
    sales = SaleRepository(db);
    await seed();
  });

  tearDown(() => db.close());

  /// Stock-in one or more batches of paracetamol with given expiry/qty/cost.
  Future<void> stockIn(
    List<({int qty, int days, int cost, int factor, int unit})> batches,
  ) async {
    final supplier = await purchases.createSupplier(
      const NewSupplier(name: 'AA Pharma'),
    );
    var n = 0;
    // The invoice must be paid exactly its total — recordPurchase refuses an
    // overpayment, so "generous" would be a rejected delivery, not a stocked
    // shelf. Line cost = qty in sold units * per-unit cost.
    final total = batches.fold<int>(0, (sum, b) => sum + b.qty * b.cost);
    await purchases.recordPurchase(
      supplierId: supplier.id,
      paidAmountPya: total,
      lines: [
        for (final b in batches)
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'B-${n++}',
            expiryDate: _inDays(b.days),
            quantity: b.qty,
            costPricePya: b.cost,
            unitConversionId: b.unit,
            unitName: b.factor == 100
                ? 'Box'
                : b.factor == 10
                ? 'Strip'
                : 'Tablet',
            conversionFactor: b.factor,
          ),
      ],
    );
  }

  Future<int> stockOf() => inventory.stockForMedicine(para.id);

  Future<List<MedicineBatch>> batchesOf() => (db.select(
    db.medicineBatches,
  )..where((t) => t.medicineId.equals(para.id))).get();

  Future<SaleReceipt> sell({
    required List<NewSaleLine> lines,
    Pya discountPya = 0,
    Pya receivedPya = 0,
    SaleMode mode = SaleMode.retail,
    PaymentMethod method = PaymentMethod.cash,
    int? customerId,
  }) {
    return sales.completeSale(
      lines: lines,
      mode: mode,
      discountPya: discountPya,
      paymentMethod: method,
      receivedPya: receivedPya,
      customerId: customerId,
      cashierUserId: cashierId,
    );
  }

  NewSaleLine line({
    required int unit,
    required String unitName,
    required int factor,
    required int quantity,
    required Pya unitPricePya,
  }) => NewSaleLine(
    medicineId: para.id,
    unitConversionId: unit,
    unitName: unitName,
    conversionFactor: factor,
    quantity: quantity,
    unitPricePya: unitPricePya,
  );

  group('FEFO deduction (brief item 2)', () {
    test('a single batch is drawn down, stock conserved', () async {
      await stockIn([
        (qty: 5, days: 300, cost: 12000, factor: 100, unit: boxId),
      ]);
      expect(await stockOf(), 500); // 5 boxes -> 500 tablets

      await sell(
        lines: [
          line(
            unit: stripId,
            unitName: 'Strip',
            factor: 10,
            quantity: 3,
            unitPricePya: 1600,
          ),
        ],
        receivedPya: 4800,
      );

      // 3 strips = 30 tablets removed from 500.
      expect(await stockOf(), 470);
      final batch = (await batchesOf()).single;
      expect(batch.qtyInSmallestUnit, 470);
    });

    test('spans batches earliest-expiry first and depletes across them', () async {
      // Soonest-expiry batch holds 10 tablets, the later one 20.
      await stockIn([
        (qty: 10, days: 60, cost: 100, factor: 1, unit: tabletId),
        (qty: 20, days: 400, cost: 150, factor: 1, unit: tabletId),
      ]);
      final byExpiry = await inventory.batchesFor(para.id);
      final soonest = byExpiry.first.batch;

      // Sell 15 tablets: drains the 60-day batch (10) then 5 from the 400-day.
      final receipt = await sell(
        lines: [
          line(
            unit: tabletId,
            unitName: 'Tablet',
            factor: 1,
            quantity: 15,
            unitPricePya: 200,
          ),
        ],
        receivedPya: 3000,
      );

      final allocations = receipt.allocations;
      expect(allocations, hasLength(2));
      // The first allocation is the soonest-expiry batch, drained fully.
      expect(allocations.first.batchId, soonest.id);
      expect(
        allocations.map((a) => a.quantity).toList(),
        containsAllInOrder([10, 5]),
      );
      expect(await stockOf(), 15); // 30 - 15
      final remaining = await batchesOf();
      final drained = remaining.firstWhere((b) => b.id == soonest.id);
      expect(drained.qtyInSmallestUnit, 0);
    });

    test('total_cost is the sum over the batches actually consumed', () async {
      await stockIn([
        (qty: 10, days: 60, cost: 100, factor: 1, unit: tabletId),
        (qty: 10, days: 400, cost: 150, factor: 1, unit: tabletId),
      ]);
      // Sell all 20 tablets: cost = 10*100 + 10*150 = 2500 pya.
      final receipt = await sell(
        lines: [
          line(
            unit: tabletId,
            unitName: 'Tablet',
            factor: 1,
            quantity: 20,
            unitPricePya: 200,
          ),
        ],
        receivedPya: 4000,
      );
      final reloaded = await sales.saleById(receipt.sale.id);
      expect(reloaded!.totalCost, 2500);
      // sale_items.unit_cost is the blend across both batches.
      expect(receipt.lines.single.unitCost, 125);
    });

    test(
      'two lines of one medicine never double-take the last strip',
      () async {
        await stockIn([
          (qty: 15, days: 300, cost: 100, factor: 1, unit: tabletId),
        ]);
        // 10 + 10 = 20 tablets wanted, only 15 exist — must fail wholesale.
        await expectLater(
          sell(
            lines: [
              line(
                unit: tabletId,
                unitName: 'Tablet',
                factor: 1,
                quantity: 10,
                unitPricePya: 200,
              ),
              line(
                unit: tabletId,
                unitName: 'Tablet',
                factor: 1,
                quantity: 10,
                unitPricePya: 200,
              ),
            ],
            receivedPya: 4000,
          ),
          throwsA(isA<SaleShortageException>()),
        );
        // Rollback: untouched, and no voucher persisted.
        expect(await stockOf(), 15);
        expect(await db.select(db.sales).get(), isEmpty);
      },
    );
  });

  group('money & totals', () {
    setUp(
      () =>
          stockIn([(qty: 5, days: 300, cost: 12000, factor: 100, unit: boxId)]),
    );

    test('subtotal, discount and total are stored in pya', () async {
      final receipt = await sell(
        lines: [
          line(
            unit: boxId,
            unitName: 'Box',
            factor: 100,
            quantity: 2,
            unitPricePya: 15000,
          ),
        ],
        discountPya: 1000,
        receivedPya: 29000,
      );
      expect(receipt.subtotalPya, 30000);
      expect(receipt.discountPya, 1000);
      expect(receipt.totalPya, 29000);
      final sale = await sales.saleById(receipt.sale.id);
      expect(sale!.subtotal, 30000);
      expect(sale.discount, 1000);
      expect(sale.totalAmount, 29000);
    });

    test('overpayment produces change; paid-in-full produces none', () async {
      final change = await sell(
        lines: [
          line(
            unit: boxId,
            unitName: 'Box',
            factor: 100,
            quantity: 1,
            unitPricePya: 15000,
          ),
        ],
        receivedPya: 20000,
      );
      expect(change.changePya, 5000);
      expect(change.creditPya, 0);

      final exact = await sell(
        lines: [
          line(
            unit: boxId,
            unitName: 'Box',
            factor: 100,
            quantity: 1,
            unitPricePya: 15000,
          ),
        ],
        receivedPya: 15000,
      );
      expect(exact.changePya, 0);
    });

    test(
      'wholesale mode prices are supplied by the cart, stored verbatim',
      () async {
        // The repository trusts the line's unit price; the cart resolves retail vs
        // wholesale. A wholesale-priced box is simply a cheaper line price.
        final receipt = await sell(
          mode: SaleMode.wholesale,
          lines: [
            line(
              unit: boxId,
              unitName: 'Box',
              factor: 100,
              quantity: 2,
              unitPricePya: 12000,
            ),
          ],
          receivedPya: 24000,
        );
        expect(receipt.subtotalPya, 24000);
        expect(receipt.sale.saleType, 'wholesale');
      },
    );
  });

  group('credit sales', () {
    Future<Customer> creditCustomer(Pya limit) =>
        sales.createCustomer(name: 'Hla Hla', creditLimitPya: limit);

    test('a balance within the limit posts to the customer debt', () async {
      await stockIn([
        (qty: 1, days: 300, cost: 12000, factor: 100, unit: boxId),
      ]);
      final customer = await creditCustomer(20000);
      final receipt = await sell(
        lines: [
          line(
            unit: boxId,
            unitName: 'Box',
            factor: 100,
            quantity: 1,
            unitPricePya: 15000,
          ),
        ],
        receivedPya: 5000, // part payment, 10,000 on credit
        customerId: customer.id,
      );
      expect(receipt.creditPya, 10000);
      expect(receipt.wasOnCredit, isTrue);
      final after = (await sales.customerById(customer.id))!;
      expect(after.currentDebt, 10000);
    });

    test(
      'a credit sale that would breach the limit is refused and rolled back',
      () async {
        await stockIn([
          (qty: 1, days: 300, cost: 12000, factor: 100, unit: boxId),
        ]);
        final customer = await creditCustomer(
          8000,
        ); // limit below the 15,000 sale
        await expectLater(
          sell(
            lines: [
              line(
                unit: boxId,
                unitName: 'Box',
                factor: 100,
                quantity: 1,
                unitPricePya: 15000,
              ),
            ],
            receivedPya: 0, // full 15,000 on credit > 8,000 limit
            customerId: customer.id,
          ),
          throwsA(
            isA<SaleRejectException>().having(
              (e) => e.message,
              'message',
              contains('credit limit'),
            ),
          ),
        );
        // Stock untouched, no voucher, debt unchanged — the transaction rolled back.
        expect(await stockOf(), 100);
        expect(await db.select(db.sales).get(), isEmpty);
        expect((await sales.customerById(customer.id))!.currentDebt, 0);
      },
    );

    test('an unpaid balance with no customer is refused', () async {
      await stockIn([
        (qty: 1, days: 300, cost: 12000, factor: 100, unit: boxId),
      ]);
      await expectLater(
        sell(
          lines: [
            line(
              unit: boxId,
              unitName: 'Box',
              factor: 100,
              quantity: 1,
              unitPricePya: 15000,
            ),
          ],
          receivedPya: 10000,
          customerId: null,
        ),
        throwsA(isA<SaleRejectException>()),
      );
    });
  });

  group('rejected sales', () {
    test('an empty cart is refused', () async {
      await expectLater(
        sell(lines: const [], receivedPya: 0),
        throwsA(
          isA<SaleRejectException>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('a discount larger than the subtotal is refused', () async {
      await stockIn([
        (qty: 1, days: 300, cost: 12000, factor: 100, unit: boxId),
      ]);
      await expectLater(
        sell(
          lines: [
            line(
              unit: boxId,
              unitName: 'Box',
              factor: 100,
              quantity: 1,
              unitPricePya: 15000,
            ),
          ],
          discountPya: 16000,
          receivedPya: 0,
          customerId: (await sales.createCustomer(
            name: 'X',
            creditLimitPya: 999999,
          )).id,
        ),
        throwsA(
          isA<SaleRejectException>().having(
            (e) => e.message,
            'message',
            contains('exceeds the subtotal'),
          ),
        ),
      );
    });

    test(
      'selling more than exists reports a shortage and touches nothing',
      () async {
        await stockIn([
          (qty: 1, days: 300, cost: 12000, factor: 100, unit: boxId),
        ]);
        await expectLater(
          sell(
            lines: [
              line(
                unit: boxId,
                unitName: 'Box',
                factor: 100,
                quantity: 2, // 200 tablets wanted, 100 exist
                unitPricePya: 15000,
              ),
            ],
            receivedPya: 30000,
          ),
          throwsA(isA<SaleShortageException>()),
        );
        expect(await stockOf(), 100);
        expect(await db.select(db.sales).get(), isEmpty);
      },
    );
  });

  group('customers', () {
    test('a blank name is refused', () async {
      await expectLater(
        sales.createCustomer(name: '   '),
        throwsA(isA<SaleRejectException>()),
      );
    });

    test(
      'the same name in another case returns the existing customer',
      () async {
        final a = await sales.createCustomer(
          name: 'Hla Hla',
          creditLimitPya: 5000,
        );
        final b = await sales.createCustomer(name: ' hla HLA ');
        expect(b.id, a.id);
        expect(await sales.customers(), hasLength(1));
      },
    );

    test('a payment reduces the debt; overpay is refused', () async {
      await stockIn([
        (qty: 1, days: 300, cost: 12000, factor: 100, unit: boxId),
      ]);
      final c = await sales.createCustomer(
        name: 'Debtor',
        creditLimitPya: 50000,
      );
      await sell(
        lines: [
          line(
            unit: boxId,
            unitName: 'Box',
            factor: 100,
            quantity: 1,
            unitPricePya: 15000,
          ),
        ],
        receivedPya: 0,
        customerId: c.id,
      );
      expect((await sales.customerById(c.id))!.currentDebt, 15000);

      await sales.recordCustomerPayment(customerId: c.id, amountPya: 5000);
      expect((await sales.customerById(c.id))!.currentDebt, 10000);

      await expectLater(
        sales.recordCustomerPayment(customerId: c.id, amountPya: 10001),
        throwsA(isA<SaleRejectException>()),
      );
    });
  });

  group('voucher number', () {
    test('is unique and increments within the day', () async {
      await stockIn([
        (qty: 3, days: 300, cost: 12000, factor: 100, unit: boxId),
      ]);
      final seen = <String>{};
      for (var i = 0; i < 3; i++) {
        final r = await sell(
          lines: [
            line(
              unit: tabletId,
              unitName: 'Tablet',
              factor: 1,
              quantity: 1,
              unitPricePya: 200,
            ),
          ],
          receivedPya: 200,
        );
        seen.add(r.sale.voucherNo);
      }
      expect(seen, hasLength(3));
      // Same-day sequence: ...-0001, -0002, -0003.
      expect(
        seen.map((v) => v.split('-').last).toList(),
        ['0001', '0002', '0003'].map((s) => s),
      );
      // Re-read by voucher number.
      final any = seen.first;
      expect((await sales.saleByVoucher(any))!.voucherNo, any);
    });
  });

  group('recall trail (sale_batch_allocations)', () {
    test('a sale records which batches it drew from', () async {
      await stockIn([
        (qty: 30, days: 200, cost: 130, factor: 1, unit: tabletId),
      ]);
      final batch = (await batchesOf()).single;
      await sell(
        lines: [
          line(
            unit: stripId,
            unitName: 'Strip',
            factor: 10,
            quantity: 2,
            unitPricePya: 1600,
          ),
        ],
        receivedPya: 3200,
      );
      final touched = await sales.salesFromBatch(batch.id);
      expect(touched, hasLength(1));
      expect(touched.single.quantity, 20);
      expect(touched.single.unitCost, 130);
    });
  });

  group('debt oracle', () {
    test('recalculateCustomerDebt rebuilds the cached figure', () async {
      await stockIn([
        (qty: 1, days: 300, cost: 12000, factor: 100, unit: boxId),
      ]);
      final c = await sales.createCustomer(
        name: 'Oracle',
        creditLimitPya: 999999,
      );
      await sell(
        lines: [
          line(
            unit: boxId,
            unitName: 'Box',
            factor: 100,
            quantity: 1,
            unitPricePya: 15000,
          ),
        ],
        receivedPya: 4000, // 11,000 on credit
        customerId: c.id,
      );
      // Corrupt it.
      await (db.update(db.customers)..where((t) => t.id.equals(c.id))).write(
        const CustomersCompanion(currentDebt: Value(999)),
      );
      await sales.recalculateCustomerDebt();
      expect((await sales.customerById(c.id))!.currentDebt, 11000);
    });
  });
}
