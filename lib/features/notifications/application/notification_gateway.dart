import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// User-facing strings for expiry notifications.
///
/// The gateway and the alert service sit below the widget tree and have no
/// [BuildContext], so the startup caller resolves these through
/// `AppLocalizations` for the current language and passes them in. The
/// [NotificationLabels.fallback] keeps the previous English copy for
/// context-free callers and tests.
class NotificationLabels {
  const NotificationLabels({
    required this.channelName,
    required this.channelDescription,
    required this.alertTitle,
    required this.expiryBody,
    required this.unknownBatch,
  });

  /// English defaults, identical to the strings shown before localisation.
  const NotificationLabels.fallback()
    : this(
        channelName: 'Expiring Stock Alerts',
        channelDescription: 'Notifications for batches expiring soon',
        alertTitle: 'Batch expiring soon',
        expiryBody: defaultExpiryBody,
        unknownBatch: 'Unknown',
      );

  static String defaultExpiryBody(String tradeName, int daysToExpiry) =>
      '$tradeName expires in $daysToExpiry days';

  /// Android notification channel name, visible in OS settings.
  final String channelName;
  final String channelDescription;
  final String alertTitle;

  /// Renders the notification body for [tradeName] expiring in
  /// [daysToExpiry] days.
  final String Function(String tradeName, int daysToExpiry) expiryBody;

  /// Placeholder for batches without a trade name.
  final String unknownBatch;
}

/// Gateway for showing local notifications.
///
/// Abstracted behind an interface so tests can use a fake implementation without
/// platform channels. The concrete [PluginNotificationGateway] wraps
/// flutter_local_notifications and catches MissingPluginException so the app
/// doesn't crash on platforms without notification support.
abstract interface class NotificationGateway {
  /// Prepares the plugin and creates the Android channel. [labels] supplies
  /// the localized channel name/description; omit it for the English
  /// fallbacks.
  Future<void> init({NotificationLabels? labels});
  Future<void> showExpiryAlert({
    required int id,
    required String title,
    required String body,
  });
}

/// Production implementation using flutter_local_notifications.
class PluginNotificationGateway implements NotificationGateway {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Channel strings captured at [init]; Android reads the name from the
  /// channel, so later language changes only take effect on the next init.
  NotificationLabels _labels = const NotificationLabels.fallback();

  @override
  Future<void> init({NotificationLabels? labels}) async {
    _labels = labels ?? _labels;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(settings: initSettings);

      // Create the notification channel for Android 8.0+.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final channel = AndroidNotificationChannel(
          'expiring_stock',
          _labels.channelName,
          description: _labels.channelDescription,
          importance: Importance.high,
        );
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }
    } catch (e) {
      // Platform doesn't support notifications or initialization failed — no-op.
    }
  }

  @override
  Future<void> showExpiryAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'expiring_stock',
      _labels.channelName,
      channelDescription: _labels.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      // Platform doesn't support notifications or show failed — no-op.
    }
  }
}
