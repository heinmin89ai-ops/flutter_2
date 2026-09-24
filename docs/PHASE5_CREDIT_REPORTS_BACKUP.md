# Phase 5 — Credit Ledgers, Expenses, Daily Reports and Encrypted Backups

Closes the loop Phase 4 left open. The receivable/payable *ledger* that
`docs/PHASE4_SALES.md` kept pointing at now exists, so a payment is a row rather
than a silent subtraction; expenses make a real net profit computable; one
Admin-only screen reports the trading day; and the database can be exported and
restored as an encrypted file. Schema 3 → 4 is the third real migration, and the
first one that *rewrites* data (the ledger backfill), not just tables.

---

## 1. Scope

The brief for this phase:

| Requirement | Where it lives |
|---|---|
| Customer receivables and supplier payables screens, with statements | `features/credit/` (`PartyCreditScreen`, shared by both directions) |
| Payments posted into a real ledger | `LedgerService` + `recordCustomerPayment` / `recordSupplierPayment` |
| Daily expenses with categories | `features/expenses/` |
| Reporting dashboard: today's sales, net profit, low stock, expiring soon | `features/reports/` |
| Database backup: encrypted, versioned, restorable | `features/backup/data/backup_service.dart` |

Returns and stock write-offs were pulled forward from "Phase 5 onward" only as
far as the ledger makes them expressible — a payment reversal exists
(`reversePayment`), a goods return does not, and that stays deliberate (§8).

---

## 2. The ledger, and why the cached columns changed meaning

Phase 4 stored debt twice-ish: `customers.current_debt` was the number, credit
sales added to it, and an interim cash payment subtracted from it **leaving no
row**. That is why Phase 4's `recalculateCustomerDebt` oracle had a documented
blind spot — it could rebuild from vouchers but could never know about the
payments, so the "repair" would silently inflate every debt the customer had
partially paid down.

Phase 5 makes the ledger authoritative:

```
credit_transactions
  kind = debt_added        (linked to the sale/voucher or purchase that opened it)
  kind = payment_received  (what the party paid, positive)

current_debt / current_payable  =  SUM(debt_added) − SUM(payment_received)
```

`current_debt` is now a *materialised sum*, nothing more. Both paths agree by
construction: `LedgerService` is the single writer, `SaleRepository`/
`PurchaseRepository` post the ledger row and rewrite the cached column **in the
same transaction**, and `recalculate*` rebuilds the column from the ledger —
which now contains the payments too. The Phase 4 blind spot is gone, and
`migration_v3_to_v4_test.dart` pins that the rebuild reproduces every migrated
balance exactly.

Design decisions worth their weight:

- **Amounts are always positive; the sign is the `kind`'s job.** A sum reads as
  `debt_added − payment_received`, and a stray edit cannot flip a signed value
  mid-ledger. Enforced by `CHECK (amount > 0)`.
- **No FK on `party_id`, bare ints on the link columns.** Customer and supplier
  share the id space (`party_type` disambiguates), and — same rule as
  `sale_batch_allocations.batch_id` — history must not delete itself when the
  source document is edited or the party removed later.
- **`textEnum` stores plain TEXT with no SQL CHECK** — drift validates enums on
  the read path. The migration test asserts the *only* real DB-level constraint
  (`amount > 0`) bites on a migrated file, rather than pretending the enum does.

A customer's statement is a running balance over `entriesFor` (oldest first), so
each row shows what the balance became, not just what moved.

---

## 3. What the migration had to invent: the ledger backfill

The upgrade (schema 3 → 4) cannot just create two tables — Phase 4 devices carry
cached columns whose history is partly unrecorded. `_backfillCreditLedger`
reconciles them:

1. One `debt_added` per unpaid remainder of each credit sale / credit purchase,
   linked to its document and stamped to the **document's own date** (so an
   ageing report on an upgraded device is not silently restated to "today").
2. Where the cached column now sits *below* the sum of those posted debts, one
   balancing `payment_received` covering the difference — that shortfall *is*
   the interim cash payment Phase 4 recorded without a row. The note says so
   explicitly, so a statement showing it reads as a reconciliation entry, not a
   bug.
3. After this, ledger sum == cached column for every party, verified row-for-row
   in the test, including a settled purchase and a walk-in cash customer that
   must have no rows at all.

