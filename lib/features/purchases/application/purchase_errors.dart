import '../../../l10n/generated/app_localizations.dart';

/// Translates `purch*` error keys thrown by [PurchaseRejectException] in the
/// purchases data layer. Registered in `l10n_bridge.dart`'s resolver list.
String? purchaseErrors(AppLocalizations l10n, String key, Map<String, String> args) =>
    switch (key) {
      'purchSupplierNameRequired' => l10n.purchSupplierNameRequired,
      'purchPaymentMustBePositive' => l10n.purchPaymentMustBePositive,
      'purchPaymentExceedsBalance' => l10n.purchPaymentExceedsBalance(args['amount']!),
      'purchAddAtLeastOneLine' => l10n.purchAddAtLeastOneLine,
      'purchDuplicateSaleUnit' => l10n.purchDuplicateSaleUnit(args['batch']!),
      'purchPaidNotNegative' => l10n.purchPaidNotNegative,
      'purchPaidExceedsInvoice' =>
        l10n.purchPaidExceedsInvoice(args['paid']!, args['total']!),
      'purchEveryLineNeedsBatch' => l10n.purchEveryLineNeedsBatch,
      'purchQuantityAtLeast1' => l10n.purchQuantityAtLeast1,
      'purchCostNotNegative' => l10n.purchCostNotNegative,
      'purchFactorAtLeast1' => l10n.purchFactorAtLeast1,
      'purchBatchAlreadyExpired' => l10n.purchBatchAlreadyExpired(args['batch']!),
      'purchSupplierDoesNotExist' => l10n.purchSupplierDoesNotExist(args['id']!),
      _ => null,
    };
