# Phase 6 — Localisation, Expiry Notifications and a Camera Scanner

The three "advanced enhancement" items the blueprint lists as bonuses, delivered
with the same rule every earlier phase followed: a platform plugin cannot run
under `flutter test`, so **every decision is pushed behind a tiny seam that a
fake can exercise**, and only the raw plugin call stays in the concrete class.
This mirrors `KeyValueStore` (boot flow), the `reopen` callback (backup) and the
FEFO allocator (POS). No table changes — the schema stays at 4.

---

## 1. Scope

| Requirement | Where it lives |
|---|---|
| English + Myanmar UI, cashier-switchable | `l10n/*.arb` + `lib/l10n/generated/`, `core/locale/locale_controller.dart` |
| Local notification for batches expiring ≤ 30 days | `features/notifications/` |
| Camera barcode scanner in POS and Add Medicine | `features/scanning/` |

Items 1–3 of the brief (credit, expenses, reports, backup) were shipped in
Phase 5; this phase is the bonuses only.

---

## 2. Localisation — `intl`/ARB, not `easy_localization`

The blueprint offered `easy_localization` **or** `intl`. `intl` +
`flutter_localizations` was chosen because it is first-party (ships with the
SDK, no third-party runtime to audit or that could break on a Flutter upgrade),
it generates *typed* getters (`l10n.checkout`) so a missing key is a compile
error rather than a string silently rendering as its own name at runtime, and it
is the path the rest of the ecosystem (and CI, which cannot pump an arbitrary
package's boot logic) understands. The generated `lib/l10n/generated/` classes
are committed exactly like `app_database.g.dart` — a fresh clone builds with no
codegen step.

Locale is **persisted**, not derived from the platform. A new install boots in
English; a Burmese-speaking cashier who picks မြန်မာ gets it again the next
morning. The persistence goes through the *existing* `SecureStore`
`KeyValueStore` seam (a new `readLocale`/`writeLocale` on the same store, not a
second store), so `LocaleController` is a plain `Notifier<String>` and the whole
load/set/restart path is unit-tested with `MemoryKeyValueStore` and no platform
channel.

Adoption is honest and partial, and deliberately so. The **dashboard and the POS
screen** — the two surfaces a cashier touches every day — read `AppLocalizations`
directly. The remaining feature screens (inventory list, credit statements,
expense entry, reports, backup) still carry English chrome: converting them is
mechanical (add keys, replace literals) and each one is better reviewed with the
Burmese wording in front of a native speaker than bulk-committed from a
translation guess. A render test pumps both locales through the real delegate set
and asserts the Burmese strings come back, so the ARB→generated→Localizations
pipeline is proven even where adoption is incomplete.

The one thing that cannot be proven offline is *glyph rendering*: the UI is
translated, but the **printed PDF voucher** still uses the `pdf` package's
default fonts, which have no Myanmar glyphs (carried forward from Phase 4 — see
the bundled-Unicode-font task). Localisation of the app and correct rendering of
Burmese on a 58 mm receipt are separate problems.

---

## 3. Expiry notifications — the dedup is the feature

`flutter_local_notifications` cannot fire under `flutter test`, so the plugin
call sits behind a `NotificationGateway` interface. The production
`PluginNotificationGateway` wraps the plugin and **swallows any platform error**
(`MissingPluginException`, no notification permission, unsupported platform) so a
till that cannot show notifications still boots — notifications are best-effort,
never fatal.

The interesting part is `ExpiryAlertService.checkAndAlert`, and it is pure:

```
for each expiring batch:
  if daysToExpiry > 30:               skip        (outside the window)
  if this batch already alerted today: skip        (per-batch, per-day)
  else: show it, record today's date, count++
```

"Already alerted today" is a `SecureStore`-backed `AlertLedger` keyed on
`expiry_alert.{batchId} → yyyy-mm-dd`. This once-per-calendar-day-per-batch
dedup is the entire reason the notification is usable: a phone that boots half a
dozen times a day would otherwise scream "Paracetamol expires in 12 days" on
every single boot, and staff would learn to swipe the alerts away within a week.
Keyed on (batch, date) — not global — because a shop with five near-expiry lines
must hear about all five. The window is checked inclusive at 30 days, and the
tests fix that boundary. The alert re-arms the next day. The batch id is reused
as the notification id, so a re-show replaces rather than stacks.

The startup hook runs in `BootGate` after licence/auth load and is wrapped so it
cannot ever block or crash boot. Because it reads through the `inventoryRevision`
/ repository providers and the gateway is a provider, the existing boot tests are
unaffected: the fake/real gateway no-ops without a platform channel.

Note the windows differ on purpose: this alert is **30 days** (an action-now
"pull this stock" signal), while the Phase 5 reports dashboard surfaces a **60
day** expiry band (a planning view). They are different questions; `expiringWithin`
takes the count as an argument and both call it with their own constant.

---

## 4. Camera scanner — one resolution for two inputs

`mobile_scanner`'s `MobileScanner` widget needs a real camera, so it is not
unit-tested. What *is* tested is the decision a scan feeds into:
`resolveScan({code, findByBarcode})` is pure and returns one of
`addProduct / showNotFound / ignoreEmpty`. The camera screen
(`ScannerScreen`) is a thin `MobileScannerController` + `onDetect` wrapper that
pops the first non-empty `rawValue` back to the caller.

The point of the seam is **agreement**: the till already accepted an HID
keyboard scanner (Phase 4 — the code types and Enter submits, matched exactly on
`medicines.barcode`). The camera path now runs the *same* `resolveScan`, so a
code means the same thing whether it arrived by laser-gun or by lens. Both stay
an *exact* barcode match, never `LIKE` — a partial scan adding the wrong medicine
is worse than telling the cashier to search. A blank capture is *ignored* rather
than reported as "not found" (an empty read is a misfire, not a missing product),
and whitespace is trimmed first because real scanners append newlines.

Integration: the POS `AppBar` gains a scanner button; the add-medicine barcode
field gains a suffix scanner button that fills the `_barcode` controller.

Android permissions were added to the main manifest: `CAMERA` (scanner) and
`POST_NOTIFICATIONS` (Android 13+ notifications). The camera path's real
behaviour — focus, torch, permission prompt flow — is only judgeable on a
device; that is stated, not faked.

---

## 5. Deliberate omissions

- **No full app-wide translation.** Dashboard + POS only, with the ARB pipeline
  tested so the rest is incremental. The rest awaits a native-speaker pass on
  wording (see §2).
- **No notification scheduling / background isolate.** Alerts fire on app
  *startup*, the offline-first-appropriate trigger. A true background "even
  while closed" reminder needs a platform scheduler (Android `WorkManager`,
  iOS silent push) and interacts with battery — deferred, not an oversight.
