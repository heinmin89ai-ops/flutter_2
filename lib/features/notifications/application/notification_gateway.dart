import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Gateway for showing local notifications.
///
/// Abstracted behind an interface so tests can use a fake implementation without
/// platform channels. The concrete [PluginNotificationGateway] wraps
/// flutter_local_notifications and catches MissingPluginException so the app
/// doesn't crash on platforms without notification support.
abstract interface class NotificationGateway {
  Future<void> init();
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

  @override
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(settings: initSettings);

      // Create the notification channel for Android 8.0+.
      if (defaultTargetPlatform == TargetPlatform.android) {
        const channel = AndroidNotificationChannel(
          'expiring_stock',
          'Expiring Stock Alerts',
          description: 'Notifications for batches expiring soon',
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
    const androidDetails = AndroidNotificationDetails(
      'expiring_stock',
      'Expiring Stock Alerts',
      channelDescription: 'Notifications for batches expiring soon',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

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
