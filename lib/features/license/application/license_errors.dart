import '../../../l10n/generated/app_localizations.dart';

/// Resolver for every `license`-prefixed key in this module.
///
/// The boot provider carries a localisation **key** (never English) as its
/// error state, so both inline UI text and `l10n.message(...)` / `l10n.describe(...)`
/// lookups route through here. Unknown keys return `null` so the next resolver
/// (or the debug fallback in `message`) gets a chance.
String? licenseErrors(AppLocalizations l10n, String key, Map<String, String> args) =>
    switch (key) {
      // Activation screen chrome.
      'licenseTitle' => l10n.licenseTitle,
      'licenseIntro' => l10n.licenseIntro,
      'licenseKeyLabel' => l10n.licenseKeyLabel,
      'licenseActivate' => l10n.licenseActivate,
      'licenseKeyRequired' => l10n.licenseKeyRequired,
      'licenseActivationFailed' => l10n.licenseActivationFailed,
      // Provider / decode failures.
      'licenseStoredKeyInvalid' => l10n.licenseStoredKeyInvalid,
      'licenseKeyNotJwt' => l10n.licenseKeyNotJwt,
      'licenseSignatureMismatch' => l10n.licenseSignatureMismatch,
      'licenseNoFeaturesClaim' => l10n.licenseNoFeaturesClaim,
      'licenseUnreadableExpiry' => l10n.licenseUnreadableExpiry,
      'licenseUnsupportedAlgorithm' => l10n.licenseUnsupportedAlgorithm(
        args['algorithm'] ?? '',
      ),
      'licenseUnknownVendor' => l10n.licenseUnknownVendor(args['vendor'] ?? ''),
      'licenseKeyExpired' => l10n.licenseKeyExpired(args['date'] ?? ''),
      'licenseSegmentNotBase64' => l10n.licenseSegmentNotBase64(
        args['label'] ?? '',
      ),
      'licenseSegmentNotJsonObject' => l10n.licenseSegmentNotJsonObject(
        args['label'] ?? '',
      ),
      'licenseSegmentNotJson' => l10n.licenseSegmentNotJson(
        args['label'] ?? '',
      ),
      'licenseSegmentNotUtf8' => l10n.licenseSegmentNotUtf8(
        args['label'] ?? '',
      ),
      _ => null,
    };
