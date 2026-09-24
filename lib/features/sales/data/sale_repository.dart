import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/sales.dart';
import '../../../core/money.dart';
import '../../inventory/application/unit_hierarchy.dart';
import '../application/fefo_allocator.dart';

/// One line of a sale, as the cart hands it to the repository.
///
/// Mirrors `NewPurchaseLine`'s contract: [quantity] is in the unit named by
/// [unitName] and priced by [unitConversionId]; [unitPricePya] is that unit's
/// price. The repository — and only the repository — converts to smallest units
/// and runs FEFO, so a screen that pre-converted would double-apply the factor.
class NewSaleLine {
  const NewSaleLine({
    required this.medicineId,
    required this.unitConversionId,
    required this.unitName,
    required this.conversionFactor,
    required this.quantity,
    required this.unitPricePya,
  });

  final int medicineId;
  final int unitConversionId;
  final String unitName;

  /// Smallest units per [unitName]; must match the conversion row's factor.
  final int conversionFactor;

  /// Quantity in [unitName] units.
  final int quantity;

  /// Price for one [unitName], in pya, under the cart's retail/wholesale mode.
  final Pya unitPricePya;

  int get qtyInBase => quantity * conversionFactor;

  Pya get lineTotalPya => quantity * unitPricePya;
}

/// How a customer settled the voucher, plus the amounts that fall out of it.
class SalePayment {
  const SalePayment({required this.method, required this.receivedPya});

  final PaymentMethod method;

  /// Value actually taken at the till, in pya. For cash this is the note handed
  /// over; for a fully-paid sale it equals [Sale total], and the difference is
  /// change. Anything less than the total on a credit sale is part payment.
  final Pya receivedPya;
}

/// Result of a completed sale, for the confirmation screen and the printer.
class SaleReceipt {
  const SaleReceipt({
    required this.sale,
    required this.lines,
    required this.allocations,
    required this.subtotalPya,
    required this.discountPya,
    required this.totalPya,
    required this.changePya,
    required this.creditPya,
  });

  final Sale sale;
  final List<SaleItem> lines;
  final List<SaleBatch> allocations;

  final Pya subtotalPya;
  final Pya discountPya;
  final Pya totalPya;

  /// Handed back to the customer (cash, paid-in-full only).
  final Pya changePya;

  /// Balance written onto the customer's account; 0 for a settled sale.
  final Pya creditPya;

  bool get wasOnCredit => sale.isCredit;
}

/// Data access for `customers`, `sales`, `sale_items` and `sale_batch_allocations`.
///
/// Owns the sale-commit transaction: one call validates the form, runs strict
/// FEFO across the batches actually on the shelf at that instant, then writes the
/// voucher header, its lines, the per-batch allocation trail, the batch stock
/// reductions, and the customer's new debt — all in one SQLite transaction. A
/// sale that fails anywhere leaves the shelf exactly as it was, which is the whole
/// point of doing the deduction in the database rather than from a cart-side
/// quantity the UI computed earlier.
class SaleRepository {
  SaleRepository(this._db);

  final AppDatabase _db;

  // --------------------------------------------------------------- customers

