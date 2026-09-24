import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/l10n/generated/app_localizations.dart';

/// The translation files actually load and render, not just compile.
///
/// The framework (`LocaleController`, `SecureStore`) is unit-tested elsewhere;
/// what is easy to break silently is the ARB → generated-class → `Localizations`
/// pipeline: a missing `flutter: generate: true`, a locale code the delegates do
/// not carry, or a template-only key that never got a Burmese value would all
/// still analyze and build, yet show English (or an assertion) on a Burmese
/// device. This test pumps a trivial widget through the same delegate set
/// `main.dart` installs and asserts the real Myanmar strings come back.
void main() {
  Future<void> pumpIn(WidgetTester tester, String locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Column(
              children: [
                Text(l10n.pointOfSale),
                Text(l10n.checkout),
                Text(l10n.noProductMatches('999')),
              ],
            );
          },
        ),
      ),
    );
  }

  testWidgets('English locale renders the template strings', (tester) async {
    await pumpIn(tester, 'en');
    expect(find.text('Point of Sale'), findsOneWidget);
    expect(find.text('Checkout'), findsOneWidget);
    // A placeholder message interpolates the value, in both languages.
    expect(find.text('No product matches 999.'), findsOneWidget);
  });

  testWidgets('Myanmar locale renders Burmese strings', (tester) async {
    await pumpIn(tester, 'my');
    expect(find.text('ရောင်းချစနစ်'), findsOneWidget); // Point of Sale
    expect(find.text('ငွေရှင်းရန်'), findsOneWidget); // Checkout
    expect(find.text('999 နှင့်ကိုက်ညီသော ပစ္စည်းမတွေ့ပါ။'), findsOneWidget);
  });

  test('both locales are declared as supported', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
      containsAll(['en', 'my']),
    );
  });
}
