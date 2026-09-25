import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/credit_transactions.dart';
import '../../../core/l10n/l10n_bridge.dart';
import '../../../core/money.dart';
import '../../credit/application/ledger_service.dart';
import '../../inventory/data/inventory_repository.dart';

/// One line of a stock-in, as entered on the form.
///
/// [quantity] is in the unit named by [unitName]; [costPricePya] is the price for
/// one of that unit. Both are converted to smallest units and per-unit cost
/// inside [PurchaseRepository.recordPurchase], which is the only place allowed to
/// do that arithmetic — a screen that pre-converted would double-apply the factor.
class NewPurchaseLine {
  const NewPurchaseLine({
    required this.medicineId,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    required this.costPricePya,
    this.unitConversionId,
    this.unitName,
    this.conversionFactor = 1,
  });

  final int medicineId;
  final String batchNumber;
  final DateTime expiryDate;

  /// Quantity in [unitName]'s units.
  final int quantity;

  /// Price per [unitName] unit, in pya.
  final Pya costPricePya;

  /// `unit_conversions.id` the line was entered in, when known.
  final int? unitConversionId;

  final String? unitName;

  /// Smallest units per [unitName]. Must be [unitConversionId]'s factor; supplied
  /// separately so a line can be recorded for a medicine whose hierarchy is not
  /// configured yet (factor 1, i.e. counted in pieces).
  final int conversionFactor;

  /// Line value in pya.
  Pya get lineTotalPya => quantity * costPricePya;

  /// Quantity converted into the medicine's smallest unit.
  int get qtyInBase => quantity * conversionFactor;
}

/// A supplier as entered on the purchase form.
class NewSupplier {
  const NewSupplier({required this.name, this.phone, this.companyName});

  final String name;
  final String? phone;
  final String? companyName;
}

/// Result of a completed stock-in, for the confirmation screen.
class PurchaseReceipt {
  const PurchaseReceipt({
    required this.purchase,
    required this.lines,
    required this.batchesCreated,
    required this.batchesMerged,
    required this.amountOwed,
  });

  final Purchase purchase;
  final List<PurchaseItem> lines;

  /// How many new `medicine_batches` rows the purchase created.
  final int batchesCreated;

  /// How many lines merged into an existing batch of the same number.
  final int batchesMerged;

  /// Balance added to the supplier's account.
  final Pya amountOwed;

  bool get wasOnCredit => purchase.isCredit;
}

/// Data access for `suppliers`, `purchases` and `purchase_items`.
///
/// Owns the stock-in transaction: one call writes the purchase header, its lines,
/// the resulting batch rows and the supplier's payable, all in one SQLite
/// transaction. There is no way to record a purchase that leaves stock and debt
/// disagreeing.
class PurchaseRepository {
  PurchaseRepository(this._db) : _ledger = LedgerService(_db);

  final AppDatabase _db;
  final LedgerService _ledger;

  // --------------------------------------------------------------- suppliers

