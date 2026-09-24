import 'package:drift/drift.dart';

import 'customers.dart';
import 'users.dart';

/// How the customer settled a voucher.
///
/// The brief names Cash and KPay; a digital-wallet payment is recorded the same
/// way as cash — the till takes the money, it just arrives through a transfer
/// screen. `change_due` is meaningful only for cash, which is why the enum lives
/// in Dart rather than as a bare TEXT the CHECK cannot enumerate: SQLite CHECKs
/// on text would need the literals duplicated in `customConstraint` anyway.
enum PaymentMethod {
  cash,
  kpay;

  static PaymentMethod parse(Object? raw) =>
      raw?.toString().toLowerCase() == kpay.name ? kpay : cash;
}

/// `sales` — one voucher (Module 5).
///
/// The header row; lines live in `sale_items`, and the stock those lines took is
/// gone from `medicine_batches` by the same transaction (`SaleRepository`'s
/// `completeSale`). Like purchases, the money columns are frozen at save time: a
/// later price edit must not restate what a customer actually paid.
@TableIndex(name: 'idx_sales_created', columns: {#createdAt})
@TableIndex(name: 'idx_sales_customer', columns: {#customerId})
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Human-facing identifier printed on the voucher, e.g. `S-20260924-0007`.
  ///
  /// UNIQUE. Generated inside the insert transaction as a per-day sequence
  /// (`S-<date>-<n>`, `n` = today's count + 1): a till is a single SQLite
  /// connection writing one sale at a time, so that counter cannot race itself.
  /// It is trusted from the database, never typed at the UI — a cashier entering
  /// a voucher number invents duplicates. Cross-device uniqueness is a Phase 8
  /// merge concern (device-namespacing the prefix), out of scope here.
  TextColumn get voucherNo =>
      text().named('voucher_no').unique().withLength(min: 6, max: 32)();

  /// Who the sale is on credit to; `null` for a walk-in cash sale.
  ///
  /// `SET NULL` rather than `CASCADE`: deactivating a customer (hard-deleting is
  /// not offered) must not erase the shop's sales history along with them.
  IntColumn get customerId => integer()
      .named('customer_id')
      .nullable()
      .references(Customers, #id, onDelete: KeyAction.setNull)();

  /// The cashier on the till, for the daily-close and per-staff reports.
  ///
  /// NOT NULL, unlike purchases' entered-by column: a voucher nobody can be
  /// traced to is the one number the owner cannot reconcile at closing time.
  /// Nullable only in the sense of `SET NULL` if the staff account is ever
  /// hard-removed, which no screen does today.
  IntColumn get userId => integer()
      .named('user_id')
      .references(Users, #id, onDelete: KeyAction.setNull)();

  /// retail / wholesale — stored as the enum's `name`.
  TextColumn get saleType =>
      text().named('sale_type').withDefault(const Constant('retail'))();

  /// What the goods cost the shop at the prices of the batches actually
  /// consumed, summed per line at save time. Phase 7's profit report is
  /// `total_amount - total_cost` plus discounts, and only this column makes the
  /// COGS side of that computable at all.
  IntColumn get totalCost => integer()
      .named('total_cost')
      .customConstraint('NOT NULL CHECK (total_cost >= 0)')();

  /// Line totals before the discount, in pya.
  IntColumn get subtotal =>
      integer().customConstraint('NOT NULL CHECK (subtotal >= 0)')();

  /// Amount knocked off, in pya. Never negative, and never more than [subtotal]
  /// — a discount larger than the sale is an error, not a rebate.
  IntColumn get discount =>
      integer().customConstraint('NOT NULL DEFAULT 0 CHECK (discount >= 0)')();

  /// What the customer was asked to pay: `subtotal - discount`, frozen here so
  /// `total_amount` in the blueprint's column list has a single unambiguous
  /// referent on this row.
  IntColumn get totalAmount => integer()
      .named('total_amount')
      .customConstraint('NOT NULL CHECK (total_amount >= 0)')();

  /// Cash or wallet value actually received, in pya.
  IntColumn get paidAmount => integer()
      .named('paid_amount')
      .customConstraint('NOT NULL DEFAULT 0 CHECK (paid_amount >= 0)')();

  /// Change handed back, in pya. Stored so the voucher and the drawer agree
  /// after the fact: `paid - total` when paid in full, `0` on a credit sale.
  IntColumn get changeDue => integer()
      .named('change_due')
      .customConstraint('NOT NULL DEFAULT 0 CHECK (change_due >= 0)')();

  TextColumn get paymentType => text()
      .named('payment_type')
      .withDefault(const Constant('cash'))
      .customConstraint(
        "NOT NULL DEFAULT 'cash' CHECK (payment_type IN ('cash', 'kpay'))",
      )();

  /// Whether any balance went onto the customer's account.
  ///
  /// Derived at save time from the amounts, never trusted from the UI — same
  /// rule as `purchases.is_credit`.
  BoolColumn get isCredit =>
      boolean().named('is_credit').withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
}
