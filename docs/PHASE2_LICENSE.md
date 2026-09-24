# Phase 2 — Signed Licences

Builds on the Phase 1 architecture (see
[`PHASE1_ARCHITECTURE.md`](PHASE1_ARCHITECTURE.md)); nothing about the folder
layout, provider style or route guards changes here. This document covers the
licence key format, the vendor tooling, and two Phase 1 weaknesses that Phase 2
closes.

---

## 1. Scope

The Phase 2 brief asked for repositories, Riverpod state, the boot flow, the
router redirect chain, `ActivationKeyScreen` and `LoginScreen`. **All of that
shipped in Phase 1** — `LicenseRepository`, `UserRepository`, `licenseProvider`,
`authProvider`, `_guard`, and both screens already exist and are covered by
tests. Re-listing them would have produced a second copy of working code.

What Phase 2 actually adds:

| Deliverable | File |
|---|---|
| Standalone vendor key generator | `tools/license_generator.py` |
| JWT (HS256) verification in the app | `lib/features/license/application/jwt_decoder.dart` |
| Compile-time secret wiring | `lib/features/license/application/license_secret.dart` |
| Decoder-agnostic contract (`LicenceFacts`) | `lib/features/license/application/key_codec.dart` |
| Licence-aware landing screen | `lib/features/shell/presentation/dashboard_screen.dart` |
| Re-verification on every start | `LicenseNotifier.load` |
| Cross-language test vectors | `test/features/license/application/jwt_decoder_test.dart` |

---

## 2. Key format

A licence key is a standard JWT, `.`-joined, base64url without padding:

```
base64url({"alg":"HS256","typ":"JWT"})
.
base64url({
  "iss": "pharmacy-pos",
  "sub": "hein-pharmacy",          // stable customer id
  "client": "Hein Pharmacy, Yangon",
  "iat": 1790000000,               // issued at (NumericDate, seconds)
  "exp": 1893456000,               // expiry (NumericDate) — omit for perpetual
  "features": {                    // the brief's features_data
    "retail": true,
    "wholesale": true,
    "cloud_backup": false
  }
})
.
base64url(HMAC-SHA256(header + "." + payload, SECRET))
```

Verification order in `JwtFeatureDecoder.decode` is deliberate:

1. Exactly three segments.
2. Decode the header and **reject any `alg` that is not `HS256`** — before
   touching the signature. Accepting `alg: none`, or letting an attacker-supplied
   header choose the algorithm, is the most common JWT implementation break.
3. Recompute the HMAC over the raw `header.payload` bytes and compare in constant
   time.
4. Only then decode the claims; check `iss`, then `exp`, then read `features`.

Signature comparison is over the base64url strings with padding stripped, which
matches what the Python side emits.

### Canonical encoding

`tools/license_generator.py` signs JSON produced with `sort_keys=True`. HMAC
covers exact bytes, so Dart must encode identically or the same claims yield two
different signatures. `_canonicalJson` in `jwt_decoder.dart` sorts keys at every
depth, and the test
`cross-language vectors → Dart issues a byte-identical key for the same claims`
asserts segment-for-segment equality against a Python-generated key. That test
is the only thing standing between a refactor and "every vendor key suddenly
fails to verify".

---

## 3. Vendor tooling

Pure standard library — no `pip install`, so it runs on any machine with Python 3.

```bash
# Issue a key
python3 tools/license_generator.py \
  --client "Hein Pharmacy, Yangon" \
  --exp 2027-01-01 \
  --features '{"retail": true, "wholesale": true, "cloud_backup": false}' \
  --pretty

# Expiry also accepts +365d, +18m, +2y, or a unix timestamp
python3 tools/license_generator.py --client "Sun Pharma, Mandalay" \
  --exp +1y --features '{"retail": true}'

# Check a key a customer is holding, without touching the app
python3 tools/license_generator.py --verify 'eyJhbGciOi...'

# Prove the signing/verification paths work after any edit
python3 tools/license_generator.py --self-test
```

`--self-test` covers seven cases, including the ones that matter: escalating
features by editing the payload, `alg: none`, a flipped signature byte, a key
signed with a different secret, and an expired key.

The tool **verifies what it just issued** before printing it, so it can never
hand out a key the app will refuse.

### Keeping the secrets in step

Both sides default to the same development placeholder. For real issuance:

```bash
export PHARMACY_LICENSE_SECRET='<the value you will compile into the app>'
flutter build apk --release --dart-define=PHARMACY_LICENSE_SECRET="$PHARMACY_LICENSE_SECRET"
```

