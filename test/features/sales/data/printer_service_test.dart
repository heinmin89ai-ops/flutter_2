import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/sales.dart';
import 'package:pharmacy_pos/core/database/tables/users.dart';
import 'package:pharmacy_pos/core/money.dart';
import 'package:pharmacy_pos/features/inventory/application/unit_hierarchy.dart';
import 'package:pharmacy_pos/features/sales/data/printer_service.dart';
import 'package:pharmacy_pos/features/sales/data/sale_repository.dart';

/// Voucher rendering (Phase 4 brief item 4).
///
/// We cannot drive a thermal printer in CI, but the honest claim this service
/// makes is "produce a correct, printable PDF from a completed sale" — and that
/// is exactly what is assertable here without hardware: the bytes are a real PDF,
/// the file name is keyed on the voucher, and the line builder joins stored ids
/// back to product names without recomputing any money.
void main() {
  late AppDatabase db;
  late SaleRepository repo;
  late int cashierId;
  late int medicineId;
  late int unitId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SaleRepository(db);
    cashierId = await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            username: 'till1',
            pinHash: r'salt$hash',
            role: UserRole.cashier,
            createdAt: DateTime(2026),
          ),
        );
    medicineId = await db
        .into(db.medicines)
        .insert(MedicinesCompanion.insert(tradeName: 'Paracetamol 500mg'));
    unitId = await db
        .into(db.unitConversions)
        .insert(
          UnitConversionsCompanion.insert(
            medicineId: medicineId,
            unitName: 'Tablet',
            retailPrice: 120,
          ),
        );
    await db
        .into(db.medicineBatches)
        .insert(
          MedicineBatchesCompanion.insert(
            medicineId: medicineId,
            batchNumber: 'X117',
            expiryDate: DateTime(2027, 3, 1),
            qtyInSmallestUnit: 100,
            costPrice: 90,
          ),
        );
  });

  tearDown(() => db.close());

  Future<SaleReceipt> sellOne({Pya receivedPya = 12000}) => repo.completeSale(
    lines: [
      NewSaleLine(
        medicineId: medicineId,
        unitConversionId: unitId,
        unitName: 'Tablet',
        conversionFactor: 1,
        quantity: 100,
        unitPricePya: 120,
      ),
    ],
    mode: SaleMode.retail,
    discountPya: 0,
    paymentMethod: PaymentMethod.cash,
    receivedPya: receivedPya,
    cashierUserId: cashierId,
  );

  const PrinterService printer = PrinterService();

  test('renders real PDF bytes for a completed sale', () async {
    final receipt = await sellOne();
    final voucher = await printer.renderVoucher(
      receipt: receipt,
      lines: const [
        ReceiptLine(
          tradeName: 'Paracetamol 500mg',
          unitName: 'Tablet',
          quantity: 100,
          unitPricePya: 120,
          lineTotalPya: 12000,
        ),
      ],
      cashierName: 'till1',
      shopName: 'Test Pharmacy',
    );

    // "%PDF" magic header and a non-trivial body: proof the renderer produced a
    // real document, not an empty buffer.
    expect(voucher.bytes, isNotEmpty);
    final header = String.fromCharCodes(voucher.bytes.take(5));
    expect(header, '%PDF-');
    expect(voucher.bytes.length, greaterThan(500));
    expect(voucher.fileName, 'voucher-${receipt.sale.voucherNo}.pdf');
  });

  test('buildLines joins stored ids to names without touching money', () async {
    final receipt = await sellOne();
    final items = await repo.itemsForSale(receipt.sale.id);

    final lines = printer.buildLines(items, (id) => 'Paracetamol 500mg');

    expect(lines, hasLength(1));
    expect(lines.single.quantity, items.single.quantity);
    expect(lines.single.unitPricePya, items.single.unitPrice);
    expect(lines.single.lineTotalPya, items.single.lineTotal);
    expect(lines.single.unitName, 'Tablet');
  });
}
