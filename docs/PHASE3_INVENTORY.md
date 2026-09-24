# Phase 3 — Inventory and Purchases

Builds on the Phase 1 architecture and the Phase 2 licence work; nothing about
the folder layout, provider style or route guards changes here. This document
records the six new tables, the two rules that decide every quantity in the app,
and the migration that was never tested before now.

---

## 1. Scope

The brief for this phase:

| Requirement | Where it lives |
|---|---|
| Medicine master with multi-unit packaging | `medicines`, `unit_conversions` |
| Batch tracking with expiry | `medicine_batches` |
| "Current total stock (calculated dynamically)" | `InventoryRepository.stockForMedicine` |
| Low-stock and 30/60/90-day expiry alerts | `InventoryRepository.list`, `expiringWithin` |
| Suppliers and payables | `suppliers` |
| Stock-in that automatically creates batches | `PurchaseRepository.recordPurchase` |
| Three screens | `InventoryListScreen`, `AddMedicineScreen`, `AddPurchaseScreen` |

Phase 4 (POS, FEFO deduction at the till, returns) is not here. The FEFO
*ordering* is already what `batchesFor` returns, so Phase 4 consumes rather than
introduces it.

Phase numbers below are the roadmap in `README.md`, which is one ahead of the
original spec's numbering from Phase 2 onward and therefore of some comments in
the Phase 1 ADR.

---

## 2. The two rules this phase is built on

### Stock lives in the smallest unit, always

`medicine_batches.qty_in_smallest_unit` is the only stock quantity in the
database. A "Box" is not a quantity — it is a row in `unit_conversions` saying
that one Box contains N of the smallest unit. Boxes, strips and bottles exist
only at the edges: when a clerk types a number or reads one back.

That single rule is what makes the multi-unit requirement tractable. The
alternative — storing per-unit quantities — needs a reconciliation step every
time a carton is broken open, and a pharmacy breaks cartons open all day. Here,
opening a box is not an event; the stock was already counted in tablets.

The conversion happens in exactly two places, both of which are tested:
`UnitHierarchy.toBase` on the way in, and `UnitHierarchy.decompose` on the way
out. A screen that pre-converted a quantity would double-apply the factor, so
`NewPurchaseLine` deliberately carries the *entered* unit and the factor
separately and lets the repository do the arithmetic.

`UnitHierarchy.from` refuses a unit set with no factor-1 row. That is the state
a shop reaches by configuring only "Box = 100", and every stock figure it
produced would be off by 100× — silently. Failing at construction turns it into
one clear error instead of a hundred wrong reports.

### The batches table *is* the stock figure

`medicines` has no `stock_qty` column and never will. Total stock is
`SUM(qty_in_smallest_unit)` computed on read. The brief's phrase "calculated
dynamically" is exactly this, and it is the only version that cannot drift out
of step with the batch rows the shop is actually looking at.

A cached column would have been faster to query. It would also have been wrong
the first time two writes interleaved, on a till that then sold medicine it did
not have. The pharmacy can absorb a slow list; it cannot absorb a stock figure
that lies. `inventory_repository_test.dart` asserts the column's *absence* by
name, so a later phase cannot add it back by accident.

Cost works the other way round and is cached on purpose: `cost_price` is a real
column, one value per batch, because the same paracetamol genuinely arrives at
different prices and Phase 7's profit needs the cost of the batch actually
consumed. Quantity can be summed without loss; a cost average cannot.

---

## 3. Money

`typedef Pya = int` — an integer count of 1/100 kyat. Nothing in the app stores
currency in a `double`; 0.1 is not representable in binary floating point and
the error surfaces on a printed receipt.

Kyat is the display unit and pya the stored one because cost prices really do
need sub-kyat precision: a 12,050-kyat box of 100 tablets is 120.5 pya a tablet.
Storing kyat as an integer would force a rounding decision on every single
stock-in line. The one place integer division happens is
`PurchaseRepository._unitCostPya`, which rounds **half-up**
(`(cost * 2 + factor) ~/ (2 * factor)`) — plain `~/` would bias every batch cost
downward and quietly inflate reported margin.

