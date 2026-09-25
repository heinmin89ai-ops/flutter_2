import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_my.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('my'),
  ];

  /// The application title shown in the app bar.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy POS'**
  String get appTitle;

  /// No description provided for @pointOfSale.
  ///
  /// In en, this message translates to:
  /// **'Point of Sale'**
  String get pointOfSale;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @retail.
  ///
  /// In en, this message translates to:
  /// **'Retail'**
  String get retail;

  /// No description provided for @wholesale.
  ///
  /// In en, this message translates to:
  /// **'Wholesale'**
  String get wholesale;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @addMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get addMedicine;

  /// No description provided for @customerCredit.
  ///
  /// In en, this message translates to:
  /// **'Customer credit'**
  String get customerCredit;

  /// No description provided for @supplierCredit.
  ///
  /// In en, this message translates to:
  /// **'Supplier credit'**
  String get supplierCredit;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupRestore;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @myanmar.
  ///
  /// In en, this message translates to:
  /// **'Myanmar'**
  String get myanmar;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username}'**
  String signedInAs(String username);

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role: {role}'**
  String role(String role);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Scan or search trade / generic / barcode'**
  String get searchHint;

  /// No description provided for @tapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap a product to start a sale.'**
  String get tapToStart;

  /// No description provided for @noProductMatches.
  ///
  /// In en, this message translates to:
  /// **'No product matches {code}.'**
  String noProductMatches(String code);

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanBarcode;

  /// No description provided for @recordDelivery.
  ///
  /// In en, this message translates to:
  /// **'Record a delivery'**
  String get recordDelivery;

  /// No description provided for @positionBarcodeInFrame.
  ///
  /// In en, this message translates to:
  /// **'Position barcode within the frame'**
  String get positionBarcodeInFrame;

  /// No description provided for @toggleTorch.
  ///
  /// In en, this message translates to:
  /// **'Toggle torch'**
  String get toggleTorch;

  /// No description provided for @noUnitsYet.
  ///
  /// In en, this message translates to:
  /// **'{name} has no units configured yet.'**
  String noUnitsYet(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInTitle;

  /// No description provided for @authSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// No description provided for @authUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsernameLabel;

  /// No description provided for @authSecretLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN or password'**
  String get authSecretLabel;

  /// No description provided for @authSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create the owner account'**
  String get authSetupTitle;

  /// No description provided for @authSetupBlurb.
  ///
  /// In en, this message translates to:
  /// **'This account can see cost prices, edit stock and manage staff. Choose something you will remember — there is no server reset for an offline device.'**
  String get authSetupBlurb;

  /// No description provided for @authConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get authConfirmLabel;

  /// No description provided for @authCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountButton;

  /// No description provided for @authSecretHelper.
  ///
  /// In en, this message translates to:
  /// **'Minimum {min} characters'**
  String authSecretHelper(String min);

  /// No description provided for @authUsernameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least {min} characters.'**
  String authUsernameMinLength(String min);

  /// No description provided for @authSecretMinLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters.'**
  String authSecretMinLength(String min);

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two entries do not match.'**
  String get authPasswordMismatch;

  /// No description provided for @authAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found. Try again.'**
  String get authAccountNotFound;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Username or PIN is incorrect.'**
  String get authInvalidCredentials;

  /// No description provided for @authAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authAccountDisabled;

  /// No description provided for @authLastAdminError.
  ///
  /// In en, this message translates to:
  /// **'Cannot deactivate the last active admin account.'**
  String get authLastAdminError;

  /// No description provided for @authUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username \"{username}\" is already taken.'**
  String authUsernameTaken(String username);

  /// No description provided for @backupEncryptTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypt backup'**
  String get backupEncryptTitle;

  /// No description provided for @backupEncryptBlurb.
  ///
  /// In en, this message translates to:
  /// **'The database is zipped and encrypted with this passphrase (AES-256-GCM). It is not stored anywhere — lose it and the backup cannot be restored.'**
  String get backupEncryptBlurb;

  /// No description provided for @backupUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock backup'**
  String get backupUnlockTitle;

  /// No description provided for @backupNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get backupNext;

  /// No description provided for @backupUnlockBlurb.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase this backup was encrypted with.'**
  String get backupUnlockBlurb;

  /// No description provided for @backupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get backupPassphrase;

  /// No description provided for @backupReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace everything with this backup?'**
  String get backupReplaceTitle;

  /// No description provided for @backupReplaceFrom.
  ///
  /// In en, this message translates to:
  /// **'From: {date}'**
  String backupReplaceFrom(String date);

  /// No description provided for @backupReplaceSchema.
  ///
  /// In en, this message translates to:
  /// **'Schema: {version}'**
  String backupReplaceSchema(String version);

  /// No description provided for @backupOverwriteWarning.
  ///
  /// In en, this message translates to:
  /// **'The current live data will be overwritten. This cannot be undone.'**
  String get backupOverwriteWarning;

  /// No description provided for @backupSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get backupSavedTitle;

  /// No description provided for @backupSavedBody.
  ///
  /// In en, this message translates to:
  /// **'{path}\n\nUnencrypted database size was {size}.'**
  String backupSavedBody(String path, String size);

  /// No description provided for @backupRestoredTitle.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get backupRestoredTitle;

  /// No description provided for @backupRestoredBody.
  ///
  /// In en, this message translates to:
  /// **'The app is now reading the backup’s data.'**
  String get backupRestoredBody;

  /// No description provided for @backupFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {reason}'**
  String backupFailedWithReason(String reason);

  /// No description provided for @backupRestoreFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {reason}'**
  String backupRestoreFailedWithReason(String reason);

  /// No description provided for @backupNoFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No backup files found in {path}.'**
  String backupNoFilesFound(String path);

  /// No description provided for @backupChooseToRestore.
  ///
  /// In en, this message translates to:
  /// **'Choose a backup to restore'**
  String get backupChooseToRestore;

  /// No description provided for @backupOwnerOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Only an owner may back up or restore the database.'**
  String get backupOwnerOnlyNote;

  /// No description provided for @backupStorageNote.
  ///
  /// In en, this message translates to:
  /// **'Backups are written to {path}.'**
  String backupStorageNote(String path);

  /// No description provided for @backupFolderFallback.
  ///
  /// In en, this message translates to:
  /// **'the app’s Backups folder'**
  String get backupFolderFallback;

  /// No description provided for @backupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an encrypted backup'**
  String get backupCreateTitle;

  /// No description provided for @backupCreateBody.
  ///
  /// In en, this message translates to:
  /// **'Snapshots the live database (VACUUM INTO, so it is consistent and WAL-free), zips it, and encrypts it with a passphrase you choose.'**
  String get backupCreateBody;

  /// No description provided for @backupCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupCreateAction;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a .pbak file, unlock it, and replace the current database. Everything now on the device is overwritten.'**
  String get backupRestoreBody;

  /// No description provided for @backupRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreAction;

  /// No description provided for @backupNoManifest.
  ///
  /// In en, this message translates to:
  /// **'Backup carries no manifest.'**
  String get backupNoManifest;

  /// No description provided for @backupMissingDatabase.
  ///
  /// In en, this message translates to:
  /// **'Backup is missing the database file.'**
  String get backupMissingDatabase;

  /// No description provided for @backupTruncated.
  ///
  /// In en, this message translates to:
  /// **'Backup file is truncated.'**
  String get backupTruncated;

  /// No description provided for @backupNotPharmacyFile.
  ///
  /// In en, this message translates to:
  /// **'Not a pharmacy backup file.'**
  String get backupNotPharmacyFile;

  /// No description provided for @backupUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'Unsupported backup version {version}.'**
  String backupUnsupportedVersion(String version);

  /// No description provided for @backupWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase, or the backup was modified.'**
  String get backupWrongPassphrase;

  /// No description provided for @backupPassphraseRequired.
  ///
  /// In en, this message translates to:
  /// **'A backup passphrase is required; unencrypted exports are not offered.'**
  String get backupPassphraseRequired;

  /// No description provided for @creditCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer Credit'**
  String get creditCustomerTitle;

  /// No description provided for @creditSupplierTitle.
  ///
  /// In en, this message translates to:
  /// **'Supplier Payables'**
  String get creditSupplierTitle;

  /// No description provided for @creditWordCustomer.
  ///
  /// In en, this message translates to:
  /// **'customer'**
  String get creditWordCustomer;

  /// No description provided for @creditWordSupplier.
  ///
  /// In en, this message translates to:
  /// **'supplier'**
  String get creditWordSupplier;

  /// No description provided for @creditOwes.
  ///
  /// In en, this message translates to:
  /// **'owes'**
  String get creditOwes;

  /// No description provided for @creditIsOwed.
  ///
  /// In en, this message translates to:
  /// **'is owed'**
  String get creditIsOwed;

  /// No description provided for @creditTotalReceivable.
  ///
  /// In en, this message translates to:
  /// **'Total receivable'**
  String get creditTotalReceivable;

  /// No description provided for @creditTotalPayable.
  ///
  /// In en, this message translates to:
  /// **'Total payable'**
  String get creditTotalPayable;

  /// No description provided for @creditSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search {party} name or phone'**
  String creditSearchHint(String party);

  /// No description provided for @creditBalanceLine.
  ///
  /// In en, this message translates to:
  /// **'{balanceWord} {amount} K'**
  String creditBalanceLine(String balanceWord, String amount);

  /// No description provided for @creditNobodyOwesShop.
  ///
  /// In en, this message translates to:
  /// **'Nobody owes the shop right now.'**
  String get creditNobodyOwesShop;

  /// No description provided for @creditShopOwesNobody.
  ///
  /// In en, this message translates to:
  /// **'The shop does not owe any supplier right now.'**
  String get creditShopOwesNobody;

  /// No description provided for @creditNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No {party} matches “{query}”.'**
  String creditNoMatches(String party, String query);

  /// No description provided for @creditTotalForSearch.
  ///
  /// In en, this message translates to:
  /// **'{label} (this search)'**
  String creditTotalForSearch(String label);

  /// No description provided for @creditRecordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a payment'**
  String get creditRecordPaymentTitle;

  /// No description provided for @creditCustomerOwesNow.
  ///
  /// In en, this message translates to:
  /// **'{name} currently owes {amount} K.'**
  String creditCustomerOwesNow(String name, String amount);

  /// No description provided for @creditSupplierOwedNow.
  ///
  /// In en, this message translates to:
  /// **'{name} is currently owed {amount} K.'**
  String creditSupplierOwedNow(String name, String amount);

  /// No description provided for @creditAmountReceived.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get creditAmountReceived;

  /// No description provided for @creditReferenceNote.
  ///
  /// In en, this message translates to:
  /// **'Reference / note (optional)'**
  String get creditReferenceNote;

  /// No description provided for @creditPaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded.'**
  String get creditPaymentRecorded;

  /// No description provided for @creditReversePaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse this payment?'**
  String get creditReversePaymentTitle;

  /// No description provided for @creditReversePaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Removes the {amount} K receipt and puts the balance back. This is recorded against your account.'**
  String creditReversePaymentBody(String amount);

  /// No description provided for @creditReverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get creditReverse;

  /// No description provided for @creditPaymentReversed.
  ///
  /// In en, this message translates to:
  /// **'Payment reversed.'**
  String get creditPaymentReversed;

  /// No description provided for @creditRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get creditRecordPayment;

  /// No description provided for @creditOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get creditOutstanding;

  /// No description provided for @creditStatement.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get creditStatement;

  /// No description provided for @creditNoLedgerActivity.
  ///
  /// In en, this message translates to:
  /// **'No ledger activity for this account yet.'**
  String get creditNoLedgerActivity;

  /// No description provided for @creditDebtAdded.
  ///
  /// In en, this message translates to:
  /// **'Credit added'**
  String get creditDebtAdded;

  /// No description provided for @creditPaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get creditPaymentReceived;

  /// No description provided for @creditReversePaymentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reverse payment'**
  String get creditReversePaymentTooltip;

  /// No description provided for @creditPaymentMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Payment must be greater than zero.'**
  String get creditPaymentMustBePositive;

  /// No description provided for @creditPaymentExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Payment exceeds the outstanding balance of {amount} kyat.'**
  String creditPaymentExceedsBalance(String amount);

  /// No description provided for @creditCustomerDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Customer {id} does not exist.'**
  String creditCustomerDoesNotExist(String id);

  /// No description provided for @creditSupplierDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Supplier {id} does not exist.'**
  String creditSupplierDoesNotExist(String id);

  /// No description provided for @creditLedgerEntryMissing.
  ///
  /// In en, this message translates to:
  /// **'That ledger entry no longer exists.'**
  String get creditLedgerEntryMissing;

  /// No description provided for @creditOnlyPaymentReversible.
  ///
  /// In en, this message translates to:
  /// **'Only a recorded payment can be reversed; a debt is undone by reversing its source sale or purchase.'**
  String get creditOnlyPaymentReversible;

  /// No description provided for @creditDebtEntryPositive.
  ///
  /// In en, this message translates to:
  /// **'A debt entry must be positive.'**
  String get creditDebtEntryPositive;

  /// No description provided for @creditPaymentEntryPositive.
  ///
  /// In en, this message translates to:
  /// **'A payment entry must be positive.'**
  String get creditPaymentEntryPositive;

  /// No description provided for @coreFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get coreFieldRequired;

  /// No description provided for @coreMoneyFormatError.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, up to two decimals'**
  String get coreMoneyFormatError;

  /// No description provided for @expNewExpense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get expNewExpense;

  /// No description provided for @expAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expAmount;

  /// No description provided for @expNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get expNoteOptional;

  /// No description provided for @expCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expCategory;

  /// No description provided for @expDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get expDeleteTitle;

  /// No description provided for @expCannotUndo.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get expCannotUndo;

  /// No description provided for @expDeleted.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted.'**
  String get expDeleted;

  /// No description provided for @expNoExpensesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No expenses recorded yet.'**
  String get expNoExpensesRecorded;

  /// No description provided for @expNoExpensesYet.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet.'**
  String get expNoExpensesYet;

  /// No description provided for @expNeedsCategory.
  ///
  /// In en, this message translates to:
  /// **'An expense needs a category.'**
  String get expNeedsCategory;

  /// No description provided for @expAmountMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero.'**
  String get expAmountMustBePositive;

  /// No description provided for @invEditMedicineTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit medicine'**
  String get invEditMedicineTitle;

  /// No description provided for @invAddMedicineTitle.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get invAddMedicineTitle;

  /// No description provided for @invTradeName.
  ///
  /// In en, this message translates to:
  /// **'Trade name'**
  String get invTradeName;

  /// No description provided for @invGenericNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Generic name (optional)'**
  String get invGenericNameOptional;

  /// No description provided for @invTradeNameRequired.
  ///
  /// In en, this message translates to:
  /// **'The name on the shelf is required'**
  String get invTradeNameRequired;

  /// No description provided for @invCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get invCategory;

  /// No description provided for @invShelfLocation.
  ///
  /// In en, this message translates to:
  /// **'Shelf location'**
  String get invShelfLocation;

  /// No description provided for @invBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get invBarcode;

  /// No description provided for @invBarcodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Scan or type the EAN. Blank for loose repackaged stock, which is most local medicines.'**
  String get invBarcodeHelper;

  /// No description provided for @invLowStockAlertAt.
  ///
  /// In en, this message translates to:
  /// **'Low-stock alert at (optional)'**
  String get invLowStockAlertAt;

  /// No description provided for @invLowStockAlertHelper.
  ///
  /// In en, this message translates to:
  /// **'Counted in the smallest unit. Blank means no alert for this item.'**
  String get invLowStockAlertHelper;

  /// No description provided for @invUnitsSection.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get invUnitsSection;

  /// No description provided for @invAddUnit.
  ///
  /// In en, this message translates to:
  /// **'Add unit'**
  String get invAddUnit;

  /// No description provided for @invUnitsSectionHint.
  ///
  /// In en, this message translates to:
  /// **'Largest package first. Exactly one unit must convert to 1 — that is the unit stock is counted in.'**
  String get invUnitsSectionHint;

  /// No description provided for @invUnitName.
  ///
  /// In en, this message translates to:
  /// **'Unit name'**
  String get invUnitName;

  /// No description provided for @invUnitNameHint.
  ///
  /// In en, this message translates to:
  /// **'Box / Strip / Tablet / Bottle'**
  String get invUnitNameHint;

  /// No description provided for @invEquals.
  ///
  /// In en, this message translates to:
  /// **'Equals'**
  String get invEquals;

  /// No description provided for @invHolds.
  ///
  /// In en, this message translates to:
  /// **'Holds'**
  String get invHolds;

  /// No description provided for @invRemoveThisUnit.
  ///
  /// In en, this message translates to:
  /// **'Remove this unit'**
  String get invRemoveThisUnit;

  /// No description provided for @invSmallestUnitNote.
  ///
  /// In en, this message translates to:
  /// **'Smallest unit — batches are counted in it.'**
  String get invSmallestUnitNote;

  /// No description provided for @invSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get invSaveChanges;

  /// No description provided for @invSaveMedicine.
  ///
  /// In en, this message translates to:
  /// **'Save medicine'**
  String get invSaveMedicine;

  /// No description provided for @invAddAtLeastOneUnit.
  ///
  /// In en, this message translates to:
  /// **'Add at least one unit.'**
  String get invAddAtLeastOneUnit;

  /// No description provided for @invEveryUnitNeedsName.
  ///
  /// In en, this message translates to:
  /// **'Every unit needs a name.'**
  String get invEveryUnitNeedsName;

  /// No description provided for @invUnitMustHoldWholePieces.
  ///
  /// In en, this message translates to:
  /// **'\"{unit}\" must hold whole pieces.'**
  String invUnitMustHoldWholePieces(String unit);

  /// No description provided for @invRetailPriceForUnit.
  ///
  /// In en, this message translates to:
  /// **'Set the retail price for \"{unit}\".'**
  String invRetailPriceForUnit(String unit);

  /// No description provided for @invShowOnlyLowStock.
  ///
  /// In en, this message translates to:
  /// **'Show only low stock'**
  String get invShowOnlyLowStock;

  /// No description provided for @invSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search name, generic or barcode'**
  String get invSearchHint;

  /// No description provided for @invLowBadge.
  ///
  /// In en, this message translates to:
  /// **'LOW'**
  String get invLowBadge;

  /// No description provided for @invNoStockBadge.
  ///
  /// In en, this message translates to:
  /// **'NO STOCK'**
  String get invNoStockBadge;

  /// No description provided for @invExpiringBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expiring} other{{count} expiring}}'**
  String invExpiringBadge(int count);

  /// No description provided for @invShelfAt.
  ///
  /// In en, this message translates to:
  /// **'Shelf {shelf}'**
  String invShelfAt(String shelf);

  /// No description provided for @invStockValueK.
  ///
  /// In en, this message translates to:
  /// **'stock value {money} K'**
  String invStockValueK(String money);

  /// No description provided for @invNothingMatchesFilter.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches this filter.'**
  String get invNothingMatchesFilter;

  /// No description provided for @invClearSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Clear the search box to see the full list.'**
  String get invClearSearchHint;

  /// No description provided for @invNoMedicinesYet.
  ///
  /// In en, this message translates to:
  /// **'No medicines yet.'**
  String get invNoMedicinesYet;

  /// No description provided for @invFirstMedicineHint.
  ///
  /// In en, this message translates to:
  /// **'Add the first one, then record a delivery to put stock on the shelf.'**
  String get invFirstMedicineHint;

  /// No description provided for @invAskOwnerToAdd.
  ///
  /// In en, this message translates to:
  /// **'Ask the owner to add medicines and record a delivery.'**
  String get invAskOwnerToAdd;

  /// No description provided for @invInventoryReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The inventory could not be read.'**
  String get invInventoryReadFailed;

  /// No description provided for @invPiecesFallback.
  ///
  /// In en, this message translates to:
  /// **'pieces'**
  String get invPiecesFallback;

  /// No description provided for @invNoStockRecordDelivery.
  ///
  /// In en, this message translates to:
  /// **'No stock. Record a delivery to add batches.'**
  String get invNoStockRecordDelivery;

  /// No description provided for @invBatchNumber.
  ///
  /// In en, this message translates to:
  /// **'Batch {number}'**
  String invBatchNumber(String number);

  /// No description provided for @invBatchCost.
  ///
  /// In en, this message translates to:
  /// **'cost {price} K'**
  String invBatchCost(String price);

  /// No description provided for @invExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get invExpired;

  /// No description provided for @invDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String invDaysLeft(int count);

  /// No description provided for @invBatchTotals.
  ///
  /// In en, this message translates to:
  /// **'{batchCount, plural, =1{1 batch} other{{batchCount} batches}} · {quantity} in stock'**
  String invBatchTotals(int batchCount, int quantity);

  /// No description provided for @invBatchValuationNote.
  ///
  /// In en, this message translates to:
  /// **'Costed at {value} kyat. FEFO sells the earliest expiry first.'**
  String invBatchValuationNote(String value);

  /// No description provided for @invNoUnitsConfigured.
  ///
  /// In en, this message translates to:
  /// **'This medicine has no units configured. Add at least the smallest unit.'**
  String get invNoUnitsConfigured;

  /// No description provided for @invNoSmallestUnit.
  ///
  /// In en, this message translates to:
  /// **'No smallest unit configured: every unit converts to more than one piece. Add the single-piece unit with factor 1.'**
  String get invNoSmallestUnit;

  /// No description provided for @invMoreThanOneSmallestUnit.
  ///
  /// In en, this message translates to:
  /// **'More than one smallest unit is configured ({names}); exactly one is required.'**
  String invMoreThanOneSmallestUnit(String names);

  /// No description provided for @invDuplicateUnitNames.
  ///
  /// In en, this message translates to:
  /// **'Unit names must differ per medicine; two units share a name.'**
  String get invDuplicateUnitNames;

  /// No description provided for @invUnknownUnit.
  ///
  /// In en, this message translates to:
  /// **'Unknown unit \"{name}\" for this medicine.'**
  String invUnknownUnit(String name);

  /// No description provided for @invQuantityAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'Quantity must be at least 1, got {value}.'**
  String invQuantityAtLeast1(int value);

  /// No description provided for @invQuantityNotNegative.
  ///
  /// In en, this message translates to:
  /// **'Quantity cannot be negative, got {value}.'**
  String invQuantityNotNegative(int value);

  /// No description provided for @invMedicineNameRequired.
  ///
  /// In en, this message translates to:
  /// **'A medicine name is required.'**
  String get invMedicineNameRequired;

  /// No description provided for @invBarcodeTaken.
  ///
  /// In en, this message translates to:
  /// **'Barcode {barcode} is already on {medicine}.'**
  String invBarcodeTaken(String barcode, String medicine);

  /// No description provided for @invMedicineStillHasStock.
  ///
  /// In en, this message translates to:
  /// **'This medicine still has stock. Write it off or transfer it first.'**
  String get invMedicineStillHasStock;

  /// No description provided for @invBatchRemovalTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Only {remaining} left in batch {batch}; cannot remove {removal}.'**
  String invBatchRemovalTooLarge(String batch, int remaining, int removal);

  /// No description provided for @licenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate your licence'**
  String get licenseTitle;

  /// No description provided for @licenseIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the activation key supplied with your pharmacy licence. This is a one-time step.'**
  String get licenseIntro;

  /// No description provided for @licenseKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Activation key'**
  String get licenseKeyLabel;

  /// No description provided for @licenseActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get licenseActivate;

  /// No description provided for @licenseKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your activation key.'**
  String get licenseKeyRequired;

  /// No description provided for @licenseActivationFailed.
  ///
  /// In en, this message translates to:
  /// **'Activation failed.'**
  String get licenseActivationFailed;

  /// No description provided for @licenseStoredKeyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Stored key could not be verified.'**
  String get licenseStoredKeyInvalid;

  /// No description provided for @licenseKeyNotJwt.
  ///
  /// In en, this message translates to:
  /// **'Key must be a JWT: three dot-separated segments.'**
  String get licenseKeyNotJwt;

  /// No description provided for @licenseSignatureMismatch.
  ///
  /// In en, this message translates to:
  /// **'Signature mismatch — key mistyped, altered, or issued with a different secret.'**
  String get licenseSignatureMismatch;

  /// No description provided for @licenseNoFeaturesClaim.
  ///
  /// In en, this message translates to:
  /// **'Key carries no features claim.'**
  String get licenseNoFeaturesClaim;

  /// No description provided for @licenseUnreadableExpiry.
  ///
  /// In en, this message translates to:
  /// **'Unreadable expiry claim in key.'**
  String get licenseUnreadableExpiry;

  /// No description provided for @licenseUnsupportedAlgorithm.
  ///
  /// In en, this message translates to:
  /// **'Unsupported key algorithm: {algorithm}.'**
  String licenseUnsupportedAlgorithm(String algorithm);

  /// No description provided for @licenseUnknownVendor.
  ///
  /// In en, this message translates to:
  /// **'Key issued by unknown vendor \"{vendor}\".'**
  String licenseUnknownVendor(String vendor);

  /// No description provided for @licenseKeyExpired.
  ///
  /// In en, this message translates to:
  /// **'Key expired on {date}.'**
  String licenseKeyExpired(String date);

  /// No description provided for @licenseSegmentNotBase64.
  ///
  /// In en, this message translates to:
  /// **'{label} segment is not valid base64url.'**
  String licenseSegmentNotBase64(String label);

  /// No description provided for @licenseSegmentNotJsonObject.
  ///
  /// In en, this message translates to:
  /// **'The {label} must decode to a JSON object.'**
  String licenseSegmentNotJsonObject(String label);

  /// No description provided for @licenseSegmentNotJson.
  ///
  /// In en, this message translates to:
  /// **'The {label} is not valid JSON.'**
  String licenseSegmentNotJson(String label);

  /// No description provided for @licenseSegmentNotUtf8.
  ///
  /// In en, this message translates to:
  /// **'The {label} is not valid UTF-8.'**
  String licenseSegmentNotUtf8(String label);

  /// No description provided for @purchChooseSupplier.
  ///
  /// In en, this message translates to:
  /// **'Choose a supplier'**
  String get purchChooseSupplier;

  /// No description provided for @purchOwes.
  ///
  /// In en, this message translates to:
  /// **'owes {amount}'**
  String purchOwes(String amount);

  /// No description provided for @purchSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get purchSupplier;

  /// No description provided for @purchChooseExisting.
  ///
  /// In en, this message translates to:
  /// **'Choose existing'**
  String get purchChooseExisting;

  /// No description provided for @purchSelectedSupplier.
  ///
  /// In en, this message translates to:
  /// **'Selected (#{id})'**
  String purchSelectedSupplier(String id);

  /// No description provided for @purchOrNewSupplierName.
  ///
  /// In en, this message translates to:
  /// **'or new supplier name'**
  String get purchOrNewSupplierName;

  /// No description provided for @purchEnterDifferentSupplier.
  ///
  /// In en, this message translates to:
  /// **'Enter a different supplier'**
  String get purchEnterDifferentSupplier;

  /// No description provided for @purchInvoiceGrnNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice / GRN number (optional)'**
  String get purchInvoiceGrnNumber;

  /// No description provided for @purchLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get purchLines;

  /// No description provided for @purchAddLine.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get purchAddLine;

  /// No description provided for @purchSaveAndAddToStock.
  ///
  /// In en, this message translates to:
  /// **'Save and add to stock'**
  String get purchSaveAndAddToStock;

  /// No description provided for @purchWhichMedicineArrived.
  ///
  /// In en, this message translates to:
  /// **'Which medicine arrived?'**
  String get purchWhichMedicineArrived;

  /// No description provided for @purchAddMedicineFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a medicine first.'**
  String get purchAddMedicineFirst;

  /// No description provided for @purchChooseMedicine.
  ///
  /// In en, this message translates to:
  /// **'Choose medicine'**
  String get purchChooseMedicine;

  /// No description provided for @purchRemoveLine.
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get purchRemoveLine;

  /// No description provided for @purchBatchExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Batch expiry date'**
  String get purchBatchExpiryDate;

  /// No description provided for @purchBatchNumber.
  ///
  /// In en, this message translates to:
  /// **'Batch number'**
  String get purchBatchNumber;

  /// No description provided for @purchExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get purchExpiry;

  /// No description provided for @purchUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get purchUnit;

  /// No description provided for @purchQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get purchQty;

  /// No description provided for @purchCostPerUnit.
  ///
  /// In en, this message translates to:
  /// **'Cost per {unit}'**
  String purchCostPerUnit(String unit);

  /// No description provided for @purchPiece.
  ///
  /// In en, this message translates to:
  /// **'piece'**
  String get purchPiece;

  /// No description provided for @purchAddsUnitsToStock.
  ///
  /// In en, this message translates to:
  /// **'Adds {count} {unit}s to stock.'**
  String purchAddsUnitsToStock(String count, String unit);

  /// No description provided for @purchAddsPiecesToStock.
  ///
  /// In en, this message translates to:
  /// **'Adds {count} pieces to stock.'**
  String purchAddsPiecesToStock(String count);

  /// No description provided for @purchInvoiceTotal.
  ///
  /// In en, this message translates to:
  /// **'Invoice total'**
  String get purchInvoiceTotal;

  /// No description provided for @purchPaidNow.
  ///
  /// In en, this message translates to:
  /// **'Paid now'**
  String get purchPaidNow;

  /// No description provided for @purchPaidNowHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave blank or short to put the balance on the supplier account.'**
  String get purchPaidNowHelper;

  /// No description provided for @purchAddedToPayable.
  ///
  /// In en, this message translates to:
  /// **'Added to payable'**
  String get purchAddedToPayable;

  /// No description provided for @purchBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get purchBalance;

  /// No description provided for @purchStockedIn.
  ///
  /// In en, this message translates to:
  /// **'Stocked in {amount} kyat'**
  String purchStockedIn(String amount);

  /// No description provided for @purchLinesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 line} other{{count} lines}}'**
  String purchLinesCount(num count);

  /// No description provided for @purchNewBatchesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new batch} other{{count} new batches}}'**
  String purchNewBatchesCount(num count);

  /// No description provided for @purchMergedIntoExisting.
  ///
  /// In en, this message translates to:
  /// **'{count} merged into an existing batch'**
  String purchMergedIntoExisting(String count);

  /// No description provided for @purchBalanceAdded.
  ///
  /// In en, this message translates to:
  /// **'Balance of {amount} kyat added to the supplier account.'**
  String purchBalanceAdded(String amount);

  /// No description provided for @purchPaidInFull.
  ///
  /// In en, this message translates to:
  /// **'Paid in full — nothing added to the supplier account.'**
  String get purchPaidInFull;

  /// No description provided for @purchPickSupplierOrName.
  ///
  /// In en, this message translates to:
  /// **'Choose a supplier or type a new name.'**
  String get purchPickSupplierOrName;

  /// No description provided for @purchLinePickMedicine.
  ///
  /// In en, this message translates to:
  /// **'Line {number}: pick a medicine.'**
  String purchLinePickMedicine(String number);

  /// No description provided for @purchLineBatchNumber.
  ///
  /// In en, this message translates to:
  /// **'Line {number}: the batch number is printed on the carton.'**
  String purchLineBatchNumber(String number);

  /// No description provided for @purchLineExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Line {number}: set the expiry date.'**
  String purchLineExpiryDate(String number);

  /// No description provided for @purchLineQuantity.
  ///
  /// In en, this message translates to:
  /// **'Line {number}: quantity must be at least 1.'**
  String purchLineQuantity(String number);

  /// No description provided for @purchLineCost.
  ///
  /// In en, this message translates to:
  /// **'Line {number}: set the cost price.'**
  String purchLineCost(String number);

  /// No description provided for @purchPaidExceedsTotal.
  ///
  /// In en, this message translates to:
  /// **'Paid {paid} is more than the {total} invoice.'**
  String purchPaidExceedsTotal(String paid, String total);

  /// No description provided for @purchSupplierNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Supplier name is required.'**
  String get purchSupplierNameRequired;

  /// No description provided for @purchPaymentMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Payment must be greater than zero.'**
  String get purchPaymentMustBePositive;

  /// No description provided for @purchPaymentExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Payment exceeds the outstanding balance of {amount} kyat.'**
  String purchPaymentExceedsBalance(String amount);

  /// No description provided for @purchAddAtLeastOneLine.
  ///
  /// In en, this message translates to:
  /// **'Add at least one medicine line.'**
  String get purchAddAtLeastOneLine;

  /// No description provided for @purchDuplicateSaleUnit.
  ///
  /// In en, this message translates to:
  /// **'The same batch ({batch}) appears twice for one medicine. Combine the quantities into a single line.'**
  String purchDuplicateSaleUnit(String batch);

  /// No description provided for @purchPaidNotNegative.
  ///
  /// In en, this message translates to:
  /// **'Paid amount cannot be negative.'**
  String get purchPaidNotNegative;

  /// No description provided for @purchPaidExceedsInvoice.
  ///
  /// In en, this message translates to:
  /// **'Paid {paid} exceeds the invoice total of {total}.'**
  String purchPaidExceedsInvoice(String paid, String total);

  /// No description provided for @purchEveryLineNeedsBatch.
  ///
  /// In en, this message translates to:
  /// **'Every line needs a batch number.'**
  String get purchEveryLineNeedsBatch;

  /// No description provided for @purchQuantityAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'Quantity must be at least 1.'**
  String get purchQuantityAtLeast1;

  /// No description provided for @purchCostNotNegative.
  ///
  /// In en, this message translates to:
  /// **'Cost price cannot be negative.'**
  String get purchCostNotNegative;

  /// No description provided for @purchFactorAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'Unit conversion factor must be 1 or more.'**
  String get purchFactorAtLeast1;

  /// No description provided for @purchBatchAlreadyExpired.
  ///
  /// In en, this message translates to:
  /// **'Batch {batch} is already expired. Refuse the delivery or record it as a write-off.'**
  String purchBatchAlreadyExpired(String batch);

  /// No description provided for @purchSupplierDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Supplier {id} does not exist.'**
  String purchSupplierDoesNotExist(String id);

  /// No description provided for @reportTitleToday.
  ///
  /// In en, this message translates to:
  /// **'Reports — today'**
  String get reportTitleToday;

  /// No description provided for @reportSalesToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sales'**
  String get reportSalesToday;

  /// No description provided for @reportVoucherCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 voucher} other{{count} vouchers}}'**
  String reportVoucherCount(int count);

  /// No description provided for @reportNetProfit.
  ///
  /// In en, this message translates to:
  /// **'Net profit'**
  String get reportNetProfit;

  /// No description provided for @reportNetProfitFormula.
  ///
  /// In en, this message translates to:
  /// **'sales − cost − expenses'**
  String get reportNetProfitFormula;

  /// No description provided for @reportReceivable.
  ///
  /// In en, this message translates to:
  /// **'Receivable'**
  String get reportReceivable;

  /// No description provided for @reportReceivableCaption.
  ///
  /// In en, this message translates to:
  /// **'owed to the shop'**
  String get reportReceivableCaption;

  /// No description provided for @reportPayable.
  ///
  /// In en, this message translates to:
  /// **'Payable'**
  String get reportPayable;

  /// No description provided for @reportPayableCaption.
  ///
  /// In en, this message translates to:
  /// **'the shop owes'**
  String get reportPayableCaption;

  /// No description provided for @reportLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get reportLowStock;

  /// No description provided for @reportLowStockEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is below its reorder level.'**
  String get reportLowStockEmpty;

  /// No description provided for @reportExpiringWithinDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Expiring within 1 day} other{Expiring within {days} days}}'**
  String reportExpiringWithinDays(int days);

  /// No description provided for @reportExpiringEmpty.
  ///
  /// In en, this message translates to:
  /// **'No batch expires in the window.'**
  String get reportExpiringEmpty;

  /// No description provided for @reportExpiredDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{expired 1d ago} other{expired {days}d ago}}'**
  String reportExpiredDaysAgo(int days);

  /// No description provided for @reportDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day left} other{{days} days left}}'**
  String reportDaysLeft(int days);

  /// No description provided for @reportBatchNumber.
  ///
  /// In en, this message translates to:
  /// **'Batch #{id}'**
  String reportBatchNumber(int id);

  /// No description provided for @reportProfitBuildTitle.
  ///
  /// In en, this message translates to:
  /// **'How net profit is built'**
  String get reportProfitBuildTitle;

  /// No description provided for @reportTotalSales.
  ///
  /// In en, this message translates to:
  /// **'Total sales'**
  String get reportTotalSales;

  /// No description provided for @reportMinusCostOfGoods.
  ///
  /// In en, this message translates to:
  /// **'− Cost of goods'**
  String get reportMinusCostOfGoods;

  /// No description provided for @reportMinusExpenses.
  ///
  /// In en, this message translates to:
  /// **'− Expenses'**
  String get reportMinusExpenses;

  /// No description provided for @reportAndMoreCount.
  ///
  /// In en, this message translates to:
  /// **'…and {count, plural, =1{1 more} other{{count} more}}'**
  String reportAndMoreCount(int count);

  /// No description provided for @dashDevLicenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Development licence secret in use'**
  String get dashDevLicenceTitle;

  /// No description provided for @dashDevLicenceBody.
  ///
  /// In en, this message translates to:
  /// **'This build verifies keys against the placeholder secret that is committed to the repository. Build with --dart-define=PHARMACY_LICENSE_SECRET=… before issuing a customer key.'**
  String get dashDevLicenceBody;

  /// No description provided for @dashLicence.
  ///
  /// In en, this message translates to:
  /// **'Licence'**
  String get dashLicence;

  /// No description provided for @dashLicenceNamed.
  ///
  /// In en, this message translates to:
  /// **'Licence: {client}'**
  String dashLicenceNamed(String client);

  /// No description provided for @dashStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String dashStatusLine(String status);

  /// No description provided for @dashExpiresLine.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String dashExpiresLine(String date);

  /// No description provided for @dashModulesLine.
  ///
  /// In en, this message translates to:
  /// **'Modules: {modules}'**
  String dashModulesLine(String modules);

  /// No description provided for @dashLicenceNever.
  ///
  /// In en, this message translates to:
  /// **'never (perpetual licence)'**
  String get dashLicenceNever;

  /// No description provided for @dashStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get dashStatusUnknown;

  /// No description provided for @dashStatusNotActivated.
  ///
  /// In en, this message translates to:
  /// **'not activated'**
  String get dashStatusNotActivated;

  /// No description provided for @dashStatusActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get dashStatusActive;

  /// No description provided for @dashStatusInvalidKey.
  ///
  /// In en, this message translates to:
  /// **'invalid key'**
  String get dashStatusInvalidKey;

  /// No description provided for @dashStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get dashStatusExpired;

  /// No description provided for @dashYourAccess.
  ///
  /// In en, this message translates to:
  /// **'Your access'**
  String get dashYourAccess;

  /// No description provided for @dashAccessCostVisible.
  ///
  /// In en, this message translates to:
  /// **'Cost prices and profit reports are visible to your role.'**
  String get dashAccessCostVisible;

  /// No description provided for @dashAccessCostHidden.
  ///
  /// In en, this message translates to:
  /// **'Cost prices and profit reports are hidden for the {role} role.'**
  String dashAccessCostHidden(String role);

  /// No description provided for @dashPhase5Note.
  ///
  /// In en, this message translates to:
  /// **'Phase 5 — credit ledgers, expenses, daily profit reports and encrypted database backup.'**
  String get dashPhase5Note;

  /// No description provided for @dashLicenceExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Licence expires in 1 day} other{Licence expires in {days} days}}'**
  String dashLicenceExpiresInDays(int days);

  /// No description provided for @dashLicenceExpiredDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Licence expired 1 day ago} other{Licence expired {days} days ago}}'**
  String dashLicenceExpiredDaysAgo(int days);

  /// No description provided for @dashLicenceRenewBody.
  ///
  /// In en, this message translates to:
  /// **'Renew before then to keep using the app. Your data stays on this device; entering a new activation key restores access immediately.'**
  String get dashLicenceRenewBody;

  /// No description provided for @notifChannelName.
  ///
  /// In en, this message translates to:
  /// **'Expiring Stock Alerts'**
  String get notifChannelName;

  /// No description provided for @notifChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Notifications for batches expiring soon'**
  String get notifChannelDescription;

  /// No description provided for @notifBatchExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Batch expiring soon'**
  String get notifBatchExpiringSoon;

  /// No description provided for @notifExpiryBody.
  ///
  /// In en, this message translates to:
  /// **'{name} expires in {days, plural, =1{1 day} other{{days} days}}'**
  String notifExpiryBody(String name, int days);

  /// No description provided for @notifUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get notifUnknown;

  /// Empty state under the POS search field.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches. Clear the search to see the catalogue.'**
  String get saleNoMatchesClearSearch;

  /// Badge on a product card with no sellable units configured.
  ///
  /// In en, this message translates to:
  /// **'no units set'**
  String get saleNoUnitsSetBadge;

  /// Toast shown when tapping the unit switch on a single-unit product.
  ///
  /// In en, this message translates to:
  /// **'This product has one sellable unit.'**
  String get saleOneSellableUnit;

  /// Title of the unit picker dialog.
  ///
  /// In en, this message translates to:
  /// **'Sell {name} as'**
  String saleSellAs(String name);

  /// Validation error under the cart discount field.
  ///
  /// In en, this message translates to:
  /// **'More than the subtotal'**
  String get saleDiscountOverSubtotal;

  /// Validation error under the cart discount field.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get saleEnterNumber;

  /// Checkout summary when no line is on the ticket.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty.'**
  String get saleCartEmpty;

  /// Checkout summary counting the cart's line items.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} line} other{{count} lines}}'**
  String saleCartLines(int count);

  /// Label of the amount-tendered field.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get saleReceivedLabel;

  /// Submit button when part of the total goes to a customer's account.
  ///
  /// In en, this message translates to:
  /// **'Charge {amount} K on credit'**
  String saleChargeOnCredit(String amount);

  /// Submit button for a fully settled sale.
  ///
  /// In en, this message translates to:
  /// **'Complete sale'**
  String get saleCompleteSale;

  /// Error when a credit sale is attempted with an empty customer list.
  ///
  /// In en, this message translates to:
  /// **'No customers yet. Create one in {screen}.'**
  String saleNoCustomersYet(String screen);

  /// Heading of the customer picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Charge this sale to'**
  String get saleChargeThisSaleTo;

  /// Customer row in the picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Debt {debt} · limit {limit} K'**
  String saleDebtAndLimit(String debt, String limit);

  /// Payment method.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get saleCash;

  /// Totals row naming the unpaid balance.
  ///
  /// In en, this message translates to:
  /// **'Balance on credit'**
  String get saleBalanceOnCredit;

  /// Totals row and voucher label for money handed back.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get saleChange;

  /// Credit picker when no customer is chosen yet.
  ///
  /// In en, this message translates to:
  /// **'Pick a customer'**
  String get salePickACustomer;

  /// Credit picker state when the tendered amount covers the total.
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get salePaidInFull;

  /// Subtitle naming the customer the balance is charged to.
  ///
  /// In en, this message translates to:
  /// **'{name} carries the balance'**
  String saleCarriesBalance(String name);

  /// Tooltip of the button that drops the chosen customer.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get saleClear;

  /// Button that opens the customer picker.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get saleChoose;

  /// Title of the post-sale confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Sale complete'**
  String get saleConfirmedTitle;

  /// Voucher number line in the sale-complete dialog.
  ///
  /// In en, this message translates to:
  /// **'Voucher: {number}'**
  String saleVoucherNumber(String number);

  /// No description provided for @saleTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total {amount} K'**
  String saleTotalAmount(String amount);

  /// No description provided for @saleChangeAmount.
  ///
  /// In en, this message translates to:
  /// **'Change {amount} K'**
  String saleChangeAmount(String amount);

  /// No description provided for @saleOnCreditAmount.
  ///
  /// In en, this message translates to:
  /// **'On credit {amount} K'**
  String saleOnCreditAmount(String amount);

  /// Dialog button that closes the confirmation and clears the till.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get saleNewSale;

  /// Print action and the voucher's own header label.
  ///
  /// In en, this message translates to:
  /// **'Voucher'**
  String get saleVoucher;

  /// Note shown after the voucher renders.
  ///
  /// In en, this message translates to:
  /// **'Voucher {file} ready ({bytes} bytes). Printing hardware wiring lands with the on-device pass.'**
  String saleVoucherReady(String file, String bytes);

  /// No description provided for @saleVoucherBuildFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not build the voucher: {error}'**
  String saleVoucherBuildFailed(String error);

  /// No description provided for @saleCouldNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Could not complete the sale: {error}'**
  String saleCouldNotComplete(String error);

  /// Checkout error when no cashier is signed in.
  ///
  /// In en, this message translates to:
  /// **'Session expired — sign in again to sell.'**
  String get saleSessionExpired;

  /// No description provided for @saleChooseCustomerForBalance.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer to carry the balance.'**
  String get saleChooseCustomerForBalance;

  /// No description provided for @saleKpayFullPayment.
  ///
  /// In en, this message translates to:
  /// **'A KPay sale must be paid in full.'**
  String get saleKpayFullPayment;

  /// Cashier name shown on the voucher when the signed-in user is unknown.
  ///
  /// In en, this message translates to:
  /// **'staff'**
  String get saleStaff;

  /// Voucher line name when the product name is not cached.
  ///
  /// In en, this message translates to:
  /// **'Item {id}'**
  String saleItemFallback(String id);

  /// No description provided for @saleCustomerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Customer name is required.'**
  String get saleCustomerNameRequired;

  /// No description provided for @saleCreditLimitNotNegative.
  ///
  /// In en, this message translates to:
  /// **'Credit limit cannot be negative.'**
  String get saleCreditLimitNotNegative;

  /// No description provided for @salePaymentMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Payment must be greater than zero.'**
  String get salePaymentMustBePositive;

  /// No description provided for @salePaymentExceedsBalance.
  ///
  /// In en, this message translates to:
  /// **'Payment exceeds the outstanding balance of {balance} kyat.'**
  String salePaymentExceedsBalance(String balance);

  /// No description provided for @saleCartIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The cart is empty.'**
  String get saleCartIsEmpty;

  /// No description provided for @saleDiscountNotNegative.
  ///
  /// In en, this message translates to:
  /// **'Discount cannot be negative.'**
  String get saleDiscountNotNegative;

  /// No description provided for @saleReceivedNotNegative.
  ///
  /// In en, this message translates to:
  /// **'Received amount cannot be negative.'**
  String get saleReceivedNotNegative;

  /// No description provided for @saleDiscountExceedsSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Discount of {discount} exceeds the subtotal of {subtotal}.'**
  String saleDiscountExceedsSubtotal(String discount, String subtotal);

  /// No description provided for @saleBalanceNeedsCustomer.
  ///
  /// In en, this message translates to:
  /// **'A sale with an unpaid balance must be charged to a customer.'**
  String get saleBalanceNeedsCustomer;

  /// No description provided for @salePartialPaymentNotKPay.
  ///
  /// In en, this message translates to:
  /// **'Partial payment cannot be a KPay sale. Record the balance as a credit or take full payment.'**
  String get salePartialPaymentNotKPay;

  /// No description provided for @saleQuantityAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'Quantity must be at least 1.'**
  String get saleQuantityAtLeast1;

  /// No description provided for @saleUnitPriceNotNegative.
  ///
  /// In en, this message translates to:
  /// **'Unit price cannot be negative.'**
  String get saleUnitPriceNotNegative;

  /// No description provided for @saleFactorAtLeast1.
  ///
  /// In en, this message translates to:
  /// **'Unit conversion factor must be 1 or more.'**
  String get saleFactorAtLeast1;

  /// No description provided for @saleLineMustNameUnit.
  ///
  /// In en, this message translates to:
  /// **'A sale line must name its unit.'**
  String get saleLineMustNameUnit;

  /// No description provided for @saleCustomerDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Customer {id} does not exist.'**
  String saleCustomerDoesNotExist(String id);

  /// No description provided for @saleCustomerNotActive.
  ///
  /// In en, this message translates to:
  /// **'{name} is not an active customer.'**
  String saleCustomerNotActive(String name);

  /// No description provided for @saleOverCreditLimit.
  ///
  /// In en, this message translates to:
  /// **'{name} is over their credit limit: this sale would take their balance to {projected}, above the {limit} limit.'**
  String saleOverCreditLimit(String name, String projected, String limit);

  /// No description provided for @saleShortage.
  ///
  /// In en, this message translates to:
  /// **'Not enough stock: {requested} needed but only {available} available.'**
  String saleShortage(String requested, String available);

  /// Shortage naming the product, as the till reports it.
  ///
  /// In en, this message translates to:
  /// **'{product} — only {available} of {requested} in stock'**
  String saleProductShortage(
    String product,
    String available,
    String requested,
  );

  /// No description provided for @saleLineMinOneUnit.
  ///
  /// In en, this message translates to:
  /// **'A sale line must take at least one smallest unit.'**
  String get saleLineMinOneUnit;

  /// No description provided for @saleVoucherDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get saleVoucherDateLabel;

  /// No description provided for @saleVoucherCustomerLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get saleVoucherCustomerLabel;

  /// No description provided for @saleVoucherCashierLabel.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get saleVoucherCashierLabel;

  /// No description provided for @saleVoucherTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get saleVoucherTypeLabel;

  /// No description provided for @saleVoucherBalanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance due'**
  String get saleVoucherBalanceDue;

  /// No description provided for @saleVoucherItemHeader.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get saleVoucherItemHeader;

  /// No description provided for @saleVoucherQtyHeader.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get saleVoucherQtyHeader;

  /// No description provided for @saleVoucherPriceHeader.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get saleVoucherPriceHeader;

  /// Voucher footer.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Keep this voucher for returns.'**
  String get saleVoucherThankYou;

  /// Voucher header when the licence shop name is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get saleVoucherShopName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'my'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'my':
      return AppLocalizationsMy();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
