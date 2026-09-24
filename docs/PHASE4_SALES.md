# Phase 4 — Sales, FEFO Deduction and Vouchers

Builds on Phase 3's stock model without changing it. This document records the
four new tables, the FEFO rule that Phase 3 left open, what one completed sale
actually writes, and the two hardware decisions — printing and scanning — that
this phase deliberately deferred rather than faked.

---

## 1. Scope

The brief for this phase:

| Requirement | Where it lives |
|---|---|
| Cart with unit switching, Subtotal / Discount / Total | `features/sales/application/cart_controller.dart` |
| Prices follow the unit chosen (from `unit_conversions`) | `CartController.switchUnit` / `setMode` |
| FEFO deduction, progressive across batches | `fefo_allocator.dart` + `SaleRepository.completeSale` |
| POS screen: search/scan bar, product grid, cart, Retail/Wholesale | `presentation/pos_screen.dart` |
| Checkout: received amount, Cash/KPay, change | `presentation/checkout_bottom_sheet.dart` |
| Voucher with No, Date, Items, Total, Cashier | `data/printer_service.dart` |

Returns and stock write-offs are Phase 5. The receivables *ledger* — payment
history, ageing, statements — is Phase 6/7; Phase 4 only records enough to charge
a sale to a customer and refuse one that would breach their limit.

Phase numbers are the roadmap in `README.md`, one ahead of the spec's own
numbering from Phase 2 onward.

---

## 2. The FEFO rule Phase 3 left open

Phase 3 shipped the *ordering* — `batchesFor` returns live batches soonest-expiry
first. The `README.md` checklist asked which deduction policy the till would use:
strict FEFO, or FEFO-with-override. This phase decides **strict**, with no
till-level override in any role.

A pharmacy sells the earliest-expiring batch because the later one is the one that
will still be on the shelf in six months. The cost is that the rule can be
inconvenient when the clerk already knows the near-expiry batch is damaged or held
— and the answer to that is Phase 5's write-off, which removes the bad stock with
a recorded reason, rather than a till override that silently sells around a batch
nobody logged as bad. An override that only the manager can use turns FEFO from a
guarantee into a suggestion, and "which customers got tablets from batch X117"
stops being a query. There is no override field to audit because there is no
override.

The allocator (`fefo_allocator.dart`) is pure Dart with no drift import: it takes
a list of `FefoBatch{available, costPya, expiryDate}` and a requested quantity and
returns the (batch, quantity) splits. It checks the total *before* consuming
anything and throws `FefoShortageException` naming requested vs available, so the
repository never writes a header it has to roll back for arithmetic that was
knowable up front.

```
allocateFefo(qty 13, batches [6 @2/3, 5 @2/10, 9 @2/20])
  → 6 from the 2-Mar batch, 5 from the 10-Mar, 2 from the 20-Mar
  → blended unit cost = round_half_up(570 / 13) = 44 pya
```

Two lines of the **same medicine** are deduplicated before allocation: the
repository tracks each batch's remaining quantity in memory across lines, so a
second Box of the same product cannot re-take stock a Strip line already consumed
in the same voucher.

---

## 3. Money and cost — what "unit_cost" means on a sale line

Money is still integer `Pya` (1/100 kyat); nothing new there. The genuinely new
figure is `sale_items.unit_cost`, and it is **per smallest unit**, not per sold
unit, so it stays comparable with `medicine_batches.cost_price` and with any other
unit the same medicine sells in.

Because one line can draw on several batches at several costs, a single line's
cost is a weighted average of what it actually consumed, rounded **half-up**
(`(total_cost*2 + qty) ~/ (2*qty)`) — the same rule `blendUnitCost` uses in
Phase 3's stock merge. The authoritative, un-rounded figures live one level down
in `sale_batch_allocations`, where each row carries that batch's exact
`unit_cost` and quantity. The line's blend is a convenience for display; the
allocations are the truth the Phase 7 profit report recomputes from.

`sales.total_cost` is deliberately *restated* inside the same transaction once
every allocation is known, so it is the sum of real batch costs rather than a
figure guessed before the batches were opened.

---

## 4. What one completed sale writes

`completeSale` is one transaction and there is no smaller public unit of work:

