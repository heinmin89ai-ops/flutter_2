import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/sales.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/features/expenses/data/expense_repository.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';
import 'package:pharmacy_pos/features/inventory/data/inventory_repository.dart';
import 'package:pharmacy_pos/features/purchases/data/purchase_repository.dart';
import 'package:pharmacy_pos/features/reports/data/report_repository.dart';
import 'package:pharmacy_pos/features/sales/data/sale_repository.dart';

/// The one object the Admin dashboard renders. These tests assemble a real day
/// — a credit sale, a supplier payable, an expense, low stock and an expiring
/// batch — and assert every field of [DailyReport], so the four headline numbers
/// are proven to describe *the same* window and to add up as the brief defines:
/// `net = sales − COGS − expenses`.
void main() {
  late AppDatabase db;
  late InventoryRepository inventory;
  late PurchaseRepository purchases;
  late SaleRepository sales;
  late ExpenseRepository expenses;
  late ReportRepository reports;

  late int cashierId;
  late Supplier supplier;
  late Medicine para;
  late int boxId;

  DateTime inDays(int n) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: n));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inventory = InventoryRepository(db);
    purchases = PurchaseRepository(db);
    sales = SaleRepository(db);
    expenses = ExpenseRepository(db);
    reports = ReportRepository(db);

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
    para = await inventory.createMedicine(
      tradeName: 'Paracetamol',
      lowStockThreshold: 500,
      units: const [
        NewUnit(name: 'Box', factor: 100, retailPricePya: 20000),
        NewUnit(name: 'Tablet', factor: 1, retailPricePya: 250),
      ],
    );
    final units = await inventory.unitsFor(para.id);
    boxId = units.firstWhere((u) => u.unitName == 'Box').id;
  });

  tearDown(() => db.close());

  /// Stock [boxes] boxes, expiring in [expiryDays], paid in full.
  Future<void> stock(int boxes, {int expiryDays = 300}) async {
    await purchases.recordPurchase(
      supplierId: supplier.id,
      paidAmountPya: boxes * 15000,
      lines: [
        NewPurchaseLine(
          medicineId: para.id,
          unitConversionId: boxId,
          unitName: 'Box',
          conversionFactor: 100,
          batchNumber: 'B-$boxes-$expiryDays',
          expiryDate: inDays(expiryDays),
          quantity: boxes,
          costPricePya: 15000,
        ),
      ],
    );
  }

  test('an empty day reports zeros, not nulls', () async {
    // Stock 10 boxes so the lowStock threshold doesn't fire.
    await stock(10);
    final r = await reports.daily();
    expect(r.totalSalesPya, 0);
    expect(r.costOfGoodsSoldPya, 0);
    expect(r.expensesPya, 0);
    expect(r.voucherCount, 0);
    expect(r.receivablePya, 0);
    expect(r.payablePya, 0);
    expect(r.netProfitPya, 0);
    expect(r.lowStock, isEmpty);
    expect(r.expiringSoon, isEmpty);
  });

  test('a full trading day assembles every headline field', () async {
    // One expiring batch with two boxes on it: FEFO sells one, the survivor is
    // still inside the 60-day window and proves the alert reads live stock.
    await stock(2, expiryDays: 30);
    await stock(4, expiryDays: 300);
    // Sell 1 box (COGS 15,000) for 20,000, 5,000 cash → 15,000 receivable.
    final customer = await sales.createCustomer(
      name: 'U Kyaw',
      creditLimitPya: 20000,
    );
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
      receivedPya: 5000,
      customerId: customer.id,
      cashierUserId: cashierId,
    );
    // A supplier payable (different medicine so it does not move para's stock).
    final amox = await inventory.createMedicine(
      tradeName: 'Amoxicillin',
      units: const [NewUnit(name: 'Capsule', factor: 1, retailPricePya: 400)],
    );
    final amoxUnits = await inventory.unitsFor(amox.id);
    await purchases.recordPurchase(
      supplierId: supplier.id,
      paidAmountPya: 2000,
      lines: [
        NewPurchaseLine(
          medicineId: amox.id,
          unitConversionId: amoxUnits.single.id,
          unitName: 'Capsule',
          conversionFactor: 1,
          batchNumber: 'A-1',
          expiryDate: inDays(300), // outside the 60-day window
          quantity: 10,
          costPricePya: 500,
        ),
      ],
    ); // total 5000, paid 2000 → 3000 payable
    // One expense today.
    await expenses.create(category: 'Rent', amountPya: 3000);

    final r = await reports.daily();

    expect(r.totalSalesPya, 20000);
    expect(r.costOfGoodsSoldPya, 15000);
    expect(r.expensesPya, 3000);
    expect(r.voucherCount, 1);
    expect(r.receivablePya, 15000);
    expect(r.payablePya, 3000);
    expect(r.grossProfitPya, 5000);
    expect(r.netProfitPya, 2000);

    // para now holds 4 boxes = 400 base units, at/below its 500 threshold;
    // amoxicillin has no threshold and is never flagged.
    expect(r.lowStock.map((row) => row.medicine.tradeName), ['Paracetamol']);
    // Only the 30-day paracetamol batch is inside the 60-day window.
    expect(r.expiringSoon.map((b) => b.tradeName), ['Paracetamol']);
    expect(ReportRepository.kExpiringWindowDays, 60);
  });

  test('a sale dated yesterday is not counted in today', () async {
    await stock(5);
    final customer = await sales.createCustomer(
      name: 'U Kyaw',
      creditLimitPya: 20000,
    );
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
      receivedPya: 20000,
      customerId: customer.id,
      cashierUserId: cashierId,
      at: inDays(1).add(const Duration(hours: 10)),
    );

    final today = await reports.daily();
    expect(today.totalSalesPya, 0);
    // But the day the sale actually happened still sees it.
    final yesterday = await reports.daily(day: inDays(1));
    expect(yesterday.totalSalesPya, 20000);
    expect(yesterday.receivablePya, 0); // fully paid
  });
}
