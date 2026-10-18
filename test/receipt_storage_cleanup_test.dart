import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/data/repositories/admin_payment_repository.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/screens/widgets/receipt_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    Get.reset();
    await GetStorage.init('test_receipt_cleanup_box');
  });

  tearDown(() {
    Get.reset();
  });

  group('ReceiptStorageStats Model', () {
    test('instantiates with accurate metrics', () {
      const stats = ReceiptStorageStats(
        totalActiveScreenshots: 45,
        olderThanOneWeekScreenshots: 38,
        rejectedScreenshotsOlderThan3Days: 8,
        totalRejectedScreenshots: 12,
        rejectedReceiptsCount: 12,
      );

      expect(stats.totalActiveScreenshots, equals(45));
      expect(stats.olderThanOneWeekScreenshots, equals(38));
      expect(stats.rejectedScreenshotsOlderThan3Days, equals(8));
      expect(stats.totalRejectedScreenshots, equals(12));
      expect(stats.rejectedReceiptsCount, equals(12));
    });
  });

  group('PaymentReview Screenshot Tracking & copyWith', () {
    test('hasScreenshot returns true when receiptPath or receiptUrl exists', () {
      const withPath = PaymentReview(
        id: 'r1',
        userId: 'u1',
        userName: 'Abebe',
        userEmail: 'abebe@example.com',
        userStream: 'natural',
        subscriptionStatus: 'active',
        receiptPath: 'u1/receipt_123.jpg',
        receiptUrl: '',
        verificationUrl: '',
        paymentMethod: 'telebirr',
        amount: 200,
        currency: 'ETB',
        status: 'approved',
      );

      expect(withPath.hasScreenshot, isTrue);

      const withUrl = PaymentReview(
        id: 'r2',
        userId: 'u2',
        userName: 'Chala',
        userEmail: 'chala@example.com',
        userStream: 'social',
        subscriptionStatus: 'active',
        receiptPath: '',
        receiptUrl: 'https://example.com/receipt.jpg',
        verificationUrl: '',
        paymentMethod: 'cbe',
        amount: 200,
        currency: 'ETB',
        status: 'approved',
      );

      expect(withUrl.hasScreenshot, isTrue);
    });

    test('hasScreenshot returns false when both are empty', () {
      const purged = PaymentReview(
        id: 'r3',
        userId: 'u3',
        userName: 'Sara',
        userEmail: 'sara@example.com',
        userStream: 'natural',
        subscriptionStatus: 'active',
        receiptPath: '',
        receiptUrl: '',
        verificationUrl: '',
        paymentMethod: 'telebirr',
        amount: 200,
        currency: 'ETB',
        status: 'approved',
      );

      expect(purged.hasScreenshot, isFalse);
    });

    test('copyWith allows clearing receiptPath and receiptUrl to purge screenshot', () {
      const initial = PaymentReview(
        id: 'r4',
        userId: 'u4',
        userName: 'Dawit',
        userEmail: 'dawit@example.com',
        userStream: 'natural',
        subscriptionStatus: 'active',
        receiptPath: 'u4/receipt.jpg',
        receiptUrl: 'https://example.com/receipt.jpg',
        verificationUrl: '',
        paymentMethod: 'abyssinia',
        amount: 200,
        currency: 'ETB',
        status: 'approved',
      );

      expect(initial.hasScreenshot, isTrue);

      final cleared = initial.copyWith(receiptPath: '', receiptUrl: '');

      expect(cleared.hasScreenshot, isFalse);
      expect(cleared.receiptPath, isEmpty);
      expect(cleared.receiptUrl, isEmpty);
      expect(cleared.amount, equals(200));
      expect(cleared.status, equals('approved'));
      expect(cleared.userName, equals('Dawit'));
    });
  });

  group('ReceiptViewer with Purged Screenshot', () {
    testWidgets('renders placeholder without calling resolveUrl when screenshot is purged',
        (tester) async {
      const purgedReview = PaymentReview(
        id: 'r5',
        userId: 'u5',
        userName: 'Helen',
        userEmail: 'helen@example.com',
        userStream: 'natural',
        subscriptionStatus: 'active',
        receiptPath: '',
        receiptUrl: '',
        verificationUrl: '',
        paymentMethod: 'telebirr',
        amount: 200,
        currency: 'ETB',
        status: 'approved',
      );

      var resolveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 500,
              child: ReceiptViewer(
                review: purgedReview,
                resolveUrl: () async {
                  resolveCalled = true;
                  return 'https://example.com/mock.jpg';
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(resolveCalled, isFalse);
      expect(find.text('Screenshot Cleared to Save Storage'), findsOneWidget);
      expect(
        find.textContaining('This payment has been reviewed and verified.'),
        findsOneWidget,
      );
    });
  });
}
