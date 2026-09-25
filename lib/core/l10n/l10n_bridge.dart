import 'package:flutter/widgets.dart';

import '../../features/auth/application/auth_errors.dart';
import '../../features/backup/application/backup_errors.dart';
import '../../features/credit/application/credit_errors.dart';
import '../../features/expenses/application/expense_errors.dart';
import '../../features/inventory/application/inventory_errors.dart';
import '../../features/license/application/license_errors.dart';
import '../../features/purchases/application/purchase_errors.dart';
import '../../features/sales/application/sales_errors.dart';
import '../../l10n/generated/app_localizations.dart';

/// An error that carries a localisation key instead of user-facing text.
///
/// Data layers throw these; presentation layers render them through
/// [AppLocalizationsError.describe]. [debugMessage] stays English for logs.
abstract class LocalizedError implements Exception {
  String get errorKey;

  Map<String, String> get errorArgs;

  String get debugMessage;

  @override
  String toString() => debugMessage;
}

typedef ErrorMessageResolver = String? Function(
  AppLocalizations l10n,
  String key,
  Map<String, String> args,
);

/// Each feature module owns one resolver over its error keys; a key not
/// claimed by any resolver is a bug, surfaced verbatim for debugging.
const List<ErrorMessageResolver> _errorResolvers = [
  authErrors,
  licenseErrors,
  inventoryErrors,
  purchaseErrors,
  salesErrors,
  creditErrors,
  expenseErrors,
  backupErrors,
];

extension AppLocalizationsError on AppLocalizations {
  /// Translates a bare error key (also usable by providers that carry keys
  /// instead of exceptions). Falls back to the key itself when unregistered.
  String message(String key, [Map<String, String> args = const {}]) {
    for (final resolve in _errorResolvers) {
      final text = resolve(this, key, args);
      if (text != null) return text;
    }
    return key;
  }

  /// Renders any caught object as user-facing text.
  String describe(Object error) => error is LocalizedError
      ? message(error.errorKey, error.errorArgs)
      : error.toString();
}

extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
