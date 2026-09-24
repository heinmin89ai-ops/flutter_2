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
  String noUnitsYet(String name) {
    return '$name has no units configured yet.';
  }
}