Conversion happens at the boundary and nowhere else: `kyatToPya` parses a typed
field, `formatMoney` renders one. `MoneyField` returns `null` for a blank field,
which is not the same as 0 — a blank wholesale price means "this shop does not
run one", a 0 means "give it away".

---

## 4. Purchases: what one stock-in actually writes

`recordPurchase` is one SQLite transaction and there is no smaller public unit of
work. A rejected invoice cannot leave a header row behind, and a saved one cannot
fail to put stock on the shelf.

```
purchases (1)  ──►  purchase_items (N)  ──►  medicine_batches (0..N)
     │                                            ▲
     └── supplier.current_payable += (total − paid)┘
```

Three decisions in there are worth their explanations:

**An invoice line keeps its unit, the batch does not.** `purchase_items`
stores `quantity = 5` and `unit_conversion_id → Box`, because that is what the
paper invoice says and a shop reconciles against paper. `medicine_batches`
stores 500 tablets. Both views are kept, which is what lets a stock-take be
argued about later. `purchase_items` has no `unit_name` column of its own — the
row it points at already has one, and copying it would let the two disagree.

**A repeated batch number merges; a different expiry does not.** Matching is on
(medicine, batch number, expiry day). The same number with another expiry date
is physically different stock and FEFO must be able to choose between them.
Merging re-weights the average cost rather than overwriting it, so stock already
on the shelf keeps its true cost. Matching is case-insensitive, because the
duplicate-line guard rejects `X120` and `x120` on one invoice as the same batch
— a case-*sensitive* merge would then let those two spellings land in two batch
rows with different costs that nobody could ever reconcile.

**`current_payable` is denormalised, and there is a repair path for it.** Every
credit purchase adds `total − paid` and every payment subtracts it, in the same
transaction as the rows that caused it. It is stored rather than summed because
the payable list sorts and filters by debt, and 50,000 purchase rows should not
be aggregated on every screen open. The cost of denormalising is that a bug can
make it lie, so `recalculatePayable()` rebuilds it from `purchases`, and a test
asserts the cached figure and the rebuilt one agree after deliberate corruption.
Overpayment is refused outright: a negative payable means the shop is owed money
by a supplier, which is a different business fact and belongs in Phase 7.

---

## 5. The first real migration

Schema 1 → 2 is the first upgrade this project has had to write, and it exposed
two bugs that only an upgrade can expose — a fresh install passes both.

**`customConstraint` replaces drift's constraints, it does not add to them.**
Writing `.withDefault(const Constant(0)).customConstraint('CHECK (x >= 0)')`
produces a column that is `NOT NULL CHECK (x >= 0)` **with no default**. Every
insert that omits the column then fails. Three columns were affected; the one
that reached the test suite was `suppliers.current_payable`, which threw
`NOT NULL constraint failed` on the *first supplier created through the UI* —
after upgrading from Phase 2. `NOT NULL DEFAULT 0` now has to be spelled inside
the constraint string, and each of the three carries a comment saying so,
because drift's own warning only appears during codegen on the columns it
happens to check.

**`Migrator.createTable()` does not create `@TableIndex` entities.** Indexes are
separate members of `allSchemaEntities` that `createAll()` iterates. A hand-rolled
step that calls `createTable` six times gets six tables and zero indexes — so
every upgraded device would have run the POS medicine search as a full table
walk while every fresh install stayed fast. `_createPhase3Tables` now issues ten
explicit `m.createIndex(...)` calls, and a test asserts they exist after an
upgrade, because nothing else in the app can tell the difference.

The migration test builds its fixture from a hand-written `CREATE TABLE` script
for the Phase 1 schema rather than from the current drift model, then opens it
with `AppDatabase.forTesting` and lets drift's own `onUpgrade` run. That is the
only way to test the upgrade a customer actually experiences: a device whose
schema is the one that shipped, not the one this branch happens to define. It
asserts the licence row and the owner's password hash are byte-identical after
the upgrade — an upgrade that lost either would brick the shop's till.

---

