// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Burmese (`my`).
class AppLocalizationsMy extends AppLocalizations {
  AppLocalizationsMy([String locale = 'my']) : super(locale);

  @override
  String get appTitle => 'ဆေးဆိုင် POS';

  @override
  String get pointOfSale => 'ရောင်းချစနစ်';

  @override
  String get checkout => 'ငွေရှင်းရန်';

  @override
  String get retail => 'လက်လီ';

  @override
  String get wholesale => 'လက်ကား';

  @override
  String get discount => 'လျှော့ဈေး';

  @override
  String get total => 'စုစုပေါင်း';

  @override
  String get subtotal => 'ကြားစုစုပေါင်း';

  @override
  String get inventory => 'ကုန်ပစ္စည်းစာရင်း';

  @override
  String get addMedicine => 'ဆေးထည့်ရန်';

  @override
  String get customerCredit => 'ဖောက်သည်အကြွေး';

  @override
  String get supplierCredit => 'ပေးသွင်းသူအကြွေး';

  @override
  String get expenses => 'အသုံးစရိတ်';

  @override
  String get reports => 'အစီရင်ခံစာများ';

  @override
  String get backupRestore => 'အရန်သိမ်းခြင်းနှင့်ပြန်လည်ထူထောင်ခြင်း';

  @override
  String get signOut => 'ထွက်ရန်';

  @override
  String get language => 'ဘာသာစကား';

  @override
  String get english => 'အင်္ဂလိပ်';

  @override
  String get myanmar => 'မြန်မာ';

  @override
  String get dashboard => 'ဒက်ရှ်ဘုတ်';

  @override
  String signedInAs(String username) {
    return '$username ဖြင့်ဝင်ရောက်ထားသည်';
  }

  @override
  String role(String role) {
    return 'အခန်းကဏ္ဍ: $role';
  }

  @override
  String get searchHint => 'ဆေးနာမည် သို့မဟုတ် ဘားကုဒ် ရှာရန်';

  @override
  String get tapToStart => 'ရောင်းရန် ပစ္စည်းကို နှိပ်ပါ။';

  @override
  String noProductMatches(String code) {
    return '$code နှင့်ကိုက်ညီသော ပစ္စည်းမတွေ့ပါ။';
  }

  @override
  String get scanBarcode => 'ဘားကုဒ် စကင်ဖတ်ရန်';

  @override
  String get recordDelivery => 'ကုန်လက်ခံမှတ်တမ်းတင်ရန်';

  @override
  String get positionBarcodeInFrame => 'ဘားကုဒ်ကို ဘောင်အတွင်း ထားပါ';

  @override
  String get toggleTorch => 'ဓာတ်မီး ဖွင့်/ပိတ်';

  @override
  String noUnitsYet(String name) {
    return '$name အတွက် ယူနစ် သတ်မှတ်ထားခြင်း မရှိသေးပါ။';
  }

  @override
  String get cancel => 'ပယ်ဖျက်ရန်';

  @override
  String get ok => 'ကောင်းပြီ';

  @override
  String get save => 'သိမ်းရန်';

  @override
  String get delete => 'ဖျက်ရန်';

  @override
  String get done => 'ပြီးပြီ';

  @override
  String get tryAgain => 'ထပ်ကြိုးစားရန်';

  @override
  String get edit => 'ပြင်ဆင်ရန်';

  @override
  String get remove => 'ဖယ်ရှားရန်';

  @override
  String get close => 'ပိတ်ရန်';

  @override
  String get record => 'မှတ်တမ်းတင်ရန်';

  @override
  String get authSignInTitle => 'ဝင်ရောက်ရန်';

  @override
  String get authSignInButton => 'ဝင်ရောက်ရန်';

  @override
  String get authUsernameLabel => 'အသုံးပြုသူအမည်';

  @override
  String get authSecretLabel => 'ပင်နံပါတ် သို့မဟုတ် စကားဝှက်';

  @override
  String get authSetupTitle => 'ပိုင်ရှင်အကောင့် ဖန်တီးရန်';

  @override
  String get authSetupBlurb =>
      'ဤအကောင့်ဖြင့် ကုန်ကျစရိတ်ဈေးများကို ကြည့်ရှုနိုင်ပြီး ကုန်ပစ္စည်းစာရင်းနှင့် ဝန်ထမ်းများကို စီမံနိုင်ပါသည်။ မမေ့နိုင်သော အမည်ကို ရွေးချယ်ပါ − အင်တာနက်မလိုသော စက်ဖြစ်သည့်အတွက် ဆာဗာမှတဆင့် ပြန်လည်သတ်မှတ်၍ မရပါ။';

  @override
  String get authConfirmLabel => 'အတည်ပြုရန်';

  @override
  String get authCreateAccountButton => 'အကောင့် ဖန်တီးရန်';

  @override
  String authSecretHelper(String min) {
    return 'အနည်းဆုံး စာလုံး $min လုံး';
  }

  @override
  String authUsernameMinLength(String min) {
    return 'အသုံးပြုသူအမည်သည် အနည်းဆုံး စာလုံး $min လုံး ရှိရပါမည်။';
  }

  @override
  String authSecretMinLength(String min) {
    return 'အနည်းဆုံး စာလုံး $min လုံး အသုံးပြုပါ။';
  }

  @override
  String get authPasswordMismatch =>
      'ရိုက်ထည့်ထားသော စာသားနှစ်ခု ကိုက်ညီမှုမရှိပါ။';

  @override
  String get authAccountNotFound => 'အကောင့် မတွေ့ရပါ။ ထပ်မံကြိုးစားပါ။';

  @override
  String get authInvalidCredentials =>
      'အသုံးပြုသူအမည် သို့မဟုတ် ပင်နံပါတ် မှားယွင်းနေပါသည်။';

  @override
  String get authAccountDisabled => 'ဤအကောင့်ကို ပိတ်ထားပါသည်။';

  @override
  String get authLastAdminError =>
      'နောက်ဆုံးကျန်ရှိသော Admin အကောင့်ကို ပိတ်၍ မရပါ။';

  @override
  String authUsernameTaken(String username) {
    return '\"$username\" သည် အသုံးပြုပြီးသား အသုံးပြုသူအမည် ဖြစ်ပါသည်။';
  }

  @override
  String get backupEncryptTitle => 'အရန်ဖိုင်ကို စာဝှက်ရန်';

  @override
  String get backupEncryptBlurb =>
      'ဒေတာဘေ့စ်ကို ဖိသိပ်ပြီး ဤစကားဝှက်ဖြင့် (AES-256-GCM) လုံခြုံစေမည်ဖြစ်သည်။ ၎င်းကို နေရာတစ်ခုခုတွင် သိမ်းထားခြင်း မရှိပါ — စကားဝှက် ပျောက်သွားပါက အရန်ဖိုင်ကို ပြန်လည်ထူထောင်၍ မရနိုင်ပါ။';

  @override
  String get backupUnlockTitle => 'အရန်ဖိုင် စာဝှက်ဖြည်ရန်';

  @override
  String get backupNext => 'ရှေ့သို့';

  @override
  String get backupUnlockBlurb =>
      'ဤအရန်ဖိုင်ကို စာဝှက်ရာတွင် အသုံးပြုခဲ့သော စကားဝှက်ကို ထည့်သွင်းပါ။';