```
sales (1)  ──►  sale_items (N)  ──►  sale_batch_allocations (per line, per batch)
    │                                        │
    │                                        └──► medicine_batches.qty -= taken
    ├──► user_id  (the cashier; required, a voucher must trace to a person)
    └──► customers.current_debt += credit  (only when is_credit)
```

Validation happens in two layers on purpose:

- **Arithmetic the UI already knew** — empty cart, negative or over-subtotal
  discount, negative received — is rejected *before* the database is touched,
  because those are input mistakes and the message should name the field.
- **Stock** — a line that can't be filled from live batches — is caught inside
  the transaction and re-thrown as `SaleShortageException` with the product's
  trade name, so the cashier sees "Paracetamol: only 4 Strips left", not a bare
  count. Because it throws inside the transaction, the header insert and any
  earlier lines roll back with it; a partially-applied voucher cannot exist.

**Credit is derived, never trusted from the UI**: `is_credit == (received <
total)`, exactly like `purchases.is_credit`. The credit limit is enforced against
`current_debt` *as it stands inside the transaction*, so two overlapping credit
sales cannot both pass a check made against a stale figure. An unpaid balance with
no customer is refused, and a **partial KPay payment is refused outright** — a
wallet transfer is settled or it isn't; a half-paid KPay voucher is a credit sale
wearing a payment method's clothes and would hide a debtor behind a "paid" flag.

`recalculateCustomerDebt` is the repair oracle for the denormalised
`current_debt`, mirroring `recalculatePayable`. Its one known limitation: it
rebuilds debt from credit sales minus what those vouchers paid, and does **not**
subtract interim cash payments recorded separately — because there is no payments
table yet (that is Phase 6). It is correct for a database that has never taken an
interim payment; the moment Phase 6 exists it must be extended to see them. This
is documented at the method, not hidden.

---

## 5. Four tables, and the two schema traps that recurred

`customers`, `sales`, `sale_items`, `sale_batch_allocations`. The design notes are
in each file's doc comment; three decisions are worth restating:

- **`sale_items.unit_conversion_id` is a real FK, not a bare `unit_name`.** A
  name copied at sale time goes stale the moment a price is edited. The integer FK
  plus a denormalised `unit_name` keeps both the join for reports and the readable
  string for reprinting a 58 mm voucher.
- **No `batch_id` on `sale_items`.** The FEFO rule means one line drains several
  batches; that split *is* `sale_batch_allocations`. The same table answers the
  recall question a pharmacy actually gets asked.
- **`sale_batch_allocations.batch_id` has no FK** — the batch must survive the
  sale and the sale must survive the batch reaching zero; a dangling id a repair
  pass can read is better than history that deletes itself.

The migration (`v2 → 3`, `_createPhase4Tables`) hit both Phase 3 traps again,
unchanged: `customConstraint` replaces drift's `NOT NULL`/`DEFAULT` rather than
adding to them (so `customers.credit_limit`, `.current_debt` and `sales.discount`
etc. spell the full constraint), and `Migrator.createTable` does not emit
`@TableIndex` entities — so the seven Phase-4 indexes are created with explicit
`m.createIndex(...)` calls. `migration_v2_to_v3_test.dart` builds a hand-written
**v2 (eight-table)** fixture and asserts the upgrade yields the current schema's
exact table set, all seven indexes, that `user_version` is stamped, that a real
FEFO sale runs on the upgraded file, and that the `payment_type` CHECK and
`voucher_no` UNIQUE actually bite *on the migrated database* — none of which a
fresh install exercises.

---

## 6. Cart state and the unit switch

`CartController` is a plain `Notifier<CartState>` with no database access — the
checkout dialog feeds it prices resolved from real `unit_conversions` rows and it
only ever stores what it is given. That separation is why the cart is testable
with a `ProviderContainer` and no mock repository.

Unit switching (`switchUnit`) resets the line's quantity to 1 on purpose: 5
tablets are not 5 strips, and carrying the number across would silently change
what the customer is buying and what leaves the shelf. If a unit the cart already
has is chosen, the two lines fold together rather than duplicating. `setMode`
(Retail/Wholesale) re-prices every line from the per-unit prices the line already
carries; a unit with no wholesale price keeps its retail price rather than falling
to zero.

