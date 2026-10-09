import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';

/// Delivers local OS notifications to the admin's device.
///
/// This service alerts the logged-in admin about pending payments and other
/// critical events, with automatic fallback polling and notification tap navigation.
class AdminNotificationService extends GetxService {
  static AdminNotificationService get instance => Get.find();

  // Channel ID updated to v2 to force recreation with max importance & sound on Android
  static const _channelId = 'admin_alerts_v2';
  static const _channelName = 'Admin Alerts';
  static const _channelDescription =
      'Alerts for pending payments and admin events.';

  final _plugin = FlutterLocalNotificationsPlugin();

  // Auto-incrementing ID so multiple notifications don't replace each other.
  int _nextId = 0;

  /// Whether the service initialized successfully.
  bool _ready = false;
  bool get isReady => _ready;

  @override
  Future<void> onInit() async {
    super.onInit();
  }

  /// Called by main() or on-demand so initialization is fully completed.
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
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      if (initialized != true) {
        debugPrint('[AdminNotificationService] Plugin init returned false.');
        return;
      }

      // Create the Android notification channel explicitly with MAX importance
      // so heads-up alerts and sounds work reliably.
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      _ready = true;
      debugPrint('[AdminNotificationService] Initialized successfully.');
    } catch (e) {
      debugPrint('[AdminNotificationService] Init error: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[AdminNotificationService] Notification tapped: ${response.payload}');
    if (Get.isRegistered<AdminNavController>()) {
      AdminNavController.instance.changePage(AdminNavPage.payments);
    }
  }

  /// Explicitly requests notification permissions on Android 13+ and iOS.
  /// Safe to call after UI is mounted.
  Future<bool> requestPermission() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint(
          '[AdminNotificationService] Notification permission granted: $granted',
        );
        return granted ?? false;
      }

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return true;
    } catch (e) {
      debugPrint('[AdminNotificationService] Permission request error: $e');
      return false;
    }
  }

  /// Checks whether notifications are currently allowed.
  Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        return enabled ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Shows a heads-up notification on the admin device.
  Future<void> show({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (!_ready) {
      debugPrint('[AdminNotificationService] Not ready — attempting initialization...');
      await _init();
    }

    final notifId = id ?? _nextId++;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: false,
      styleInformation: BigTextStyleInformation(body),
      icon: '@mipmap/launcher_icon',
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
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          macOS: iosDetails,
        ),
        payload: payload ?? 'payments',
      );
      debugPrint('[AdminNotificationService] Notification delivered: "$title" - "$body"');
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
      payload: 'payments',
    );
  }

  /// Convenience method for pending payment count alerts.
  Future<void> pendingPaymentsAlert({required int count}) async {
    if (count <= 0) return;
    await show(
      id: 1001, // Specific ID so summary updates in-place
      title: '💳 Pending payments awaiting review',
      body: count == 1
          ? '1 payment is waiting for your verification.'
          : '$count payments are waiting for your verification.',
      payload: 'payments',
    );
  }

  /// Test notification to immediately confirm the notification system works.
  Future<void> testNotification() async {
    await show(
      id: 1000,
      title: '🔔 Test Notification',
      body: 'Local notifications are active and working!',
      payload: 'payments',
    );
  }
}