## 6. Route-level RBAC

`kRoutePermissions` in `lib/routing/routes.dart` names the permission each
feature route requires, and the guard in `main.dart` enforces it on every
navigation attempt. The dashboard's buttons are gated by the same map, but that
is the cosmetic half: a hidden button is a courtesy, while a typed or bookmarked
URL is still a request.

Adding the map surfaced a bug in the guard that had been latent since Phase 1:
its last line returned `AppRoutes.home` for *every* signed-in location other than
home, so all three new screens bounced back to the dashboard even when the role
was allowed to open them. Nothing in the existing suite caught it, because
`boot_flow_test.dart` only ever navigates by tapping buttons the app chose to
show. `test/routing/route_guard_test.dart` now drives the real router with an
explicit `push`, which is what a deep link and a bookmark both look like — and
which fails against the pre-fix guard for exactly that reason.

Cashier is granted `viewInventory` and denied `manageInventory` /
`managePurchases`, so a cashier may open the stock list and may not edit the
catalogue or accept a delivery. `viewCostPrice` gates the stock-valuation figure
on the list separately: knowing Paracetamol is running low is a different
permission from knowing what the shop paid for it.

---

## 7. UI state, and two designs that were rejected

**The search box is not a provider argument.** `inventoryListProvider` reads an
`InventoryFilter` from a `Notifier` rather than taking the search string as a
`family` argument. A family keyed on the query would cache one provider — and
one full result list — per keystroke prefix: typing `para` leaves five live
providers holding the whole filtered inventory each.

**The picker does not reuse the list.** `AddPurchaseScreen`'s medicine chooser
reads `catalog()`, a plain ordered `SELECT` on `medicines`. The list screen's
query runs three grouped aggregations over every batch in the shop to compute
stock and expiry; using it to draw a list of names would turn a screen open into
a full stock recount.

**`InventoryRevision`** is a counter notifier bumped after every write. drift can
stream per query, but that means a second API on every repository method for a
purely local concern, on an app with exactly one writer.

---

## 8. Deliberate omissions

- **Batch quantities are read-only after stock-in.** Phase 3's batch sheet shows
  the batches; it does not edit them. Stock correction is Phase 5's write-off and
  transfer module, which has somewhere to record *why*.
- **`recordSupplierPayment`'s `note` is not persisted.** There is no payments
  table in the blueprint and inventing a side table here would fork the payable
  ledger that Phase 7 owns.
- **No stock-value report.** `stockValuePya` is computed and shown on the list;
  the report built on it is Phase 7's.
- **`adjustBatch` leaves cost alone on purpose.** A write-off removes value at the
  recorded cost, which is correct accounting, and found stock has no cost to blend
  against.
- **The `intl` package is not a dependency yet.** Expiry dates are rendered by a
  local `_ymd` helper. A date-format library is worth adding when Phase 6's
  printed voucher needs locale-aware formatting, not before.

---

## 9. Tests added

| File | Covers |
|---|---|
| `test/core/database/migration_v1_to_v2_test.dart` | 1→2 upgrade on a hand-written Phase 1 fixture: tables, indexes, `user_version`, preserved licence and credentials, FK enforcement on the upgraded connection |
| `test/core/money_test.dart` | pya parsing and rendering, grouping tolerance, three-decimal rejection, blank ≠ 0, round-trip |
| `test/features/inventory/application/unit_hierarchy_test.dart` | base-unit enforcement, coarsest-first ordering, `decompose`/`formatStock` incl. pluralisation, wholesale fallback |
| `test/features/inventory/data/inventory_repository_test.dart` | create-with-units, dynamic stock and valuation, search and low-stock filters, expiry windows, threshold tri-state, deactivate guard, batch adjust, cost blending |
| `test/features/purchases/data/purchase_repository_test.dart` | stock-in auto-creating batches, unit conversion at the boundary, repeated-batch merge with blended cost, payable accrual and the `recalculatePayable` oracle, every rejection path |
| `test/routing/route_guard_test.dart` | the guard as a pure function and the real router pushed to a protected route by both roles |
