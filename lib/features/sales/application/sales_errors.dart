import '../../../l10n/generated/app_localizations.dart';

/// Error- and label-key resolver for the sales module.
///
/// Every `sale*` key thrown by [SaleRepository] / `fefo_allocator` (and every
/// voucher label the checkout sheet resolves by key) is routed here, so
/// `AppLocalizationsError.message` in `core/l10n/l10n_bridge.dart` can render it.
/// Parameterised keys read their arguments from [args]; the argument map is
/// string-valued because the data layer formats money and ids before throwing.
String? salesErrors(
  AppLocalizations l10n,
  String key,
  Map<String, String> args,
) => switch (key) {
  // ----------------------------------------------------- POS screen labels
  'saleNoMatchesClearSearch' => l10n.saleNoMatchesClearSearch,
  'saleNoUnitsSetBadge' => l10n.saleNoUnitsSetBadge,
  'saleOneSellableUnit' => l10n.saleOneSellableUnit,
  'saleSellAs' => l10n.saleSellAs(args['name']!),
  'saleDiscountOverSubtotal' => l10n.saleDiscountOverSubtotal,
  'saleEnterNumber' => l10n.saleEnterNumber,

  // ------------------------------------------------------- checkout labels
  'saleCartEmpty' => l10n.saleCartEmpty,
  'saleCartLines' => l10n.saleCartLines(int.parse(args['count']!)),
  'saleReceivedLabel' => l10n.saleReceivedLabel,
  'saleChargeOnCredit' => l10n.saleChargeOnCredit(args['amount']!),
  'saleCompleteSale' => l10n.saleCompleteSale,
  'saleNoCustomersYet' => l10n.saleNoCustomersYet(args['screen']!),
  'saleChargeThisSaleTo' => l10n.saleChargeThisSaleTo,
  'saleDebtAndLimit' => l10n.saleDebtAndLimit(args['debt']!, args['limit']!),
  'saleCash' => l10n.saleCash,
  'saleBalanceOnCredit' => l10n.saleBalanceOnCredit,
  'saleChange' => l10n.saleChange,
  'salePickACustomer' => l10n.salePickACustomer,
  'salePaidInFull' => l10n.salePaidInFull,
  'saleCarriesBalance' => l10n.saleCarriesBalance(args['name']!),
  'saleClear' => l10n.saleClear,
  'saleChoose' => l10n.saleChoose,
  'saleConfirmedTitle' => l10n.saleConfirmedTitle,
  'saleVoucherNumber' => l10n.saleVoucherNumber(args['number']!),
  'saleTotalAmount' => l10n.saleTotalAmount(args['amount']!),
  'saleChangeAmount' => l10n.saleChangeAmount(args['amount']!),
  'saleOnCreditAmount' => l10n.saleOnCreditAmount(args['amount']!),
  'saleNewSale' => l10n.saleNewSale,
  'saleVoucher' => l10n.saleVoucher,
  'saleVoucherReady' => l10n.saleVoucherReady(args['file']!, args['bytes']!),
  'saleVoucherBuildFailed' => l10n.saleVoucherBuildFailed(args['error']!),
  'saleCouldNotComplete' => l10n.saleCouldNotComplete(args['error']!),
  'saleSessionExpired' => l10n.saleSessionExpired,
  'saleChooseCustomerForBalance' => l10n.saleChooseCustomerForBalance,
  'saleKpayFullPayment' => l10n.saleKpayFullPayment,
  'saleStaff' => l10n.saleStaff,
  'saleItemFallback' => l10n.saleItemFallback(args['id']!),

  // ------------------------------------------------ repository rejections
  'saleCustomerNameRequired' => l10n.saleCustomerNameRequired,
  'saleCreditLimitNotNegative' => l10n.saleCreditLimitNotNegative,
  'salePaymentMustBePositive' => l10n.salePaymentMustBePositive,
  'salePaymentExceedsBalance' => l10n.salePaymentExceedsBalance(
    args['balance']!,
  ),
  'saleCartIsEmpty' => l10n.saleCartIsEmpty,
  'saleDiscountNotNegative' => l10n.saleDiscountNotNegative,
  'saleReceivedNotNegative' => l10n.saleReceivedNotNegative,
  'saleDiscountExceedsSubtotal' => l10n.saleDiscountExceedsSubtotal(
    args['discount']!,
    args['subtotal']!,
  ),
  'saleBalanceNeedsCustomer' => l10n.saleBalanceNeedsCustomer,
  'salePartialPaymentNotKPay' => l10n.salePartialPaymentNotKPay,
  'saleQuantityAtLeast1' => l10n.saleQuantityAtLeast1,
  'saleUnitPriceNotNegative' => l10n.saleUnitPriceNotNegative,
  'saleFactorAtLeast1' => l10n.saleFactorAtLeast1,
  'saleLineMustNameUnit' => l10n.saleLineMustNameUnit,
  'saleCustomerDoesNotExist' => l10n.saleCustomerDoesNotExist(args['id']!),
  'saleCustomerNotActive' => l10n.saleCustomerNotActive(args['name']!),
  'saleOverCreditLimit' => l10n.saleOverCreditLimit(
    args['name']!,
    args['projected']!,
    args['limit']!,
  ),

  // ---------------------------------------------------------------- FEFO
  'saleShortage' => l10n.saleShortage(args['requested']!, args['available']!),
  'saleProductShortage' => l10n.saleProductShortage(
    args['product']!,
    args['available']!,
    args['requested']!,
  ),
  'saleLineMinOneUnit' => l10n.saleLineMinOneUnit,

  // ------------------------------------------------------- voucher labels
  'saleVoucherDateLabel' => l10n.saleVoucherDateLabel,
  'saleVoucherCustomerLabel' => l10n.saleVoucherCustomerLabel,
  'saleVoucherCashierLabel' => l10n.saleVoucherCashierLabel,
  'saleVoucherTypeLabel' => l10n.saleVoucherTypeLabel,
  'saleVoucherBalanceDue' => l10n.saleVoucherBalanceDue,
  'saleVoucherItemHeader' => l10n.saleVoucherItemHeader,
  'saleVoucherQtyHeader' => l10n.saleVoucherQtyHeader,
  'saleVoucherPriceHeader' => l10n.saleVoucherPriceHeader,
  'saleVoucherThankYou' => l10n.saleVoucherThankYou,
  'saleVoucherShopName' => l10n.saleVoucherShopName,

  _ => null,
};
