# Pharmacy POS

Offline-first mobile pharmacy management system (retail & wholesale) for Android
and iOS. Flutter · Riverpod · drift (SQLite).

**Current status: Phase 5 — credit ledgers, expenses, daily reports and encrypted
backups.** Two more tables (`credit_transactions`, `expenses`) on top of Phase 4's
twelve, and schema 3 → 4 — the first migration that *rewrites* data, backfilling
the ledger from the balances a Phase 4 device already carries. Payments are now
rows, not silent subtractions, so `current_debt` / `current_payable` are a genuine
`SUM(debt_added) − SUM(payment_received)` and Phase 4's repair-oracle blind spot is
gone. Expenses make a real net profit (sales − COGS − expenses) computable; one
Admin-only dashboard reports today's trading with low-stock and 60-day-expiry
alerts; and the database exports and restores as a passphrase-encrypted,
versioned `.pbak` file (AES-256-GCM over PBKDF2). Google Drive upload is deferred
— the encrypted file is the transport-neutral artifact a Drive adapter wraps
later. Phases 1–4 delivered the foundation, signed licences, inventory and
purchasing, and sales/POS. Returns and stock write-offs land in Phase 6.

---

## Phase plan

| Phase | Modules | Status |
|---|---|---|
| 1 | Architecture, Drift setup, `users` + `license_config`, RBAC, boot flow | `main` |
| 2 | Signed licences: JWT verification, vendor key generator, expiry enforcement | `feature/phase-2-license-jwt` |
| 3 | Inventory, multi-unit stock, batches and expiry alerts + stock-in, suppliers and payables (the spec's Modules 3 and 4) | `feature/phase-3-inventory-purchases` |
| 4 | Sales & POS: FEFO deduction, search/scan, retail/wholesale, voucher printing (the spec's Module 5) | `feature/phase-4-sales-pos` |
| 5 | Credit ledger (receivables & payables), expenses, daily reports, encrypted database backup (the spec's Modules 6 and 7) | this branch |
| 6 onward | Returns and stock adjustments (write-offs, transfers), ageing reports, Drive backup adapter | planned |

The spec's Phase 2 brief (repositories, state management, boot flow, router
redirects, activation and login screens) was already implemented in Phase 1, so
that phase delivered only what was genuinely new — the licence signing scheme and
tooling. That renumbered the remaining roadmap by one. Purchases came forward
into Phase 3 because stock cannot be created without a delivery: the batch table
and the multi-unit rule are only testable end to end once something writes them.

See [`docs/PHASE5_CREDIT_REPORTS_BACKUP.md`](docs/PHASE5_CREDIT_REPORTS_BACKUP.md)
for the ledger rule, the backfill, the backup envelope and the Drive deferral,
[`docs/PHASE4_SALES.md`](docs/PHASE4_SALES.md) for the FEFO rule, the sale
transaction and the printing/scanning deferrals,
[`docs/PHASE3_INVENTORY.md`](docs/PHASE3_INVENTORY.md) for the unit and money
rules and the migration lessons, [`docs/PHASE2_LICENSE.md`](docs/PHASE2_LICENSE.md)
for the key format and its limits, and
[`docs/PHASE1_ARCHITECTURE.md`](docs/PHASE1_ARCHITECTURE.md) for the architecture
decision record.

---

## Setup

```bash
flutter pub get
dart run build_runner build          # regenerates app_database.g.dart after any table change
flutter analyze
flutter test
flutter run
```

`build_runner` must be re-run after editing anything under
`lib/core/database/tables/` — the generated `app_database.g.dart` is committed so
a fresh clone builds without a codegen step.

---

## Boot flow

```
main()
  └─ BootGate: load licence, restore session
       ├─ license_config empty ................. ActivationKeyScreen
       │    └─ valid key ....................... SetupAdminScreen (first run) → LoginScreen
       ├─ stored key fails signature / expired . ActivationKeyScreen (re-enter key)
       ├─ licensed, no session ................. LoginScreen
       └─ licensed, session restored ........... DashboardScreen
```

Routes are guarded in one place (`appGuard` in `lib/main.dart`), driven by a
`ChangeNotifier` that bridges the licence and auth providers into GoRouter's
`refreshListenable`. Both gates fail closed: an unknown licence state holds on the
splash, and an absent session denies every permission.

Phase 3 added a third layer: `kRoutePermissions` maps each feature route to the
permission it requires, so a typed or bookmarked URL is denied by the same rule
that hides the dashboard's button. `appGuard` is a pure function of (licence
state, session, location) so that map is testable without a widget tree.

On a fresh install the first Admin is created through `SetupAdminScreen` rather
than seeded with a default PIN — see the ADR for why.

---

## Licence keys

The vendor tool is dependency-free Python:

```bash
python3 tools/license_generator.py \
  --client "Hein Pharmacy, Yangon" \
  --exp 2027-01-01 \
  --features '{"retail": true, "wholesale": true, "cloud_backup": false}'
```

It prints a JWT to paste into the activation screen. `--verify` checks a key a
customer is holding, `--self-test` proves the signing paths. Before issuing real
keys, set the secret on both sides:

```bash
export PHARMACY_LICENSE_SECRET='<your secret>'
flutter build apk --release --dart-define=PHARMACY_LICENSE_SECRET="$PHARMACY_LICENSE_SECRET"
```

`docs/PHASE2_LICENSE.md` explains the format and, importantly, what this scheme
does *not* protect against.

---

## Layout

```
lib/
  core/        database, rbac, secure storage, shared primitives
  features/    one folder per module: data / application / presentation
  routing/     route path constants and the route→permission map
```

Features never import another feature's `presentation/`; cross-feature calls go
through the owning feature's `application/` providers. Pure business rules (`key_codec.dart`, `jwt_decoder.dart`, `password_service.dart`)
stay free of Flutter imports so they are testable without a widget tree.
`unit_hierarchy.dart` and `money.dart` follow the same rule.

Phase 3 added `features/inventory/` and `features/purchases/`. Two pieces are
pure Dart with no drift or Flutter imports, because they decide what a customer
actually receives: `unit_hierarchy.dart` (the packaging arithmetic and the
smallest-unit rule) and `money.dart` (integer pya). Phase 4 added
`features/sales/`, whose FEFO allocator and cart controller follow the same rule —
`fefo_allocator.dart` and `cart_controller.dart` are pure Dart and carry every
decision about which batch a sale drains and what a line costs, so both are
testable without a database or a widget tree.

---

## Testing

```bash
flutter test                    # 361 cases
flutter test --coverage         # lcov.info for CI
python3 tools/license_generator.py --self-test   # 7 cases
```

Coverage is concentrated where the risk is:

- `test/features/license/application/jwt_decoder_test.dart` — signature and
  `alg`-confusion rejection, expiry against an injected clock, and
  **cross-language vectors**: keys produced by the Python tool are verified in
  Dart, and Dart issuance is asserted byte-identical to Python's.
- `test/features/auth/application/pbkdf2_vectors_test.dart` — the hand-written
  PBKDF2 loop is checked against `hashlib` reference vectors, not merely
  round-tripped against itself.
- `test/core/database/app_database_test.dart` — singleton `CHECK`, unique
  username, enum storage, and that the `foreign_keys` pragma is actually applied
  per connection.
- `test/boot_flow_test.dart` — the real router and screens driven end to end
  against an in-memory database and an in-memory key-value store, including the
  expired-after-restart and edited-`features_data` paths.
- `test/features/auth/data/user_repository_test.dart` — coarse auth outcomes,
  soft delete, last-admin guard, RBAC map.
- `test/core/database/migration_v1_to_v2_test.dart` — the schema 1 → 2 upgrade,
  built on a hand-written Phase 1 fixture rather than the current drift model.
  This is where the `customConstraint`-eats-`DEFAULT` and missing-`createIndex`
  bugs were caught; a fresh install passes both.
- `test/features/inventory/` — money parsing, the unit hierarchy, and stock
  computed from batches. Includes a test asserting `medicines` has *no* stock
  column, so the cache cannot be added back by accident.
- `test/features/purchases/data/purchase_repository_test.dart` — stock-in
  creating batches, unit conversion at the boundary, repeated-batch merge with a
  blended cost, and the cached payable agreeing with `recalculatePayable`.
- `test/features/sales/` — the FEFO allocator (single/cross-batch fills, blended
  half-up cost, shortage naming the numbers), the cart (unit switching resets
  quantity, retail/wholesale re-pricing, discount clamp), and `SaleRepository`
  running a real sale against an in-memory database: batch deduction, the credit-
  limit rollback, voucher uniqueness and the recall audit trail.
- `test/core/database/migration_v2_to_v3_test.dart` — the schema 2 → 3 upgrade on
  a hand-written Phase 3 (v2) fixture, asserting the four sales tables, all seven
  new indexes, and that the `payment_type` CHECK and `voucher_no` UNIQUE bite on
  the *migrated* file, which a fresh install never proves.
- `test/features/credit/` — the ledger service (positivity, party-type isolation,
  signed per-party sums) and `CreditRepository` against a real credit sale:
  payments posting in step with the cached column, a statement's running balance,
  and `reversePayment` refusing anything that isn't a payment.
- `test/core/database/migration_v3_to_v4_test.dart` — the schema 3 → 4 upgrade on
  a hand-written Phase 4 fixture *with live debts*: the ledger backfill must
  reproduce every cached balance exactly, keep each document's own date, and a
  re-open must not repeat it. The first migration that rewrites data.
- `test/features/expenses/` and `test/features/reports/` — half-open period
  queries, category totals, and a hand-built trading day's full
  sales − COGS − expenses arithmetic with the low-stock and expiry alert sets.
- `test/features/backup/data/backup_service_test.dart` — envelope round-trip,
  wrong passphrase **and** a single flipped byte both rejected by the GCM tag,
  foreign/truncated files rejected on the header, and `restoreIntoPlace` driven
  against real on-disk files: live rows (including a WAL-resident one) replaced
  and the reopened connection reading the restored data.
- `test/routing/route_guard_test.dart` — the route permission map, and the real
  router pushed to a protected route by both roles. Phase 5's admin-only routes
  made the *denial* half provable for the first time: `/pos` is legitimately held
  by both roles, so before Phase 5 no route could demonstrate a cashier being
  refused.

`AppDatabase.forTesting(NativeDatabase.memory())` and `MemoryKeyValueStore` are
the seams; neither requires platform channels, so the whole suite runs headless.

---

## Known gaps carried forward

Deliberate decisions, not oversights — each is recorded in the ADR:

- **No encryption at rest.** Cost prices and customer debt sit in a plain SQLite
  file. SQLCipher needs iOS podspec and Android ABI work; deferred to Phase 8.
  `flutter_secure_storage` covers the licence key and session only. (Phase 5's
  backup is encrypted, but the *live* database file is still plaintext.)
- **Licence keys are HMAC-signed, so the app can mint them.** The verifying and
  signing secret are the same value, compiled into the APK. This stops a customer
  editing `features_data` in a SQLite editor; it does not stop someone who dumps
  the binary. Ed25519 is the fix and `FeatureDecoder` exists so it is a one-line
  swap — see `docs/PHASE2_LICENSE.md`.
- **No licence revocation.** An offline device with a valid key keeps working.
  Mitigated by issuing a short `exp` and the dashboard countdown, not by code.
- **Device clock rollback extends an expiring licence.** Needs a persisted
  high-water boot time, which interacts with Phase 8 backup restore — deliberately
  unbuilt until that contract exists.
- **`PIN or password` accepts short values.** The store rejects nothing below the
  username minimum; enforcing a 6-character floor is `SetupAdminScreen`'s rule,
  and a raw 4-digit PIN remains weak against a copied database even at 120k
  PBKDF2 rounds.
- **ESC/POS transport and camera scanning are absent.** Phase 4 renders a voucher
  to PDF and reads a hardware (HID) barcode scanner through the search box, both
  of which work offline with no new permission. Printing that PDF to an actual
  thermal roll (ESC/POS, and a Unicode font for Burmese names) and the
  `mobile_scanner` camera path are deferred to the on-device pass.
- **Backup is an encrypted file, not a Drive upload.** Phase 5 ships the whole
  pipeline — `VACUUM INTO` snapshot, PBKDF2 + AES-256-GCM envelope, in-app
  restore — writing `.pbak` files to the app's documents directory. The Drive
  adapter is deferred deliberately: offline CI cannot exercise OAuth, and the
  file is the transport-neutral artifact (`BackupArtifact.bytes` +
  `suggestedFileName`) an upload layer wraps without touching the format.
- **A restore can roll the device clock backwards** relative to the data (an old
  backup restored over new work), which interacts with the clock-rollback gap
  above. No warning is shown beyond the manifest's creation date on the confirm
  dialog; a proper "this file is older than your newest local backup" guard
  belongs with the Drive adapter.

---

## Release checklist before Phase 6

- [ ] Generate a real `PHARMACY_LICENSE_SECRET` and stop shipping the committed
      placeholder; the dashboard warns in debug builds until this is done.
- [ ] Decide the renewal UX — re-entering a key on an activated device currently
      resets `activated_at`. Carried unresolved from Phase 2.
- [x] FEFO deduction rule — decided in Phase 4 as **strict**, no till override in
      any role; bad stock is removed with a Phase 6 write-off instead.
- [x] Scanner input approach — decided in Phase 4: HID/USB barcode guns are
      keyboards handled by the POS search field's submit path; the `mobile_scanner`
      camera path is deferred to the on-device pass.
- [x] Backup-restore contract — decided in Phase 5: a self-describing versioned
      envelope (magic `"PPBK"`, an envelope format version byte that is *rejected*
      on restore when unknown, plus a manifest carrying `schema_version` and the
      creation instant shown on the confirm dialog). Schema-level compatibility —
      restoring a *future* schema, or a Phase 1 database onto current code — is
      still the open migration-direction question for Phase 8.
- [ ] Wire the on-device printing pass: ESC/POS transport to the 58/80 mm roll plus
      a bundled Unicode font so Burmese shop and product names render. Confirm the
      printer models in the field before choosing the transport library.
- [ ] Build the Drive adapter on top of `BackupArtifact`, with a "newer local data
      than this file" warning on restore.