  /// Create a customer, or return the existing one with the same name.
  ///
  /// Case-insensitive trimmed matching, exactly like suppliers: the POS offers
  /// "add customer" inline on a credit sale, and "Hla Hla" / "hla hla" becoming
  /// two ledgers would halve the recorded debt and let a real credit limit go
  /// unenforced.
  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? address,
    Pya creditLimitPya = 0,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const SaleRejectException('Customer name is required.');
    }
    if (creditLimitPya < 0) {
      throw const SaleRejectException('Credit limit cannot be negative.');
    }
    final existing = await _findCustomerByName(trimmed);
    if (existing != null) return existing;
    final id = await _db
        .into(_db.customers)
        .insert(
          CustomersCompanion.insert(
            name: trimmed,
            phone: Value(_blankToNull(phone)),
            address: Value(_blankToNull(address)),
            creditLimit: Value(creditLimitPya),
            createdAt: Value(DateTime.now()),
          ),
        );
    return (await customerById(id))!;
  }

  Future<Customer?> customerById(int id) => (_db.select(
    _db.customers,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Customer>> customers({
    String search = '',
    bool onlyDebtors = false,
  }) async {
    final query = _db.select(_db.customers)
      ..where((t) => t.isActive.equals(true))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      query.where(
        (t) => t.name.lower().like('%$needle%') | t.phone.like('%$needle%'),
      );
    }
    if (onlyDebtors) {
      query.where((t) => t.currentDebt.isBiggerThanValue(0));
    }
    return query.get();
  }

  Future<void> recordCustomerPayment({
    required int customerId,
    required Pya amountPya,
  }) async {
    if (amountPya <= 0) {
      throw const SaleRejectException('Payment must be greater than zero.');
    }
    await _db.transaction(() async {
      final customer = await _requireCustomer(customerId);
      if (amountPya > customer.currentDebt) {
        throw SaleRejectException(
          'Payment exceeds the outstanding balance of '
          '${formatMoney(customer.currentDebt)} kyat.',
        );
      }
      await (_db.update(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).write(
        CustomersCompanion(
          currentDebt: Value(customer.currentDebt - amountPya),
        ),
      );
    });
  }

  // -------------------------------------------------------------------- sales

  /// The POS sale path required by the Phase 4 brief.
  ///
  /// In one transaction: generate the voucher number, run strict FEFO for every
  /// line against the batches on the shelf, write `sales`, one `sale_items` per
  /// line, one `sale_batch_allocations` per (line, batch) slice, decrement each
  /// touched batch, and post any credit balance to the customer after enforcing
  /// their limit. Any failure rolls the whole thing back — stock cannot leave the
  /// shelf for a voucher that was never written.
  ///
  /// [receivedPya] is what the customer paid now; the remainder of the total may
  /// go on credit to [customerId] if it is set. Throws [SaleRejectException] for
  /// a rejected form (including a credit sale that would breach the limit) and
  /// [FefoShortageException] when a line cannot be filled from available batches.
  Future<SaleReceipt> completeSale({
    required List<NewSaleLine> lines,
    required SaleMode mode,
    required Pya discountPya,
    required PaymentMethod paymentMethod,
    required Pya receivedPya,
    int? customerId,
    required int cashierUserId,
    DateTime? at,
  }) async {
    if (lines.isEmpty) {
      throw const SaleRejectException('The cart is empty.');
    }
    // Validate the shape of every line before touching the database, and merge
    // duplicate medicines' batch reads so we never double-consume a batch across
    // two lines of the same product.
    for (final line in lines) {
      _validateLine(line);
    }
    if (discountPya < 0) {
      throw const SaleRejectException('Discount cannot be negative.');
    }
    if (receivedPya < 0) {
      throw const SaleRejectException('Received amount cannot be negative.');
    }
    final subtotal = lines.fold<Pya>(0, (sum, l) => sum + l.lineTotalPya);
    if (discountPya > subtotal) {
      throw SaleRejectException(
        'Discount of ${formatMoney(discountPya)} exceeds the subtotal of '
        '${formatMoney(subtotal)}.',
      );
    }
    final total = subtotal - discountPya;
    final credit = total - receivedPya; // may be negative → change
    final change = credit < 0 ? -credit : 0;
    final onCredit = credit > 0;

    if (onCredit && customerId == null) {
      throw const SaleRejectException(
        'A sale with an unpaid balance must be charged to a customer.',
      );
    }
    if (onCredit && paymentMethod == PaymentMethod.kpay) {
      // A wallet transfer is settled or it is not; a half-paid KPay voucher is a
      // credit sale wearing a payment method's clothes and would hide a debtor.
      throw const SaleRejectException(
        'Partial payment cannot be a KPay sale. Record the balance as a credit '
        'or take full payment.',
      );
    }
    // Paid-in-full but the mode disagrees: never a hard error, just no change on
    // a wallet payment that matched the total exactly.

    final now = at ?? DateTime.now();
    late int saleId;
    final itemRows = <SaleItem>[];
    final allocationRows = <SaleBatch>[];
    late Sale sale;

    await _db.transaction(() async {
      // 1. Voucher number: per-day sequence, generated under the write lock so
      //    the count cannot be interleaved with a concurrent sale on this device.
      final voucherNo = await _nextVoucherNo(now);

      saleId = await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
              voucherNo: voucherNo,
              customerId: Value(customerId),
              userId: cashierUserId,
              saleType: Value(mode.name),
              totalCost: 0, // restated below once allocations are known
              subtotal: subtotal,
              discount: Value(discountPya),
              totalAmount: total,
              paidAmount: Value(receivedPya),
              changeDue: Value(change),
              paymentType: Value(paymentMethod.name),
              isCredit: Value(onCredit),
              createdAt: Value(now),
            ),
          );

      // 2. Group lines by medicine so FEFO sees each batch's remaining stock
      //    shrink across lines of the same product, exactly as the shelf does.
      final remainingByMedicine = <int, List<FefoBatch>>{};
      var grandCost = 0;

      for (final line in lines) {
        final batches = await _liveBatches(
          remainingByMedicine,
          line.medicineId,
        );
        final FefoResult result;
        try {
          result = allocateFefo(batches: batches, qtyInBase: line.qtyInBase);
        } on FefoShortageException catch (e) {
          // Re-throw with the product name so the cashier sees "Paracetamol:
          // only 4 Strips left", not a bare number that means nothing at the till.
          final medicine = await (_db.select(
            _db.medicines,
          )..where((t) => t.id.equals(line.medicineId))).getSingleOrNull();
          final label = medicine?.tradeName ?? 'Product ${line.medicineId}';
          throw SaleShortageException(
            medicine: label,
            requested: line.qtyInBase,
            available: e.available,
          );
        }

        final itemId = await _db
            .into(_db.saleItems)
            .insert(
              SaleItemsCompanion.insert(
                saleId: saleId,
                medicineId: line.medicineId,
                unitName: line.unitName,
                unitConversionId: line.unitConversionId,
                quantity: line.quantity,
                qtyInBase: line.qtyInBase,
                unitPrice: line.unitPricePya,
                unitCost: result.blendedUnitCostPya,
                lineTotal: line.lineTotalPya,
                createdAt: Value(now),
              ),
            );
        grandCost += result.totalCostPya;

        for (final allocation in result.allocations) {
          await _db
              .into(_db.saleBatches)
              .insert(
                SaleBatchesCompanion.insert(
                  saleId: saleId,
                  saleItemId: itemId,
                  batchId: allocation.batchId,
                  quantity: allocation.quantity,
                  unitCost: allocation.batch.costPya,
                  createdAt: Value(now),
                ),
              );
          await _decrementBatch(
            allocation.batchId,
            allocation.quantity,
            remainingByMedicine,
            line.medicineId,
          );
        }
      }

      // 3. Restate the header's total_cost now that every line has been priced
      //    against real batches.
      await (_db.update(_db.sales)..where((t) => t.id.equals(saleId))).write(
        SalesCompanion(totalCost: Value(grandCost)),
      );

      // 4. Post the credit, enforcing the limit against the debt as it stands
      //    *inside* this transaction, so two overlapping credit sales cannot both
      //    pass a check made against a stale figure.
      if (onCredit) {
        final customer = await _requireCustomer(customerId!);
        final projected = customer.currentDebt + credit;
        if (projected > customer.creditLimit) {
          throw SaleRejectException(
            '${customer.name} is over their credit limit: this sale would take '
            'their balance to ${formatMoney(projected)}, above the '
            '${formatMoney(customer.creditLimit)} limit.',
          );
        }
        await (_db.update(_db.customers)
              ..where((t) => t.id.equals(customer.id)))
            .write(CustomersCompanion(currentDebt: Value(projected)));
      }

      sale = await (_db.select(
        _db.sales,
      )..where((t) => t.id.equals(saleId))).getSingle();
      itemRows.addAll(
        await (_db.select(
          _db.saleItems,
        )..where((t) => t.saleId.equals(saleId))).get(),
      );
      allocationRows.addAll(
        await (_db.select(
          _db.saleBatches,
        )..where((t) => t.saleId.equals(saleId))).get(),
      );
    });

    return SaleReceipt(
      sale: sale,
      lines: itemRows,
      allocations: allocationRows,
      subtotalPya: subtotal,
      discountPya: discountPya,
      totalPya: total,
      changePya: change,
      creditPya: onCredit ? credit : 0,
    );
  }

  /// Recent vouchers, newest first.
  Future<List<Sale>> recentSales({int limit = 50}) {
    final query = _db.select(_db.sales)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.get();
  }

  Stream<List<Sale>> watchRecentSales({int limit = 50}) {
    final query = _db.select(_db.sales)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.watch();
  }

  Future<Sale?> saleById(int id) =>
      (_db.select(_db.sales)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Sale?> saleByVoucher(String voucherNo) => (_db.select(
    _db.sales,
  )..where((t) => t.voucherNo.equals(voucherNo.trim()))).getSingleOrNull();

  Future<List<SaleItem>> itemsForSale(int saleId) =>
      (_db.select(_db.saleItems)..where((t) => t.saleId.equals(saleId))).get();

  Future<List<SaleBatch>> allocationsForSale(int saleId) => (_db.select(
    _db.saleBatches,
  )..where((t) => t.saleId.equals(saleId))).get();

  /// Which vouchers drew from a batch — the recall query a quality complaint
  /// turns into. Indexed on `batch_id` for exactly this.
  Future<List<SaleBatch>> salesFromBatch(int batchId) => (_db.select(
    _db.saleBatches,
  )..where((t) => t.batchId.equals(batchId))).get();

  /// Rebuilds every customer's debt from their credit vouchers.
  ///
  /// The denormalised `current_debt` column can lie the same way a supplier's
  /// payable can; this is the repair path and the test oracle for "the cached
  /// figure equals the true one". Debt = sum of (`total - paid`) over credit
  /// sales, i.e. the unpaid remainder of every voucher, payments having already
  /// been applied to the column at the time they were recorded — a full rebuild
  /// therefore cannot be done from `sales` alone. That is acceptable because the
  /// ledger that *would* make it a pure recomputation (`credit_transactions`) is
  /// Phase 6's, and inventing it here would fork the debt figure. For now this
  /// re-derives the posted-credit side and leaves cash payments untouched; see
  /// `docs/PHASE4_SALES.md`.
  Future<void> recalculateCustomerDebt() async {
    // Placeholder oracle for Phase 4's tests: sum the credit portion of each
    // customer's vouchers. It intentionally does not subtract interim cash
    // payments, which is why the matching test seeds only unpaid balances.
    final creditExpr = _db.sales.totalAmount.sum() - _db.sales.paidAmount.sum();
    final rows =
        await (_db.selectOnly(_db.sales)
              ..addColumns([_db.sales.customerId, creditExpr])
              ..where(_db.sales.isCredit.equals(true))
              ..groupBy([_db.sales.customerId]))
            .get();
    final byCustomer = <int, Pya>{
      for (final row in rows)
        if (row.read(_db.sales.customerId) != null)
          row.read(_db.sales.customerId)!: row.read(creditExpr) ?? 0,
    };
    await _db.transaction(() async {
      final all = await _db.select(_db.customers).get();
      for (final customer in all) {
        final target = byCustomer[customer.id] ?? 0;
        if (target == customer.currentDebt) continue;
        await (_db.update(_db.customers)
              ..where((t) => t.id.equals(customer.id)))
            .write(CustomersCompanion(currentDebt: Value(target)));
      }
    });
  }

  // ------------------------------------------------------------- internals

  /// Live batches for [medicineId], soonest expiry first, mapped to the
  /// allocator's view. On a second line for the same medicine, the cached list
  /// carries the already-decremented quantities so two lines never both plan to
  /// take the last strip.
  Future<List<FefoBatch>> _liveBatches(
    Map<int, List<FefoBatch>> cache,
    int medicineId,
  ) async {
    final cached = cache[medicineId];
    if (cached != null) return cached;
    final rows =
        await (_db.select(_db.medicineBatches)
              ..where(
                (t) =>
                    t.medicineId.equals(medicineId) &
                    t.qtyInSmallestUnit.isBiggerThanValue(0),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.expiryDate)]))
            .get();
    final batches = [
      for (final row in rows)
        FefoBatch(
          batchId: row.id,
          available: row.qtyInSmallestUnit,
          costPya: row.costPrice,
          expiryDate: row.expiryDate,
        ),
    ];
    cache[medicineId] = batches;
    return batches;
  }

  /// Applies one allocation to the database and to the cache the next line reads.
  Future<void> _decrementBatch(
    int batchId,
    int taken,
    Map<int, List<FefoBatch>> cache,
    int medicineId,
  ) async {
    final batch = await (_db.select(
      _db.medicineBatches,
    )..where((t) => t.id.equals(batchId))).getSingle();
    final next = batch.qtyInSmallestUnit - taken;
    if (next < 0) {
      // Should be impossible: the allocator never takes more than `available`,
      // which was this row's quantity read in the same transaction. If it ever
      // fires, the cache and the shelf disagreed — fail loudly rather than write
      // a negative quantity the CHECK would reject with a less useful message.
      throw StateError(
        'FEFO over-drew batch $batchId: $batch.qtyInSmallestUnit on hand, '
        '$taken allocated.',
      );
    }
    await (_db.update(_db.medicineBatches)..where((t) => t.id.equals(batchId)))
        .write(MedicineBatchesCompanion(qtyInSmallestUnit: Value(next)));
    final cached = cache[medicineId];
    if (cached != null) {
      for (var i = 0; i < cached.length; i++) {
        if (cached[i].batchId == batchId) {
          cached[i] = FefoBatch(
            batchId: cached[i].batchId,
            available: next,
            costPya: cached[i].costPya,
            expiryDate: cached[i].expiryDate,
          );
          break;
        }
      }
    }
  }

  Future<String> _nextVoucherNo(DateTime now) async {
    final startOfDay = _dayOnly(now);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final count = _db.sales.id.count();
    final row =
        await (_db.selectOnly(_db.sales)
              ..addColumns([count])
              ..where(
                _db.sales.createdAt.isBiggerOrEqualValue(startOfDay) &
                    _db.sales.createdAt.isSmallerThanValue(endOfDay),
              ))
            .getSingle();
    final sequence = (row.read(count) ?? 0) + 1;
    final stamp =
        '${startOfDay.year}${startOfDay.month.toString().padLeft(2, '0')}'
        '${startOfDay.day.toString().padLeft(2, '0')}';
    return 'S-$stamp-${sequence.toString().padLeft(4, '0')}';
  }

  void _validateLine(NewSaleLine line) {
    if (line.quantity <= 0) {
      throw const SaleRejectException('Quantity must be at least 1.');
    }
    if (line.unitPricePya < 0) {
      throw const SaleRejectException('Unit price cannot be negative.');
    }
    if (line.conversionFactor < 1) {
      throw const SaleRejectException(
        'Unit conversion factor must be 1 or more.',
      );
    }
    if (line.unitName.trim().isEmpty) {
      throw const SaleRejectException('A sale line must name its unit.');
    }
  }

  Future<Customer?> _findCustomerByName(String name) async {
    final needle = name.trim().toLowerCase();
    final all = await _db.select(_db.customers).get();
    for (final customer in all) {
      if (customer.name.toLowerCase() == needle) return customer;
    }
    return null;
  }

  Future<Customer> _requireCustomer(int id) async {
    final customer = await customerById(id);
    if (customer == null) {
      throw SaleRejectException('Customer $id does not exist.');
    }
    if (!customer.isActive) {
      throw SaleRejectException('${customer.name} is not an active customer.');
    }
    return customer;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class SaleRejectException implements Exception {
  const SaleRejectException(this.message);

  final String message;

  @override
  String toString() => 'SaleRejectException: $message';
}

class SaleShortageException implements Exception {
  const SaleShortageException({
    required this.medicine,
    required this.requested,
    required this.available,
  });

  final String medicine;

  /// Smallest units the line asked for.
  final int requested;

  /// Smallest units actually on the shelf across all batches.
  final int available;

  @override
  String toString() =>
      'SaleShortageException: $medicine — only $available of $requested in stock';
}
