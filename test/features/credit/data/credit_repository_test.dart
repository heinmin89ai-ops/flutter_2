import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/credit_transactions.dart';
import 'package:pharmacy_pos/core/database/tables/sales.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/core/money.dart';
import 'package:pharmacy_pos/features/credit/application/ledger_service.dart';
import 'package:pharmacy_pos/features/credit/data/credit_repository.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';
import 'package:pharmacy_pos/features/inventory/data/inventory_repository.dart';
import 'package:pharmacy_pos/features/purchases/data/purchase_repository.dart';
import 'package:pharmacy_pos/features/sales/data/sale_repository.dart';

/// End-to-end tests for the *screen-facing* credit read/write repository.
///
/// `SaleRepository` and `PurchaseRepository` already post to the ledger as a
/// side effect of a sale or a delivery; `CreditRepository` is the layer the
/// Phase 5 screens call, and it must never fork the cached balance from the
/// ledger. These tests pin that property at the seams where a real regression is
/// most likely: the ledger/column invariant after a payment, the running-balance
/// arithmetic on a statement, the delete-transaction gate on
/// [CreditRepository.reversePayment], and the party-name resolution the
/// recentActivity feed renders.
void main() {
  late AppDatabase db;
  late LedgerService ledger;
  late InventoryRepository inventory;
  late SaleRepository sales;
  late PurchaseRepository purchases;
  late CreditRepository credit;

  late Medicine para;
  late int boxId;
  late int cashierId;
  late Supplier supplier;

  DateTime inDays(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: n));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);
    inventory = InventoryRepository(db);
    sales = SaleRepository(db);
    purchases = PurchaseRepository(db);
    credit = CreditRepository(db);

    para = await inventory.createMedicine(
      tradeName: 'Paracetamol',
      units: const [
        NewUnit(name: 'Box', factor: 100, retailPricePya: 20000),
        NewUnit(name: 'Tablet', factor: 1, retailPricePya: 250),
      ],
    );
    final units = await inventory.unitsFor(para.id);
    boxId = units.firstWhere((u) => u.unitName == 'Box').id;
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
    supplier = await purchases.createSupplier(
      const NewSupplier(name: 'AA Pharma'),
    );
  });

  tearDown(() => db.close());

  Future<Pya> ledgerBalance(PartyType type, int partyId) async {
    final map = await ledger.balancesByParty(type);
    return map[partyId] ?? 0;
  }

  /// Put `boxes` boxes (factor 100) on the shelf, paid in full at 150 cost/box.
  Future<void> stock(int boxes) async {
    await purchases.recordPurchase(
      supplierId: supplier.id,
      paidAmountPya: boxes * 15000,
      lines: [
        NewPurchaseLine(
          medicineId: para.id,
          unitConversionId: boxId,
          unitName: 'Box',
          conversionFactor: 100,
          batchNumber: 'B-$boxes',
          expiryDate: inDays(300),
          quantity: boxes,
          costPricePya: 15000,
        ),
      ],
    );
  }

  /// Sell one Box for 20,000 pya on credit, part-paid by [received].
  Future<void> creditSale({
    required Customer customer,
    required Pya received,
  }) async {
    await sales.completeSale(
      lines: [
        NewSaleLine(
          medicineId: para.id,
          unitConversionId: boxId,
          unitName: 'Box',
          conversionFactor: 100,
          quantity: 1,
          unitPricePya: 20000,
        ),
      ],
      mode: SaleMode.retail,
      discountPya: 0,
      paymentMethod: PaymentMethod.cash,
      receivedPya: received,
      customerId: customer.id,
      cashierUserId: cashierId,
    );
  }

  group('debtors / payables', () {
    test(
      'a credit sale lands the customer in debtors with the exact sum',
      () async {
        await stock(10);
        final customer = await sales.createCustomer(
          name: 'U Kyaw',
          phone: '09-111',
          creditLimitPya: 30000,
        );
        await creditSale(customer: customer, received: 3000);

        final debtor = (await credit.debtors()).single;
        expect(debtor.id, customer.id);
        expect(debtor.name, 'U Kyaw');
        expect(debtor.phone, '09-111');
        expect(debtor.balancePya, 17000);
        expect(debtor.creditLimitPya, 30000);
        expect(
          await ledgerBalance(PartyType.customer, customer.id),
          debtor.balancePya,
        );
      },
    );

    test('a credit supplier payable lands in payables', () async {
      // Record a delivery on credit: total 5000, paid 2000 -> 3000 owed.
      await purchases.recordPurchase(
        supplierId: supplier.id,
        paidAmountPya: 2000,
        lines: [
          NewPurchaseLine(
            medicineId: para.id,
            batchNumber: 'P-2',
            expiryDate: inDays(200),
            quantity: 10,
            costPricePya: 500,
          ),
        ],
      );
      final payable = (await credit.payables()).single;
      expect(payable.id, supplier.id);
      expect(payable.balancePya, 3000);
      expect(await ledgerBalance(PartyType.supplier, supplier.id), 3000);
    });

    test('search filters debtors by name and phone', () async {
      await stock(10);
      final customer = await sales.createCustomer(
        name: 'U Kyaw',
        phone: '09-111',
        creditLimitPya: 30000,
      );
      await creditSale(customer: customer, received: 0);

      expect((await credit.debtors(search: 'kyaw')).map((d) => d.name), [
        'U Kyaw',
      ]);
      expect((await credit.debtors(search: '09-111')).length, 1);
      expect(await credit.debtors(search: 'nomatch'), isEmpty);
    });

    test('totalReceivable sums debtors; totalPayable starts at zero', () async {
      await stock(10);
      final customer = await sales.createCustomer(
        name: 'U Kyaw',
        creditLimitPya: 30000,
      );
      await creditSale(customer: customer, received: 0);
      expect(await credit.totalReceivable(), 20000);
      expect(await credit.totalPayable(), 0);
    });
  });

  group('recordCustomerPayment', () {
    test('writes a payment row and drops the cached column together', () async {
      await stock(10);
      final customer = await sales.createCustomer(
        name: 'U Kyaw',
        creditLimitPya: 30000,
      );
      await creditSale(customer: customer, received: 0); // debt 20000

      await credit.recordCustomerPayment(
        customerId: customer.id,
        amountPya: 6000,
        note: 'cash at counter',
      );

      final after = (await credit.debtors()).single.balancePya;
      expect(after, 14000);
      expect(await ledgerBalance(PartyType.customer, customer.id), after);
      final kinds = (await credit.statement(
        partyType: PartyType.customer,
        partyId: customer.id,
      )).map((e) => e.transaction.kind);
      expect(kinds, [
        TransactionKind.debtAdded,
        TransactionKind.paymentReceived,
      ]);
    });

    test(
      'an overpayment is refused without touching ledger or column',
      () async {
        await stock(10);
        final customer = await sales.createCustomer(
          name: 'U Kyaw',
          creditLimitPya: 30000,
        );
        await creditSale(customer: customer, received: 15000); // debt 5000

        await expectLater(
          credit.recordCustomerPayment(
            customerId: customer.id,
            amountPya: 5001,
          ),
          throwsA(
            isA<CreditRejectException>().having(
              (e) => e.message,
              'message',
              contains('exceeds the outstanding balance'),
            ),
          ),
        );
        expect((await credit.debtors()).single.balancePya, 5000);
        expect(await ledgerBalance(PartyType.customer, customer.id), 5000);
      },
    );

    test('a zero or negative payment is refused', () async {
      await stock(10);
      final customer = await sales.createCustomer(
        name: 'U Kyaw',
        creditLimitPya: 30000,
      );
      await creditSale(customer: customer, received: 0);
      for (final bad in [0, -100]) {
        expect(
          () => credit.recordCustomerPayment(
            customerId: customer.id,
            amountPya: bad,
          ),
          throwsA(isA<CreditRejectException>()),
        );
      }
    });
  });

  group('statement running balance', () {
    test(
      'tracks each row chronologically and resolves the party name',
      () async {
        await stock(20);
        final customer = await sales.createCustomer(
          name: 'U Kyaw',
          creditLimitPya: 100000,
        );
        await creditSale(customer: customer, received: 10000); // debt 10000
        await credit.recordCustomerPayment(
          customerId: customer.id,
          amountPya: 3000,
        ); // -> 7000
        await creditSale(customer: customer, received: 0); // +20000 -> 27000
        await credit.recordCustomerPayment(
          customerId: customer.id,
          amountPya: 27000,
        ); // -> 0

        final stmt = await credit.statement(
          partyType: PartyType.customer,
          partyId: customer.id,
        );
        expect(stmt.map((e) => e.runningBalancePya), [10000, 7000, 27000, 0]);
        expect(stmt.map((e) => e.signedAmountPya), [
          10000,
          -3000,
          20000,
          -27000,
        ]);
        for (final e in stmt) {
          expect(e.partyName, 'U Kyaw');
        }
      },
    );
  });

  group('recentActivity', () {
    test('newest-first feed resolves party names', () async {
      await stock(20);
      final a = await sales.createCustomer(
        name: 'U Kyaw',
        creditLimitPya: 50000,
      );
      final b = await sales.createCustomer(
        name: 'Daw Hla',
        creditLimitPya: 50000,
      );
      await creditSale(customer: a, received: 0);
      await creditSale(customer: b, received: 0);

      final feed = await credit.recentActivity(PartyType.customer);
      expect(feed, hasLength(2));
      expect({for (final e in feed) e.partyName}, {'U Kyaw', 'Daw Hla'});
    });
  });

  group('reversePayment', () {
    Future<(Customer, int)> seedPayment({
      required Pya owed,
      required Pya pay,
    }) async {
      await stock(10);
      final customer = await sales.createCustomer(
        name: 'U Kyaw',
        creditLimitPya: 30000,
      );
      await creditSale(customer: customer, received: 20000 - owed);
      await credit.recordCustomerPayment(
        customerId: customer.id,
        amountPya: pay,
      );
      final stmt = await credit.statement(
        partyType: PartyType.customer,
        partyId: customer.id,
      );
      final txnId = stmt
          .firstWhere(
            (e) => e.transaction.kind == TransactionKind.paymentReceived,
          )
          .transaction
          .id;
      return (customer, txnId);
    }

    test('removes a payment row and restores the cached column', () async {
      final (customer, txnId) = await seedPayment(owed: 20000, pay: 7000);
      expect((await credit.debtors()).single.balancePya, 13000);
      await credit.reversePayment(
        transactionId: txnId,
        performedByUserId: null,
      );
      expect((await credit.debtors()).single.balancePya, 20000);
      expect(await ledgerBalance(PartyType.customer, customer.id), 20000);
    });

    test('refuses to reverse a debt_added', () async {
      await stock(10);
      final customer = await sales.createCustomer(
        name: 'U Kyaw',
        creditLimitPya: 30000,
      );
      await creditSale(customer: customer, received: 17000); // debt 3000
      final stmt = await credit.statement(
        partyType: PartyType.customer,
        partyId: customer.id,
      );
      final debtId = stmt
          .firstWhere((e) => e.transaction.kind == TransactionKind.debtAdded)
          .transaction
          .id;
      await expectLater(
        credit.reversePayment(transactionId: debtId, performedByUserId: null),
        throwsA(
          isA<CreditRejectException>().having(
            (e) => e.message,
            'message',
            contains('Only a recorded payment'),
          ),
        ),
      );
    });

    test('an unknown transaction id is refused', () async {
      await expectLater(
        credit.reversePayment(transactionId: 9999, performedByUserId: null),
        throwsA(isA<CreditRejectException>()),
      );
    });
  });
}
