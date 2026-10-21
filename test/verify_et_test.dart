import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/models/verify_et_model.dart';
import 'package:m_admin/features/payments/controllers/verify_et_controller.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_verify_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (methodCall) async => '.');

  group('Verify.ET Model & Controller Tests', () {
    test('VerifyEtResult parses 200 Completed JSON payload correctly', () {
      final json = {
        'bank': 'cbe',
        'status': 'success',
        'verified': true,
        'amount': 1500,
        'currency': 'ETB',
        'senderName': 'Abebe Bikila',
        'receiverName': 'Acme Trading',
        'receiverAccount': '1****7441',
        'referenceNumber': 'FT26EXAMPLE1',
        'receiptNumber': 'fHCxyExampleRcpt1',
        'timestamp': '2026-02-20T12:00:00.000Z',
        'confirmationHistory': {
          'scope': 'platform',
          'isFirstConfirmation': true,
          'confirmedBefore': false,
          'firstConfirmedAt': '2026-02-20T12:00:00.000Z',
          'lastConfirmedAt': '2026-02-20T12:00:00.000Z',
          'confirmationCount': 1,
        },
        'settlementAccountMatch': {
          'matched': true,
          'matchType': 'masked_pattern',
          'matchConfidence': 'high',
          'source': 'account_registry',
          'bank': 'cbe',
          'receiverAccount': '1****7441',
          'matchedSettlementAccount': '1000303997441',
          'candidateCount': 1,
          'ambiguous': false,
          'reason': 'receiver_mask_matches_visible_digits',
        },
      };

      final result = VerifyEtResult.fromJson(json, requestId: 'req-abc-123');

      expect(result.verified, isTrue);
      expect(result.bank, equals('cbe'));
      expect(result.amount, equals(1500.0));
      expect(result.currency, equals('ETB'));
      expect(result.senderName, equals('Abebe Bikila'));
      expect(result.receiverName, equals('Acme Trading'));
      expect(result.receiverAccount, equals('1****7441'));
      expect(result.referenceNumber, equals('FT26EXAMPLE1'));
      expect(result.receiptNumber, equals('fHCxyExampleRcpt1'));
      expect(result.requestId, equals('req-abc-123'));

      // Check settlement match
      expect(result.settlementAccountMatch, isNotNull);
      expect(result.settlementAccountMatch!.matched, isTrue);
      expect(result.settlementAccountMatch!.matchedSettlementAccount, equals('1000303997441'));
      expect(result.settlementAccountMatch!.reasonLabel, contains('Mask matches visible account digits'));

      // Check confirmation history
      expect(result.confirmationHistory, isNotNull);
      expect(result.confirmationHistory!.isFirstConfirmation, isTrue);
      expect(result.confirmationHistory!.confirmationCount, equals(1));
    });

    test('VerifyEtResult handles unverified / queued payload', () {
      final json = {
        'bank': 'telebirr',
        'status': 'pending',
        'verified': false,
        'amount': 0,
        'currency': 'ETB',
        'processingStatus': 'queued',
      };

      final result = VerifyEtResult.fromJson(json);

      expect(result.verified, isFalse);
      expect(result.bank, equals('telebirr'));
      expect(result.status, equals('pending'));
      expect(result.processingStatus, equals('queued'));
    });

    test('VerifyEtController pre-fills bank and reference from PaymentReview', () {
      const review = PaymentReview(
        id: 'rev-1',
        userId: 'user-1',
        userName: 'Abebe Test',
        userEmail: 'abebe@test.com',
        userStream: 'natural',
        subscriptionStatus: 'inactive',
        receiptPath: 'receipts/test.jpg',
        receiptUrl: 'https://example.com/receipt.jpg',
        verificationUrl: 'fHCxyTestReceipt123',
        paymentMethod: 'cbe',
        status: 'pending',
        amount: 300,
        currency: 'ETB',
      );

      final ctrl = Get.put(VerifyEtController());
      ctrl.prefillFromReview(review);

      expect(ctrl.selectedBank.value, equals('cbe'));
      expect(ctrl.referenceCtrl.text, equals('fHCxyTestReceipt123'));
    });

    test('PaymentVerifyChecker activates for CBE (including payment_cbe_birr), Telebirr, and Abyssinia', () {
      expect(PaymentVerifyChecker.resolveSupportedBank('cbe'), equals('cbe'));
      expect(PaymentVerifyChecker.resolveSupportedBank('payment_cbe'), equals('cbe'));
      expect(PaymentVerifyChecker.resolveSupportedBank('payment_cbe_birr'), equals('cbe'));
      expect(PaymentVerifyChecker.resolveSupportedBank('cbe_birr'), equals('cbe'));
      expect(PaymentVerifyChecker.resolveSupportedBank('commercial_bank_of_ethiopia'), equals('cbe'));
      expect(PaymentVerifyChecker.resolveSupportedBank('telebirr'), equals('telebirr'));
      expect(PaymentVerifyChecker.resolveSupportedBank('payment_telebirr'), equals('telebirr'));
      expect(PaymentVerifyChecker.resolveSupportedBank('abyssinia'), equals('boa'));
      expect(PaymentVerifyChecker.resolveSupportedBank('payment_abyssinia'), equals('boa'));
      expect(PaymentVerifyChecker.resolveSupportedBank('boa'), equals('boa'));

      // Non-supported methods should return null (no checker shown)
      expect(PaymentVerifyChecker.resolveSupportedBank('cash'), isNull);
      expect(PaymentVerifyChecker.resolveSupportedBank('other'), isNull);
    });

    testWidgets('PaymentVerifyChecker header renders on narrow screen (320px) without overflow on LIVE badge and Scan button', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const review = PaymentReview(
        id: 'rev-narrow',
        userId: 'user-narrow',
        userName: 'Tigist Getnet',
        userEmail: 'tigist@test.com',
        userStream: 'natural',
        subscriptionStatus: 'inactive',
        receiptPath: 'receipts/test.jpg',
        receiptUrl: 'https://example.com/receipt.jpg',
        verificationUrl: 'https://example.com/receipt.jpg',
        paymentMethod: 'cbe',
        status: 'pending',
        amount: 200,
        currency: 'ETB',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaymentVerifyChecker(review: review),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
