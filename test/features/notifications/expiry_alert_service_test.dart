import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_pos/core/secure/secure_store.dart';
import 'package:pharmacy_pos/features/notifications/application/expiry_alert_service.dart';
import 'package:pharmacy_pos/features/notifications/application/notification_gateway.dart';

/// The expiry-alert decision, driven entirely through fakes.
///
/// `flutter_local_notifications` has no platform channel under `flutter test`,
/// so the plugin call lives behind [NotificationGateway] and the *logic* — which
/// batches qualify, and how often a qualifying batch may fire — is tested here
/// against a [RecordingGateway] and a [MemoryKeyValueStore]-backed [AlertLedger].
///
/// The load-bearing behaviour is the once-per-day dedup: a till that booted six
/// times a day would otherwise scream "Paracetamol expires in 12 days" six times
/// every day, and the shop would learn to swipe the alerts away. Dedup keyed on
/// (batch, calendar date) is what turns a nag into a usable daily reminder.
class RecordingGateway implements NotificationGateway {
  final List<(int id, String title, String body)> shown = [];
  int initCalls = 0;

  @override
  Future<void> init({NotificationLabels? labels}) async => initCalls++;

  @override
  Future<void> showExpiryAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    shown.add((id, title, body));
  }
}

void main() {
  late RecordingGateway gateway;
  late AlertLedger ledger;
  late ExpiryAlertService service;

  // A fixed "now" so day-rollover is deterministic; never DateTime.now() here.
  final day1 = DateTime(2026, 9, 24, 8);
  final day2 = day1.add(const Duration(days: 1));

  ExpiryAlert alert({required int batchId, required int days}) => ExpiryAlert(
    batchId: batchId,
    tradeName: 'Med-$batchId',
    daysToExpiry: days,
  );

  setUp(() {
    gateway = RecordingGateway();
    ledger = AlertLedger(SecureStore(store: MemoryKeyValueStore()));
    service = ExpiryAlertService(gateway: gateway, ledger: ledger);
  });

  test('a batch inside the window fires exactly once', () async {
    final fired = await service.checkAndAlert(
      expiring: [alert(batchId: 5, days: 12)],
      now: day1,
    );
    expect(fired, 1);
    expect(gateway.shown, hasLength(1));
    // The batch id is reused as the notification id so a re-show replaces
    // rather than stacks.
    expect(gateway.shown.single.$1, 5);
    expect(gateway.shown.single.$2, isNotEmpty);
    expect(gateway.shown.single.$3, contains('Med-5'));
  });

  test('the same batch does not re-fire on the same calendar day', () async {
    await service.checkAndAlert(
      expiring: [alert(batchId: 5, days: 12)],
      now: day1,
    );
    final again = await service.checkAndAlert(
      expiring: [alert(batchId: 5, days: 12)],
      // later the same day, different clock-time.
      now: DateTime(2026, 9, 24, 19),
    );
    expect(again, 0);
    expect(gateway.shown, hasLength(1));
  });

  test('a batch re-fires the next day', () async {
    await service.checkAndAlert(
      expiring: [alert(batchId: 5, days: 11)],
      now: day1,
    );
    final next = await service.checkAndAlert(
      expiring: [alert(batchId: 5, days: 11)],
      now: day2,
    );
    expect(next, 1, reason: 'a new day is a new reminder');
    expect(gateway.shown, hasLength(2));
  });

  test('a batch beyond the window never fires', () async {
    final fired = await service.checkAndAlert(
      expiring: [alert(batchId: 9, days: kExpiryAlertWindowDays + 1)],
      now: day1,
    );
    expect(fired, 0);
    expect(gateway.shown, isEmpty);
  });

  test('the window boundary is inclusive', () async {
    // daysToExpiry == the window (30) is "expiring within 30 days" and MUST
    // alert; an off-by-one here silently loses a whole day of the alert band.
    final fired = await service.checkAndAlert(
      expiring: [alert(batchId: 10, days: kExpiryAlertWindowDays)],
      now: day1,
    );
    expect(fired, 1);
  });

  test('dedup is per batch, not global', () async {
    // Firing batch 5 must not suppress batch 6 the same day — otherwise a shop
    // with several near-expiry lines only ever hears about the first one.
    await service.checkAndAlert(
      expiring: [alert(batchId: 5, days: 3)],
      now: day1,
    );
    final fired = await service.checkAndAlert(
      expiring: [alert(batchId: 6, days: 4)],
      now: day1,
    );
    expect(fired, 1);
    expect(gateway.shown.map((n) => n.$1), containsAll([5, 6]));
  });

  test('a mixed list alerts only the eligible, not-yet-seen batches', () async {
    final fired = await service.checkAndAlert(
      expiring: [
        alert(batchId: 1, days: 5), // eligible
        alert(batchId: 2, days: 90), // outside window
        alert(batchId: 3, days: -2), // already expired (negative) — still <30,
        // but a *negative* is a write-off problem, not an upcoming one; the
        // current rule keeps it (<= window). Pinned so a future change to the
        // rule is a conscious decision, not a silent regression.
      ],
      now: day1,
    );
    expect(fired, 2);
    expect(gateway.shown.map((n) => n.$1), containsAll([1, 3]));
    expect(gateway.shown.map((n) => n.$1), isNot(contains(2)));
  });
}
