/// Shared secret used to verify vendor-issued licence keys (HS256).
///
/// Override at build time so the real secret never lives in the repository:
///
/// ```sh
/// flutter build apk --release \
///   --dart-define=PHARMACY_LICENSE_SECRET='<the vendor secret>'
/// ```
///
/// The generator reads the same value from `PHARMACY_LICENSE_SECRET`; both
/// sides must match or every key is rejected as a signature mismatch.
///
/// ## Why a compile-time constant is a weak point
///
/// HS256 is a *symmetric* scheme: the key that verifies is the key that signs.
/// Anything compiled into the APK can be lifted out of it — `strings`, a
/// debugger, or `objection` — so a customer with the app installed can produce
/// valid keys for any feature set. This raises the cost of casual tampering
/// (editing `features_data` in a SQLite GUI no longer works) but it is not
/// copy protection.
///
/// The fix is Ed25519: the vendor signs with a private key, the app embeds only
/// the public key, so the app can never mint a licence. `FeatureDecoder` exists
/// so that swap is one class plus one provider. See docs/PHASE2_LICENSE.md.
const String kLicenseSecret = String.fromEnvironment(
  'PHARMACY_LICENSE_SECRET',
  defaultValue: 'pharmacy-pos-dev-secret-CHANGE-ME-0f3a9c7d51b642e8',
);

/// True when the build still carries the placeholder secret from source control.
///
/// A release built with this value active accepts any key signed with the
/// public, committed secret — including ones a customer generates themselves.
/// Surfaced on the dashboard in debug builds so it cannot ship unnoticed.
const bool kUsingDevelopmentLicenseSecret =
    kLicenseSecret == 'pharmacy-pos-dev-secret-CHANGE-ME-0f3a9c7d51b642e8';
