import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/database/app_database.dart';
import 'package:pharmacy_pos/core/database/tables/credit_transactions.dart';
import 'package:pharmacy_pos/core/money.dart';
import 'package:pharmacy_pos/features/credit/application/ledger_service.dart';

/// Direct unit coverage of the ledger's *single-writer* invariant.
///
/// Phase 5's whole refactor rests on `SUM(debt_added) − SUM(payment_received)`
/// being a faithful rebuild of the cached column. The migration test proves the
/// invariant for historic rows; this file proves it for the shape of writes the
/// screens and repositories make from here on: postDebt with a linked document,
/// postPayment with none, party isolation, and the exact sums the oracle reads.
void main() {
  late AppDatabase db;
  late LedgerService ledger;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);
  });

  tearDown(() => db.close());

  Future<Pya> signedSum({
    required PartyType partyType,
    required int partyId,
  }) async {
    final rows = await ledger.entriesFor(
      partyType: partyType,
      partyId: partyId,
    );
    return rows.fold<Pya>(
      0,
      (s, r) =>
          s + (r.kind == TransactionKind.debtAdded ? r.amount : -r.amount),
    );
  }

  group('postDebt', () {
    test('appends one row per call, oldest-first on entriesFor', () async {
      final t0 = DateTime.utc(2026, 9, 1, 9);
      final t1 = t0.add(const Duration(hours: 1));
      await ledger.postDebt(
        partyType: PartyType.customer,
        partyId: 7,
        amountPya: 5000,
        saleId: 100,
        at: t1,
      );
      await ledger.postDebt(
        partyType: PartyType.customer,
        partyId: 7,
        amountPya: 3000,
        saleId: 101,
        at: t0,
      );

      final rows = await ledger.entriesFor(
        partyType: PartyType.customer,
        partyId: 7,
      );
      expect(rows.map((r) => r.amount), [3000, 5000]);
      expect(rows.map((r) => r.linkedSaleId), [101, 100]);
      for (final r in rows) {
        expect(r.kind, TransactionKind.debtAdded);
        expect(r.partyType, PartyType.customer);
      }
    });

    test('a zero or negative amount is refused before any row is written', () {
      for (final bad in [0, -1, -5000]) {
        expect(
          () => ledger.postDebt(
            partyType: PartyType.customer,
            partyId: 1,
            amountPya: bad,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('a blank note is stored as null, and a real note survives', () async {
      await ledger.postDebt(
        partyType: PartyType.supplier,
        partyId: 3,
        amountPya: 1000,
        note: '   ',
      );
      await ledger.postDebt(
        partyType: PartyType.supplier,
        partyId: 3,
        amountPya: 1000,
        note: 'GRN-88',
      );
      final rows = await ledger.entriesFor(
        partyType: PartyType.supplier,
        partyId: 3,
      );
      expect(rows[0].note, isNull);
      expect(rows[1].note, 'GRN-88');
    });
  });

  group('postPayment', () {
    test('appends a payment_received row with no linked document', () async {
      await ledger.postPayment(
        partyType: PartyType.customer,
        partyId: 12,
        amountPya: 4500,
        note: 'cash',
      );
      final row = (await ledger.entriesFor(
        partyType: PartyType.customer,
        partyId: 12,
      )).single;
      expect(row.kind, TransactionKind.paymentReceived);
      expect(row.linkedSaleId, isNull);
      expect(row.linkedPurchaseId, isNull);
      expect(row.note, 'cash');
    });

    test('a zero or negative amount is refused', () {
      for (final bad in [0, -500]) {
        expect(
          () => ledger.postPayment(
            partyType: PartyType.customer,
            partyId: 1,
            amountPya: bad,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
    });
  });

  test(
    'party isolation: a customer row is invisible to a supplier query',
    () async {
      await ledger.postDebt(
        partyType: PartyType.customer,
        partyId: 5,
        amountPya: 1000,
      );
      await ledger.postDebt(
        partyType: PartyType.supplier,
        partyId: 5,
        amountPya: 2000,
      );
      final asCustomer = await ledger.entriesFor(
        partyType: PartyType.customer,
        partyId: 5,
      );
      final asSupplier = await ledger.entriesFor(
        partyType: PartyType.supplier,
        partyId: 5,
      );
      // The two party-id spaces overlap by design, so the ledger mustn't.
      expect(asCustomer, hasLength(1));
      expect(asCustomer.single.amount, 1000);
      expect(asSupplier, hasLength(1));
      expect(asSupplier.single.amount, 2000);
    },
  );

  group('balancesByParty', () {
    test('sums debt_added − payment_received per party, in one pass', () async {
      await ledger.postDebt(
        partyType: PartyType.customer,
        partyId: 1,
        amountPya: 10000,
      );
      await ledger.postPayment(
        partyType: PartyType.customer,
        partyId: 1,
        amountPya: 4000,
      );
      await ledger.postDebt(
        partyType: PartyType.customer,
        partyId: 2,
        amountPya: 6000,
      );
      await ledger.postDebt(
        partyType: PartyType.supplier,
        partyId: 1, // deliberately colliding id on the other side
        amountPya: 90000,
      );

      final customers = await ledger.balancesByParty(PartyType.customer);
      final suppliers = await ledger.balancesByParty(PartyType.supplier);
      expect(customers, {1: 6000, 2: 6000});
      expect(suppliers, {1: 90000});
    });

    test('a party absent from the ledger maps to no key at all', () async {
      final map = await ledger.balancesByParty(PartyType.customer);
      expect(map, isEmpty);
    });
  });

  test(
    'signed sums rebuilt through the ledger match the cached-column formula',
    () async {
      // The property Phase 5 depends on: the exact arithmetic `recalculate*`
      // performs must equal a per-party fold of the ledger rows.
      await ledger.postDebt(
        partyType: PartyType.customer,
        partyId: 42,
        amountPya: 25000,
      );
      await ledger.postPayment(
        partyType: PartyType.customer,
        partyId: 42,
        amountPya: 7500,
      );
      await ledger.postDebt(
        partyType: PartyType.customer,
        partyId: 42,
        amountPya: 100,
      );
      expect(
        await signedSum(partyType: PartyType.customer, partyId: 42),
        25000 - 7500 + 100,
      );
      expect(await ledger.balancesByParty(PartyType.customer), {
        42: 25000 - 7500 + 100,
      });
    },
  );
}