  @override
  String get backupPassphrase => 'စကားဝှက်';

  @override
  String get backupReplaceTitle =>
      'အချက်အလက်အားလုံးကို ဤအရန်ဖိုင်ဖြင့် အစားထိုးမလား?';

  @override
  String backupReplaceFrom(String date) {
    return 'ရင်းမြစ်: $date';
  }

  @override
  String backupReplaceSchema(String version) {
    return 'ဒေတာပုံစံ: $version';
  }

  @override
  String get backupOverwriteWarning =>
      'လက်ရှိအသုံးပြုနေသော ဒေတာများ ပျက်သွားပြီး အစားထိုးခံရမည်ဖြစ်သည်။ ၎င်းကို ပြန်ပြင်၍မရတော့ပါ။';

  @override
  String get backupSavedTitle => 'အရန်သိမ်းခြင်း ပြီးဆုံးပါပြီ';

  @override
  String backupSavedBody(String path, String size) {
    return '$path\n\nစာဝှက်မထားသော ဒေတာဘေ့စ် အရွယ်အစားမှာ $size ဖြစ်ပါသည်။';
  }

  @override
  String get backupRestoredTitle => 'ပြန်လည်ထူထောင်ပြီးပါပြီ';

  @override
  String get backupRestoredBody =>
      'အက်ပ်သည် ယခုအခါ အရန်ဖိုင်မှ ဒေတာကို ဖတ်ရှုနေပါသည်။';

  @override
  String backupFailedWithReason(String reason) {
    return 'အရန်သိမ်းခြင်း မအောင်မြင်ပါ: $reason';
  }

  @override
  String backupRestoreFailedWithReason(String reason) {
    return 'ပြန်လည်ထူထောင်ခြင်း မအောင်မြင်ပါ: $reason';
  }

  @override
  String backupNoFilesFound(String path) {
    return '$path တွင် အရန်သိမ်းဖိုင်များ မတွေ့ရပါ။';
  }

  @override
  String get backupChooseToRestore =>
      'ပြန်လည်ထူထောင်ရန် အရန်ဖိုင်ကို ရွေးချယ်ပါ';

  @override
  String get backupOwnerOnlyNote =>
      'ပိုင်ရှင်သာ ဒေတာဘေ့စ်ကို အရန်သိမ်းခြင်းနှင့် ပြန်လည်ထူထောင်ခြင်း ပြုလုပ်နိုင်ပါသည်။';

  @override
  String backupStorageNote(String path) {
    return 'အရန်ဖိုင်များကို $path တွင် သိမ်းဆည်းပါသည်။';
  }

  @override
  String get backupFolderFallback => 'အက်ပ်၏ Backups ဖိုလ်ဒါ';

  @override
  String get backupCreateTitle => 'စာဝှက်ထားသော အရန်ဖိုင် ဖန်တီးရန်';

  @override
  String get backupCreateBody =>
      'လက်ရှိဒေတာဘေ့စ်ကို ပုံတူပွားယူပြီး (VACUUM INTO ဖြင့် တစ်ပြေးညီရှိသော၊ WAL မပါဝင်သေသော အခြေအနေတွင် ရယူကာ) ဖိသိပ်အပြီး သင်ရွေးချယ်သော စကားဝှက်ဖြင့် စာဝှက်ထားပေးပါသည်။';

  @override
  String get backupCreateAction => 'အရန်သိမ်းရန်';

  @override
  String get backupRestoreTitle => 'အရန်ဖိုင်မှ ပြန်လည်ထူထောင်ရန်';

  @override
  String get backupRestoreBody =>
      '.pbak ဖိုင်တစ်ခုကို ရွေးချယ်၍ စာဝှက်ဖြည်ပြီး လက်ရှိဒေတာဘေ့စ်ကို အစားထိုးပါ။ စက်ပေါ်ရှိ လက်ရှိဒေတာအားလုံး အစားထိုးခံရပါမည်။';

  @override
  String get backupRestoreAction => 'ပြန်လည်ထူထောင်ရန်';

  @override
  String get backupNoManifest =>
      'အရန်ဖိုင်တွင် manifest (ဖိုင်ညွှန်းစာရင်း) ပါဝင်ခြင်း မရှိပါ။';

  @override
  String get backupMissingDatabase =>
      'အရန်ဖိုင်တွင် ဒေတာဘေ့စ်ဖိုင် ပါဝင်ခြင်း မရှိပါ။';

  @override
  String get backupTruncated => 'အရန်ဖိုင် မပြည့်စုံပါ (တိုတောင်းနေပါသည်)။';

  @override
  String get backupNotPharmacyFile => 'ဤသည် ဆေးဆိုင် အရန်သိမ်းဖိုင် မဟုတ်ပါ။';

  @override
  String backupUnsupportedVersion(String version) {
    return 'မပံ့ပိုးထားသော အရန်ဖိုင် ဗားရှင်း $version။';
  }

  @override
  String get backupWrongPassphrase =>
      'စကားဝှက် မှားယွင်းနေပါသည်၊ သို့မဟုတ် အရန်ဖိုင်ကို ပြင်ဆင်ထားခြင်း ဖြစ်ပါသည်။';

  @override
  String get backupPassphraseRequired =>
      'အရန်သိမ်းရန် စကားဝှက် လိုအပ်ပါသည်။ စာဝှက်မထားသော အရန်ဖိုင်ထုတ်ယူမှုများ မပေးဆောင်ပါ။';

  @override
  String get creditCustomerTitle => 'ဖောက်သည်အကြွေး';

  @override
  String get creditSupplierTitle => 'ပေးသွင်းသူ ပေးရန်ကျငွေ';

  @override
  String get creditWordCustomer => 'ဖောက်သည်';

  @override
  String get creditWordSupplier => 'ပေးသွင်းသူ';

  @override
  String get creditOwes => 'ကျန်ရစ်သည်';

  @override
  String get creditIsOwed => 'ပေးရန်ကျသည်';

  @override
  String get creditTotalReceivable => 'ရရှိမည်ငွေ စုစုပေါင်း';

  @override
  String get creditTotalPayable => 'ပေးရန်ငွေ စုစုပေါင်း';

  @override
  String creditSearchHint(String party) {
    return '$party အမည် သို့မဟုတ် ဖုန်းနံပါတ်ဖြင့် ရှာဖွေရန်';
  }

  @override
  String creditBalanceLine(String balanceWord, String amount) {
    return '$amount ကျပ် $balanceWord';
  }

  @override
  String get creditNobodyOwesShop => 'လက်ရှိတွင် ဆိုင်အား ငွေကျန်ရစ်သူ မရှိပါ။';

  @override
  String get creditShopOwesNobody =>
      'လက်ရှိတွင် ဆိုင်မှ ပေးသွင်းသူအား ပေးရန်ကျသောငွေ မရှိပါ။';

  @override
  String creditNoMatches(String party, String query) {
    return '“$query” နှင့် ကိုက်ညီသော $party မတွေ့ပါ။';
  }

  @override
  String creditTotalForSearch(String label) {
    return '$label (ဤရှာဖွေမှုအတွက်)';
  }

  @override
  String get creditRecordPaymentTitle => 'ငွေပေးချေမှု မှတ်တမ်းတင်ရန်';

