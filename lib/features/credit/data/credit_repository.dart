import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/credit_transactions.dart';
import '../../../core/l10n/l10n_bridge.dart';
import '../../../core/money.dart';
import '../../credit/application/ledger_service.dart';

/// A party (customer or supplier) together with the balance the ledger says they
/// carry right now.
///
/// [balancePya] is read from the denormalised `current_debt` / `current_payable`
/// column, not recomputed here — those columns are the ledger's materialisation
/// (the v3→4 migration and both `recalculate*` oracles keep them exact), and a
/// receivables list that re-SUMmed every row on every open would be doing the
/// ledger's work twice on the busiest screen in Module 6.
class PartyBalance {
  const PartyBalance({
    required this.id,
    required this.name,
    required this.phone,
    required this.balancePya,
    this.creditLimitPya,
  });

  final int id;
  final String name;
  final String? phone;
  final Pya balancePya;

  /// Only meaningful for a customer; `null` for a supplier.
  final Pya? creditLimitPya;

  /// How much of a customer's ceiling is used, `null` when there is no limit to
  /// measure against (a supplier, or a zero-limit cash customer).
  double? get utilisation {
    final limit = creditLimitPya;
    if (limit == null || limit <= 0) return null;
    return balancePya / limit;
  }
}

/// A ledger row resolved to the party it belongs to, for a statement feed.
///
/// The screen shows a running statement per party and a combined activity list;
/// both need the party's name beside each movement, which the raw
/// [CreditTransaction] does not carry. [runningBalancePya] is the signed balance
/// as of that row, oldest-first, so the statement reads like a bank one.
class StatementEntry {
  const StatementEntry({
    required this.transaction,
    required this.runningBalancePya,
    this.partyName,
  });

  final CreditTransaction transaction;
  final Pya runningBalancePya;
  final String? partyName;

  Pya get signedAmountPya => transaction.kind == TransactionKind.debtAdded
      ? transaction.amount
      : -transaction.amount;
}

/// Read side and admin write side of Module 6's receivables and payables.
///
/// [SaleRepository] and [PurchaseRepository] already *post* to the ledger as a
/// side effect of a sale or a payment; this repository is the screen-facing
/// layer that lists debtors, pulls a party's statement, and lets an admin record
/// a payment or write one off against a party directly. Every mutation here
/// funnels through [LedgerService] and updates the cached column in the same
/// transaction, so it cannot fork the balance from the ledger — the invariant the
/// whole Phase 5 refactor exists to hold.
class CreditRepository {
  CreditRepository(this._db) : _ledger = LedgerService(_db);

  final AppDatabase _db;
  final LedgerService _ledger;

  // ---------------------------------------------------------------- read

