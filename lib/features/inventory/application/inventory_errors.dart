import '../../../l10n/generated/app_localizations.dart';

/// Translates inventory module error keys (unit hierarchy configuration and
/// medicine repository conflicts) into the active locale.
String? inventoryErrors(
  AppLocalizations l10n,
  String key,
  Map<String, String> args,
) => switch (key) {
  'invNoUnitsConfigured' => l10n.invNoUnitsConfigured,
  'invNoSmallestUnit' => l10n.invNoSmallestUnit,
  'invMoreThanOneSmallestUnit' => l10n.invMoreThanOneSmallestUnit(
    args['names']!,
  ),
  'invDuplicateUnitNames' => l10n.invDuplicateUnitNames,
  'invUnknownUnit' => l10n.invUnknownUnit(args['name']!),
  'invQuantityAtLeast1' => l10n.invQuantityAtLeast1(int.parse(args['value']!)),
  'invQuantityNotNegative' => l10n.invQuantityNotNegative(
    int.parse(args['value']!),
  ),
  'invMedicineNameRequired' => l10n.invMedicineNameRequired,
  'invBarcodeTaken' => l10n.invBarcodeTaken(
    args['barcode']!,
    args['medicine']!,
  ),
  'invMedicineStillHasStock' => l10n.invMedicineStillHasStock,
  'invBatchRemovalTooLarge' => l10n.invBatchRemovalTooLarge(
    args['batch']!,
    int.parse(args['remaining']!),
    int.parse(args['removal']!),
  ),
  _ => null,
};