- **No per-role alert settings.** The 30-day window is a constant; making it
  shop-configurable is a small, safe follow-up, not a Phase 6 risk.
- **No on-device verification claimed for the camera.** The resolver logic is
  tested; the `MobileScanner` widget, camera focus and the torch toggle are
  explicitly a device-pass item.

---

## 6. Tests added

| File | Covers |
|---|---|
| `test/core/locale/locale_controller_test.dart` | default `en`; `setLocale` updates state *and* writes through to `SecureStore`; a persisted value rehydrates on `load` (restart path); no-op when nothing saved; no redundant rewrite |
| `test/core/locale/localization_render_test.dart` | pumps both locales through the real delegate set and asserts English **and** Myanmar strings render (placeholder interpolation included); both locales declared supported |
| `test/features/notifications/expiry_alert_service_test.dart` | fires once in-window; **same batch not re-fired the same calendar day**; re-fires next day; out-of-window never fires; the 30-day boundary is inclusive; dedup is per-batch not global; a mixed list alerts only the eligible set |
| `test/features/scanning/scan_resolution_test.dart` | exact hit → add; whitespace trimmed before matching; unknown → not-found; blank → ignored (never "missing"); a blank code short-circuits before any lookup |

Suite total: 381 Dart tests (was 361 before Phase 6) plus the 7-case Python
licence self-test.