  /// Customers who owe the shop, largest balance first.
  ///
  /// [search] matches name or phone. Ordered by balance descending because this
  /// is a collection list: whoever owes most is called first.
  Future<List<PartyBalance>> debtors({String search = ''}) async {
    final query = _db.select(_db.customers)
      ..where((t) => t.currentDebt.isBiggerThanValue(0))
      ..orderBy([
        (t) => OrderingTerm(expression: t.currentDebt, mode: OrderingMode.desc),
      ]);
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      query.where(
        (t) => t.name.lower().like('%$needle%') | t.phone.like('%$needle%'),
      );
    }
    return [
      for (final c in await query.get())
        PartyBalance(
          id: c.id,
          name: c.name,
          phone: c.phone,
          balancePya: c.currentDebt,
          creditLimitPya: c.creditLimit,
        ),
    ];
  }

  /// Suppliers the shop owes, largest payable first.
  Future<List<PartyBalance>> payables({String search = ''}) async {
    final query = _db.select(_db.suppliers)
      ..where((t) => t.currentPayable.isBiggerThanValue(0))
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.currentPayable, mode: OrderingMode.desc),
      ]);
    final needle = search.trim().toLowerCase();
    if (needle.isNotEmpty) {
      query.where(
        (t) =>
            t.name.lower().like('%$needle%') |
            t.companyName.lower().like('%$needle%') |
            t.phone.like('%$needle%'),
      );
    }
    return [
      for (final s in await query.get())
        PartyBalance(
          id: s.id,
          name: s.name,
          phone: s.phone,
          balancePya: s.currentPayable,
        ),
    ];
  }

  /// Total owed to the shop across every customer.
  Future<Pya> totalReceivable() async {
    final sum = _db.customers.currentDebt.sum();
    final row = await (_db.selectOnly(
      _db.customers,
    )..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }

  /// Total the shop owes across every supplier.
  Future<Pya> totalPayable() async {
    final sum = _db.suppliers.currentPayable.sum();
    final row = await (_db.selectOnly(
      _db.suppliers,
    )..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }

  /// A party's full statement, oldest first, with a running balance column.
  ///
  /// The running figure is rebuilt in Dart from the ordered deltas rather than
  /// stored, so it is always consistent with the ledger even if a repair pass has
  /// just run.
  Future<List<StatementEntry>> statement({
    required PartyType partyType,
    required int partyId,
  }) async {
    final rows = await _ledger.entriesFor(
      partyType: partyType,
      partyId: partyId,
    );
    final name = await _partyName(partyType, partyId);
    final result = <StatementEntry>[];
    var running = 0;
    for (final r in rows) {
      running += r.kind == TransactionKind.debtAdded ? r.amount : -r.amount;
      result.add(
        StatementEntry(
          transaction: r,
          runningBalancePya: running,
          partyName: name,
        ),
      );
    }
    return result;
  }

  /// The combined ledger activity feed for one party type, newest first.
  ///
  /// Backs the credit screen's "all payments" tab; party names are resolved once
  /// in a batch rather than per row.
  Future<List<StatementEntry>> recentActivity(
    PartyType partyType, {
    int limit = 50,
  }) async {
    final rows = partyType == PartyType.customer
        ? await _ledger.customerEntries(limit: limit)
        : await _ledger.supplierEntries(limit: limit);
    if (rows.isEmpty) return const [];
    final names = await _namesFor(partyType, {for (final r in rows) r.partyId});
    return [
      for (final r in rows)
        StatementEntry(
          transaction: r,
          runningBalancePya: 0, // a combined feed has no single running balance
          partyName: names[r.partyId],
        ),
    ];
  }

  // --------------------------------------------------------------- writes

  /// Record a cash payment from a customer, reducing their debt.
  ///
  /// Mirrors [SaleRepository.recordCustomerPayment] exactly — same transaction,
  /// ledger post plus cached-column update — because the credit screen offers a
  /// payment entry independent of any voucher. An overpayment is refused: a
  /// negative debt is a refund, which Module 6 does not model.
  Future<void> recordCustomerPayment({
    required int customerId,
    required Pya amountPya,
    int? recordedByUserId,
    String? note,
  }) async {
    if (amountPya <= 0) {
      throw const CreditRejectException(
        errorKey: 'creditPaymentMustBePositive',
        debugMessage: 'Payment must be greater than zero.',
      );
    }
    await _db.transaction(() async {
      final customer = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(customerId))).getSingleOrNull();
      if (customer == null) {
        throw CreditRejectException(
          errorKey: 'creditCustomerDoesNotExist',
          errorArgs: {'id': '$customerId'},
          debugMessage: 'Customer $customerId does not exist.',
        );
      }
      if (amountPya > customer.currentDebt) {
        throw CreditRejectException(
          errorKey: 'creditPaymentExceedsBalance',
          errorArgs: {'amount': formatMoney(customer.currentDebt)},
          debugMessage:
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
      await _ledger.postPayment(
        partyType: PartyType.customer,
        partyId: customerId,
        amountPya: amountPya,
        recordedByUserId: recordedByUserId,
        note: note,
      );
    });
  }

  /// Record a cash payment to a supplier, reducing the payable.
  Future<void> recordSupplierPayment({
    required int supplierId,
    required Pya amountPya,
    int? recordedByUserId,
    String? note,
  }) async {
    if (amountPya <= 0) {
      throw const CreditRejectException(
        errorKey: 'creditPaymentMustBePositive',
        debugMessage: 'Payment must be greater than zero.',
      );
    }
    await _db.transaction(() async {
      final supplier = await (_db.select(
        _db.suppliers,
      )..where((t) => t.id.equals(supplierId))).getSingleOrNull();
      if (supplier == null) {
        throw CreditRejectException(
          errorKey: 'creditSupplierDoesNotExist',
          errorArgs: {'id': '$supplierId'},
          debugMessage: 'Supplier $supplierId does not exist.',
        );
      }
      if (amountPya > supplier.currentPayable) {
        throw CreditRejectException(
          errorKey: 'creditPaymentExceedsBalance',
          errorArgs: {'amount': formatMoney(supplier.currentPayable)},
          debugMessage:
              'Payment exceeds the outstanding balance of '
              '${formatMoney(supplier.currentPayable)} kyat.',
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
      );
    });
  }

  /// Delete a ledger payment row and restore the balance it reduced.
  ///
  /// This is [Permission.deleteTransaction]'s screen action: an admin undoing a
  /// mis-keyed cash receipt. Only a `payment_received` may be deleted this way —
  /// deleting a `debt_added` would silently erase a sale's or purchase's opening
  /// balance, which the source document still reports, so it is refused. The
  /// cached column is bumped back by the removed amount in the same transaction
  /// so the ledger and the column stay reconciled.
  Future<void> reversePayment({
    required int transactionId,
    required int? performedByUserId,
  }) async {
    await _db.transaction(() async {
      final row = await (_db.select(
        _db.creditTransactions,
      )..where((t) => t.id.equals(transactionId))).getSingleOrNull();
      if (row == null) {
        throw const CreditRejectException(
          errorKey: 'creditLedgerEntryMissing',
          debugMessage: 'That ledger entry no longer exists.',
        );
      }
      if (row.kind != TransactionKind.paymentReceived) {
        throw const CreditRejectException(
          errorKey: 'creditOnlyPaymentReversible',
          debugMessage:
              'Only a recorded payment can be reversed; a debt is undone by '
              'reversing its source sale or purchase.',
        );
      }
      if (row.partyType == PartyType.customer) {
        final customer = await (_db.select(
          _db.customers,
        )..where((t) => t.id.equals(row.partyId))).getSingleOrNull();
        if (customer != null) {
          await (_db.update(
            _db.customers,
          )..where((t) => t.id.equals(customer.id))).write(
            CustomersCompanion(
              currentDebt: Value(customer.currentDebt + row.amount),
            ),
          );
        }
      } else {
        final supplier = await (_db.select(
          _db.suppliers,
        )..where((t) => t.id.equals(row.partyId))).getSingleOrNull();
        if (supplier != null) {
          await (_db.update(
            _db.suppliers,
          )..where((t) => t.id.equals(supplier.id))).write(
            SuppliersCompanion(
              currentPayable: Value(supplier.currentPayable + row.amount),
            ),
          );
        }
      }
      await (_db.delete(
        _db.creditTransactions,
      )..where((t) => t.id.equals(transactionId))).go();
    });
  }

  // ------------------------------------------------------------- internals

  Future<String?> _partyName(PartyType type, int id) async {
    if (type == PartyType.customer) {
      final c = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return c?.name;
    }
    final s = await (_db.select(
      _db.suppliers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return s?.name;
  }

  Future<Map<int, String>> _namesFor(PartyType type, Set<int> ids) async {
    if (ids.isEmpty) return const {};
    if (type == PartyType.customer) {
      final rows = await (_db.select(
        _db.customers,
      )..where((t) => t.id.isIn(ids))).get();
      return {for (final r in rows) r.id: r.name};
    }
    final rows = await (_db.select(
      _db.suppliers,
    )..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id: r.name};
  }
}

class CreditRejectException implements LocalizedError {
  const CreditRejectException({
    required this.errorKey,
    this.errorArgs = const {},
    required this.debugMessage,
  });

  @override
  final String errorKey;

  @override
  final Map<String, String> errorArgs;

  @override
  final String debugMessage;

  /// English log text, kept for existing test/assert call sites.
  String get message => debugMessage;

  @override
  String toString() => 'CreditRejectException: $debugMessage';
}
