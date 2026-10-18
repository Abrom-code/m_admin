import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:m_admin/features/notifications/controllers/notifications_controller.dart';
import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
import 'package:m_admin/features/notifications/screens/notification_compose_screen.dart';
import 'package:m_admin/features/notifications/services/admin_notification_link_parser.dart';

class _FakeNotificationsController extends GetxController
    implements NotificationsController {
  @override
  final isSending = false.obs;
  @override
  final isLoading = false.obs;
  @override
  final isDeleting = false.obs;
  @override
  final isSelecting = false.obs;
  @override
  final rows = <AdminNotificationModel>[].obs;
  @override
  final selectedIds = <int>{}.obs;
  @override
  final typeFilter = RxnString();
  @override
  final errorMessage = RxnString();
  @override
  bool get allSelected => false;

  @override
  Future<bool> send({
    required String title,
    required String body,
    required String type,
    required String audience,
  }) async {
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('AdminNotificationLinkParser Action Button Labels', () {
    test('resolves Play Store link to Update MatricET', () {
      const link = AdminNotificationLink(
        text: '',
        url: 'https://play.google.com/store/apps/details?id=com.abopia.matricet',
      );
      expect(link.actionButtonLabel, equals('Update MatricET'));
    });

    test('resolves Telegram support bot link to Contact Support', () {
      const link = AdminNotificationLink(
        text: '',
        url: 'https://t.me/matricetbot',
      );
      expect(link.actionButtonLabel, equals('Contact Support'));
    });

    test('resolves Telegram channel link to Join Channel', () {
      const link = AdminNotificationLink(
        text: '',
        url: 'https://t.me/MatricET',
      );
      expect(link.actionButtonLabel, equals('Join Channel'));
    });

    test('resolves Challenge link to Join Challenge', () {
      const link = AdminNotificationLink(
        text: '',
        url: 'challenge:c-1234',
      );
      expect(link.actionButtonLabel, equals('Join Challenge'));
    });
  });

  group('NotificationComposeScreen UI & Zero Overflow', () {
    testWidgets('renders cleanly on narrow screen (360x640) with no TabBar and no overflows', (tester) async {
      final fakeController = _FakeNotificationsController();

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationComposeScreen(controller: fakeController),
        ),
      );
      await tester.pumpAndSettle();

      // No overflows should have occurred
      expect(tester.takeException(), isNull);

      // Verify top Compose and Sent tabs are removed
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Sent'), findsNothing);

      // Verify Compose title in AppBar
      expect(find.text('Compose Notification'), findsWidgets);

      // Verify Compose notification header box is removed
      expect(find.text('Send a push notification to students'), findsNothing);

      // Verify Type and Audience are DropdownButtonFormField widgets in a row
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Audience'), findsOneWidget);
      expect(find.text('Announcement'), findsOneWidget);
      expect(find.text('All students'), findsOneWidget);

      // Verify invalid 'Pricing Promo' is NOT present
      expect(find.text('Pricing Promo'), findsNothing);
      expect(find.text('Upgrade to Premium'), findsNothing);

      // Verify requested action chips are present
      expect(find.text('Play Store'), findsOneWidget);
      expect(find.text('Telegram Channel'), findsOneWidget);
      expect(find.text('Telegram Support'), findsOneWidget);
      expect(find.text('Challenge'), findsOneWidget);
    });

    testWidgets('Quick tags insert exact requested URLs and message typing section is enlarged without leading icon', (tester) async {
      final fakeController = _FakeNotificationsController();

      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationComposeScreen(controller: fakeController),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Play Store chip
      await tester.ensureVisible(find.text('Play Store'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play Store'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('https://play.google.com/store/apps/details?id=com.abopia.matricet'),
        findsWidgets,
      );

      // Tap Telegram Channel chip
      await tester.ensureVisible(find.text('Telegram Channel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Telegram Channel'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('https://t.me/MatricET'),
        findsWidgets,
      );

      // Tap Telegram Support chip
      await tester.ensureVisible(find.text('Telegram Support'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Telegram Support'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('https://t.me/matricetbot'),
        findsWidgets,
      );

      // Verify Message TextField is larger (minLines: 8, maxLines: 16) and has NO leading icon
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      final messageTextField = textFields.firstWhere(
        (tf) => tf.decoration?.labelText == 'Message Body',
      );
      expect(messageTextField.minLines, equals(8));
      expect(messageTextField.maxLines, equals(16));
      expect(messageTextField.decoration?.prefixIcon, isNull);
    });
  });
}
