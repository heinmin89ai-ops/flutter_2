# Phase 1 — Architecture & Foundation

**Project:** Offline-first Mobile Pharmacy Management System (Retail & Wholesale)
**Stack:** Flutter 3.x · Riverpod · drift (SQLite) · flutter_secure_storage
**Phase:** 1 of 7 — Folder structure, Drift setup, `users` + `license_config` entities

---

## 1. Architecture decision

**Chosen: Feature-first (vertical slice) with a thin shared layer.**

Full Clean Architecture (domain / data / presentation × 7 modules) was rejected for
Phase 1 because:

- This is a **single-device, offline-first** app. There is no repository-abstraction
  seam to buy us anything — there is exactly one data source (local SQLite) and no
  DTO/entity duplication to defend against.
- drift already generates the data layer. Adding a hand-written `Repository` +
  `DataSource` + `Entity` triple per table multiplies ~14 tables into ~50 files of
  pass-through code before a single screen exists.
- The team is one developer shipping phases weekly. Locality beats purism: opening
  one folder and finding its screens, providers and queries together is worth more
  than theoretical testability of code that has no I/O boundary to mock.

We keep the two Clean Architecture ideas that *do* pay rent:

1. **Features never import each other's presentation.** Cross-feature calls go
   through the feature's `application/` provider file only. This is what lets us
   swap Riverpod providers for real services in Phase 6 without touching screens.
2. **Pure Dart domain rules live apart from Flutter.** FEFO batch selection,
   multi-unit stock formatting and profit calculation are the three places this app
   will actually have bugs, and they must be testable without a widget tree.

If the project later grows cloud sync (Supabase/Drive) or a second client, the
`data/` layer is the single place that changes — features stay put.

---

## 2. Folder structure

```
lib/
  main.dart                        # bootstrap: Drift init → license check → runApp
  app.dart                         # MaterialApp, router, theme

  core/                            # shared, feature-agnostic
    constants/
      app_colors.dart
      app_strings.dart
      expiry_thresholds.dart       # 30 / 60 / 90 day warning windows
    database/
      app_database.dart            # @DriftDatabase(tables: [...]) + schemaVersion
      app_database.g.dart          # generated
      tables/
        users.dart                 # Phase 1
        license_config.dart        # Phase 1
        medicines.dart             # Phase 2
        unit_conversions.dart      # Phase 2
        medicine_batches.dart      # Phase 2
        customers.dart             # Phase 4
        suppliers.dart             # Phase 3
        purchases.dart             # Phase 3
        purchase_items.dart        # Phase 3
        sales.dart                 # Phase 4
        sale_items.dart            # Phase 4
        credit_transactions.dart   # Phase 6
        expenses.dart              # Phase 3
    error/
      failures.dart                # sealed Failure types
    rbac/
      permission.dart              # Permission enum + role → permission map
      permission_guard.dart        # consumer-side guards for widgets/routes
    result/
      result.dart                  # sealed Result<T> = Success | Failure
    secure/
      secure_store.dart            # flutter_secure_storage wrapper
    services/
      id_seq_service.dart          # voucher_no sequence generator
    utils/
      formatters.dart              # kyat, date, qty display
    widgets/                       # shared dumb widgets
      app_button.dart
      empty_state.dart

  features/
    license/                       # Module 1
      data/
        license_repository.dart
      application/
        license_providers.dart     # licenseStateProvider, featureFlagProvider
        key_codec.dart             # decode activation_key → features_data
      presentation/
        activation_key_screen.dart

    auth/                          # Module 2
      data/
        user_repository.dart
      application/
        auth_providers.dart        # current-user, role, effective permissions
        password_service.dart      # PBKDF2/bcrypt hashing, never plaintext
      presentation/
        login_screen.dart
        user_management/
          users_screen.dart
          user_form_screen.dart

    inventory/                     # Module 3
      data/
        medicine_repository.dart
        batch_repository.dart
      application/
        inventory_providers.dart
        unit_hierarchy.dart        # Box→Strip→Tablet resolution (pure Dart)
        fefo_allocator.dart        # FEFO batch pick algorithm (pure Dart)
        stock_formatter.dart       # "2 Boxes, 3 Strips" (pure Dart)
      domain/
        stock_alert.dart           # low-stock + expiry rule evaluation
      presentation/
        medicine_list_screen.dart
        medicine_form_screen.dart
        batch_form_screen.dart
        alerts_screen.dart
        widgets/stock_badge.dart

    purchasing/                    # Module 4
      data/purchase_repository.dart
      application/purchase_providers.dart
      presentation/
        purchase_list_screen.dart
        purchase_form_screen.dart
        supplier_form_screen.dart
        expense_form_screen.dart

    sales/                         # Module 5
      data/sale_repository.dart    # transactional: sale + items + stock debit
      application/
        pos_providers.dart         # cart state, unit toggle, retail/wholesale mode
        pricing_service.dart       # tiered wholesale pricing rules
      presentation/
        pos_screen.dart
        voucher_preview_screen.dart
        returns_screen.dart
        widgets/cart_tile.dart

    reporting/                     # Module 6
      data/report_repository.dart  # raw SQL aggregates over drift
      application/report_providers.dart
      presentation/
        dashboard_screen.dart
        profit_loss_screen.dart
        aging_report_screen.dart
        fast_moving_screen.dart

    credit/                        # Module 6 (Phase 6)
      data/credit_repository.dart
      application/credit_providers.dart
      presentation/
        customer_ledger_screen.dart
        payment_entry_screen.dart

    backup/                        # Module 7
      data/backup_repository.dart  # VACUUM INTO → encrypt → Drive upload
      application/backup_providers.dart
      presentation/backup_screen.dart

    printing/                      # Module 5 (Phase 5, cross-cutting)
      thermal_printer_service.dart # 58/80mm ESC/POS
      pdf_invoice_service.dart
      voucher_share_service.dart   # Viber / Telegram via share sheet

  routing/
    app_router.dart                # GoRouter + RBAC redirect guards
    routes.dart                    # path constants

  theme/
    app_theme.dart
```

