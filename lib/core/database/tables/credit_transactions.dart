import 'package:drift/drift.dart';

/// Who a `credit_transactions` row belongs to.
///
/// A ledger entry is either a customer's debt (they owe the shop) or a
/// supplier's payable (the shop owes them). Stored as the lower-case enum name
/// like `users.role`, so a raw SQLite client can still read it.
enum PartyType { customer, supplier }

/// The two ledger movements Module 6 needs.
///
/// [debtAdded] increases what one party is owed; [paymentReceived] reduces it.
/// Keeping it to these two — rather than a running balance column per row — is
/// what lets `recalculate*` rebuild a party's balance from a `SUM` of signed
/// deltas and be provably consistent with the incremental updates.
enum TransactionKind { debtAdded, paymentReceived }

/// `credit_transactions` — the receivable/payable ledger (Module 6).
///
/// This is the table Phase 4's doc comment kept pointing at. Before it, a
/// customer's `current_debt` was the *only* record of what they owed: an interim
/// cash payment reduced the number and left no trace, so `recalculateCustomerDebt`
/// could not rebuild the true figure and had to skip payments entirely (see
/// `docs/PHASE4_SALES.md`). With a ledger, `current_debt`/`current_payable` become
/// a genuine materialisation of `SUM(debt_added) - SUM(payment_received)` — both
/// the incremental update and the repair oracle now read the same rows.
///
/// [partyId] has no FK on purpose: a customer and a supplier share the id space,
/// so [partyType] disambiguates it, and neither party can be hard-deleted while
/// their ledger must survive. Likewise [linkedSaleId]/[linkedPurchaseId] are bare
/// ints, matching `sale_batch_allocations.batch_id`: history must not delete
/// itself when the source document is edited or written off later.
@TableIndex(name: 'idx_credit_txn_party', columns: {#partyType, #partyId})
@TableIndex(name: 'idx_credit_txn_created', columns: {#createdAt})
class CreditTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get partyType => textEnum<PartyType>().named('party_type')();

  /// `customers.id` or `suppliers.id`, read with [partyType].
  IntColumn get partyId => integer().named('party_id')();

  TextColumn get kind => textEnum<TransactionKind>()();

  /// Absolute amount of this movement, in pya. Always positive; the sign is the
  /// [kind]'s job, so a sum reads as `debt_added - payment_received`, not a mix
  /// of signed values that a stray edit could flip.
  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount > 0)')();

  TextColumn get note => text().withLength(max: 240).nullable()();

  /// The voucher that opened this debt (`debt_added` on a credit sale).
  IntColumn get linkedSaleId => integer().named('linked_sale_id').nullable()();

  /// The invoice that opened this payable (`debt_added` on a credit purchase).
  IntColumn get linkedPurchaseId =>
      integer().named('linked_purchase_id').nullable()();

  /// Who recorded it, for a disputed payment. Nullable: a migration backfill
  /// attributes historic rows to no one rather than inventing a clerk.
  IntColumn get recordedByUserId =>
      integer().named('recorded_by_user_id').nullable()();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  String get tableName => 'credit_transactions';
}