  @override
  String creditCustomerOwesNow(String name, String amount) {
    return '$name သည် ဆိုင်အား လက်ရှိ $amount ကျပ် ကျန်ရစ်နေသည်။';
  }

  @override
  String creditSupplierOwedNow(String name, String amount) {
    return 'ဆိုင်သည် $name အား လက်ရှိ $amount ကျပ် ပေးရန်ကျနေသည်။';
  }

  @override
  String get creditAmountReceived => 'လက်ခံရရှိသော ငွေပမာဏ';

  @override
  String get creditReferenceNote => 'ကိုးကားချက် / မှတ်ချက် (မဖြစ်မနေ မဟုတ်ပါ)';

  @override
  String get creditPaymentRecorded => 'ငွေပေးချေမှုကို မှတ်တမ်းတင်ပြီးပါပြီ။';

  @override
  String get creditReversePaymentTitle =>
      'ဤငွေပေးချေမှုကို ပြန်လည်ပယ်ဖျက်မလား?';

  @override
  String creditReversePaymentBody(String amount) {
    return '$amount ကျပ် လက်ခံရရှိမှုကို ဖယ်ရှားပြီး ကျန်ငွေလက်ကျန်ကို ပြန်လည်ရရှိစေပါမည်။ ဤလုပ်ဆောင်ချက်ကို သင့်အကောင့်တွင် မှတ်တမ်းတင်ပါမည်။';
  }

  @override
  String get creditReverse => 'ပြန်လည်ပယ်ဖျက်ရန်';

  @override
  String get creditPaymentReversed =>
      'ငွေပေးချေမှုကို ပြန်လည်ပယ်ဖျက်ပြီးပါပြီ။';

  @override
  String get creditRecordPayment => 'ငွေပေးချေမှု မှတ်တမ်းတင်ရန်';

  @override
  String get creditOutstanding => 'ကျန်ငွေ';

  @override
  String get creditStatement => 'ငွေစာရင်းချုပ်';

  @override
  String get creditNoLedgerActivity =>
      'ဤအကောင့်အတွက် ငွေစာရင်း လှုပ်ရှားမှု မရှိသေးပါ။';

  @override
  String get creditDebtAdded => 'အကြွေးတင်မြှောက်ခြင်း';

  @override
  String get creditPaymentReceived => 'ငွေလက်ခံရရှိခြင်း';

  @override
  String get creditReversePaymentTooltip => 'ငွေလက်ခံမှုကို ပြန်လည်ပယ်ဖျက်ရန်';

  @override
  String get creditPaymentMustBePositive => 'ငွေပမာဏသည် သုညထက် ကြီးရပါမည်။';

  @override
  String creditPaymentExceedsBalance(String amount) {
    return 'ငွေပမာဏသည် ကျန်ငွေ $amount ကျပ် ထက် ကျော်လွန်နေပါသည်။';
  }

  @override
  String creditCustomerDoesNotExist(String id) {
    return 'ဖောက်သည် $id မတည်ရှိပါ။';
  }

  @override
  String creditSupplierDoesNotExist(String id) {
    return 'ပေးသွင်းသူ $id မတည်ရှိပါ။';
  }

  @override
  String get creditLedgerEntryMissing =>
      'ထိုငွေစာရင်းမှတ်တမ်းသည် ယခု မတည်ရှိတော့ပါ။';

  @override
  String get creditOnlyPaymentReversible =>
      'မှတ်တမ်းတင်ပြီးသား ငွေလက်ခံမှုကိုသာ ပြန်လည်ပယ်ဖျက်နိုင်သည်။ အကြွေးတင်မှုကို မူလရောင်းချမှု သို့မဟုတ် ဝယ်ယူမှုကို ပြန်လည်ပယ်ဖျက်ခြင်းဖြင့်သာ ပြန်လည်ဖြေရှင်းနိုင်ပါသည်။';

  @override
  String get creditDebtEntryPositive =>
      'အကြွေးတင် မှတ်တမ်းသည် အပေါင်းကိန်း ဖြစ်ရပါမည်။';

  @override
  String get creditPaymentEntryPositive =>
      'ငွေပေးချေမှု မှတ်တမ်းသည် အပေါင်းကိန်း ဖြစ်ရပါမည်။';

  @override
  String get coreFieldRequired => 'လိုအပ်သည်';

  @override
  String get coreMoneyFormatError => 'ဂဏန်းကို ဒသမ နှစ်နေရာအထိ ထည့်သွင်းပါ';

  @override
  String get expNewExpense => 'အသုံးစရိတ်အသစ်';

  @override
  String get expAmount => 'ပမာဏ';

  @override
  String get expNoteOptional => 'မှတ်ချက် (ရွေးချယ်စရာ)';

  @override
  String get expCategory => 'အမျိုးအစား';

  @override
  String get expDeleteTitle => 'ဤအသုံးစရိတ်ကို ဖျက်မလား?';

  @override
  String get expCannotUndo => '၎င်းကို ပြန်ပြင်၍မရတော့ပါ။';

  @override
  String get expDeleted => 'အသုံးစရိတ်ကို ဖျက်ပြီးပါပြီ။';

  @override
  String get expNoExpensesRecorded =>
      'အသုံးစရိတ် မှတ်တမ်းတင်ထားခြင်း မရှိသေးပါ။';

  @override
  String get expNoExpensesYet => 'အသုံးစရိတ် မရှိသေးပါ။';

  @override
  String get expNeedsCategory => 'အသုံးစရိတ်အတွက် အမျိုးအစား လိုအပ်ပါသည်။';

  @override
  String get expAmountMustBePositive => 'ပမာဏသည် သုညထက် များရပါမည်။';

  @override
  String get invEditMedicineTitle => 'ဆေး ပြင်ဆင်ရန်';

  @override
  String get invAddMedicineTitle => 'ဆေး အသစ်ထည့်ရန်';

  @override
  String get invTradeName => 'ကုန်သွယ်ရေး ဆေးနာမည်';

  @override
  String get invGenericNameOptional => 'ဂျဲနရစ် ဆေးနာမည် (မဖြစ်မနေ မလိုပါ)';

  @override
  String get invTradeNameRequired => 'သေတ္တာပေါ်ဆေးနာမည် မဖြစ်မနေ လိုအပ်ပါသည်';

  @override
  String get invCategory => 'အမျိုးအစား';

  @override
  String get invShelfLocation => 'သိမ်းထားသည့် နေရာ';

  @override
  String get invBarcode => 'ဘားကုဒ်';

  @override
  String get invBarcodeHelper =>
      'EAN ဘားကုဒ်ကို စကင်ဖတ်ပါ သို့မဟုတ် ရိုက်ထည့်ပါ။ အထုပ်ခွဲရောင်းသည့် ဆေးများအတွက် ဗလာထားပါ (ပြည်တွင်း ဆေးအများစုမှာ ဤသို့ဖြစ်သည်)။';

  @override
  String get invLowStockAlertAt => 'လက်ကျန်နည်း သတိပေးချက် (မဖြစ်မနေ မလိုပါ)';

  @override
  String get invLowStockAlertHelper =>
      'အငယ်ဆုံးယူနစ်ဖြင့် တွက်ချက်သည်။ ဗလာထားပါက ဤဆေးအတွက် သတိပေးချက် မရှိပါ။';

  @override
  String get invUnitsSection => 'ယူနစ်များ';