The catalog is loaded once by `posCatalogProvider` (`catalogWithUnits`, a single
one-pass query joining the hierarchies), and search filtering happens in Dart over
that cached list so the POS search box does not hit SQLite on every keystroke.

---

## 7. Printing and scanning — what was deferred, honestly

The brief offered `blue_thermal_printer` **or** `pdf`, and a "Bluetooth scanner".

**Printing.** `blue_thermal_printer`'s current release caps its Dart SDK at
`<3.0.0`, so it cannot compile into this build, and it needs a paired ESC/POS
device — nothing CI can exercise. Phase 4 ships `PrinterService`, which renders a
completed sale to a **PDF** (`pdf` package): one renderer covering print-to-any-
printer and digital share, and — the part that matters here — its bytes are
assertable in a unit test (`printer_service_test.dart` checks the `%PDF` magic
header, the file name, and that `buildLines` joins ids to names without touching
money). The service never recomputes a total; every figure comes off
`SaleReceipt`, so a voucher cannot print a number that disagrees with the
database. **ESC/POS transport for an actual 58 mm roll is deferred to the
on-device pass**; it is the right transport, and wiring it against no printer
would be a fake.

**Scanning.** A USB/Bluetooth barcode gun is a HID keyboard — it types the code
and presses Enter. The POS search field's submit handler already tries an exact
barcode match first, so "scan to add" works today with no dependency and no camera
permission. The `mobile_scanner` *camera* path is what is deferred: it adds a
permission a till otherwise does not need, and its real behaviour is only
judgeable on a device.

One known rendering limitation, not blocking: the `pdf` default fonts (Helvetica)
have no Unicode support, so a Burmese product or shop name prints as garbage. The
fix — bundle a Unicode TTF and pass it to `pw.ThemeData` — belongs with the
on-device printing pass, where the actual printer, roll width and font can be
decided together.

---

## 8. Deliberate omissions

- **No returns / refunds.** Phase 5. The allocation table is exactly what makes
  them possible later — a return restocks the same batches the sale took — so the
  data is ready even though no screen uses it yet.
- **No per-staff or daily-close reports.** `sales.user_id` and the `created_at`
  index exist so Phase 7 can group by them; the report itself is Phase 7's.
- **No cross-device voucher uniqueness.** `S-YYYYMMDD-0001` is unique per till
  (one connection, one sale at a time, so its day-sequence can't race itself);
  device-namespacing the prefix is a Phase 8 merge concern.
- **No `intl` dependency yet.** Dates render via a local formatter. Locale-aware
  formatting arrives with the printed-voucher pass.

---

## 9. Tests added

| File | Covers |
|---|---|
| `test/features/sales/application/fefo_allocator_test.dart` | single/cross-batch fills, exact depletion, three-way splits, empty-batch skip, half-up blend, shortage names requested vs available, `qty<=0` rejection |
| `test/features/sales/application/cart_controller_test.dart` | default + preferred unit, repeat-add merge, unit switch re-prices and resets qty, fold-into-duplicate, wholesale pricing and retail fallback, subtotal/discount/clamp/floor, quantity-0 removes, clear |
| `test/features/sales/data/sale_repository_test.dart` | FEFO single/cross-batch, `total_cost`, two lines no double-take, pya totals, change, wholesale, credit within/over limit (rollback), unpaid-no-customer, empty cart, over-discount, shortage, customer dedupe/payment guards, voucher uniqueness + increment, recall trail, debt oracle |
| `test/features/sales/data/printer_service_test.dart` | real `%PDF` bytes + file name for a completed sale, `buildLines` id→name join without recomputing money |
| `test/core/database/migration_v2_to_v3_test.dart` | 2→3 upgrade on a hand-written v2 fixture: exact table set, all 7 indexes, `user_version`, preserved licence/credentials/stock, `payment_type` CHECK and `voucher_no` UNIQUE bite on the migrated file, a real FEFO sale runs post-upgrade |
| `test/routing/route_guard_test.dart` (extended) | `/pos` in the permission map and reachable by both roles; states that `pos` cannot be proven *denied* with a real role because both roles legitimately hold it |
