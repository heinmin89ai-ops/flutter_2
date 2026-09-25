// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pharmacy POS';

  @override
  String get pointOfSale => 'Point of Sale';

  @override
  String get checkout => 'Checkout';

  @override
  String get retail => 'Retail';

  @override
  String get wholesale => 'Wholesale';

  @override
  String get discount => 'Discount';

  @override
  String get total => 'Total';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get inventory => 'Inventory';

  @override
  String get addMedicine => 'Add medicine';

  @override
  String get customerCredit => 'Customer credit';

  @override
  String get supplierCredit => 'Supplier credit';

  @override
  String get expenses => 'Expenses';

  @override
  String get reports => 'Reports';

  @override
  String get backupRestore => 'Backup & restore';

  @override
  String get signOut => 'Sign out';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get myanmar => 'Myanmar';

  @override
  String get dashboard => 'Dashboard';

  @override
  String signedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String role(String role) {
    return 'Role: $role';
  }

  @override
  String get searchHint => 'Scan or search trade / generic / barcode';

  @override
  String get tapToStart => 'Tap a product to start a sale.';

  @override
  String noProductMatches(String code) {
    return 'No product matches $code.';
  }

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get recordDelivery => 'Record a delivery';

  @override
  String get positionBarcodeInFrame => 'Position barcode within the frame';

  @override
  String get toggleTorch => 'Toggle torch';

  @override
  String noUnitsYet(String name) {
    return '$name has no units configured yet.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get done => 'Done';

  @override
  String get tryAgain => 'Try again';

  @override
  String get edit => 'Edit';

  @override
  String get remove => 'Remove';

  @override
  String get close => 'Close';

  @override
  String get record => 'Record';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authUsernameLabel => 'Username';

  @override
  String get authSecretLabel => 'PIN or password';

  @override
  String get authSetupTitle => 'Create the owner account';

  @override
  String get authSetupBlurb =>
      'This account can see cost prices, edit stock and manage staff. Choose something you will remember — there is no server reset for an offline device.';

  @override
  String get authConfirmLabel => 'Confirm';

  @override
  String get authCreateAccountButton => 'Create account';

  @override
  String authSecretHelper(String min) {
    return 'Minimum $min characters';
  }

  @override
  String authUsernameMinLength(String min) {
    return 'Username must be at least $min characters.';
  }

  @override
  String authSecretMinLength(String min) {
    return 'Use at least $min characters.';
  }

  @override
  String get authPasswordMismatch => 'The two entries do not match.';

  @override
  String get authAccountNotFound => 'Account not found. Try again.';

  @override
  String get authInvalidCredentials => 'Username or PIN is incorrect.';

  @override
  String get authAccountDisabled => 'This account has been disabled.';

  @override
  String get authLastAdminError =>
      'Cannot deactivate the last active admin account.';

  @override
  String authUsernameTaken(String username) {
    return 'Username \"$username\" is already taken.';
  }

  @override
  String get backupEncryptTitle => 'Encrypt backup';

  @override
  String get backupEncryptBlurb =>
      'The database is zipped and encrypted with this passphrase (AES-256-GCM). It is not stored anywhere — lose it and the backup cannot be restored.';

  @override
  String get backupUnlockTitle => 'Unlock backup';

  @override
  String get backupNext => 'Next';

  @override
  String get backupUnlockBlurb =>
      'Enter the passphrase this backup was encrypted with.';

  @override
  String get backupPassphrase => 'Passphrase';

  @override
  String get backupReplaceTitle => 'Replace everything with this backup?';

  @override
  String backupReplaceFrom(String date) {
    return 'From: $date';
  }

  @override
  String backupReplaceSchema(String version) {
    return 'Schema: $version';
  }

  @override
  String get backupOverwriteWarning =>
      'The current live data will be overwritten. This cannot be undone.';

  @override
  String get backupSavedTitle => 'Backup saved';

  @override
  String backupSavedBody(String path, String size) {
    return '$path\n\nUnencrypted database size was $size.';
  }

  @override
  String get backupRestoredTitle => 'Restored';

  @override
  String get backupRestoredBody => 'The app is now reading the backup’s data.';

  @override
  String backupFailedWithReason(String reason) {
    return 'Backup failed: $reason';
  }

  @override
  String backupRestoreFailedWithReason(String reason) {
    return 'Restore failed: $reason';
  }

  @override
  String backupNoFilesFound(String path) {
    return 'No backup files found in $path.';
  }

  @override
  String get backupChooseToRestore => 'Choose a backup to restore';

  @override
  String get backupOwnerOnlyNote =>
      'Only an owner may back up or restore the database.';

  @override
  String backupStorageNote(String path) {
    return 'Backups are written to $path.';
  }

  @override
  String get backupFolderFallback => 'the app’s Backups folder';

  @override
  String get backupCreateTitle => 'Create an encrypted backup';

  @override
  String get backupCreateBody =>
      'Snapshots the live database (VACUUM INTO, so it is consistent and WAL-free), zips it, and encrypts it with a passphrase you choose.';

  @override
  String get backupCreateAction => 'Create backup';

  @override
  String get backupRestoreTitle => 'Restore from a backup';

  @override
  String get backupRestoreBody =>
      'Pick a .pbak file, unlock it, and replace the current database. Everything now on the device is overwritten.';

  @override
  String get backupRestoreAction => 'Restore';

  @override
  String get backupNoManifest => 'Backup carries no manifest.';

  @override
  String get backupMissingDatabase => 'Backup is missing the database file.';

  @override
  String get backupTruncated => 'Backup file is truncated.';

  @override
  String get backupNotPharmacyFile => 'Not a pharmacy backup file.';

  @override
  String backupUnsupportedVersion(String version) {
    return 'Unsupported backup version $version.';
  }

  @override
  String get backupWrongPassphrase =>
      'Wrong passphrase, or the backup was modified.';

  @override
  String get backupPassphraseRequired =>
      'A backup passphrase is required; unencrypted exports are not offered.';

  @override
  String get creditCustomerTitle => 'Customer Credit';

  @override
  String get creditSupplierTitle => 'Supplier Payables';

  @override
  String get creditWordCustomer => 'customer';

  @override
  String get creditWordSupplier => 'supplier';

  @override
  String get creditOwes => 'owes';

  @override
  String get creditIsOwed => 'is owed';

  @override
  String get creditTotalReceivable => 'Total receivable';

  @override
  String get creditTotalPayable => 'Total payable';

  @override
  String creditSearchHint(String party) {
    return 'Search $party name or phone';
  }

  @override
  String creditBalanceLine(String balanceWord, String amount) {
    return '$balanceWord $amount K';
  }

  @override
  String get creditNobodyOwesShop => 'Nobody owes the shop right now.';

  @override
  String get creditShopOwesNobody =>
      'The shop does not owe any supplier right now.';

  @override
  String creditNoMatches(String party, String query) {
    return 'No $party matches “$query”.';
  }

  @override
  String creditTotalForSearch(String label) {
    return '$label (this search)';
  }

  @override
  String get creditRecordPaymentTitle => 'Record a payment';

  @override
  String creditCustomerOwesNow(String name, String amount) {
    return '$name currently owes $amount K.';
  }

  @override
  String creditSupplierOwedNow(String name, String amount) {
    return '$name is currently owed $amount K.';
  }

  @override
  String get creditAmountReceived => 'Amount received';

  @override
  String get creditReferenceNote => 'Reference / note (optional)';

  @override
  String get creditPaymentRecorded => 'Payment recorded.';

  @override
  String get creditReversePaymentTitle => 'Reverse this payment?';

  @override
  String creditReversePaymentBody(String amount) {
    return 'Removes the $amount K receipt and puts the balance back. This is recorded against your account.';
  }

  @override
  String get creditReverse => 'Reverse';

  @override
  String get creditPaymentReversed => 'Payment reversed.';

  @override
  String get creditRecordPayment => 'Record payment';

  @override
  String get creditOutstanding => 'Outstanding';

  @override
  String get creditStatement => 'Statement';

  @override
  String get creditNoLedgerActivity =>
      'No ledger activity for this account yet.';

  @override
  String get creditDebtAdded => 'Credit added';

  @override
  String get creditPaymentReceived => 'Payment received';

  @override
  String get creditReversePaymentTooltip => 'Reverse payment';

  @override
  String get creditPaymentMustBePositive =>
      'Payment must be greater than zero.';

  @override
  String creditPaymentExceedsBalance(String amount) {
    return 'Payment exceeds the outstanding balance of $amount kyat.';
  }

  @override
  String creditCustomerDoesNotExist(String id) {
    return 'Customer $id does not exist.';
  }

  @override
  String creditSupplierDoesNotExist(String id) {
    return 'Supplier $id does not exist.';
  }

  @override
  String get creditLedgerEntryMissing => 'That ledger entry no longer exists.';

  @override
  String get creditOnlyPaymentReversible =>
      'Only a recorded payment can be reversed; a debt is undone by reversing its source sale or purchase.';

  @override
  String get creditDebtEntryPositive => 'A debt entry must be positive.';

  @override
  String get creditPaymentEntryPositive => 'A payment entry must be positive.';

  @override
  String get coreFieldRequired => 'Required';

  @override
  String get coreMoneyFormatError => 'Enter a number, up to two decimals';

  @override
  String get expNewExpense => 'New expense';

  @override
  String get expAmount => 'Amount';

  @override
  String get expNoteOptional => 'Note (optional)';

  @override
  String get expCategory => 'Category';

  @override
  String get expDeleteTitle => 'Delete this expense?';

  @override
  String get expCannotUndo => 'This cannot be undone.';

  @override
  String get expDeleted => 'Expense deleted.';

  @override
  String get expNoExpensesRecorded => 'No expenses recorded yet.';

  @override
  String get expNoExpensesYet => 'No expenses yet.';

  @override
  String get expNeedsCategory => 'An expense needs a category.';

  @override
  String get expAmountMustBePositive => 'Amount must be greater than zero.';

  @override
  String get invEditMedicineTitle => 'Edit medicine';

  @override
  String get invAddMedicineTitle => 'Add medicine';

  @override
  String get invTradeName => 'Trade name';

  @override
  String get invGenericNameOptional => 'Generic name (optional)';

  @override
  String get invTradeNameRequired => 'The name on the shelf is required';

  @override
  String get invCategory => 'Category';

  @override
  String get invShelfLocation => 'Shelf location';

  @override
  String get invBarcode => 'Barcode';

  @override
  String get invBarcodeHelper =>
      'Scan or type the EAN. Blank for loose repackaged stock, which is most local medicines.';

  @override
  String get invLowStockAlertAt => 'Low-stock alert at (optional)';

  @override
  String get invLowStockAlertHelper =>
      'Counted in the smallest unit. Blank means no alert for this item.';

  @override
  String get invUnitsSection => 'Units';

  @override
  String get invAddUnit => 'Add unit';

  @override
  String get invUnitsSectionHint =>
      'Largest package first. Exactly one unit must convert to 1 — that is the unit stock is counted in.';

  @override
  String get invUnitName => 'Unit name';

  @override
  String get invUnitNameHint => 'Box / Strip / Tablet / Bottle';

  @override
  String get invEquals => 'Equals';

  @override
  String get invHolds => 'Holds';

  @override
  String get invRemoveThisUnit => 'Remove this unit';

  @override
  String get invSmallestUnitNote =>
      'Smallest unit — batches are counted in it.';

  @override
  String get invSaveChanges => 'Save changes';

  @override
  String get invSaveMedicine => 'Save medicine';

  @override
  String get invAddAtLeastOneUnit => 'Add at least one unit.';

  @override
  String get invEveryUnitNeedsName => 'Every unit needs a name.';

  @override
  String invUnitMustHoldWholePieces(String unit) {
    return '\"$unit\" must hold whole pieces.';
  }

  @override
  String invRetailPriceForUnit(String unit) {
    return 'Set the retail price for \"$unit\".';
  }

  @override
  String get invShowOnlyLowStock => 'Show only low stock';

  @override
  String get invSearchHint => 'Search name, generic or barcode';

  @override
  String get invLowBadge => 'LOW';

  @override
  String get invNoStockBadge => 'NO STOCK';

  @override
  String invExpiringBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expiring',
      one: '1 expiring',
    );
    return '$_temp0';
  }

  @override
  String invShelfAt(String shelf) {
    return 'Shelf $shelf';
  }

  @override
  String invStockValueK(String money) {
    return 'stock value $money K';
  }

  @override
  String get invNothingMatchesFilter => 'Nothing matches this filter.';

  @override
  String get invClearSearchHint => 'Clear the search box to see the full list.';

  @override
  String get invNoMedicinesYet => 'No medicines yet.';

  @override
  String get invFirstMedicineHint =>
      'Add the first one, then record a delivery to put stock on the shelf.';

  @override
  String get invAskOwnerToAdd =>
      'Ask the owner to add medicines and record a delivery.';

  @override
  String get invInventoryReadFailed => 'The inventory could not be read.';

  @override
  String get invPiecesFallback => 'pieces';

  @override
  String get invNoStockRecordDelivery =>
      'No stock. Record a delivery to add batches.';

  @override
  String invBatchNumber(String number) {
    return 'Batch $number';
  }

  @override
  String invBatchCost(String price) {
    return 'cost $price K';
  }

  @override
  String get invExpired => 'expired';

  @override
  String invDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String invBatchTotals(int batchCount, int quantity) {
    String _temp0 = intl.Intl.pluralLogic(
      batchCount,
      locale: localeName,
      other: '$batchCount batches',
      one: '1 batch',
    );
    return '$_temp0 · $quantity in stock';
  }

  @override
  String invBatchValuationNote(String value) {
    return 'Costed at $value kyat. FEFO sells the earliest expiry first.';
  }

  @override
  String get invNoUnitsConfigured =>
      'This medicine has no units configured. Add at least the smallest unit.';

  @override
  String get invNoSmallestUnit =>
      'No smallest unit configured: every unit converts to more than one piece. Add the single-piece unit with factor 1.';

  @override
  String invMoreThanOneSmallestUnit(String names) {
    return 'More than one smallest unit is configured ($names); exactly one is required.';
  }

  @override
  String get invDuplicateUnitNames =>
      'Unit names must differ per medicine; two units share a name.';

  @override
  String invUnknownUnit(String name) {
    return 'Unknown unit \"$name\" for this medicine.';
  }

  @override
  String invQuantityAtLeast1(int value) {
    return 'Quantity must be at least 1, got $value.';
  }

  @override
  String invQuantityNotNegative(int value) {
    return 'Quantity cannot be negative, got $value.';
  }

  @override
  String get invMedicineNameRequired => 'A medicine name is required.';

  @override
  String invBarcodeTaken(String barcode, String medicine) {
    return 'Barcode $barcode is already on $medicine.';
  }

  @override
  String get invMedicineStillHasStock =>
      'This medicine still has stock. Write it off or transfer it first.';

  @override
  String invBatchRemovalTooLarge(String batch, int remaining, int removal) {
    return 'Only $remaining left in batch $batch; cannot remove $removal.';
  }

  @override
  String get licenseTitle => 'Activate your licence';

  @override
  String get licenseIntro =>
      'Enter the activation key supplied with your pharmacy licence. This is a one-time step.';

  @override
  String get licenseKeyLabel => 'Activation key';

  @override
  String get licenseActivate => 'Activate';

  @override
  String get licenseKeyRequired => 'Enter your activation key.';

  @override
  String get licenseActivationFailed => 'Activation failed.';

  @override
  String get licenseStoredKeyInvalid => 'Stored key could not be verified.';

  @override
  String get licenseKeyNotJwt =>
      'Key must be a JWT: three dot-separated segments.';

  @override
  String get licenseSignatureMismatch =>
      'Signature mismatch — key mistyped, altered, or issued with a different secret.';

  @override
  String get licenseNoFeaturesClaim => 'Key carries no features claim.';

  @override
  String get licenseUnreadableExpiry => 'Unreadable expiry claim in key.';

  @override
  String licenseUnsupportedAlgorithm(String algorithm) {
    return 'Unsupported key algorithm: $algorithm.';
  }

  @override
  String licenseUnknownVendor(String vendor) {
    return 'Key issued by unknown vendor \"$vendor\".';
  }

  @override
  String licenseKeyExpired(String date) {
    return 'Key expired on $date.';
  }

  @override
  String licenseSegmentNotBase64(String label) {
    return '$label segment is not valid base64url.';
  }

  @override
  String licenseSegmentNotJsonObject(String label) {
    return 'The $label must decode to a JSON object.';
  }

  @override
  String licenseSegmentNotJson(String label) {
    return 'The $label is not valid JSON.';
  }

  @override
  String licenseSegmentNotUtf8(String label) {
    return 'The $label is not valid UTF-8.';
  }

  @override
  String get purchChooseSupplier => 'Choose a supplier';

  @override
  String purchOwes(String amount) {
    return 'owes $amount';
  }

  @override
  String get purchSupplier => 'Supplier';

  @override
  String get purchChooseExisting => 'Choose existing';

  @override
  String purchSelectedSupplier(String id) {
    return 'Selected (#$id)';
  }

  @override
  String get purchOrNewSupplierName => 'or new supplier name';

  @override
  String get purchEnterDifferentSupplier => 'Enter a different supplier';

  @override
  String get purchInvoiceGrnNumber => 'Invoice / GRN number (optional)';

  @override
  String get purchLines => 'Lines';

  @override
  String get purchAddLine => 'Add line';

  @override
  String get purchSaveAndAddToStock => 'Save and add to stock';

  @override
  String get purchWhichMedicineArrived => 'Which medicine arrived?';

  @override
  String get purchAddMedicineFirst => 'Add a medicine first.';

  @override
  String get purchChooseMedicine => 'Choose medicine';

  @override
  String get purchRemoveLine => 'Remove line';

  @override
  String get purchBatchExpiryDate => 'Batch expiry date';

  @override
  String get purchBatchNumber => 'Batch number';

  @override
  String get purchExpiry => 'Expiry';

  @override
  String get purchUnit => 'Unit';

  @override
  String get purchQty => 'Qty';

  @override
  String purchCostPerUnit(String unit) {
    return 'Cost per $unit';
  }

  @override
  String get purchPiece => 'piece';

  @override
  String purchAddsUnitsToStock(String count, String unit) {
    return 'Adds $count ${unit}s to stock.';
  }

  @override
  String purchAddsPiecesToStock(String count) {
    return 'Adds $count pieces to stock.';
  }

  @override
  String get purchInvoiceTotal => 'Invoice total';

  @override
  String get purchPaidNow => 'Paid now';

  @override
  String get purchPaidNowHelper =>
      'Leave blank or short to put the balance on the supplier account.';

  @override
  String get purchAddedToPayable => 'Added to payable';

  @override
  String get purchBalance => 'Balance';

  @override
  String purchStockedIn(String amount) {
    return 'Stocked in $amount kyat';
  }

  @override
  String purchLinesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '1 line',
    );
    return '$_temp0';
  }

  @override
  String purchNewBatchesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new batches',
      one: '1 new batch',
    );
    return '$_temp0';
  }

  @override
  String purchMergedIntoExisting(String count) {
    return '$count merged into an existing batch';
  }

  @override
  String purchBalanceAdded(String amount) {
    return 'Balance of $amount kyat added to the supplier account.';
  }

  @override
  String get purchPaidInFull =>
      'Paid in full — nothing added to the supplier account.';

  @override
  String get purchPickSupplierOrName => 'Choose a supplier or type a new name.';

  @override
  String purchLinePickMedicine(String number) {
    return 'Line $number: pick a medicine.';
  }

  @override
  String purchLineBatchNumber(String number) {
    return 'Line $number: the batch number is printed on the carton.';
  }

  @override
  String purchLineExpiryDate(String number) {
    return 'Line $number: set the expiry date.';
  }

  @override
  String purchLineQuantity(String number) {
    return 'Line $number: quantity must be at least 1.';
  }

  @override
  String purchLineCost(String number) {
    return 'Line $number: set the cost price.';
  }

  @override
  String purchPaidExceedsTotal(String paid, String total) {
    return 'Paid $paid is more than the $total invoice.';
  }

  @override
  String get purchSupplierNameRequired => 'Supplier name is required.';

  @override
  String get purchPaymentMustBePositive => 'Payment must be greater than zero.';

  @override
  String purchPaymentExceedsBalance(String amount) {
    return 'Payment exceeds the outstanding balance of $amount kyat.';
  }

  @override
  String get purchAddAtLeastOneLine => 'Add at least one medicine line.';

  @override
  String purchDuplicateSaleUnit(String batch) {
    return 'The same batch ($batch) appears twice for one medicine. Combine the quantities into a single line.';
  }

  @override
  String get purchPaidNotNegative => 'Paid amount cannot be negative.';

  @override
  String purchPaidExceedsInvoice(String paid, String total) {
    return 'Paid $paid exceeds the invoice total of $total.';
  }

  @override
  String get purchEveryLineNeedsBatch => 'Every line needs a batch number.';

  @override
  String get purchQuantityAtLeast1 => 'Quantity must be at least 1.';

  @override
  String get purchCostNotNegative => 'Cost price cannot be negative.';

  @override
  String get purchFactorAtLeast1 => 'Unit conversion factor must be 1 or more.';

  @override
  String purchBatchAlreadyExpired(String batch) {
    return 'Batch $batch is already expired. Refuse the delivery or record it as a write-off.';
  }

  @override
  String purchSupplierDoesNotExist(String id) {
    return 'Supplier $id does not exist.';
  }

  @override
  String get reportTitleToday => 'Reports — today';

  @override
  String get reportSalesToday => 'Today\'s sales';

  @override
  String reportVoucherCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vouchers',
      one: '1 voucher',
    );
    return '$_temp0';
  }

  @override
  String get reportNetProfit => 'Net profit';

  @override
  String get reportNetProfitFormula => 'sales − cost − expenses';

  @override
  String get reportReceivable => 'Receivable';

  @override
  String get reportReceivableCaption => 'owed to the shop';

  @override
  String get reportPayable => 'Payable';

  @override
  String get reportPayableCaption => 'the shop owes';

  @override
  String get reportLowStock => 'Low stock';

  @override
  String get reportLowStockEmpty => 'Nothing is below its reorder level.';

  @override
  String reportExpiringWithinDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expiring within $days days',
      one: 'Expiring within 1 day',
    );
    return '$_temp0';
  }

  @override
  String get reportExpiringEmpty => 'No batch expires in the window.';

  @override
  String reportExpiredDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'expired ${days}d ago',
      one: 'expired 1d ago',
    );
    return '$_temp0';
  }

  @override
  String reportDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String reportBatchNumber(int id) {
    return 'Batch #$id';
  }

  @override
  String get reportProfitBuildTitle => 'How net profit is built';

  @override
  String get reportTotalSales => 'Total sales';

  @override
  String get reportMinusCostOfGoods => '− Cost of goods';

  @override
  String get reportMinusExpenses => '− Expenses';

  @override
  String reportAndMoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more',
      one: '1 more',
    );
    return '…and $_temp0';
  }

  @override
  String get dashDevLicenceTitle => 'Development licence secret in use';

  @override
  String get dashDevLicenceBody =>
      'This build verifies keys against the placeholder secret that is committed to the repository. Build with --dart-define=PHARMACY_LICENSE_SECRET=… before issuing a customer key.';

  @override
  String get dashLicence => 'Licence';

  @override
  String dashLicenceNamed(String client) {
    return 'Licence: $client';
  }

  @override
  String dashStatusLine(String status) {
    return 'Status: $status';
  }

  @override
  String dashExpiresLine(String date) {
    return 'Expires: $date';
  }

  @override
  String dashModulesLine(String modules) {
    return 'Modules: $modules';
  }

  @override
  String get dashLicenceNever => 'never (perpetual licence)';

  @override
  String get dashStatusUnknown => 'unknown';

  @override
  String get dashStatusNotActivated => 'not activated';

  @override
  String get dashStatusActive => 'active';

  @override
  String get dashStatusInvalidKey => 'invalid key';

  @override
  String get dashStatusExpired => 'expired';

  @override
  String get dashYourAccess => 'Your access';

  @override
  String get dashAccessCostVisible =>
      'Cost prices and profit reports are visible to your role.';

  @override
  String dashAccessCostHidden(String role) {
    return 'Cost prices and profit reports are hidden for the $role role.';
  }

  @override
  String get dashPhase5Note =>
      'Phase 5 — credit ledgers, expenses, daily profit reports and encrypted database backup.';

  @override
  String dashLicenceExpiresInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Licence expires in $days days',
      one: 'Licence expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String dashLicenceExpiredDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Licence expired $days days ago',
      one: 'Licence expired 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get dashLicenceRenewBody =>
      'Renew before then to keep using the app. Your data stays on this device; entering a new activation key restores access immediately.';

  @override
  String get notifChannelName => 'Expiring Stock Alerts';

  @override
  String get notifChannelDescription =>
      'Notifications for batches expiring soon';

  @override
  String get notifBatchExpiringSoon => 'Batch expiring soon';

  @override
  String notifExpiryBody(String name, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$name expires in $_temp0';
  }

  @override
  String get notifUnknown => 'Unknown';

  @override
  String get saleNoMatchesClearSearch =>
      'Nothing matches. Clear the search to see the catalogue.';

  @override
  String get saleNoUnitsSetBadge => 'no units set';

  @override
  String get saleOneSellableUnit => 'This product has one sellable unit.';

  @override
  String saleSellAs(String name) {
    return 'Sell $name as';
  }

  @override
  String get saleDiscountOverSubtotal => 'More than the subtotal';

  @override
  String get saleEnterNumber => 'Enter a number';

  @override
  String get saleCartEmpty => 'Your cart is empty.';

  @override
  String saleCartLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines',
      one: '$count line',
    );
    return '$_temp0';
  }

  @override
  String get saleReceivedLabel => 'Received';

  @override
  String saleChargeOnCredit(String amount) {
    return 'Charge $amount K on credit';
  }

  @override
  String get saleCompleteSale => 'Complete sale';

  @override
  String saleNoCustomersYet(String screen) {
    return 'No customers yet. Create one in $screen.';
  }

  @override
  String get saleChargeThisSaleTo => 'Charge this sale to';

  @override
  String saleDebtAndLimit(String debt, String limit) {
    return 'Debt $debt · limit $limit K';
  }

  @override
  String get saleCash => 'Cash';

  @override
  String get saleBalanceOnCredit => 'Balance on credit';

  @override
  String get saleChange => 'Change';

  @override
  String get salePickACustomer => 'Pick a customer';

  @override
  String get salePaidInFull => 'Paid in full';

  @override
  String saleCarriesBalance(String name) {
    return '$name carries the balance';
  }

  @override
  String get saleClear => 'Clear';

  @override
  String get saleChoose => 'Choose';

  @override
  String get saleConfirmedTitle => 'Sale complete';

  @override
  String saleVoucherNumber(String number) {
    return 'Voucher: $number';
  }

  @override
  String saleTotalAmount(String amount) {
    return 'Total $amount K';
  }

  @override
  String saleChangeAmount(String amount) {
    return 'Change $amount K';
  }

  @override
  String saleOnCreditAmount(String amount) {
    return 'On credit $amount K';
  }

  @override
  String get saleNewSale => 'New sale';

  @override
  String get saleVoucher => 'Voucher';

  @override
  String saleVoucherReady(String file, String bytes) {
    return 'Voucher $file ready ($bytes bytes). Printing hardware wiring lands with the on-device pass.';
  }

  @override
  String saleVoucherBuildFailed(String error) {
    return 'Could not build the voucher: $error';
  }

  @override
  String saleCouldNotComplete(String error) {
    return 'Could not complete the sale: $error';
  }

  @override
  String get saleSessionExpired => 'Session expired — sign in again to sell.';

  @override
  String get saleChooseCustomerForBalance =>
      'Choose a customer to carry the balance.';

  @override
  String get saleKpayFullPayment => 'A KPay sale must be paid in full.';

  @override
  String get saleStaff => 'staff';

  @override
  String saleItemFallback(String id) {
    return 'Item $id';
  }

  @override
  String get saleCustomerNameRequired => 'Customer name is required.';

  @override
  String get saleCreditLimitNotNegative => 'Credit limit cannot be negative.';

  @override
  String get salePaymentMustBePositive => 'Payment must be greater than zero.';

  @override
  String salePaymentExceedsBalance(String balance) {
    return 'Payment exceeds the outstanding balance of $balance kyat.';
  }

  @override
  String get saleCartIsEmpty => 'The cart is empty.';

  @override
  String get saleDiscountNotNegative => 'Discount cannot be negative.';

  @override
  String get saleReceivedNotNegative => 'Received amount cannot be negative.';

  @override
  String saleDiscountExceedsSubtotal(String discount, String subtotal) {
    return 'Discount of $discount exceeds the subtotal of $subtotal.';
  }

  @override
  String get saleBalanceNeedsCustomer =>
      'A sale with an unpaid balance must be charged to a customer.';

  @override
  String get salePartialPaymentNotKPay =>
      'Partial payment cannot be a KPay sale. Record the balance as a credit or take full payment.';

  @override
  String get saleQuantityAtLeast1 => 'Quantity must be at least 1.';

  @override
  String get saleUnitPriceNotNegative => 'Unit price cannot be negative.';

  @override
  String get saleFactorAtLeast1 => 'Unit conversion factor must be 1 or more.';

  @override
  String get saleLineMustNameUnit => 'A sale line must name its unit.';

  @override
  String saleCustomerDoesNotExist(String id) {
    return 'Customer $id does not exist.';
  }

  @override
  String saleCustomerNotActive(String name) {
    return '$name is not an active customer.';
  }

  @override
  String saleOverCreditLimit(String name, String projected, String limit) {
    return '$name is over their credit limit: this sale would take their balance to $projected, above the $limit limit.';
  }

  @override
  String saleShortage(String requested, String available) {
    return 'Not enough stock: $requested needed but only $available available.';
  }

  @override
  String saleProductShortage(
    String product,
    String available,
    String requested,
  ) {
    return '$product — only $available of $requested in stock';
  }

  @override
  String get saleLineMinOneUnit =>
      'A sale line must take at least one smallest unit.';

  @override
  String get saleVoucherDateLabel => 'Date';

  @override
  String get saleVoucherCustomerLabel => 'Customer';

  @override
  String get saleVoucherCashierLabel => 'Cashier';

  @override
  String get saleVoucherTypeLabel => 'Type';

  @override
  String get saleVoucherBalanceDue => 'Balance due';

  @override
  String get saleVoucherItemHeader => 'Item';

  @override
  String get saleVoucherQtyHeader => 'Qty';

  @override
  String get saleVoucherPriceHeader => 'Price';

  @override
  String get saleVoucherThankYou => 'Thank you. Keep this voucher for returns.';

  @override
  String get saleVoucherShopName => 'Pharmacy';
}