  Future<List<Supplier>> suppliers({String search = ''}) {
    final query = _db.select(_db.suppliers)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      query.where(
        (t) =>
            t.name.lower().like('%$needle%') |
            t.companyName.lower().like('%$needle%') |
            t.phone.like('%$needle%'),
      );
    }
    return query.get();
  }

  Stream<List<Supplier>> watchSuppliers() => _db.select(_db.suppliers).watch();

  Future<Supplier?> supplierById(int id) => (_db.select(
    _db.suppliers,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Create a supplier, or return the existing one with the same name.
  ///
  /// Matching on a case-insensitive trimmed name because the purchase form offers
  /// "add supplier" inline: without this, "AA Pharma" and "aa pharma" become two
  /// payables and the shop's debt is understated by half.
  Future<Supplier> createSupplier(NewSupplier entry) async {
    final name = entry.name.trim();
    if (name.isEmpty) {
      throw const PurchaseRejectException(
        'purchSupplierNameRequired',
        'Supplier name is required.',
      );
    }
    final existing = await _findSupplierByName(name);
    if (existing != null) return existing;
    final id = await _db
        .into(_db.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: name,
            phone: Value(_blankToNull(entry.phone)),
            companyName: Value(_blankToNull(entry.companyName)),
            createdAt: Value(DateTime.now()),
          ),
        );
    return (await supplierById(id))!;
  }

  /// Record a supplier payment against their account.
  ///
  /// Reduces [Supplier.currentPayable] *and* appends a `payment_received` row to
  /// the credit ledger in the same transaction, so
  /// [recalculatePayable] can rebuild the payable from the ledger alone. Before
  /// Phase 5 a supplier payment subtracted from the column and left no trace —
  /// the same gap the customer side had (see `docs/PHASE4_SALES.md`).
  ///
  /// Refuses to overpay: a negative payable would mean the shop is owed money by
  /// a supplier, which is a different business fact and belongs in Phase 7's
  /// credit module, not here.
  Future<void> recordSupplierPayment({
    required int supplierId,
    required Pya amountPya,
    int? recordedByUserId,
    String? note,
    DateTime? at,
  }) async {
    if (amountPya <= 0) {
      throw const PurchaseRejectException(
        'purchPaymentMustBePositive',
        'Payment must be greater than zero.',
      );
    }
    await _db.transaction(() async {
      final supplier = await _requireSupplier(supplierId);
      if (amountPya > supplier.currentPayable) {
        throw PurchaseRejectException(
          'purchPaymentExceedsBalance',
          'Payment exceeds the outstanding balance of '
          '${formatMoney(supplier.currentPayable)} kyat.',
          errorArgs: {'amount': formatMoney(supplier.currentPayable)},
        );
      }
      await (_db.update(
        _db.suppliers,
      )..where((t) => t.id.equals(supplierId))).write(
        SuppliersCompanion(
          currentPayable: Value(supplier.currentPayable - amountPya),
        ),
      );
      await _ledger.postPayment(
        partyType: PartyType.supplier,
        partyId: supplierId,
        amountPya: amountPya,
        recordedByUserId: recordedByUserId,
        note: note,
        at: at,
      );
    });
  }

  /// Every ledger row for [supplierId], oldest first — the payable statement
  /// screen's feed (Module 6).
  Future<List<CreditTransaction>> supplierLedger(int supplierId) =>
      _ledger.entriesFor(partyType: PartyType.supplier, partyId: supplierId);

  // ---------------------------------------------------------------- purchases

  /// The stock-in path required by the Phase 3 brief.
  ///
  /// In one transaction: insert `purchases`, insert each `purchase_items` line,
  /// then create or merge a `medicine_batches` row per line carrying that line's
  /// batch number, expiry, converted quantity and per-smallest-unit cost. If any
  /// step fails the whole thing rolls back, so a half-recorded invoice is not
  /// possible.
  ///
  /// [paidAmountPya] may be less than the line total; the difference goes onto
  /// the supplier's payable and [Purchase.wasOnCredit] reports it.
  ///
  /// Throws [PurchaseRejectException] for a rejected form, and
  /// [UnitConfigException] (from the inventory side) if a line names a unit that
  /// does not belong to its medicine.
  Future<PurchaseReceipt> recordPurchase({
    required int supplierId,
    required List<NewPurchaseLine> lines,
    required Pya paidAmountPya,
    int? enteredByUserId,
    String? referenceNo,
    String? note,
    DateTime? at,
  }) async {
    if (lines.isEmpty) {
      throw const PurchaseRejectException(
        'purchAddAtLeastOneLine',
        'Add at least one medicine line.',
      );
    }
    // Checked before the transaction so an unknown supplier is a clear message
    // rather than the raw FOREIGN KEY failure SQLite would otherwise raise.
    await _requireSupplier(supplierId);
    final now = at ?? DateTime.now();

    // Validate every line before touching the database, so a rejected invoice
    // never leaves a header row behind.
    final seen = <String>{};
    for (final line in lines) {
      _validateLine(line);
      final key =
          '${line.medicineId}|${line.batchNumber.trim().toLowerCase()}'
          '|${_dayOnly(line.expiryDate).toIso8601String()}';
      if (!seen.add(key)) {
        throw PurchaseRejectException(
          'purchDuplicateSaleUnit',
          'The same batch (${line.batchNumber}) appears twice for one medicine. '
          'Combine the quantities into a single line.',
          errorArgs: {'batch': line.batchNumber},
        );
      }
    }

    final total = lines.fold<Pya>(0, (sum, l) => sum + l.lineTotalPya);
    if (paidAmountPya < 0) {
      throw const PurchaseRejectException(
        'purchPaidNotNegative',
        'Paid amount cannot be negative.',
      );
    }
    if (paidAmountPya > total) {
      throw PurchaseRejectException(
        'purchPaidExceedsInvoice',
        'Paid ${formatMoney(paidAmountPya)} exceeds the invoice total of '
        '${formatMoney(total)}.',
        errorArgs: {
          'paid': formatMoney(paidAmountPya),
          'total': formatMoney(total),
        },
      );
    }
    final owed = total - paidAmountPya;

    late int purchaseId;
    var created = 0;
    var merged = 0;
    final itemIds = <int>[];

    await _db.transaction(() async {
      purchaseId = await _db
          .into(_db.purchases)
          .insert(
            PurchasesCompanion.insert(
              supplierId: supplierId,
              totalAmount: total,
              paidAmount: Value(paidAmountPya),
              isCredit: Value(owed > 0),
              referenceNo: Value(_blankToNull(referenceNo)),
              note: Value(_blankToNull(note)),
              enteredByUserId: Value(enteredByUserId),
              createdAt: Value(now),
            ),
          );

      for (final line in lines) {
        final itemId = await _db
            .into(_db.purchaseItems)
            .insert(
              PurchaseItemsCompanion.insert(
                purchaseId: purchaseId,
                medicineId: line.medicineId,
                unitConversionId: Value(line.unitConversionId),
                batchNumber: line.batchNumber.trim(),
                expiryDate: _dayOnly(line.expiryDate),
                quantity: line.quantity,
                costPrice: line.costPricePya,
                lineTotal: line.lineTotalPya,
              ),
            );
        itemIds.add(itemId);

        final outcome = await _applyBatch(line, itemId, now);
        if (outcome.merged) {
          merged++;
        } else {
          created++;
        }
      }

      if (owed > 0) {
        final supplier = await _requireSupplier(supplierId);
        await (_db.update(
          _db.suppliers,
        )..where((t) => t.id.equals(supplierId))).write(
          SuppliersCompanion(
            currentPayable: Value(supplier.currentPayable + owed),
          ),
        );
        // Post the payable's opening entry to the ledger, linked to this invoice,
        // so `recalculatePayable` can rebuild the column from ledger rows and a
        // later write-off can find the exact document to reverse.
        await _ledger.postDebt(
          partyType: PartyType.supplier,
          partyId: supplierId,
          amountPya: owed,
          purchaseId: purchaseId,
          recordedByUserId: enteredByUserId,
          at: now,
        );
      }
    });

    final purchase = await (_db.select(
      _db.purchases,
    )..where((t) => t.id.equals(purchaseId))).getSingle();
    final stored = await (_db.select(
      _db.purchaseItems,
    )..where((t) => t.purchaseId.equals(purchaseId))).get();

    return PurchaseReceipt(
      purchase: purchase,
      lines: stored,
      batchesCreated: created,
      batchesMerged: merged,
      amountOwed: owed,
    );
  }

  /// Recent purchases, newest first, for the stock-in list.
  Future<List<Purchase>> recentPurchases({int limit = 50, int? supplierId}) {
    final query = _db.select(_db.purchases)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    if (supplierId != null) {
      query.where((t) => t.supplierId.equals(supplierId));
    }
    return query.get();
  }

  Stream<List<Purchase>> watchRecentPurchases({int limit = 50}) {
    final query = _db.select(_db.purchases)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.watch();
  }

  Future<List<PurchaseItem>> itemsForPurchase(int purchaseId) => (_db.select(
    _db.purchaseItems,
  )..where((t) => t.purchaseId.equals(purchaseId))).get();

  /// Suppliers owing money, largest balance first.
  Future<List<Supplier>> withPayable() =>
      (_db.select(_db.suppliers)
            ..where((t) => t.currentPayable.isBiggerThanValue(0))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.currentPayable,
                mode: OrderingMode.desc,
              ),
            ]))
          .get();

  /// Rebuilds every supplier's payable from the `credit_transactions` ledger.
  ///
  /// `current_payable` is a materialisation of `SUM(debt_added) −
  /// SUM(payment_received)` per supplier, and — with Phase 5's ledger now written
  /// by both [recordPurchase] and [recordSupplierPayment] — that sum *is* the
  /// true balance. Before the ledger existed (Phase 4) a payment reduced the
  /// column without leaving a row, so this oracle had to sum the purchase headers
  /// only and could not survive an interim payment; it is now a genuine
  /// recomputation and the test oracle for "the cached figure equals the true
  /// one". A device upgrading from Phase 4 gets equivalent rows backfilled by the
  /// v3→4 migration, so its old payments are visible here too.
  Future<void> recalculatePayable() async {
    final ledger = await _ledger.balancesByParty(PartyType.supplier);
    await _db.transaction(() async {
      final suppliers = await _db.select(_db.suppliers).get();
      for (final supplier in suppliers) {
        final target = ledger[supplier.id] ?? 0;
        if (target == supplier.currentPayable) continue;
        await (_db.update(_db.suppliers)
              ..where((t) => t.id.equals(supplier.id)))
            .write(SuppliersCompanion(currentPayable: Value(target)));
      }
    });
  }

  // ------------------------------------------------------------- internals

  /// Creates the batch for [line], or merges into one that already matches.
  ///
  /// Matching on (medicine, batch number, expiry) rather than batch number alone:
  /// the same number with a different expiry is physically different stock and
  /// FEFO must be able to pick between them.
  ///
  /// The number is compared case-insensitively because the duplicate-line guard
  /// above already treats `X120` and `x120` as the same batch. Allowing a
  /// case-sensitive merge would let those two spellings land in two batch rows
  /// with different costs, and the pharmacy would never reconcile them.
  Future<({bool merged})> _applyBatch(
    NewPurchaseLine line,
    int purchaseItemId,
    DateTime now,
  ) async {
    final existing =
        await (_db.select(_db.medicineBatches)
              ..where(
                (t) =>
                    t.medicineId.equals(line.medicineId) &
                    t.batchNumber.lower().equals(
                      line.batchNumber.trim().toLowerCase(),
                    ) &
                    t.expiryDate.equals(_dayOnly(line.expiryDate)),
              )
              ..limit(1))
            .getSingleOrNull();

    final unitCost = _unitCostPya(line);

    if (existing == null) {
      await _db
          .into(_db.medicineBatches)
          .insert(
            MedicineBatchesCompanion.insert(
              medicineId: line.medicineId,
              batchNumber: line.batchNumber.trim(),
              expiryDate: _dayOnly(line.expiryDate),
              qtyInSmallestUnit: line.qtyInBase,
              costPrice: unitCost,
              purchaseItemId: Value(purchaseItemId),
              createdAt: Value(now),
            ),
          );
      return (merged: false);
    }

    // Re-weight the average rather than overwriting, so stock already on the
    // shelf keeps its true cost in profit reports.
    await (_db.update(
      _db.medicineBatches,
    )..where((t) => t.id.equals(existing.id))).write(
      MedicineBatchesCompanion(
        qtyInSmallestUnit: Value(existing.qtyInSmallestUnit + line.qtyInBase),
        costPrice: Value(
          blendUnitCost(
            existingQty: existing.qtyInSmallestUnit,
            existingCostPya: existing.costPrice,
            addedQty: line.qtyInBase,
            addedCostPya: unitCost,
          ),
        ),
      ),
    );
    return (merged: true);
  }

  /// Cost of one smallest unit for [line], in pya.
  ///
  /// A strip of 10 tablets bought at 4,500 pya costs 450 pya a tablet, exactly.
  /// When the price does not divide evenly the error is under half a pya per
  /// unit, so it is rounded half-up rather than truncated: plain `~/` biases
  /// every batch cost downward and quietly inflates the reported margin. The
  /// residue is small and one-directional-free, and belongs to Phase 7's
  /// valuation report rather than to a ledger that never closes.
  static Pya _unitCostPya(NewPurchaseLine line) =>
      (line.costPricePya * 2 + line.conversionFactor) ~/
      (2 * line.conversionFactor);

  void _validateLine(NewPurchaseLine line) {
    if (line.batchNumber.trim().isEmpty) {
      throw const PurchaseRejectException(
        'purchEveryLineNeedsBatch',
        'Every line needs a batch number.',
      );
    }
    if (line.quantity <= 0) {
      throw const PurchaseRejectException(
        'purchQuantityAtLeast1',
        'Quantity must be at least 1.',
      );
    }
    if (line.costPricePya < 0) {
      throw const PurchaseRejectException(
        'purchCostNotNegative',
        'Cost price cannot be negative.',
      );
    }
    if (line.conversionFactor < 1) {
      throw const PurchaseRejectException(
        'purchFactorAtLeast1',
        'Unit conversion factor must be 1 or more.',
      );
    }
    if (_dayOnly(line.expiryDate).isBefore(_dayOnly(DateTime.now()))) {
      throw PurchaseRejectException(
        'purchBatchAlreadyExpired',
        'Batch ${line.batchNumber} is already expired. '
        'Refuse the delivery or record it as a write-off.',
        errorArgs: {'batch': line.batchNumber},
      );
    }
  }

  Future<Supplier?> _findSupplierByName(String name) async {
    final needle = name.trim().toLowerCase();
    final all = await _db.select(_db.suppliers).get();
    for (final supplier in all) {
      if (supplier.name.toLowerCase() == needle) return supplier;
    }
    return null;
  }

  Future<Supplier> _requireSupplier(int id) async {
    final supplier = await supplierById(id);
    if (supplier == null) {
      throw PurchaseRejectException(
        'purchSupplierDoesNotExist',
        'Supplier $id does not exist.',
        errorArgs: {'id': '$id'},
      );
    }
    return supplier;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// A rejected stock-in. Carries a `purch*` localisation key instead of
/// user-facing text; [debugMessage] keeps the original English for logs and
/// tests, and [message] stays as a deprecated alias for it.
class PurchaseRejectException implements LocalizedError {
  const PurchaseRejectException(
    this.errorKey,
    this.debugMessage, {
    this.errorArgs = const {},
  });

  @override
  final String errorKey;

  @override
  final Map<String, String> errorArgs;

  @override
  final String debugMessage;

  /// English text, kept so callers and tests matching on the message still
  /// work while the module finishes localising.
  String get message => debugMessage;

  @override
  String toString() => 'PurchaseRejectException: $debugMessage';
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
