import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

/// Delivers local OS notifications to the admin's device.
///
/// This has nothing to do with FCM — the admin app never receives FCM.
/// FCM is only *sent* to students via the edge function.
///
/// This service is used exclusively for alerting the logged-in admin about
/// events detected over Supabase Realtime (e.g. a new pending payment).
class AdminNotificationService extends GetxService {
  static AdminNotificationService get instance => Get.find();

  static const _channelId = 'admin_alerts';
  static const _channelName = 'Admin Alerts';
  static const _channelDescription =
      'Alerts for new pending payments and other admin events.';

  final _plugin = FlutterLocalNotificationsPlugin();

  // Auto-incrementing ID so multiple notifications don't replace each other.
  int _nextId = 0;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _init();
  }

  Future<void> _init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      ),
    );

    // Request Android 13+ POST_NOTIFICATIONS permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Shows a heads-up notification on the admin device.
  ///
  /// [title] and [body] are the notification text.
  /// [id] can be supplied to update/replace a specific notification; omit to
  /// always show a new one.
  Future<void> show({
    required String title,
    required String body,
    int? id,
  }) async {
    final notifId = id ?? _nextId++;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      // Heads-up banner on Android 5+
      fullScreenIntent: false,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      notifId,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
    );
  }

  /// Convenience method for new-payment alerts.
  Future<void> newPendingPayment({required String paymentMethod}) async {
    final method = paymentMethod.isEmpty
        ? 'New payment'
        : '${paymentMethod[0].toUpperCase()}${paymentMethod.substring(1)}';

    await show(
      title: '💳 New payment pending',
      body: '$method payment is waiting for your review.',
    );
  }
}