`test/` mirrors `lib/` one-to-one. The pure-Dart files (`fefo_allocator.dart`,
`unit_hierarchy.dart`, `pricing_service.dart`, `key_codec.dart`) are the first
things under test — they carry the business risk.

---

## 3. Database design notes (drift)

**Column mapping.** drift converts `snake_case` Dart field names to `snake_case`
SQL by default, so the schema blueprint maps 1:1 with no `@JsonKey`-style renaming.
The one place to be explicit is table names — set `@TableName('license_config')`
where Dart naming would otherwise pluralise oddly.

**Pragmas, set in `migration.beforeOpen` so they apply to every connection:**

| Pragma | Value | Why |
|---|---|---|
| `foreign_keys` | `ON` | SQLite defaults OFF per connection. Without it every `ON DELETE CASCADE` in later phases silently does nothing. Set on **every** open, not just migrations. |
| `journal_mode` | `WAL` | POS writes must not block dashboard reads on the same isolate. |
| `synchronous` | `NORMAL` | `FULL` is noticeably slow on cheap Android flash; `NORMAL` under WAL is the accepted trade for a pharmacy till. |

**Schema versioning.** Start at `schemaVersion: 1`. Every phase bumps by one and
ships a `MigrationStrategy.up` step. **Never** edit an old `CreateData`-only
definition once a phase is released — Phase 2 adds four tables, so `upgrade` must
`createTable` them explicitly. A release device that skips a step is unrecoverable
without a restore from Phase 7 backup, which does not exist yet in Phase 1. This is
the single most expensive mistake available to us at this stage.

**No SQLCipher in Phase 1.** Cost/price and customer-debt columns sitting in a
plain file on a rooted device is a real exposure, but adding `sqlite3_flutter_libs`
with a cipher build breaks the iOS podspec and Android `abiFilters` configuration.
Deferred with a decision record below. `flutter_secure_storage` covers only the
session token and license key, not rows.

---

## 4. Phase 1 tables

### `users`

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | int | PK, autoincrement | |
| `username` | text | NOT NULL, **UNIQUE** | SQL UNIQUE is byte-exact; case-insensitive matching is a Dart-side concern (`UserRepository.findByUsername`) |
| `pin_hash` | text | NOT NULL | PBKDF2-HMAC-SHA256, per-user random salt stored inline as `salt$hash` |
| `role` | text | NOT NULL | Dart enum `UserRole { admin, cashier }` via `TextColumn` |
| `is_active` | bool | NOT NULL, default true | soft delete — a cashier's sales must keep their name |
| `created_at` | dateTime | NOT NULL | |

