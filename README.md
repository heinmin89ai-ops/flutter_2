# Pharmacy POS

Offline-first mobile pharmacy management system (retail & wholesale) for Android
and iOS. Flutter · Riverpod · drift (SQLite).

**Current status: Phase 3 — inventory and purchases.** Six tables (`medicines`,
`unit_conversions`, `medicine_batches`, `suppliers`, `purchases`,
`purchase_items`), the multi-unit hierarchy, dynamically computed batch stock,
stock-in that creates batches in one transaction, supplier payables, and three
screens. Schema 1 → 2 is this project's first real migration. Phase 1 delivered
the folder structure, Drift setup, RBAC and the boot flow; Phase 2 made the
activation key a signed JWT. POS, vouchers, credit, reporting and backup land in
Phases 4–8.

---

## Phase plan

| Phase | Modules | Status |
|---|---|---|
| 1 | Architecture, Drift setup, `users` + `license_config`, RBAC, boot flow | `main` |
| 2 | Signed licences: JWT verification, vendor key generator, expiry enforcement | `feature/phase-2-license-jwt` |
| 3 | Inventory, multi-unit stock, batches and expiry alerts + stock-in, suppliers and payables (the spec's Modules 3 and 4) | this branch |
| 4 | Sales & POS: FEFO deduction, search/scan, retail/wholesale, returns, voucher printing | awaiting approval of the spec's Phase 4 brief |
| 5 onward | Stock adjustments (write-offs, transfers), expenses, credit, reporting, Drive backup | planned |

The spec's Phase 2 brief (repositories, state management, boot flow, router
redirects, activation and login screens) was already implemented in Phase 1, so
that phase delivered only what was genuinely new — the licence signing scheme and
tooling. That renumbered the remaining roadmap by one. Purchases came forward
into Phase 3 because stock cannot be created without a delivery: the batch table
and the multi-unit rule are only testable end to end once something writes them.

See [`docs/PHASE3_INVENTORY.md`](docs/PHASE3_INVENTORY.md) for the unit and money
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
smallest-unit rule) and `money.dart` (integer pya). The FEFO *allocator* is
Phase 4's; what exists here is the ordering it will consume — `batchesFor`
returns live batches soonest-expiry first.

---

## Testing

```bash
flutter test                    # 243 cases
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
- `test/routing/route_guard_test.dart` — the route permission map, and the real
  router pushed to a protected route by both roles.

`AppDatabase.forTesting(NativeDatabase.memory())` and `MemoryKeyValueStore` are
the seams; neither requires platform channels, so the whole suite runs headless.

---

## Known gaps carried forward

Deliberate decisions, not oversights — each is recorded in the ADR:

- **No encryption at rest.** Cost prices and customer debt sit in a plain SQLite
  file. SQLCipher needs iOS podspec and Android ABI work; deferred to Phase 8.
  `flutter_secure_storage` covers the licence key and session only.
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
- **Thermal printing, barcode scanning and Drive backup are absent.** Hardware-
  dependent, scheduled in Phases 6 and 8.

---

## Release checklist before Phase 4

- [ ] Generate a real `PHARMACY_LICENSE_SECRET` and stop shipping the committed
      placeholder; the dashboard warns in debug builds until this is done.
- [ ] Decide the renewal UX — re-entering a key on an activated device currently
      resets `activated_at`. Carried unresolved from Phase 2.
- [ ] Choose the FEFO deduction rule at the till: strict (never sell a later
      batch while an earlier one has stock) or allowed-with-override, and who may
      override. Batch ordering is already what `batchesFor` returns.
- [ ] Decide the `mobile_scanner` vs. Bluetooth-HID scanner input approach (affects
      POS field focus handling in Phase 5).
- [ ] Confirm 58mm vs 80mm printer models in the field; `blue_thermal_printer`
      connection lifecycle is easier to get right if it is designed in early.
- [ ] Agree the backup-restore contract now: Phase 8 must be able to restore a
      Phase 1 database, so the schema-version field belongs in the backup header
      from the first release.