  @override
  String get invAddUnit => 'ယူနစ် ထည့်ရန်';

  @override
  String get invUnitsSectionHint =>
      'အကြီးဆုံး အထုပ်ကို အရင် စဉ်ပါ။ ယူနစ်တစ်ခုသည် ၁ နှင့် ညီရမည် — ထိုယူနစ်ဖြင့်သာ လက်ကျန်ကို ရေတွက်သည်။';

  @override
  String get invUnitName => 'ယူနစ်နာမည်';

  @override
  String get invUnitNameHint => 'ဘူး / ဆေးထုပ် / ဆေးပြား / ဖန်ဘူး';

  @override
  String get invEquals => 'ညီသည်';

  @override
  String get invHolds => 'ပါဝင်သည်';

  @override
  String get invRemoveThisUnit => 'ဤယူနစ်ကို ဖယ်ရှားရန်';

  @override
  String get invSmallestUnitNote =>
      'အငယ်ဆုံးယူနစ် — လက်ကျန်အထုပ်များကို ဤယူနစ်ဖြင့်သာ ရေတွက်သည်။';

  @override
  String get invSaveChanges => 'ပြင်ဆင်ချက်များ သိမ်းရန်';

  @override
  String get invSaveMedicine => 'ဆေးကို သိမ်းရန်';

  @override
  String get invAddAtLeastOneUnit => 'ယူနစ် အနည်းဆုံး တစ်ခု ထည့်သွင်းပါ။';

  @override
  String get invEveryUnitNeedsName => 'ယူနစ်တိုင်းတွင် နာမည် လိုအပ်ပါသည်။';

  @override
  String invUnitMustHoldWholePieces(String unit) {
    return '$unit တွင် အငယ်ဆုံးယူနစ် အပြည့်အဝသာ ပါဝင်ရမည်။';
  }

  @override
  String invRetailPriceForUnit(String unit) {
    return '$unit အတွက် လက်လီဈေးနှုန်း သတ်မှတ်ပါ။';
  }

  @override
  String get invShowOnlyLowStock => 'လက်ကျန်နည်းသည်များကိုသာ ပြရန်';

  @override
  String get invSearchHint => 'ဆေးနာမည်၊ ဂျဲနရစ် သို့မဟုတ် ဘားကုဒ် ရှာရန်';

  @override
  String get invLowBadge => 'နည်းနေ';

  @override
  String get invNoStockBadge => 'လက်ကျန်မရှိ';

