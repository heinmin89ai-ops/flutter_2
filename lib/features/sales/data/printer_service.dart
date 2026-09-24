import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/sales.dart';
import '../../../core/money.dart';
import 'sale_repository.dart';

/// A rendered voucher, ready to hand to a printer or a share sheet.
class VoucherBytes {
  const VoucherBytes({required this.bytes, required this.fileName});

  final Uint8List bytes;

  /// Suggested download/share name, keyed on the voucher number so a reprinted
  /// slip and its original never collide in a Downloads folder.
  final String fileName;
}

/// Line as the receipt needs to show it, with the product name resolved.
///
/// [SaleItem] stores ids and a denormalised unit name but not the trade name, so
/// the printer is handed a small pre-joined view. Building it here rather than in
/// the repository keeps the data layer free of presentation concerns and lets the
/// screen pass whatever it already has cached.
class ReceiptLine {
  const ReceiptLine({
    required this.tradeName,
    required this.unitName,
    required this.quantity,
    required this.unitPricePya,
    required this.lineTotalPya,
  });

  final String tradeName;
  final String unitName;
  final int quantity;
  final Pya unitPricePya;
  final Pya lineTotalPya;
}

/// Voucher printing (Phase 4 brief item 4).
///
/// The brief allowed `blue_thermal_printer` **or** `pdf`; this builds on `pdf`
/// because that is the choice an offline shop can actually rely on and the one
/// this codebase can test without hardware:
///
/// * `blue_thermal_printer`'s current release caps its SDK at `<3.0.0` and needs
///   a paired ESC/POS printer, so it cannot be compiled into a Dart 3 build or
///   exercised in CI. ESC/POS remains the right *transport* for a 58 mm till
///   receipt, and wiring it is deferred to the on-device pass — see
///   `docs/PHASE4_SALES.md`.
/// * A PDF receipt covers the other two channels the blueprint names — printing
///   to any attached printer and sharing the voucher digitally — from one
///   renderer, and its bytes are assertable in a unit test.
///
/// The service only formats an already-completed sale. It never recomputes money:
/// every figure comes off [SaleReceipt] and [ReceiptLine], so a voucher cannot
/// print a total that disagrees with what the database stored.
class PrinterService {
  const PrinterService();

  /// A portrait page narrow enough to print on a till roll or A4 alike; margins
  /// are applied at the [pw.Page], not the format.
  static const PdfPageFormat _format = PdfPageFormat(220, 320);

  /// Renders [receipt] to PDF bytes.
  ///
  /// [shopName] is the licence client name when the caller has it (printed as the
  /// header), falling back to a generic one. [cashierName] is resolved by the
  /// caller from the signed-in user, because the brief requires the cashier's
  /// *name* on the voucher and `sale_items` stores only their id. [lines] are the
  /// pre-joined rows; they must correspond to [receipt]'s sale.
  Future<VoucherBytes> renderVoucher({
    required SaleReceipt receipt,
    required List<ReceiptLine> lines,
    required String cashierName,
    String shopName = 'Pharmacy',
    String? customerName,
  }) async {
    final doc = pw.Document();
    final sale = receipt.sale;

    doc.addPage(
      pw.Page(
        pageFormat: _format,
        margin: const pw.EdgeInsets.fromLTRB(12, 12, 12, 8),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                shopName,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            _row('Voucher', sale.voucherNo),
            _row('Date', _formatDate(sale.createdAt)),
            if (customerName != null) _row('Customer', customerName),
            _row('Cashier', cashierName),
            _row('Type', _capitalise(sale.saleType)),
            pw.Divider(),
            _itemsTable(lines),
            pw.Divider(),
            _amountRow('Subtotal', receipt.subtotalPya),
            if (receipt.discountPya > 0)
              _amountRow('Discount', receipt.discountPya, negative: true),
            _amountRow('Total', receipt.totalPya, bold: true),
            _amountRow(
              sale.paymentType == PaymentMethod.kpay.name ? 'KPay' : 'Cash',
              sale.paidAmount,
            ),
            if (receipt.changePya > 0) _amountRow('Change', receipt.changePya),
            if (receipt.creditPya > 0)
              _amountRow('Balance due', receipt.creditPya),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('Thank you. Keep this voucher for returns.'),
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    return VoucherBytes(
      bytes: bytes,
      fileName: 'voucher-${sale.voucherNo}.pdf',
    );
  }

  /// Convenience: resolve [SaleReceipt]'s lines into [ReceiptLine]s using a
  /// name lookup the caller supplies, keeping this service free of database
  /// access. The screen already holds the catalogue; passing a resolver avoids a
  /// second query per reprint.
  List<ReceiptLine> buildLines(
    List<SaleItem> items,
    String Function(int medicineId) tradeNameFor,
  ) {
    return [
      for (final item in items)
        ReceiptLine(
          tradeName: tradeNameFor(item.medicineId),
          unitName: item.unitName,
          quantity: item.quantity,
          unitPricePya: item.unitPrice,
          lineTotalPya: item.lineTotal,
        ),
    ];
  }

  static pw.Widget _row(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );

  static pw.Widget _itemsTable(List<ReceiptLine> lines) {
    // A fixed-column table so a long product name wraps within its cell instead
    // of pushing the price off the roll — the one layout mistake that reliably
    // truncates a real receipt.
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(5),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          children: [_th('Item'), _th('Qty'), _th('Price'), _th('Total')],
        ),
        for (final line in lines)
          pw.TableRow(
            children: [
              _td(line.tradeName),
              _td('${line.quantity} ${line.unitName}'),
              _td(formatMoney(line.unitPricePya)),
              _td(formatMoney(line.lineTotalPya)),
            ],
          ),
      ],
    );
  }

  static pw.Widget _th(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget _td(String text) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
  );

  static pw.Widget _amountRow(
    String label,
    Pya pya, {
    bool bold = false,
    bool negative = false,
  }) {
    final amount = negative ? -pya : pya;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '${formatMoney(amount)} Ks',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  static String _capitalise(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
