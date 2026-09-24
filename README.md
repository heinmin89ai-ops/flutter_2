# Pharmacy POS

Offline-first mobile pharmacy management system (retail & wholesale) for Android
and iOS. Flutter · Riverpod · drift (SQLite).

**Current status: Phase 1 — foundation.** Folder structure, Drift schema for
`users` and `license_config`, RBAC map, PBKDF2 credential hashing, activation-key
boot flow, and the licence → login → home route guard. Inventory, purchasing, POS,
credit, reporting and backup land in Phases 2–7.

---

## Phase plan

| Phase | Modules | Status |
|---|---|---|
| 1 | Architecture, Drift setup, `users` + `license_config`, RBAC, boot flow | this branch |
| 2 | Inventory & stock: medicines, unit hierarchy, batches, FEFO, alerts | planned |
| 3 | Purchases (stock-in) & expenses | planned |
| 4 | Sales & POS: search/scan, unit switching, retail/wholesale, returns | planned |
| 5 | Vouchers: thermal print, PDF, Viber/Telegram share | planned |
| 6 | Credit management & reporting dashboards | planned |
| 7 | Backup & restore to Google Drive | planned |

See [`docs/PHASE1_ARCHITECTURE.md`](docs/PHASE1_ARCHITECTURE.md) for the
architecture decision record.

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
       ├─ stored payload unreadable ............ ActivationKeyScreen (re-enter key)
       ├─ licensed, no session ................. LoginScreen
       └─ licensed, session restored ........... PhaseOneHome
```

Routes are guarded in one place (`_guard` in `lib/main.dart`), driven by a
`ChangeNotifier` that bridges the licence and auth providers into GoRouter's
`refreshListenable`. Both gates fail closed: an unknown licence state holds on the
splash, and an absent session denies every permission.

On a fresh install the first Admin is created through `SetupAdminScreen` rather
than seeded with a default PIN — see the ADR for why.

---

## Layout

```
lib/
  core/        database, rbac, secure storage, shared primitives
  features/    one folder per module: data / application / presentation
  routing/     route path constants
```

Features never import another feature's `presentation/`; cross-feature calls go
through the owning feature's `application/` providers. Pure business rules
(`key_codec.dart`, `password_service.dart`) stay free of Flutter imports so they
are testable without a widget tree.

Phase 2 adds `features/inventory/` with the FEFO allocator, unit hierarchy and
stock formatter as pure Dart, and they are the first things under test there.

---

## Testing

```bash
flutter test                    # 88 cases
flutter test --coverage         # lcov.info for CI
```

Coverage is concentrated where the risk is:

- `test/features/auth/application/pbkdf2_vectors_test.dart` — the hand-written
  PBKDF2 loop is checked against `hashlib` reference vectors, not merely
  round-tripped against itself.
- `test/core/database/app_database_test.dart` — singleton `CHECK`, unique
  username, enum storage, and that the `foreign_keys` pragma is actually applied
  per connection.
- `test/boot_flow_test.dart` — the real router and screens driven end to end
  against an in-memory database and an in-memory key-value store.
- `test/features/auth/data/user_repository_test.dart` — coarse auth outcomes,
  soft delete, last-admin guard, RBAC map.

`AppDatabase.forTesting(NativeDatabase.memory())` and `MemoryKeyValueStore` are
the seams; neither requires platform channels, so the whole suite runs headless.

---

## Known gaps carried forward

Deliberate Phase 1 decisions, not oversights — each is recorded in the ADR:

- **No encryption at rest.** Cost prices and customer debt sit in a plain SQLite
  file. SQLCipher needs iOS podspec and Android ABI work; deferred to Phase 7.
  `flutter_secure_storage` covers the licence key and session only.
- **Activation keys are checksummed, not signed.** A rooted device can forge a
  key with valid framing. The decoder sits behind `FeatureDecoder` so a signed
  implementation can replace it without touching the boot screen.
- **`PIN or password` accepts short values.** The store rejects nothing below the
  username minimum; enforcing a 6-character floor is `SetupAdminScreen`'s rule,
  and a raw 4-digit PIN remains weak against a copied database even at 120k
  PBKDF2 rounds.
- **Thermal printing, barcode scanning and Drive backup are absent.** Hardware-
  dependent, scheduled in Phases 5 and 7.

---

## Release checklist before Phase 2

- [ ] Decide the `mobile_scanner` vs. Bluetooth-HID scanner input approach (affects
      POS field focus handling in Phase 4).
- [ ] Confirm 58mm vs 80mm printer models in the field; `blue_thermal_printer`
      connection lifecycle is easier to get right if it is designed in early.
- [ ] Add CI running `dart format --output=none --set-exit-if-changed`, `flutter
      analyze --fatal-infos`, `flutter test` and a **codegen-drift check**
      (`build_runner build` then `git diff --exit-code`) so a forgotten
      regeneration cannot merge.
- [ ] Agree the backup-restore contract now: Phase 7 must be able to restore a
      Phase 1 database, so the schema-version field belongs in the backup header
      from the first release.