The trap this design walks around: a naive backfill (copy the column, invent one
debt row of that size) would make every *future* payment reverse an entry that
never existed, and the oracle would fight the incremental writes. Reconciling to
the column instead keeps all three paths — backfill, incremental, rebuild — on
the same arithmetic forever. Re-opening an already-migrated file must not repeat
the backfill (also pinned).

---

## 4. Expenses

`expenses` is deliberately small: category (free text from an autocomplete of
recent categories, not a table — a pharmacy's cost buckets are its own), positive
`CHECK (amount > 0)`, `created_at`, note. It exists because net profit is not
computable without it:

```
net profit = sales − COGS − expenses
```

COGS comes from Phase 4's `sale_batch_allocations` (real batch costs, no guesses);
sales from `sales`; expenses from this table. `totalInPeriod` uses a half-open
`[from, to)` day range so a "today" report never double-counts midnight.
`totalsByCategory` powers the breakdown tile. Deleting an expense is gated on the
same `deleteTransaction` permission as reversing a payment — both edit money
history.

---

## 5. The reports dashboard (Admin only)

One screen, one provider (`dailyReportProvider`), built for the way a shop owner
actually reads a day: a stat band (today's total sales, net profit), a profit
breakdown (sales − COGS − expenses, with the credit slices `receivable`/`payable
shown beside it), then the two alerts that need action — low stock (on-hand at
or below each medicine's `low_stock_threshold`) and expiring within
`kExpiringWindowDays` (60). Refresh bumps `inventoryRevisionProvider` rather
than holding a timer; a till on a phone should not poll SQLite.

The report test pins the arithmetic with a hand-built trading day — 20,000
sales, 15,000 COGS, 3,000 expenses → 5,000 gross, 2,000 net — and, importantly,
that a sale from *yesterday* is not in today's numbers. The empty-day case
asserts zeros with actual stock behind it, so a "low stock" false alarm on a
fresh install is a test failure, not a support call.

Route-level enforcement is real here for the first time: `/pos` is legitimately
held by both roles, so until now no route could be *proven* denied by a role.
Phase 5's admin-only routes (`/reports`, `/expenses`, `/backup`) close that gap —
the route-guard suite now asserts the owner reaches all five new routes *and*
that a real cashier is bounced from every one, including through the actual
GoRouter widget tree.

---

## 6. Backup: the envelope, and why "cloud" means file export for now

The format is versioned and self-describing — the file name carries a timestamp
and nothing else:

```
"PPBK" | version(1) | salt(16) | iterations(4, BE) | nonce(12) | ciphertext...
ciphertext = AES-256-GCM( ZIP( pharmacy_pos.db , manifest.json ) )
key        = PBKDF2-HMAC-SHA256(passphrase, salt, iterations)
```

Three decisions carry the design:

- **`VACUUM INTO`, not a file copy.** The snapshot is transactionally consistent,
  WAL-free and cannot capture a torn page while the till writes. A raw copy
  would miss the `-wal` sidecar (rows committed but not yet checkpointed).
- **PBKDF2 at 150k rounds, random salt and nonce per backup.** A shop's backup
  passphrase is realistically a short PIN; feeding it raw to AES makes an
  offline brute-force of a stolen file trivial. The per-backup salt means two
  backups of the same database byte-differ, killing both rainbow tables and
  "same content?" fingerprinting. Tests use `kTestIterations` via the
  constructor — the override exists for exactly this.
- **AES-GCM, and a blank passphrase is refused.** There is no unencrypted mode,
  because "export the patient purchase history" is precisely the thing a backup
  feature must make hard. GCM authenticates: a wrong passphrase and a tampered
  file produce the *same* `BackupAuthException` — an attacker learns nothing, and
  a corrupt file can never half-decrypt into a garbage database that SQLite then
  opens partially.

**Restore** (`restoreIntoPlace`) is the dangerous half, so its order is fixed:
write the new bytes to a sibling staging file *and flush it* before anything is
closed; only then close the live connection, rename over the live file (copy-
delete fallback across filesystems), delete stale `-wal`/`-shm` sidecars, and
reopen via a caller-supplied callback. A crash before the rename leaves the old
database intact. The reopen callback goes through Riverpod
(`reopenFactory` → `container.invalidate(appDatabaseProvider)` + read), which
re-runs the provider — disposing the old handle through its own `onDispose` and
building exactly one new one — instead of hand-having a database past the
provider that would leak or double-close it. The screen captures the container
synchronously *before* its first await, because a `WidgetRef` is not usable
across an async gap.

**Google Drive is deliberately deferred.** An offline-first app must not have
its only backup path depend on an OAuth consent the CI (and a pharmacy with no
connectivity, which is the point of the app) cannot exercise; the encrypted
`.pbak` file is the transport-neutral artifact a Drive adapter wraps later. The
service already returns `BackupArtifact(bytes, suggestedFileName)` for exactly
that seam. This mirrors how Phase 4 deferred ESC/POS rather than faking a
printer.

---

## 7. Screens and the shared-party shape

One screen serves both credit directions: `PartyCreditScreen(partyType: ...)`,
because "who owes money" and "record a payment" are the same interaction with the
sign flipped, and two near-copies of that would drift. The ledger's `recorded_by`
comes from the live `authProvider` session — not a provider that could read a
stale user — so a disputed payment names the clerk who actually tapped it.

Reversing a payment exists (`reversePayment`: the *only* delete on the ledger,
refuses anything that isn't a payment, guarded by `deleteTransaction`); reversing
a debt does not, because the honest way to clear a bad debt is a write-off with a
reason, and that belongs with returns in Phase 6.

---

## 8. Deliberate omissions

- **No returns / goods write-offs** — Phase 6, unchanged from Phase 4's plan.
- **No Drive upload** — see §6; the envelope and file artifact are the contract.
- **No auto-backup schedule.** A phone app that silently encrypts the whole
  database with PBKDF2 in the background is a battery incident; this is an
  explicit button, and a reminder policy wants field input on when a shop closes.
- **No ageing buckets** (30/60/90 days) yet — the ledger rows carry the document
  dates that make them a pure query; the screen can come with Phase 6's returns
  reporting.
- **`expense_category` is free text**, not a table. A categories table would
  force a seed list onto every shop; a countable distinct list already falls out
  of `totalsByCategory` for the autocomplete.

---

## 9. Tests added

| File | Covers |
|---|---|
| `test/features/credit/application/ledger_service_test.dart` (9) | postDebt/postPayment positivity, party-type isolation, `balancesByParty` signed sums, entry ordering, note filtering, blank-note→null |
| `test/features/credit/data/credit_repository_test.dart` (12) | credit sale via the real `completeSale` posting one linked `debt_added`, `recordCustomerPayment` ledger+column in step, statement running balance, `reversePayment` (restores balance, refuses debt rows and unknown ids), overpayment and credit-limit refusals |
| `test/features/expenses/data/expense_repository_test.dart` (10) | create validation, half-open period query, category/search filters, `totalsByCategory` ordering, delete |
| `test/features/reports/data/report_repository_test.dart` (3) | a full trading day's sales/COGS/expenses/gross/net/receivable/payable arithmetic, low-stock and 60-day expiry alert sets (FEFO-aware), yesterday-excluded and empty-day zeros |
| `test/features/backup/data/backup_service_test.dart` (12) | envelope round-trip, wrong passphrase and single-flipped-byte → `BackupAuthException`, foreign/truncated file → `BackupFormatException`, blank passphrase → `BackupRejectException`, salt/nonce randomisation with identical plaintext, manifest inspect, and `restoreIntoPlace` on **real on-disk files**: live rows replaced and WAL-held rows dropped, reopen reads the restored data |
| `test/core/database/migration_v3_to_v4_test.dart` (12) | v3→v4 on a hand-written Phase 4 fixture with live debts: exact table/index set, `amount > 0` CHECK bites on the migrated file, **backfill reproduces every cached balance and keeps each document's own date**, balancing-payment notes, oracle rebuild preserves them, a real Phase 5 credit sale lands beside backfilled rows, re-open never repeats the backfill |
| `test/routing/route_guard_test.dart` (extended, 17) | all five Phase 5 routes in `kRoutePermissions`; owner reaches every one; **a cashier is provably denied every one** — the first role-denial proof the route map has had; real-router widget tests for `/reports` both roles |

Suite total: 361 Dart tests (was 299 before Phase 5) plus the 7-case Python
licence self-test.