Mismatch produces a clear `Signature mismatch` at the activation field, not a
mysterious crash.

---

## 4. Two Phase 1 weaknesses closed

### 4a. Expiry was only checked once

Phase 1 decoded the key at activation, stored `features_data`, and never looked
at `exp` again. A shop whose licence expired in March kept full access through
December, because `load()` only parsed the cached JSON.

Phase 2 treats the persisted `activation_key` as the only source of truth and
re-runs **signature + expiry** on every app start. `features_data` is still
written, but purely as a display cache — nothing gates on it. Covered by
`load re-verifies the stored key instead of trusting the cached blob` and
`an expired key stops working after a restart`.

That second weakness is the same bug class: a rooted device could edit
`features_data` in a SQLite GUI and unlock modules. Re-verifying the key makes
the edit inert.

### 4b. The activation field rejected real keys

Phase 1's formatter allowed `[A-Za-z0-9_-]` because the old key format had no
dots. A JWT is dot-separated, so that formatter would have silently stripped
every `.` from a pasted key and produced a confusing checksum error. Now
`[A-Za-z0-9_\-.]`, and the decoder strips all whitespace so a key wrapped across
two lines in an email still works.

### Also: `expired` is now a distinct status

`LicenseStatus.expired` is separate from `invalidKey` because the support
response differs completely — one is "buy a renewal", the other is "your install
looks tampered with". The dashboard shows a countdown inside 21 days
(`LicenseState.expiryWarningWindow`) so a shop is not cut off mid-sale.

---

## 5. Honest limits of this design

**HS256 here is tamper-*evidence*, not copy protection.** It is a symmetric
scheme: the key that verifies is the key that signs, and it is compiled into the
APK. Anyone who extracts it — `strings`, a Frida hook, `objection` — can mint
keys for any feature set. What this stops is editing the licence row in a SQLite
editor, which is the realistic attack from a customer. It does not stop a
determined one.

The dashboard surfaces this in debug builds when the committed placeholder
secret is still active, because a release shipped with it accepts keys anyone can
generate.

### Upgrade path: Ed25519

For a paid product, switch to an asymmetric scheme:

- Vendor holds a private key (kept offline, ideally in a hardware token).
- The app embeds **only the public key**.
- `FeatureDecoder` gains an `Ed25519FeatureDecoder`; `featureDecoderProvider`
  changes by one line. No screen, guard or consumer touches the format.
- Python side: `pip install pynacl`, swap `_sign` for `SigningKey.sign`, and put
  the signature in the third JWT segment with `alg: EdDSA`.
- Dart side: `package:cryptography` `Ed25519()` verify, or FFI to libsodium.

The app can then never produce a valid licence, which is the property that
actually matters.

Two other gaps worth naming:

- **No revocation.** An offline device with a valid key keeps working even if the
  customer stops paying. Fixing that needs either a short `exp` (renew every 30
  days) or a network check, which conflicts with offline-first. A short `exp` is
  the pragmatic answer and needs no new code — the countdown UI already exists.
- **Clock rollback.** Setting the device clock back extends an expiring licence.
  Mitigation is to persist the highest boot time seen and refuse keys expiring
  before it. Deliberately not built yet: it interacts with Phase 7 backup
  restore, where a legitimately older timestamp is expected.

---

## 6. Schema note

`license_config` is unchanged, so `kSchemaVersion` stays at `1` and there is no
migration. `activation_key` holds the JWT (up to ~400 chars for a typical
payload) and `features_data` holds the display cache. Both were `TEXT` already.

---

## 7. Verifying

```bash
dart run build_runner build && git diff --exit-code -- '*.g.dart'   # no drift
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test                                    # 106 cases
python3 tools/license_generator.py --self-test  # 7 cases
```

CI (`.github/workflows/ci.yml`) runs the four Dart checks plus
`--self-test` on every push to `main` and `feature/**`.

---

## 8. Carried into Phase 3

- [ ] Decide the renewal UX: a key re-entered while a valid one is stored should
      probably preserve `activated_at`, which `updateFeatures` supports but
      `activate` currently resets.
- [ ] Clock-rollback guard, designed together with the Phase 7 backup header.
- [ ] Inventory tables (`medicines`, `unit_conversions`, `medicine_batches`) —
      `kSchemaVersion` goes to 2 and `onUpgrade` needs its first real path.