  @override
  String invExpiringBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ခု သက်တမ်းကုန်နီး',
    );
    return '$_temp0';
  }

  @override
  String invShelfAt(String shelf) {
    return 'သိမ်းနေရာ - $shelf';
  }

  @override
  String invStockValueK(String money) {
    return 'လက်ကျန်တန်ဖိုး $money K';
  }

  @override
  String get invNothingMatchesFilter =>
      'ဤစစ်ထုတ်မှုနှင့် ကိုက်ညီသော ဆေး မတွေ့ပါ။';

  @override
  String get invClearSearchHint =>
      'စာရင်းအပြည့်အဝ ပြန်မြင်ရန် ရှာဖွေမှုဘောက်ကို ရှင်းလင်းပါ။';

  @override
  String get invNoMedicinesYet => 'ဆေးစာရင်း မထည့်ရသေးပါ။';

  @override
  String get invFirstMedicineHint =>
      'ပထမဆုံး ဆေးကို ထည့်သွင်းပြီး ကုန်လက်ခံမှတ်တမ်း တင်၍ လက်ကျန် သိမ်းပါ။';

  @override
  String get invAskOwnerToAdd =>
      'ဆေးများ ထည့်သွင်းပြီး ကုန်လက်ခံမှတ်တမ်း တင်ရန် ဆိုင်ရှင်ကို တောင်းဆိုပါ။';

  @override
  String get invInventoryReadFailed =>
      'ကုန်ပစ္စည်းစာရင်းကို ဖတ်ရှု၍ မရနိုင်ပါ။';

  @override
  String get invPiecesFallback => 'အလုံး';

  @override
  String get invNoStockRecordDelivery =>
      'လက်ကျန် မရှိပါ။ အထုပ်များ ထည့်သွင်းရန် ကုန်လက်ခံမှတ်တမ်း တင်ပါ။';

  @override
  String invBatchNumber(String number) {
    return 'အထုပ် $number';
  }

  @override
  String invBatchCost(String price) {
    return 'ဝယ်ဈေး $price K';
  }

  @override
  String get invExpired => 'သက်တမ်းကုန်ပြီး';

  @override
  String invDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ရက် ကျန်',
    );
    return '$_temp0';
  }

  @override
  String invBatchTotals(int batchCount, int quantity) {
    String _temp0 = intl.Intl.pluralLogic(
      batchCount,
      locale: localeName,
      other: 'အထုပ် $batchCount ခု',
    );
    return '$_temp0 · လက်ကျန် $quantity';
  }

  @override
  String invBatchValuationNote(String value) {
    return 'တန်ဖိုးစုစုပေါင်း $value ကျပ်။ သက်တမ်းအကုန်ဆုံးကို ဦးစားပေး ရောင်းချသည်။';
  }

  @override
  String get invNoUnitsConfigured =>
      'ဤဆေးအတွက် ယူနစ်များ သတ်မှတ်ထားခြင်း မရှိပါ။ အငယ်ဆုံးယူနစ်ကို အနည်းဆုံး ထည့်သွင်းပါ။';

  @override
  String get invNoSmallestUnit =>
      'အငယ်ဆုံးယူနစ် သတ်မှတ်ထားခြင်း မရှိပါ — ယူနစ်အားလုံးသည် ၁ ထက်ပိုသော အလုံးရေသို့ ပြောင်းလဲသည်။ အလုံးရေ ၁ နှင့်ညီသော ယူနစ်ကို ထပ်ထည့်ပါ။';

  @override
  String invMoreThanOneSmallestUnit(String names) {
    return 'အငယ်ဆုံးယူနစ် တစ်ခုထက် ပို သတ်မှတ်ထားသည် ($names) — တစ်ခုတည်းသာ လိုအပ်ပါသည်။';
  }

  @override
  String get invDuplicateUnitNames =>
      'ဆေးတစ်ခုအတွင်း ယူနစ်နာမည်များ ကွဲပြားရမည်; ယူနစ်နှစ်ခု နာမည်တူနေပါသည်။';

  @override
  String invUnknownUnit(String name) {
    return 'ဤဆေးအတွက် ယူနစ် \"$name\" ကို မတွေ့ရှိရပါ။';
  }

  @override
  String invQuantityAtLeast1(int value) {
    return 'အရေအတွက်သည် အနည်းဆုံး ၁ ဖြစ်ရပါမည်၊ $value ရရှိသည်။';
  }

  @override
  String invQuantityNotNegative(int value) {
    return 'အရေအတွက်သည် အနှုတ်ဖြစ်၍ မရပါ၊ $value ရရှိသည်။';
  }

  @override
  String get invMedicineNameRequired => 'ဆေးနာမည် မဖြစ်မနေ လိုအပ်ပါသည်။';

  @override
  String invBarcodeTaken(String barcode, String medicine) {
    return 'ဘားကုဒ် $barcode သည် $medicine တွင် အသုံးပြုပြီးဖြစ်သည်။';
  }

  @override
  String get invMedicineStillHasStock =>
      'ဤဆေးတွင် လက်ကျန်ရှိနေသေးပါသည်။ ဦးစွာ စွန့်ပစ်မှတ်တမ်း တင်ပါ သို့မဟုတ် လွှဲပြောင်းပါ။';

  @override
  String invBatchRemovalTooLarge(String batch, int remaining, int removal) {
    return 'အထုပ် $batch တွင် $remaining ခုသာ ကျန်ရှိသဖြင့် $removal ခုကို ဖယ်ရှား၍ မရပါ။';
  }

  @override
  String get licenseTitle => 'သင့် လိုင္စင္ကို ဖြင့္ပါ';

  @override
  String get licenseIntro =>
      'သင့် ဆေးဆိုင် လိုင္စင္ႏွင့္အတူ ပံ့ပိုးထားသော ဖြင့္သော့ကို ထည့္သြင္းပါ။ ဤအဆင့္ကို တစ်ကြိမ်သာ လုပ်ဆောင်ရပါမည်။';

  @override
  String get licenseKeyLabel => 'ဖြင့္သော့';

  @override
  String get licenseActivate => 'ဖြင့္ရန္';

  @override
  String get licenseKeyRequired => 'ဖြင့္သော့ကို ထည့္သြင္းပါ။';

  @override
  String get licenseActivationFailed => 'ဖြင့္၍ မရပါ။';

  @override
  String get licenseStoredKeyInvalid =>
      'သိမ္းဆည္းထားသော သော့ကို အတည္ျပဳ၍ မရပါ။';

  @override
  String get licenseKeyNotJwt =>
      'သော့သည် JWT ပုံစံျဖစ္ရပါမည္ — အပိုင္း ၃ ခုကို ဝီသကၤတာ (.) ျဖင့္ ခြားထားရပါမည္။';

  @override
  String get licenseSignatureMismatch =>
      'signature မကိုက္ညီပါ — သော့ကို မွားယြင္းစြာထည့္သြင္း၊ ေျပာင္းလဲထား၊ သို႔မဟုတ္ အျခား secret ျဖင့္ ထုတ္ျပန္ထားပါသည္။';

  @override
  String get licenseNoFeaturesClaim => 'သော့တြင္ features အခ်က္အလက္ မပါဝင္ပါ။';

  @override
  String get licenseUnreadableExpiry =>
      'သော့၏ သက္တမ္းကုန္ရက္ (exp) အခ်က္အလက္ကို ဖတ္၍ မရပါ။';

  @override
  String licenseUnsupportedAlgorithm(String algorithm) {
    return 'မေထာက္ပံ့ထားသော key algorithm - $algorithm။';
  }

  @override
  String licenseUnknownVendor(String vendor) {
    return '\"$vendor\" သည် မသိရသော ထုတ္ျပန္သူျဖစ္သည္။';
  }

  @override
  String licenseKeyExpired(String date) {
    return 'သော့သည် $date တြင္ သက္တမ္းကုန္သည္။';
  }

  @override
  String licenseSegmentNotBase64(String label) {
    return '$label အပိုင္းသည္ base64url အစစ္အမွန္ မဟုတ္ပါ။';
  }

  @override
  String licenseSegmentNotJsonObject(String label) {
    return '$label အပိုင္းသည္ JSON object အျဖစ္ မကူးယူနိုင်ပါ။';
  }

  @override
  String licenseSegmentNotJson(String label) {
    return '$label အပိုင္းသည္ JSON အစစ္အမွန္ မဟုတ္ပါ။';
  }

  @override
  String licenseSegmentNotUtf8(String label) {
    return '$label အပိုင္းသည္ UTF-8 အစစ္အမွန္ မဟုတ္ပါ။';
  }

  @override
  String get purchChooseSupplier => 'ပေးသွင်းသူကို ရွေးချယ်ပါ';

  @override
  String purchOwes(String amount) {
    return 'ကျန်ငွေ $amount';
  }

  @override
  String get purchSupplier => 'ပေးသွင်းသူ';

  @override
  String get purchChooseExisting => 'ရှိပြီးသားကို ရွေးချယ်ရန်';

  @override
  String purchSelectedSupplier(String id) {
    return 'ရွေးချယ်ထားသည် (#$id)';
  }

  @override
  String get purchOrNewSupplierName => 'သို့မဟုတ် ပေးသွင်းသူအသစ် အမည်';

  @override
  String get purchEnterDifferentSupplier => 'အခြားပေးသွင်းသူ ထည့်သွင်းရန်';

  @override
  String get purchInvoiceGrnNumber => 'ဘောက်ချာ / GRN အမှတ် (မဖြစ်မနေမဟုတ်)';

  @override
  String get purchLines => 'ပစ္စည်းစာရင်း';

  @override
  String get purchAddLine => 'ပစ္စည်းအသစ် ထပ်ထည့်ရန်';

  @override
  String get purchSaveAndAddToStock => 'သိမ်းဆည်းပြီး ဂိုထဲထည့်သွင်းရန်';

  @override
  String get purchWhichMedicineArrived => 'မည်ဆေး ရောက်ရှိလာသနည်း။';

  @override
  String get purchAddMedicineFirst => 'ဆေးကို ဦးစွာ ထည့်သွင်းပါ။';

  @override
  String get purchChooseMedicine => 'ဆေး ရွေးချယ်ရန်';

  @override
  String get purchRemoveLine => 'ပစ္စည်းအကြိတ်ကို ဖယ်ရှားရန်';

  @override
  String get purchBatchExpiryDate => 'ဘက်ခ် သက်တမ်းကုန်ရက်';

  @override
  String get purchBatchNumber => 'ဘက်ခ်အမှတ်';

  @override
  String get purchExpiry => 'သက်တမ်းကုန်ရက်';

  @override
  String get purchUnit => 'ယူနစ်';

  @override
  String get purchQty => 'အရေအတွက်';

  @override
  String purchCostPerUnit(String unit) {
    return '$unitလျှင် ကုန်ကျငွေ';
  }

  @override
  String get purchPiece => 'တစ်ခု';

  @override
  String purchAddsUnitsToStock(String count, String unit) {
    return 'ဂိုထဲသို့ $unit $count ယူနစ် ထပ်ထည့်မည်။';
  }

  @override
  String purchAddsPiecesToStock(String count) {
    return 'ဂိုထဲသို့ $count ခု ထပ်ထည့်မည်။';
  }

  @override
  String get purchInvoiceTotal => 'ဘောက်ချာ စုစုပေါင်း';

  @override
  String get purchPaidNow => 'ယခု ပေးငွေ';

  @override
  String get purchPaidNowHelper =>
      'ကျန်ငွေကို ပေးသွင်းသူ၏ အကြွေးစာရင်းတွင် ထားလိုပါက ဗလာ (သို့) လျှော့ထည့်ပါ။';

  @override
  String get purchAddedToPayable => 'အကြွေးစာရင်းတင်ငွေ';

  @override
  String get purchBalance => 'ကျန်ငွေ';

  @override
  String purchStockedIn(String amount) {
    return 'ကျပ် $amount တန်ဖိုး ကုန်လှောင်ပြီးပါပြီ';
  }

  @override
  String purchLinesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'အကြိတ် $count',
    );
    return '$_temp0';
  }

  @override
  String purchNewBatchesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ဘက်ခ်အသစ် $count',
    );
    return '$_temp0';
  }

  @override
  String purchMergedIntoExisting(String count) {
    return 'ဘက်ခ် $count ခုကို လက်ရှိဘက်ခ်ထဲ ပေါင်းထည့်ပြီး';
  }

  @override
  String purchBalanceAdded(String amount) {
    return 'ကျန်ငွေ ကျပ် $amount ကို ပေးသွင်းသူအကြွေးစာရင်းသို့ တင်သွင်းပြီးပါပြီ။';
  }

  @override
  String get purchPaidInFull =>
      'ငွေပြည့်ပေးဆောင်ပြီးဖြစ်သဖြင့် ပေးသွင်းသူအကြွေးစာရင်းသို့ မတင်သွင်းရပါ။';

  @override
  String get purchPickSupplierOrName =>
      'ပေးသွင်းသူကို ရွေးချယ်ပါ သို့မဟုတ် အမည်အသစ် ရိုက်ထည့်ပါ။';

  @override
  String purchLinePickMedicine(String number) {
    return 'အကြိတ် $number: ဆေးကို ရွေးချယ်ပါ။';
  }

  @override
  String purchLineBatchNumber(String number) {
    return 'အကြိတ် $number: ဘက်ခ်အမှတ်ကို သေတ္တာပေါ်တွင် ပါရှိပါသည်။';
  }

  @override
  String purchLineExpiryDate(String number) {
    return 'အကြိတ် $number: သက်တမ်းကုန်ရက် သတ်မှတ်ပါ။';
  }

  @override
  String purchLineQuantity(String number) {
    return 'အကြိတ် $number: အရေအတွက် အနည်းဆုံး 1 ဖြစ်ရပါမည်။';
  }

  @override
  String purchLineCost(String number) {
    return 'အကြိတ် $number: ကုန်ကျဈေး သတ်မှတ်ပါ။';
  }

  @override
  String purchPaidExceedsTotal(String paid, String total) {
    return 'ပေးငွေ $paid သည် ဘောက်ချာတန်ဖိုး $total ထက် ကျော်လွန်နေပါသည်။';
  }

  @override
  String get purchSupplierNameRequired =>
      'ပေးသွင်းသူအမည် မဖြစ်မနေ လိုအပ်ပါသည်။';

  @override
  String get purchPaymentMustBePositive => 'ပေးငွေသည် သုညထက် ကြီးရပါမည်။';

  @override
  String purchPaymentExceedsBalance(String amount) {
    return 'ပေးငွေသည် ကျန်ငွေ ကျပ် $amount ထက် ကျော်လွန်နေပါသည်။';
  }

  @override
  String get purchAddAtLeastOneLine =>
      'ဆေးပစ္စည်းအကြိတ် အနည်းဆုံး 1 ထည့်သွင်းပါ။';

  @override
  String purchDuplicateSaleUnit(String batch) {
    return 'ဆေးတစ်ခုတည်းအတွက် တူညီသော ဘက်ခ် ($batch) နှစ်ကြိမ် ပါရှိနေပါသည်။ အရေအတွက်များကို အကြိတ်တစ်ခုတည်းတွင် ပေါင်းထည့်ပါ။';
  }

  @override
  String get purchPaidNotNegative => 'ပေးငွေပမာဏ အနှုတ်ကိန်း ဖြစ်၍မရပါ။';

  @override
  String purchPaidExceedsInvoice(String paid, String total) {
    return 'ပေးငွေ $paid သည် ဘောက်ချာ စုစုပေါင်း $total ထက် ကျော်လွန်နေပါသည်။';
  }

  @override
  String get purchEveryLineNeedsBatch =>
      'အကြိတ်တိုင်းတွင် ဘက်ခ်အမှတ် လိုအပ်ပါသည်။';

  @override
  String get purchQuantityAtLeast1 => 'အရေအတွက် အနည်းဆုံး 1 ဖြစ်ရပါမည်။';

  @override
  String get purchCostNotNegative => 'ကုန်ကျဈေးနှုန်း အနှုတ်ကိန်း ဖြစ်၍မရပါ။';

  @override
  String get purchFactorAtLeast1 =>
      'ယူနစ်ပြောင်းကိန်းသည် 1 သို့မဟုတ် ထက်ပို ဖြစ်ရပါမည်။';

  @override
  String purchBatchAlreadyExpired(String batch) {
    return 'ဘက်ခ် $batch သည် သက်တမ်းလွန်ပြီးဖြစ်ပါသည်။ လက်ခံခြင်းကို ငြင်းပယ်ပါ သို့မဟုတ် ဆုံးရှုံးမှုအဖြစ် မှတ်တမ်းတင်ပါ။';
  }

  @override
  String purchSupplierDoesNotExist(String id) {
    return 'ပေးသွင်းသူ $id မတည်ရှိပါ။';
  }

  @override
  String get reportTitleToday => 'အစီရင်ခံစာများ — ယနေ့';

  @override
  String get reportSalesToday => 'ယနေ့ ရောင်းအား';

  @override
  String reportVoucherCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ရောင်းချလက်မှတ် $count ခု',
    );
    return '$_temp0';
  }

  @override
  String get reportNetProfit => 'စုစုပေါင်းအမြတ်';

  @override
  String get reportNetProfitFormula => 'ရောင်းအား − ကုန်စရိတ် − အသုံးစရိတ်';

  @override
  String get reportReceivable => 'လက်ခံရရှိမည်ငွေ';

  @override
  String get reportReceivableCaption => 'ဆေးဆိုင်မှ ရရှိမည့်ငွေ';

  @override
  String get reportPayable => 'ပေးချေရမည်ငွေ';

  @override
  String get reportPayableCaption => 'ဆေးဆိုင်မှ ပေးချေရမည့်ငွေ';

  @override
  String get reportLowStock => 'လက်ကျန်နည်းပါး';

  @override
  String get reportLowStockEmpty =>
      'ပြန်မှာယူရမည့်အဆင့်အောက် ရောက်နေသော ဆေးဝါးမရှိပါ။';

  @override
  String reportExpiringWithinDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'ရက် $days ရက်အတွင်း သက်တမ်းကုန်မည့်',
    );
    return '$_temp0';
  }

  @override
  String get reportExpiringEmpty =>
      'ဤကာလအတွင်း သက်တမ်းကုန်သွားမည့် ဘက်ချ်မရှိပါ။';

  @override
  String reportExpiredDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'သက်တမ်း $days ရက်က ကုန်ဆုံး',
    );
    return '$_temp0';
  }

  @override
  String reportDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days ရက် ကျန်',
    );
    return '$_temp0';
  }

  @override
  String reportBatchNumber(int id) {
    return 'ဘက်ချ် #$id';
  }

  @override
  String get reportProfitBuildTitle => 'စုစုပေါင်းအမြတ် တွက်ချက်ပုံ';

  @override
  String get reportTotalSales => 'စုစုပေါင်း ရောင်းအား';

  @override
  String get reportMinusCostOfGoods => '− ကုန်ပစ္စည်းစရိတ်';

  @override
  String get reportMinusExpenses => '− အသုံးစရိတ်';

  @override
  String reportAndMoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ခု',
    );
    return '…နှင့် နောက်ထပ် $_temp0';
  }

  @override
  String get dashDevLicenceTitle =>
      'ဖွံ့ဖြိုးရေး လိုင်စင်သော့ကို အသုံးပြုနေသည်';

  @override
  String get dashDevLicenceBody =>
      'ဤ build သည် သော့များကို repository တွင် ထည့်သွင်းထားသော နမူနာသော့ဖြင့် စစ်ဆေးနေပါသည်။ ဖောက်သည်သော့ ထုတ်ပေးမည့်အစား --dart-define=PHARMACY_LICENSE_SECRET=… ဖြင့် build လုပ်ပါ။';

  @override
  String get dashLicence => 'လိုင်စင်';

  @override
  String dashLicenceNamed(String client) {
    return 'လိုင်စင်: $client';
  }

  @override
  String dashStatusLine(String status) {
    return 'အခြေအနေ: $status';
  }

  @override
  String dashExpiresLine(String date) {
    return 'သက်တမ်းကုန်ဆုံးရက်: $date';
  }

  @override
  String dashModulesLine(String modules) {
    return 'မော်ဂျူးများ: $modules';
  }

  @override
  String get dashLicenceNever => 'မရှိ (အပြီးသတ် လိုင်စင်)';

  @override
  String get dashStatusUnknown => 'မသိရှိရ';

  @override
  String get dashStatusNotActivated => 'လိုင်စင် မဖွင့်ရသေး';

  @override
  String get dashStatusActive => 'တက်ကြွနေသည်';

  @override
  String get dashStatusInvalidKey => 'သော့ မှားယွင်းနေသည်';

  @override
  String get dashStatusExpired => 'သက်တမ်း ကုန်ဆုံးပြီ';

  @override
  String get dashYourAccess => 'သင့်အသုံးပြုခွင့်';

  @override
  String get dashAccessCostVisible =>
      'ကုန်ကျဈေးနှင့် အမြတ်အစွန်း အစီရင်ခံစာများကို သင့်အခန်းကဏ္ဍအတွက် ပြသထားသည်။';

  @override
  String dashAccessCostHidden(String role) {
    return '$role အခန်းကဏ္ဍအတွက် ကုန်ကျဈေးနှင့် အမြတ်အစွန်း အစီရင်ခံစာများကို ဖျောက်ထားသည်။';
  }

  @override
  String get dashPhase5Note =>
      'အဆင့် ၅ — အကြွေးစာရင်းများ၊ အသုံးစရိတ်များ၊ နေ့စဉ်အမြတ်အစွန်း အစီရင်ခံစာများနှင့် လုံခြုံရေးကုဒ်ပြု database အရန်သိမ်းခြင်း။';

  @override
  String dashLicenceExpiresInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'လိုင်စင် သက်တမ်း ရက် $days ရက်အတွင်း ကုန်ဆုံးမည်',
    );
    return '$_temp0';
  }

  @override
  String dashLicenceExpiredDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'လိုင်စင် သက်တမ်း $days ရက်က ကုန်ဆုံးပြီ',
    );
    return '$_temp0';
  }

  @override
  String get dashLicenceRenewBody =>
      'အက်ပ်ကို ဆက်လက်အသုံးပြုနိုင်ရန် ၎င်းမတိုင်မီ လိုင်စင်ပြန်လည်သုံးပါ။ သင့်ဒေတာသည် ဤစက်ထဲတွင်သာ ရှိနေမည်ဖြစ်ပြီး ဖွင့်သော့အသစ် ထည့်သွင်းပါက အသုံးပြုခွင့်ကို ချက်ချင်း ပြန်လည်ရရှိနိုင်ပါသည်။';

  @override
  String get notifChannelName => 'သက်တမ်းကုန်နီး ကုန်ပစ္စည်း အသိပေးချက်များ';

  @override
  String get notifChannelDescription =>
      'သက်တမ်းကုန်နီးနေသော ဘက်ချ်များအတွက် အသိပေးချက်များ';

  @override
  String get notifBatchExpiringSoon => 'ဘက်ချ် သက်တမ်းကုန်နီးနေပါပြီ';

  @override
  String notifExpiryBody(String name, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'ရက် $days ရက်အတွင်း',
    );
    return '$name သည် $_temp0 သက်တမ်းကုန်မည်ပါ။';
  }

  @override
  String get notifUnknown => 'အမည်မသိ';

  @override
  String get saleNoMatchesClearSearch =>
      'ကိုက်ညီသော ပစ္စည်း မတွေ့ပါ။ ရှာဖွေမှုကို ရှင်းလင်းပြီး ပစ္စည်းစာရင်းကို ပြန်လည်ကြည့်ပါ။';

  @override
  String get saleNoUnitsSetBadge => 'ယူနစ် သတ်မှတ်ထားခြင်း မရှိပါ';

  @override
  String get saleOneSellableUnit =>
      'ဤပစ္စည်းတွင် ရောင်းချနိုင်သော ယူနစ် တစ်ခုတည်းသာ ရှိပါသည်။';

  @override
  String saleSellAs(String name) {
    return '$name ကို ရောင်းမည့် ယူနစ်';
  }

  @override
  String get saleDiscountOverSubtotal => 'ကြားစုစုပေါင်းထက် ပိုများနေပါသည်';

  @override
  String get saleEnterNumber => 'ဂဏန်း ထည့်သွင်းပါ';

  @override
  String get saleCartEmpty => 'ဈေးတန်းထဲတွင် ပစ္စည်း မရှိပါ။';

  @override
  String saleCartLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ပစ္စည်း $count မျိုး',
    );
    return '$_temp0';
  }

  @override
  String get saleReceivedLabel => 'ရရှိသောငွေ';

  @override
  String saleChargeOnCredit(String amount) {
    return 'အကြွေးအဖြစ် $amount ကျပ် တင်ရန်';
  }

  @override
  String get saleCompleteSale => 'ရောင်းချမှု အပြီးသတ်ရန်';

  @override
  String saleNoCustomersYet(String screen) {
    return 'ဖောက်သည် မရှိသေးပါ။ $screen တွင် ဖန်တီးပါ။';
  }

  @override
  String get saleChargeThisSaleTo => 'ဤရောင်းချမှု အကြွေးတင်မည့် ဖောက်သည်';

  @override
  String saleDebtAndLimit(String debt, String limit) {
    return 'အကြွေး $debt · ကန့်သတ်ချက် $limit ကျပ်';
  }

  @override
  String get saleCash => 'ငွေသား';

  @override
  String get saleBalanceOnCredit => 'အကြွေးကျန်';

  @override
  String get saleChange => 'ပြန်အမ်းငွေ';

  @override
  String get salePickACustomer => 'ဖောက်သည် ရွေးချယ်ပါ';

  @override
  String get salePaidInFull => 'ငွေပြည့်ရှင်းပြီး';

  @override
  String saleCarriesBalance(String name) {
    return '$name ၏ အကြွေးကျန် ဖြစ်ပါမည်';
  }

  @override
  String get saleClear => 'ရှင်းလင်းရန်';

  @override
  String get saleChoose => 'ရွေးချယ်ရန်';

  @override
  String get saleConfirmedTitle => 'ရောင်းချမှု ပြီးဆုံးပါပြီ';

  @override
  String saleVoucherNumber(String number) {
    return 'ဘောက်ချာလက်မှတ် - $number';
  }

  @override
  String saleTotalAmount(String amount) {
    return 'စုစုပေါင်း $amount ကျပ်';
  }

  @override
  String saleChangeAmount(String amount) {
    return 'ပြန်အမ်းငွေ $amount ကျပ်';
  }

  @override
  String saleOnCreditAmount(String amount) {
    return 'အကြွေး $amount ကျပ်';
  }

  @override
  String get saleNewSale => 'ရောင်းချမှု အသစ်';

  @override
  String get saleVoucher => 'ဘောက်ချာလက်မှတ်';

  @override
  String saleVoucherReady(String file, String bytes) {
    return 'ဘောက်ချာလက်မှတ် $file အသင့်ဖြစ်ပါပြီ ($bytes ဘိုက်)။ ပရင်တာ ချိတ်ဆက်မှုကို စက်ပေါ်တွင် စမ်းသပ်သည့် အဆင့်၌ ထည့်သွင်းဆောင်ရွက်ပါမည်။';
  }

  @override
  String saleVoucherBuildFailed(String error) {
    return 'ဘောက်ချာလက်မှတ်ကို မဖန်တီးနိုင်ပါ - $error';
  }

  @override
  String saleCouldNotComplete(String error) {
    return 'ရောင်းချမှုကို ပြီးမြောက်အောင် မဆောင်ရွက်နိုင်ပါ - $error';
  }

  @override
  String get saleSessionExpired =>
      'အကောင့်ဝင်မှု သက်တမ်း ကုန်ဆုံးနေပါသည် — ပြန်လည်ဝင်ရောက်ပြီး ရောင်းချပါ။';

  @override
  String get saleChooseCustomerForBalance =>
      'အကြွေးကျန် ခံယူရန် ဖောက်သည်ကို ရွေးချယ်ပါ။';

  @override
  String get saleKpayFullPayment =>
      'KPay ဖြင့် ရောင်းချပါက ကျသင့်ငွေကို အပြည့်အဝ ရှင်းထိပ်ရပါမည်။';

  @override
  String get saleStaff => 'ဝန်ထမ်း';

  @override
  String saleItemFallback(String id) {
    return 'ပစ္စည်း $id';
  }

  @override
  String get saleCustomerNameRequired => 'ဖောက်သည် အမည် လိုအပ်ပါသည်။';

  @override
  String get saleCreditLimitNotNegative =>
      'အကြွေး ကန့်သတ်ချက်သည် အနှုတ်ဂဏန်း ဖြစ်၍ မရပါ။';

  @override
  String get salePaymentMustBePositive => 'ငွေပေးချေမှုသည် သုညထက် ကြီးရပါမည်။';

  @override
  String salePaymentExceedsBalance(String balance) {
    return 'ပေးချေသောငွေသည် ကျန်ငွေ $balance ကျပ်ထက် ကျော်လွန်နေပါသည်။';
  }

  @override
  String get saleCartIsEmpty => 'ဈေးတန်းထဲတွင် ပစ္စည်း မရှိပါ။';

  @override
  String get saleDiscountNotNegative => 'လျှော့ဈေးသည် အနှုတ်ဂဏန်း ဖြစ်၍ မရပါ။';

  @override
  String get saleReceivedNotNegative => 'ရရှိသောငွေသည် အနှုတ်ဂဏန်း ဖြစ်၍ မရပါ။';

  @override
  String saleDiscountExceedsSubtotal(String discount, String subtotal) {
    return 'လျှော့ဈေး $discount သည် ကြားစုစုပေါင်း $subtotal ထက် ကျော်လွန်နေပါသည်။';
  }

  @override
  String get saleBalanceNeedsCustomer =>
      'မရှင်းဆဲ ငွေကျန်ရှိသော ရောင်းချမှုကို ဖောက်သည်တစ်ဦးအား အကြွေးတင်ရပါမည်။';

  @override
  String get salePartialPaymentNotKPay =>
      'KPay ရောင်းချမှုအတွက် ငွေတစ်ပိုင်းတစ်စ ခံယူ၍ မရပါ။ ကျန်ငွေကို အကြွေးအဖြစ် မှတ်တမ်းတင်ပါ သို့မဟုတ် အပြည့်အဝ ငွေရှင်းထိပ်ပါ။';

  @override
  String get saleQuantityAtLeast1 => 'အရေအတွက်သည် အနည်းဆုံး ၁ ဖြစ်ရပါမည်။';

  @override
  String get saleUnitPriceNotNegative =>
      'ယူနစ်ဈေးနှုန်းသည် အနှုတ်ဂဏန်း ဖြစ်၍ မရပါ။';

  @override
  String get saleFactorAtLeast1 =>
      'ယူနစ် ပြောင်းလဲမြှောက်ဖော်ကိန်းသည် ၁ သို့မဟုတ် ၎င်းထက် များရပါမည်။';

  @override
  String get saleLineMustNameUnit =>
      'ရောင်းချစာကြောင်းတိုင်းတွင် ယူနစ်အမည် ပါဝင်ရပါမည်။';

  @override
  String saleCustomerDoesNotExist(String id) {
    return 'ဖောက်သည် $id မတည်ရှိပါ။';
  }

  @override
  String saleCustomerNotActive(String name) {
    return '$name သည် အသုံးပြုနိုင်သော ဖောက်သည် မဟုတ်ပါ။';
  }

  @override
  String saleOverCreditLimit(String name, String projected, String limit) {
    return '$name ၏ အကြွေးကန့်သတ်ချက် ကျော်လွန်နေပါသည် — ဤရောင်းချမှုကြောင့် ကျန်ငွေ $projected ဖြစ်ပြီး ကန့်သတ်ချက် $limit ထက် ကျော်နေမည် ဖြစ်သည်။';
  }

  @override
  String saleShortage(String requested, String available) {
    return 'လက်ကျန် မလုံလောက်ပါ — $requested လိုအပ်သော်လည်း $available သာ ရှိပါသည်။';
  }

  @override
  String saleProductShortage(
    String product,
    String available,
    String requested,
  ) {
    return '$product — လက်ကျန် $available သာရှိပြီး $requested လိုအပ်ပါသည်';
  }

  @override
  String get saleLineMinOneUnit =>
      'ရောင်းချစာကြောင်းတိုင်းသည် အနည်းဆုံး အသေးဆုံးယူနစ် ၁ ခု ယူရပါမည်။';

  @override
  String get saleVoucherDateLabel => 'ရက်စွဲ';

  @override
  String get saleVoucherCustomerLabel => 'ဖောက်သည်';

  @override
  String get saleVoucherCashierLabel => 'ငွေရှင်းသူ';

  @override
  String get saleVoucherTypeLabel => 'အမျိုးအစား';

  @override
  String get saleVoucherBalanceDue => 'ကျငွေ';

  @override
  String get saleVoucherItemHeader => 'ပစ္စည်း';

  @override
  String get saleVoucherQtyHeader => 'အရေအတွက်';

  @override
  String get saleVoucherPriceHeader => 'ဈေးနှုန်း';

  @override
  String get saleVoucherThankYou =>
      'ကျေးဇူးတင်ပါသည်။ ပြန်လည်အပ်နှံရန် ဤဘောက်ချာလက်မှတ်ကို သိမ်းဆည်းထားပါ။';

  @override
  String get saleVoucherShopName => 'ဆေးဆိုင်';
}