**Why `pin_hash` is not `pin`.** The blueprint names the column `pin_hash`, which is
correct and worth holding to. A 4-digit PIN has 10,000 candidates — a plain or
unsalted-SHA256 value falls to a table lookup on a copied DB file. Phase 1 therefore
stores `pbkdf2Sha256(password, salt, iterations: 120_000)` and, if the shop insists
on a 4-digit PIN, `pin` is rejected in favour of a minimum 6-character secret. This
is a Phase 1 decision, not a Phase 6 polish item.

### `license_config`

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | int | PK | **singleton, always 1** |
| `activation_key` | text | NOT NULL | |
| `features_data` | text | NOT NULL | JSON string of module permissions |
| `activated_at` | dateTime | NOT NULL | |
| `updated_at` | dateTime | NOT NULL | |

**Singleton enforcement.** Two independent layers, because the boot flow reads this
table before any Dart code has decided anything:

1. `insertOrReplace` with an explicit `id: 1` in `LicenseRepository.activate()`.
2. A SQL `CHECK (id = 1)` on the primary key column, so a bad write fails at the
   database rather than producing two rows and a non-deterministic boot.

The column carries `NOT NULL CHECK (id = 1)` and `primaryKey => {id}` declares the
key separately. Repeating `PRIMARY KEY` inside the column constraint makes SQLite
emit two primary keys and reject the whole `CREATE TABLE` — caught by the
migration test, not by reading the generated DDL.

**Boot flow.** `main()` opens the DB → selects the singleton → empty ⇒
`ActivationKeyScreen`; present ⇒ decode the stored blob into `licenseProvider`'s
feature map ⇒ `LoginScreen`. A stored blob that fails to decode returns to the
activation screen rather than trapping the shop in a crash loop — the recovery is
to re-enter a key they already own.

### First-run administrator

The blueprint's auth flow implies a usable account after activation. Seeding
`admin` / a fixed PIN was rejected: a constant default on an offline device that
also stores cost prices and customer debt is the weakest link in the system, and
there is no server that can rotate it. `SetupAdminScreen` therefore creates the
first Admin after activation, with the secret supplied by the owner.

This is a deviation from a literal reading of "seed an admin", so `BootGate`
counts users and routes an empty table to setup instead of to a login screen that
could never succeed.

**Security note on `features_data`.** A locally-decoded, locally-stored permission
blob is tamperable — editing JSON on the device unlocks paid modules. Phase 1
implements the flow as specified and stores the raw key, but `key_codec.dart` is
written behind an interface so a signed/HMAC-verified payload can replace the
decoder without touching the boot screen. Flagging now so it is not mistaken for
a complete licensing scheme.

> **Resolved in Phase 2.** The decoder is now HMAC-verified and re-checked on
> every start, so an edited `features_data` grants nothing. See
> [`PHASE2_LICENSE.md`](PHASE2_LICENSE.md).

---

## 4b. Guards added beyond the blueprint

**Last-admin protection.** `UserRepository.setActive` refuses to deactivate the
only active Admin, and `hasOtherActiveAdmin` is the predicate the user list uses
to decide whether to offer the action. Without it, one mis-tap on a shop's only
owner account locks out cost prices, user management and reports permanently —
there is no reset path on an offline device.

**Coarse auth outcomes.** `authenticate` returns `invalidCredentials` for both a
missing account and a wrong secret, and runs a decoy PBKDF2 derivation on the
missing-account path so the response time does not reveal whether the username
exists.

---

## 5. Deferred decisions

| Item | Phase | Status |
|---|---|---|
| SQLCipher encryption at rest | 7 | Deferred; needs iOS podspec + ABI filter work |
| Drive OAuth tokens | 7 | Deferred |
| ESC/POS printer calibration (58 vs 80mm) | 5 | Deferred, hardware-dependent |
| `medicines` multi-unit hierarchy | 2 | Next |
| FEFO enforcement on sale | 2→4 | Algorithm in 2, wired to POS in 4 |

---

## 6. Build & verify

```bash
flutter pub get
dart run build_runner build          # generates app_database.g.dart
flutter analyze                      # must stay clean
flutter test                         # 88 cases
dart format --output=none --set-exit-if-changed lib test
```

Re-run `build_runner` after any change under `lib/core/database/tables/`. The
generated `app_database.g.dart` is committed, so a clone builds without a codegen
step — which makes a CI check that regeneration produces no diff necessary, or a
stale generated file can merge and only fail on a device.
