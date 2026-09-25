import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/secure/secure_store.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/data/inventory_repository.dart';
import 'notification_gateway.dart';

/// Alert window: batches expiring within this many days trigger notifications.
const int kExpiryAlertWindowDays = 30;

/// Lightweight batch info for expiry alerts.
///
/// Decoupled from [StockBatch] so the alert logic can be tested without drift
/// dependencies.
class ExpiryAlert {
  const ExpiryAlert({
    required this.batchId,
    required this.tradeName,
    required this.daysToExpiry,
  });

  final int batchId;
  final String tradeName;
  final int daysToExpiry;
}

/// Tracks which batches have been alerted on which dates, so we don't spam
/// the same batch every day.
///
/// Stores one key per batch: `expiry_alert.{batchId}` → `yyyy-mm-dd` of the
/// last alert date. A batch is "already alerted today" when its stored date
/// matches today's date.
class AlertLedger {
  AlertLedger(this._store);

  final SecureStore _store;

  static String _keyFor(int batchId) => 'expiry_alert.$batchId';

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Returns true if [batchId] was already alerted on [date].
  Future<bool> wasAlertedToday(int batchId, DateTime date) async {
    final stored = await _store.read(_keyFor(batchId));
    return stored == _dateKey(date);
  }

  /// Marks [batchId] as alerted on [date].
  Future<void> markAlerted(int batchId, DateTime date) async {
    await _store.write(key: _keyFor(batchId), value: _dateKey(date));
  }
}

/// Service that checks expiring batches and fires notifications.
///
/// Pure logic: takes a list of [ExpiryAlert] and a [now] timestamp, filters
/// by the alert window, deduplicates via [AlertLedger], and calls the gateway
/// for each new alert. Returns the count of notifications actually shown.
class ExpiryAlertService {
  ExpiryAlertService({required this.gateway, required this.ledger});

  final NotificationGateway gateway;
  final AlertLedger ledger;

  /// Checks [expiring] batches and shows notifications for those within
  /// [kExpiryAlertWindowDays] that haven't been alerted today.
  ///
  /// [labels] carries the user-facing strings, resolved into the current
  /// language by the caller; it defaults to English so context-free callers
  /// (and tests) keep working.
  ///
  /// Returns the number of notifications shown.
  Future<int> checkAndAlert({
    required List<ExpiryAlert> expiring,
    required DateTime now,
    NotificationLabels labels = const NotificationLabels.fallback(),
  }) async {
    var count = 0;

    for (final alert in expiring) {
      if (alert.daysToExpiry > kExpiryAlertWindowDays) {
        continue;
      }
      if (await ledger.wasAlertedToday(alert.batchId, now)) {
        continue;
      }

      await gateway.showExpiryAlert(
        id: alert.batchId,
        title: labels.alertTitle,
        body: labels.expiryBody(alert.tradeName, alert.daysToExpiry),
      );
      await ledger.markAlerted(alert.batchId, now);
      count++;
    }

    return count;
  }
}

/// Provider for the notification gateway.
///
/// Uses the plugin implementation in production. Tests override this with a
/// fake gateway.
final Provider<NotificationGateway> notificationGatewayProvider =
    Provider<NotificationGateway>((ref) => PluginNotificationGateway());

/// Provider for the alert ledger.
final Provider<AlertLedger> alertLedgerProvider = Provider<AlertLedger>((ref) {
  final store = ref.watch(secureStoreProvider);
  return AlertLedger(store);
});

/// Provider for the expiry alert service.
final Provider<ExpiryAlertService> expiryAlertServiceProvider =
    Provider<ExpiryAlertService>((ref) {
      final gateway = ref.watch(notificationGatewayProvider);
      final ledger = ref.watch(alertLedgerProvider);
      return ExpiryAlertService(gateway: gateway, ledger: ledger);
    });

/// Startup hook: checks expiring batches and fires notifications.
///
/// Called from [BootGate._bootstrap] after licence and auth are loaded. Wrapped
/// in try/catch so notification failures don't block app startup. [labels]
/// should be built by the caller from `AppLocalizations` so alerts appear in
/// the user's language; without it the English fallbacks are used.
Future<void> runExpiryAlertStartup(
  WidgetRef ref, {
  NotificationLabels? labels,
}) async {
  try {
    final resolved = labels ?? const NotificationLabels.fallback();
    final service = ref.read(expiryAlertServiceProvider);
    final gateway = ref.read(notificationGatewayProvider);

    await gateway.init(labels: resolved);

    final repo = ref.read(inventoryRepositoryProvider);
    final batches = await repo.expiringWithin(kExpiryAlertWindowDays);

    final alerts = [
      for (final batch in batches)
        ExpiryAlert(
          batchId: batch.batch.id,
          tradeName: batch.tradeName ?? resolved.unknownBatch,
          daysToExpiry: batch.daysToExpiry,
        ),
    ];

    await service.checkAndAlert(
      expiring: alerts,
      now: DateTime.now(),
      labels: resolved,
    );
  } catch (_) {
    // Notifications are best-effort; don't block startup on failure.
  }
}
