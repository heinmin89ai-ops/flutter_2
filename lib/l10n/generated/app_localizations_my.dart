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
}
