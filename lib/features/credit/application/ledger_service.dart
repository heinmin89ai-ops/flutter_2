import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/credit_transactions.dart';
import '../../../core/l10n/l10n_bridge.dart';
import '../../../core/money.dart';

/// The single writer for `credit_transactions`.
///
/// Both `SaleRepository.recordCustomerPayment` and
/// `PurchaseRepository.recordSupplierPayment` funnel through here, and every
/// balance-changing entry — including the ones the migration added for historic
/// payments and the ones Phase 5's screens post — is written in the same
/// transaction as the cached column it modifies. That is what makes
/// `SUM(debt_added) − SUM(payment_received)` a valid rebuild of
/// `current_debt` / `current_payable`, so the repair oracle and the incremental
/// writes can never disagree.
///
/// This service does not read or write any cached column; it appends ledger
/// rows. Callers are responsible for doing both, in one transaction.
class LedgerService {
  const LedgerService(this._db);

  final AppDatabase _db;

  /// Append a `debt_added` row.
  ///
  /// [saleId] or [purchaseId] identifies the source document — required so a
  /// future write-off or reversal can find the entry to reverse. Both are
  /// nullable because the same ledger covers a customer's debt and a supplier's
  /// payable; exactly one is normally set.
  Future<void> postDebt({
    required PartyType partyType,
    required int partyId,
    required Pya amountPya,
    int? saleId,
    int? purchaseId,
    int? recordedByUserId,
    String? note,
    DateTime? at,
  }) async {
    if (amountPya <= 0) {
      throw CreditLedgerException(
        errorKey: 'creditDebtEntryPositive',
        debugMessage: 'A debt entry must be positive.',
      );
    }
    await _db
        .into(_db.creditTransactions)
        .insert(
          CreditTransactionsCompanion.insert(
            partyType: partyType,
            partyId: partyId,
            kind: TransactionKind.debtAdded,
            amount: amountPya,
            linkedSaleId: Value(saleId),
            linkedPurchaseId: Value(purchaseId),
            recordedByUserId: Value(recordedByUserId),
            note: Value(_blankToNull(note)),
            createdAt: Value(at ?? DateTime.now()),
          ),
        );
  }

  /// Append a `payment_received` row.
  ///
  /// [amountPya] is what the party paid, positive. Callers validate it against
  /// the outstanding balance before writing so this stays a mechanical append;
  /// an overpayment is a mistake at the form, not a thing the ledger should
  /// ever hold.
  Future<void> postPayment({
    required PartyType partyType,
    required int partyId,
    required Pya amountPya,
    int? recordedByUserId,
    String? note,
    DateTime? at,
  }) async {
    if (amountPya <= 0) {
      throw CreditLedgerException(
        errorKey: 'creditPaymentEntryPositive',
        debugMessage: 'A payment entry must be positive.',
      );
    }
    await _db
        .into(_db.creditTransactions)
        .insert(
          CreditTransactionsCompanion.insert(
            partyType: partyType,
            partyId: partyId,
            kind: TransactionKind.paymentReceived,
            amount: amountPya,
            recordedByUserId: Value(recordedByUserId),
            note: Value(_blankToNull(note)),
            createdAt: Value(at ?? DateTime.now()),
          ),
        );
  }

  /// Every ledger row for [partyId] of [partyType], oldest first.
  Future<List<CreditTransaction>> entriesFor({
    required PartyType partyType,
    required int partyId,
  }) async =>
      (_db.select(_db.creditTransactions)
            ..where(
              (t) =>
                  t.partyType.equals(partyType.name) &
                  t.partyId.equals(partyId),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .get();

  /// The whole ledger across all customers (Module 6's receivables feed).
  Future<List<CreditTransaction>> customerEntries({
    String search = '',
    int? limit,
  }) {
    return _entries(PartyType.customer, search, limit);
  }

  /// The whole ledger across all suppliers (Module 6's payables feed).
  Future<List<CreditTransaction>> supplierEntries({
    String search = '',
    int? limit,
  }) {
    return _entries(PartyType.supplier, search, limit);
  }

  Future<List<CreditTransaction>> _entries(
    PartyType type,
    String search,
    int? limit,
  ) async {
    final query = _db.select(_db.creditTransactions)
      ..where((t) => t.partyType.equals(type.name))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    if (limit != null) query.limit(limit);
    final needle = search.trim().toLowerCase();
    // Filter on `note` alone rather than joining to the party table: the ledger
    // screen resolves names once from customers/suppliers anyway, and a LIKE on
    // note covers "cash", "bank transfer", "partial" and every other free-text
    // label a shop actually types.
    if (needle.isNotEmpty) {
      query.where((t) => t.note.lower().like('%$needle%'));
    }
    return query.get();
  }

  /// Signed `debt_added − payment_received` totals per party, in one grouped
  /// pass, so the ledger's own arithmetic can be compared with the cached
  /// column during a rebuild.
  ///
  /// Returns a map keyed on `party_id`. A party missing entirely from the
  /// ledger maps to 0 here, which callers use to catch "the cached column says
  /// 5,000 but no debt was ever posted".
  Future<Map<int, Pya>> balancesByParty(PartyType partyType) async {
    // One SUM expression held in a local variable so `TypedResult.read` finds
    // the same object it was given. `partyType`, `partyId` and `kind` come from
    // the same row, so the grouping key is the (party, kind) pair.
    final signedSum = _db.creditTransactions.amount.sum();
    final rows =
        await (_db.selectOnly(_db.creditTransactions)
              ..addColumns([
                _db.creditTransactions.partyId,
                _db.creditTransactions.kind,
                signedSum,
              ])
              ..where(_db.creditTransactions.partyType.equals(partyType.name))
              ..groupBy([
                _db.creditTransactions.partyId,
                _db.creditTransactions.kind,
              ]))
            .get();
    final byParty = <int, Pya>{};
    for (final row in rows) {
      final party = row.read(_db.creditTransactions.partyId);
      final kind = row.read(_db.creditTransactions.kind);
      final total = row.read(signedSum) ?? 0;
      if (party == null || kind == null) continue;
      byParty[party] =
          (byParty[party] ?? 0) +
          (kind == TransactionKind.debtAdded.name ? total : -total);
    }
    return byParty;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// A rejected ledger append, carrying a localisation key for the UI.
///
/// Extends [ArgumentError] so existing callers and tests that catch argument
/// misuse keep working unchanged, while `l10n.describe(e)` renders the
/// user-facing text wherever a localised context is available.
class CreditLedgerException extends ArgumentError implements LocalizedError {
  CreditLedgerException({
    required this.errorKey,
    this.errorArgs = const {},
    required this.debugMessage,
  }) : super(debugMessage);

  @override
  final String errorKey;

  @override
  final Map<String, String> errorArgs;

  @override
  final String debugMessage;
}
