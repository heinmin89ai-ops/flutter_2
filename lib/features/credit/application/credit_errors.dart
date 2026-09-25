import '../../../l10n/generated/app_localizations.dart';

/// Resolver for every `credit*` message key owned by Module 6.
///
/// Covers both the rejection messages thrown by [CreditRepository] /
/// [LedgerService] (which arrive here as `errorKey` + `errorArgs` on a
/// `LocalizedError`) and the parameterised strings the credit screens render
/// through `l10n.message(key, args)`. Unrelated keys return `null` so the
/// next resolver gets a chance.
String? creditErrors(
  AppLocalizations l10n,
  String key,
  Map<String, String> args,
) => switch (key) {
  // Vocabulary and screens
  'creditCustomerTitle' => l10n.creditCustomerTitle,
  'creditSupplierTitle' => l10n.creditSupplierTitle,
  'creditWordCustomer' => l10n.creditWordCustomer,
  'creditWordSupplier' => l10n.creditWordSupplier,
  'creditOwes' => l10n.creditOwes,
  'creditIsOwed' => l10n.creditIsOwed,
  'creditTotalReceivable' => l10n.creditTotalReceivable,
  'creditTotalPayable' => l10n.creditTotalPayable,
  'creditSearchHint' => l10n.creditSearchHint(args['party']!),
  'creditBalanceLine' => l10n.creditBalanceLine(
    args['balanceWord']!,
    args['amount']!,
  ),
  'creditNobodyOwesShop' => l10n.creditNobodyOwesShop,
  'creditShopOwesNobody' => l10n.creditShopOwesNobody,
  'creditNoMatches' => l10n.creditNoMatches(args['party']!, args['query']!),
  'creditTotalForSearch' => l10n.creditTotalForSearch(args['label']!),
  // Record-payment dialog and statement screen
  'creditRecordPaymentTitle' => l10n.creditRecordPaymentTitle,
  'creditCustomerOwesNow' => l10n.creditCustomerOwesNow(
    args['name']!,
    args['amount']!,
  ),
  'creditSupplierOwedNow' => l10n.creditSupplierOwedNow(
    args['name']!,
    args['amount']!,
  ),
  'creditAmountReceived' => l10n.creditAmountReceived,
  'creditReferenceNote' => l10n.creditReferenceNote,
  'creditPaymentRecorded' => l10n.creditPaymentRecorded,
  'creditReversePaymentTitle' => l10n.creditReversePaymentTitle,
  'creditReversePaymentBody' => l10n.creditReversePaymentBody(
    args['amount']!,
  ),
  'creditReverse' => l10n.creditReverse,
  'creditPaymentReversed' => l10n.creditPaymentReversed,
  'creditRecordPayment' => l10n.creditRecordPayment,
  'creditOutstanding' => l10n.creditOutstanding,
  'creditStatement' => l10n.creditStatement,
  'creditNoLedgerActivity' => l10n.creditNoLedgerActivity,
  'creditDebtAdded' => l10n.creditDebtAdded,
  'creditPaymentReceived' => l10n.creditPaymentReceived,
  'creditReversePaymentTooltip' => l10n.creditReversePaymentTooltip,
  // Rejections from the repository
  'creditPaymentMustBePositive' => l10n.creditPaymentMustBePositive,
  'creditPaymentExceedsBalance' => l10n.creditPaymentExceedsBalance(
    args['amount']!,
  ),
  'creditCustomerDoesNotExist' => l10n.creditCustomerDoesNotExist(
    args['id']!,
  ),
  'creditSupplierDoesNotExist' => l10n.creditSupplierDoesNotExist(
    args['id']!,
  ),
  'creditLedgerEntryMissing' => l10n.creditLedgerEntryMissing,
  'creditOnlyPaymentReversible' => l10n.creditOnlyPaymentReversible,
  // Ledger-service preconditions
  'creditDebtEntryPositive' => l10n.creditDebtEntryPositive,
  'creditPaymentEntryPositive' => l10n.creditPaymentEntryPositive,
  _ => null,
};
