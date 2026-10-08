import 'package:flutter/foundation.dart';
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

  /// Whether the service initialized successfully.
  bool _ready = false;

  @override
  Future<void> onInit() async {
    super.onInit();
    // onInit is called by Get.put — but main() awaits init() directly via
    // putAsync, so this is a no-op to avoid double-initializing.
  }

  /// Called by main() via Get.putAsync so initialization is fully awaited
  /// before any Realtime subscription can fire.
  Future<void> init() async {
    await _init();
  }

  Future<void> _init() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final initialized = await _plugin.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
          macOS: iosSettings,
        ),
      );

      if (initialized != true) {
        debugPrint('[AdminNotificationService] Plugin init returned false.');
        return;
      }

      // Create the Android notification channel explicitly so the OS knows
      // about it before the first notification is shown.
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );

        // Request Android 13+ POST_NOTIFICATIONS permission.
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint(
          '[AdminNotificationService] Notification permission: $granted',
        );
      }

      _ready = true;
      debugPrint('[AdminNotificationService] Initialized successfully.');
    } catch (e) {
      debugPrint('[AdminNotificationService] Init error: $e');
    }
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
    if (!_ready) {
      debugPrint('[AdminNotificationService] Not ready — skipping "$title".');
      return;
    }

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

    try {
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
    } catch (e) {
      debugPrint('[AdminNotificationService] show() error: $e');
    }
  }

  /// Convenience method for new-payment alerts.
  Future<void> newPendingPayment({required String paymentMethod}) async {
    final method = paymentMethod.isEmpty
        ? 'New'
        : '${paymentMethod[0].toUpperCase()}${paymentMethod.substring(1)}';

    await show(
      title: '💳 New payment pending',
      body: '$method payment is waiting for your review.',
    );
  }
}
