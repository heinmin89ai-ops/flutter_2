import '../../../l10n/generated/app_localizations.dart';

/// Translates the `exp*` error keys thrown by `ExpenseRepository`.
///
/// Registered in the central `_errorResolvers` list so `l10n.describe(e)`
/// renders [LocalizedError]s from this module in the active locale.
String? expenseErrors(
  AppLocalizations l10n,
  String key,
  Map<String, String> args,
) => switch (key) {
  'expNeedsCategory' => l10n.expNeedsCategory,
  'expAmountMustBePositive' => l10n.expAmountMustBePositive,
  _ => null,
};
