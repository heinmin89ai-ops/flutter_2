import '../../../l10n/generated/app_localizations.dart';

/// Translates the `backup*` error keys thrown by `BackupService`.
///
/// Registered in the central `_errorResolvers` list so `l10n.describe(e)`
/// renders [LocalizedError]s from this module in the active locale.
String? backupErrors(
  AppLocalizations l10n,
  String key,
  Map<String, String> args,
) => switch (key) {
  'backupNoManifest' => l10n.backupNoManifest,
  'backupMissingDatabase' => l10n.backupMissingDatabase,
  'backupTruncated' => l10n.backupTruncated,
  'backupNotPharmacyFile' => l10n.backupNotPharmacyFile,
  'backupUnsupportedVersion' => l10n.backupUnsupportedVersion(
    args['version'] ?? '',
  ),
  'backupWrongPassphrase' => l10n.backupWrongPassphrase,
  'backupPassphraseRequired' => l10n.backupPassphraseRequired,
  _ => null,
};
