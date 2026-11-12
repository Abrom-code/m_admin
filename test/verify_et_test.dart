import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/data/services/scanned_receipt_storage.dart';
import 'package:m_admin/data/services/receipt_extractor_service.dart';
import 'package:m_admin/data/services/verify_et_service.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/models/verify_et_model.dart';
import 'package:m_admin/features/payments/controllers/verify_et_controller.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_verify_checker.dart';
import 'package:m_admin/features/payments/screens/widgets/verify_et_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async => '.');
    await GetStorage.init();
  });

  group('links.et Model, Scanned Database & Controller Tests', () {
    test('LinksEtResult parses telebirr-html receipt correctly', () {
      final json = {
        'ok': true,
        'providerKey': 'telebirr',
        'resolvedUrl': 'https://transactioninfo.ethiotelecom.et/receipt/ABCD1234EF',
        'httpStatus': 200,
        'fetchedAt': '2026-01-01T00:00:00.000Z',
        'rawHtmlLength': 25928,
        'error': null,
        'receipt': {
          'source': 'telebirr-html',
          'payerName': 'Abebe Bikila',
          'payerTelebirrNo': '251911223344',
          'creditedPartyName': 'MatricMate Platform',
          'creditedPartyAccountNo': '251933445566',
          'transactionStatus': 'Completed',
          'receiptNo': 'ABCD1234EF',
          'paymentDate': '01-01-2026 00:00:00',
          'settledAmount': '1500 Birr',
          'serviceFee': '1.74 Birr',
          'serviceFeeVAT': '0.26 Birr',
          'totalPaidAmount': '1502 Birr',
          'paymentReason': 'MatricMate Subscription',
          'paymentMode': 'telebirr',
          'paymentChannel': 'API/App',
        },
      };

      final result = LinksEtResult.fromJson(json);

      expect(result.ok, isTrue);
      expect(result.verified, isTrue);
      expect(result.providerKey, equals('telebirr'));
      expect(result.amount, equals(1500.0));
      expect(result.currency, equals('ETB'));
      expect(result.senderName, equals('Abebe Bikila'));
      expect(result.receiverName, equals('MatricMate Platform'));
      expect(result.referenceNumber, equals('ABCD1234EF'));
      expect(result.receipt?.source, equals('telebirr-html'));
      expect(result.receipt?.totalAmount, equals(1502.0));
    });

    test('LinksEtResult parses cbe-pdf and mb-json receipts correctly', () {
      final cbePdfJson = {
        'ok': true,
        'providerKey': 'cbe',
        'resolvedUrl': 'https://mreciept.cbe.com.et/v2/test-cbe',
        'httpStatus': 200,
        'receipt': {
          'source': 'cbe-pdf',
          'payerName': 'Chala Desta',
          'payerAccount': '1000****7441',
          'receiverName': 'MatricMate Org',
          'receiverAccount': '1000303997441',
          'paymentDate': '1/1/2026, 00:00:00 AM',
          'reference': 'FT2600000000',
          'paymentReason': 'Account Transfer',
          'transferredAmount': 850,
          'totalAmount': 852,
          'currency': 'ETB',
        },
      };

      final result = LinksEtResult.fromJson(cbePdfJson);
      expect(result.verified, isTrue);
      expect(result.bank, equals('cbe'));
      expect(result.amount, equals(850.0));
      expect(result.senderName, equals('Chala Desta'));
      expect(result.referenceNumber, equals('FT2600000000'));
      expect(result.receiverAccount, equals('1000303997441'));
    });

    test('LinksEtResult handles queued 202 response with statusUrl', () {
      final queuedJson = {
        'processingStatus': 'queued',
        'requestId': '550e8400-e29b-41d4-a716-446655440000',
        'statusUrl': '/api/verify/550e8400-e29b-41d4-a716-446655440000',
        'eventsUrl': '/api/verify/550e8400-e29b-41d4-a716-446655440000/events',
        'httpStatus': 202,
      };

      final result = LinksEtResult.fromJson(queuedJson);
      expect(result.isPending, isTrue);
      expect(result.verified, isFalse);
      expect(result.requestId, equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(result.statusUrl, equals('/api/verify/550e8400-e29b-41d4-a716-446655440000'));
    });

    test('ScannedReceiptStorage stores verification and detects previously scanned receipts with status and date', () {
      final storage = ScannedReceiptStorage();
      storage.clearAll();

      const testRef = 'DF33KS5FB9';
      const testMethod = 'telebirr';

      // 1. Initially, reference should not exist in database
      expect(storage.findRecord(testRef), isNull);

      // 2. First verification: stores method, id, status, date
      final saved1 = storage.saveRecord(
        id: testRef,
        method: testMethod,
        status: 'verified',
        amount: 300.0,
        payerName: 'Almaz',
      );

      expect(saved1.id, equals(testRef));
      expect(saved1.method, equals(testMethod));
      expect(saved1.status, equals('verified'));
      expect(saved1.scanCount, equals(1));
      expect(saved1.wasScannedBefore, isFalse);

      // 3. Lookup finds the stored record
      final found = storage.findRecord(testRef);
      expect(found, isNotNull);
      expect(found!.id, equals(testRef));
      expect(found.method, equals(testMethod));
      expect(found.status, equals('verified'));
      expect(found.formattedScannedDate, isNotEmpty);

      // 4. Second scan (double-scan simulation): stores updated record with previous status and date
      final saved2 = storage.saveRecord(
        id: testRef,
        method: testMethod,
        status: 'verified',
        amount: 300.0,
      );

      expect(saved2.scanCount, equals(2));
      expect(saved2.wasScannedBefore, isTrue);
      expect(saved2.previousStatus, equals('verified'));
      expect(saved2.previousScannedAt, isNotNull);

      // Cleanup
      storage.clearAll();
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
        verificationUrl: 'https://mreciept.cbe.com.et/v2/test',
        paymentMethod: 'cbe',
        status: 'pending',
        amount: 300,
        currency: 'ETB',
      );

      final ctrl = Get.put(VerifyEtController());
      ctrl.prefillFromReview(review);

      expect(ctrl.selectedBank.value, equals('cbe'));
      expect(ctrl.referenceCtrl.text, equals('https://mreciept.cbe.com.et/v2/test'));
    });

    test('PaymentVerifyChecker resolves supported Ethiopian bank methods', () {
      expect(PaymentVerifyChecker.resolveSupportedBank('cbe'), equals('cbe'));
      expect(PaymentVerifyChecker.resolveSupportedBank('payment_cbe'), equals('cbe'));
      expect(PaymentVerifyChecker.resolveSupportedBank('payment_cbe_birr'), equals('cbe'));
      expect(PaymentVerifyChecker.resolveSupportedBank('telebirr'), equals('telebirr'));
      expect(PaymentVerifyChecker.resolveSupportedBank('payment_telebirr'), equals('telebirr'));
      expect(PaymentVerifyChecker.resolveSupportedBank('abyssinia'), equals('boa'));
      expect(PaymentVerifyChecker.resolveSupportedBank('boa'), equals('boa'));
      expect(PaymentVerifyChecker.resolveSupportedBank('awash'), equals('awash'));
      expect(PaymentVerifyChecker.resolveSupportedBank('zemen'), equals('zemen'));
      expect(PaymentVerifyChecker.resolveSupportedBank('mpesa'), equals('mpesa'));
      expect(PaymentVerifyChecker.resolveSupportedBank('cash'), isNull);
    });

    test('LinksEtService.sanitizeTelebirrReference extracts clean tokens from prefixes, URLs and whitespace', () {
      expect(
        LinksEtService.sanitizeTelebirrReference('DET8FJGUJ4'),
        equals('DET8FJGUJ4'),
      );
      expect(
        LinksEtService.sanitizeTelebirrReference(' det8fjguj4 '),
        equals('DET8FJGUJ4'),
      );
      expect(
        LinksEtService.sanitizeTelebirrReference('Transaction No: DJL64F9ZOE'),
        equals('DJL64F9ZOE'),
      );
      expect(
        LinksEtService.sanitizeTelebirrReference('Lakkoofsa Kaffaltii DJL64F9ZOE'),
        equals('DJL64F9ZOE'),
      );
      expect(
        LinksEtService.sanitizeTelebirrReference('https://transactioninfo.ethiotelecom.et/receipt/DF33KS5FB9'),
        equals('DF33KS5FB9'),
      );
      expect(
        LinksEtService.sanitizeTelebirrReference('transactioninfo.ethiotelecom.et/receipt/ABCD1234EF'),
        equals('ABCD1234EF'),
      );
    });

    test('LinksEtResult identifies parsed but failed validation (missing receipt) and provides user-friendly guidance', () {
      final json = {
        'ok': false,
        'providerKey': 'telebirr',
        'resolvedUrl': 'https://transactioninfo.ethiotelecom.et/receipt/NOTFOUND12',
        'httpStatus': 200,
        'receipt': {'source': 'telebirr-html'},
        'error': 'parsed but failed validation (missing receiptNo / payerName / transactionStatus)',
      };

      final result = LinksEtResult.fromJson(json);

      expect(result.verified, isFalse);
      expect(result.isSuccess, isFalse);
      expect(result.isParsedButInvalid, isTrue);
      expect(result.status, equals('Receipt Not Found'));
      expect(result.userFriendlyErrorMessage, contains('Receipt not found on Ethio Telecom portal'));
      expect(result.telebirrPortalUrl, contains('transactioninfo.ethiotelecom.et/receipt/'));
    });

    test('LinksEtService.resolveReceiptInput intelligently auto-constructs CBE and BOA URLs from references, tokens and SMS', () {
      // 1. Bank of Abyssinia bare token or labeled token
      final boaBare = LinksEtService.resolveReceiptInput(
        input: 'FT24250000000000A',
        bank: 'boa',
      );
      expect(boaBare.url, equals('https://cs.bankofabyssinia.com/slip/?trx=FT24250000000000A'));
      expect(boaBare.isAutoConstructed, isTrue);

      final boaLabeled = LinksEtService.resolveReceiptInput(
        input: 'Ref: FT24250000000000A',
        bank: 'abyssinia',
      );
      expect(boaLabeled.url, equals('https://cs.bankofabyssinia.com/slip/?trx=FT24250000000000A'));

      final boaNormalizeId = LinksEtService.resolveReceiptInput(
        input: 'https://cs.bankofabyssinia.com/slip/?id=FT24250000000000A',
        bank: 'boa',
      );
      expect(boaNormalizeId.url, equals('https://cs.bankofabyssinia.com/slip/?trx=FT24250000000000A'));

      // 2. CBE dashed token from SMS
      final cbeDashed = LinksEtService.resolveReceiptInput(
        input: 'FT26291KVDWY-10004350',
        bank: 'cbe',
      );
      expect(cbeDashed.url, equals('https://mbreciept.cbe.com.et/FT26291KVDWY-10004350'));
      expect(cbeDashed.isAutoConstructed, isTrue);

      // 3. CBE mobile mixed-case token
      final cbeToken = LinksEtService.resolveReceiptInput(
        input: 'fHCxz62uM8157lCfet',
        bank: 'cbe',
      );
      expect(cbeToken.url, equals('https://mbreciept.cbe.com.et/fHCxz62uM8157lCfet'));
      expect(cbeToken.isAutoConstructed, isTrue);

      // 4. CBE bare FT reference
      final cbeBare = LinksEtService.resolveReceiptInput(
        input: 'FT26291KVDWY',
        bank: 'cbe',
      );
      expect(cbeBare.url, equals('https://apps.cbe.com.et:100/?id=FT26291KVDWY'));
      expect(cbeBare.isAutoConstructed, isTrue);

      // 5. CBE raw confirmation SMS extraction
      final cbeSms = LinksEtService.resolveReceiptInput(
        input: 'Dear Customer, ETB 300.00 debited. Ref: FT26291KVDWY. Receipt: https://mbreciept.cbe.com.et/v2/xyz123abc456.',
        bank: 'cbe',
      );
      expect(cbeSms.url, equals('https://mbreciept.cbe.com.et/v2/xyz123abc456'));

      // 6. Telebirr shorthand reference
      final tele = LinksEtService.resolveReceiptInput(
        input: 'Transaction No: DET8FJGUJ4',
        bank: 'telebirr',
      );
      expect(tele.reference, equals('DET8FJGUJ4'));
      expect(tele.isTelebirrShorthand, isTrue);
    });

    test('ScannedReceiptStorage records approved payment with email, method, and transactionId locally', () {

      final storage = ScannedReceiptStorage();

      const txId = 'FT26291ABCDE';

      const email = 'student@example.com';

      const method = 'cbe';



      // 1. Record approved payment

      final record = storage.recordApprovedPayment(

        transactionId: txId,

        paymentMethod: method,

        userEmail: email,

        amount: 500.0,

        payerName: 'Student Abebe',

        receiptId: 'receipt-12345',

      );



      expect(record.id, equals(txId));

      expect(record.userEmail, equals(email));

      expect(record.method, equals(method));

      expect(record.status, equals('approved'));

      expect(record.isApproved, isTrue);

      expect(record.approvedAt, isNotNull);

      expect(record.formattedApprovedDate, isNotNull);



      // 2. Lookup by transaction ID

      final found = storage.findRecord(txId);

      expect(found, isNotNull);

      expect(found!.id, equals(txId));

      expect(found.userEmail, equals(email));

      expect(found.status, equals('approved'));

      expect(found.isApproved, isTrue);



      // 3. Lookup by email

      final emailRecords = storage.findRecordsByEmail(email);

      expect(emailRecords, isNotEmpty);

      expect(emailRecords.first.id, equals(txId));

      expect(emailRecords.first.userEmail, equals(email));



      // 4. Double-scan tracking after approval

      final secondScan = storage.saveRecord(

        id: txId,

        method: method,

        status: 'verified',

        amount: 500.0,

      );

      expect(secondScan.wasScannedBefore, isTrue);

      expect(secondScan.scanCount, equals(2));

      expect(secondScan.previousStatus, equals('approved'));



      // Clean up test key

      storage.removeRecord(txId);

    });



    test('ReceiptExtractorService cache stores and retrieves extracted transaction ID', () {

      final extractor = ReceiptExtractorService.instance;

      const key = 'test-review-id-99';

      const res = ReceiptExtractionResult(

        transactionId: 'DJL64F9ZOE',

        bank: 'telebirr',

        amount: 200.0,

      );



      extractor.setCache(key, res);

      final cached = extractor.getCached(key);



      expect(cached, isNotNull);

      expect(cached!.transactionId, equals('DJL64F9ZOE'));

      expect(cached.bank, equals('telebirr'));

      expect(cached.amount, equals(200.0));

      expect(cached.hasTransactionId, isTrue);

    });



    test('ScannedReceiptRecord displays time in Eastern UTC+3 and 12-hour format', () {

      // 05:30 UTC = 08:30 AM in UTC+3 (East Africa Time)

      final utcTime = DateTime.utc(2026, 11, 4, 5, 30);

      final record = ScannedReceiptRecord(

        id: 'TX-TZ-TEST-12',

        method: 'cbe',

        status: 'approved',

        scannedAt: utcTime,

        approvedAt: utcTime.add(const Duration(hours: 12)), // 17:30 UTC = 8:30 PM EAT

        userEmail: 'student@example.com',

      );



      // Scanned at 5:30 UTC -> 8:30 AM in UTC+3

      expect(record.formattedScannedDate, contains('8:30 AM'));

      expect(record.formattedScannedDate, contains('EAT'));

      expect(record.formattedScannedDate, contains('4 Nov 2026'));



      // Approved at 17:30 UTC -> 8:30 PM in UTC+3

      expect(record.formattedApprovedDate, contains('8:30 PM'));

      expect(record.formattedApprovedDate, contains('EAT'));

      expect(record.formattedApprovedDate, contains('4 Nov 2026'));



      // EthiopianTimeHelper formatEatDateTime in 12-hour format

      final formattedEat = EthiopianTimeHelper.formatEatDateTime(utcTime, includeYear: true);

      expect(formattedEat, contains('8:30 AM'));

      expect(formattedEat, contains('4 Nov 2026'));

    });



    testWidgets('PaymentVerifyChecker renders on narrow screen (320px) without overflow and displays links.et gateway badge', (tester) async {
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
        verificationUrl: 'https://mreciept.cbe.com.et/v2/test',
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

      expect(find.text('verify.et'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('VerifyEtResult parses official verify.et 200 completed response with confirmationHistory', () {
      final verifyEtJson = {
        'success': true,
        'message': 'Verification completed.',
        'data': [
          {
            'bank': 'telebirr',
            'amount': 200,
            'status': 'success',
            'currency': 'ETB',
            'verified': true,
            'timestamp': '2026-11-02T18:20:09.000Z',
            'senderName': 'hayat seid ebrahim',
            'receiverName': 'Abrham Teramed Nega',
            'receiverAccount': '2519****6811',
            'referenceNumber': 'DK22M4PI5I',
            'transactionNumber': 'DK22M4PI5I',
            'receiptNumber': 'DK22M4PI5I',
            'confirmationHistory': {
              'scope': 'platform',
              'isFirstConfirmation': false,
              'confirmedBefore': true,
              'firstConfirmedAt': '2026-11-02T18:36:16.898Z',
              'lastConfirmedAt': '2026-11-02T18:36:40.658Z',
              'confirmationCount': 3,
            },
            'settlementAccountMatch': {
              'matched': true,
              'matchType': 'masked_pattern',
              'matchConfidence': 'high',
              'source': 'account_registry',
              'bank': 'telebirr',
              'receiverAccount': '2519****6811',
              'matchedSettlementAccount': '0939080897',
              'reason': 'receiver_mask_matches_visible_digits',
            },
            'bankSpecific': {
              'amountValue': 200,
              'paymentMode': 'telebirr',
              'paymentReason': 'Send Money to Registered Customer',
              'receiptUrl': 'https://transactioninfo.ethiotelecom.et/receipt/DK22M4PI5I',
            },
          }
        ],
        'requestId': '063c77c9-ec86-4980-b609-815fd038e4cd',
        'verification': {
          'requestId': '063c77c9-ec86-4980-b609-815fd038e4cd',
          'processingStatus': 'completed',
          'status': 'success',
          'verified': true,
        },
        'links': {
          'statusUrl': '/api/verify/063c77c9-ec86-4980-b609-815fd038e4cd',
        },
      };

      final result = LinksEtResult.fromJson(verifyEtJson);

      expect(result.ok, isTrue);
      expect(result.verified, isTrue);
      expect(result.isSuccess, isTrue);
      expect(result.bank, equals('telebirr'));
      expect(result.amount, equals(200.0));
      expect(result.currency, equals('ETB'));
      expect(result.senderName, equals('hayat seid ebrahim'));
      expect(result.receiverName, equals('Abrham Teramed Nega'));
      expect(result.receiverAccount, equals('2519****6811'));
      expect(result.referenceNumber, equals('DK22M4PI5I'));
      expect(result.requestId, equals('063c77c9-ec86-4980-b609-815fd038e4cd'));
      expect(result.statusUrl, equals('/api/verify/063c77c9-ec86-4980-b609-815fd038e4cd'));

      // Platform-wide duplicate verification detection
      expect(result.confirmationHistory, isNotNull);
      expect(result.confirmationHistory!.confirmedBefore, isTrue);
      expect(result.confirmationHistory!.confirmationCount, equals(3));
      expect(result.wasScannedBefore, isTrue);

      // Settlement account matching
      expect(result.settlementAccountMatch, isNotNull);
      expect(result.settlementAccountMatch!.matched, isTrue);
      expect(result.settlementAccountMatch!.matchedSettlementAccount, equals('0939080897'));
    });

    test('VerifyEtResult parses GET /api/verify/:requestId status response with result map', () {
      final statusJson = {
        'success': true,
        'message': 'Verification status.',
        'data': {
          'requestId': 'df659c07-8b96-49ae-a2b2-a4a8f67b8e95',
          'bank': 'cbe',
          'processingStatus': 'completed',
          'status': 'success',
          'verified': true,
          'result': {
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
          },
          'completedAt': '2026-02-20T12:00:02.340Z',
        },
      };

      final result = LinksEtResult.fromJson(statusJson);

      expect(result.ok, isTrue);
      expect(result.verified, isTrue);
      expect(result.bank, equals('cbe'));
      expect(result.amount, equals(1500.0));
      expect(result.senderName, equals('Abebe Bikila'));
      expect(result.receiverName, equals('Acme Trading'));
      expect(result.referenceNumber, equals('FT26EXAMPLE1'));
      expect(result.requestId, equals('df659c07-8b96-49ae-a2b2-a4a8f67b8e95'));
    });

    test('VerifyEtHistoryItem correctly parses verify.et cloud history records', () {
      final historyJson = {
        'requestId': 'df659c07-8b96-49ae-a2b2-a4a8f67b8e95',
        'bank': 'telebirr',
        'processingStatus': 'completed',
        'status': 'success',
        'verified': true,
        'result': {
          'bank': 'telebirr',
          'status': 'success',
          'verified': true,
          'amount': 200,
          'currency': 'ETB',
          'senderName': 'hayat seid ebrahim',
          'receiverName': 'Abrham Teramed Nega',
          'referenceNumber': 'DK22M4PI5I',
        },
        'durationMs': 1553,
        'createdAt': '2026-11-02T18:36:34.842Z',
      };

      final item = VerifyEtHistoryItem.fromJson(historyJson);

      expect(item.requestId, equals('df659c07-8b96-49ae-a2b2-a4a8f67b8e95'));
      expect(item.referenceNumber, equals('DK22M4PI5I'));
      expect(item.bank, equals('telebirr'));
      expect(item.verified, isTrue);
      expect(item.amount, equals(200.0));
      expect(item.currency, equals('ETB'));
      expect(item.senderName, equals('hayat seid ebrahim'));
      expect(item.receiverName, equals('Abrham Teramed Nega'));
    });
     test('Telebirr URL is strictly sanitized to clean 10-char reference code', () {
      const fullUrl = 'https://transactioninfo.ethiotelecom.et/receipt/DK22M4PI5I';
      const cleanToken = 'DK22M4PI5I';

      // 1. Static sanitization helper
      expect(VerifyEtService.sanitizeTelebirrReference(fullUrl), equals(cleanToken));
      expect(VerifyEtService.sanitizeTelebirrReference('http://transactioninfo.ethiotelecom.et/receipt/DJL64F9ZOE?lang=en'), equals('DJL64F9ZOE'));
      expect(VerifyEtService.sanitizeTelebirrReference(cleanToken), equals(cleanToken));

      // 2. ReceiptTextParser extraction from OCR / scanned URL
      final parsed = ReceiptTextParser.parse(fullUrl);
      expect(parsed.bank, equals('telebirr'));
      expect(parsed.transactionId, equals(cleanToken));
      expect(parsed.receiptUrl, equals(fullUrl));

      // 3. LinksEtResult / VerifyEtResult referenceNumber getter
      final telebirrWithUrlJson = {
        'success': true,
        'data': [
          {
            'bank': 'telebirr',
            'amount': 500,
            'currency': 'ETB',
            'referenceNumber': fullUrl,
          }
        ]
      };
      final res = LinksEtResult.fromJson(telebirrWithUrlJson);
      expect(res.referenceNumber, equals(cleanToken));
      expect(res.resolvedUrl, equals(fullUrl));
    });

    test('VerifyEtService resolves default settlement accounts and account suffixes for bank verification', () {
      // Settlement accounts
      expect(VerifyEtService.resolveDefaultSettlementAccount('telebirr'), equals('0960586811'));
      expect(VerifyEtService.resolveDefaultSettlementAccount('cbe'), equals('1000435011237'));
      expect(VerifyEtService.resolveDefaultSettlementAccount('boa'), equals('165093089'));
      expect(VerifyEtService.resolveDefaultSettlementAccount('abyssinia'), equals('165093089'));

      // Account suffixes (BOA strictly 5 digits, CBE strictly 8 digits)
      expect(VerifyEtService.resolveDefaultAccountSuffix('boa'), equals('93089'));
      expect(VerifyEtService.resolveDefaultAccountSuffix('abyssinia'), equals('93089'));
      expect(VerifyEtService.resolveDefaultAccountSuffix('cbe'), equals('35011237'));

      // Suffix sanitization
      expect(VerifyEtService.sanitizeAccountSuffix('1000435011237', 'cbe'), equals('35011237'));
      expect(VerifyEtService.sanitizeAccountSuffix('435011237', 'cbe'), equals('35011237'));
      expect(VerifyEtService.sanitizeAccountSuffix('35011237', 'cbe'), equals('35011237'));
      expect(VerifyEtService.sanitizeAccountSuffix('165093089', 'boa'), equals('93089'));
      expect(VerifyEtService.sanitizeAccountSuffix('93089', 'boa'), equals('93089'));
    });

    test('LinksEtService.resolveReceiptInput resolves Awash and Dashen bank references', () {
      // Awash labeled reference
      final awash = LinksEtService.resolveReceiptInput(
        input: 'Txn ID: AW987654321',
        bank: 'awash',
      );
      expect(awash.reference, equals('AW987654321'));
      expect(awash.resolvedBank, equals('awash'));

      // Dashen labeled reference
      final dashen = LinksEtService.resolveReceiptInput(
        input: 'Ref: DA11223344',
        bank: 'dashen',
      );
      expect(dashen.reference, equals('DA11223344'));
      expect(dashen.resolvedBank, equals('dashen'));

      // CBE Birr labeled reference
      final cbebirr = LinksEtService.resolveReceiptInput(
        input: 'Receipt No: CB88776655',
        bank: 'cbebirr',
      );
      expect(cbebirr.reference, equals('CB88776655'));
      expect(cbebirr.resolvedBank, equals('cbebirr'));
    });

    test('VerifyEtResult parses official Bank of Abyssinia (boa) verification response', () {
      final boaJson = {
        'success': true,
        'message': 'Verification completed.',
        'data': [
          {
            'bank': 'boa',
            'amount': 500,
            'status': 'success',
            'currency': 'ETB',
            'verified': true,
            'timestamp': '2026-11-02T19:00:00.000Z',
            'senderName': 'Yared Hagos',
            'receiverName': 'MatricMate Platform',
            'receiverAccount': '165093089',
            'referenceNumber': 'FT24250000000000A',
            'bankSpecific': {
              'accountSuffix': '93089',
              'amountValue': 500,
            },
          }
        ],
        'requestId': 'req-boa-12345',
        'verification': {
          'processingStatus': 'completed',
          'status': 'success',
          'verified': true,
        },
      };

      final result = LinksEtResult.fromJson(boaJson);
      expect(result.ok, isTrue);
      expect(result.verified, isTrue);
      expect(result.bank, equals('boa'));
      expect(result.amount, equals(500.0));
      expect(result.senderName, equals('Yared Hagos'));
      expect(result.receiverName, equals('MatricMate Platform'));
      expect(result.receiverAccount, equals('165093089'));
      expect(result.referenceNumber, equals('FT24250000000000A'));
      expect(result.upstreamInspectionUrl, contains('https://cs.bankofabyssinia.com/slip/?trx=FT24250000000000A'));
    });

    test('VerifyEtResult parses official CBE verification response for FT26312J0K6V', () {
      final cbeJson = {
        'success': true,
        'message': 'Transaction verified successfully.',
        'data': [
          {
            'verified': true,
            'status': 'success',
            'bank': 'cbe',
            'referenceNumber': 'FT26312J0K6V',
            'amount': 200,
            'currency': 'ETB',
            'senderName': 'Mr Abdisa Jemal Bulbula',
            'receiverName': 'Mr Abrham Teramed Nega',
            'receiverAccount': '1****1237',
            'timestamp': '2026-11-08T07:11:00.000Z',
            'requestId': '007a0fd4-31b7-4f91-b0a6-c111034f7407',
          }
        ],
        'requestId': '007a0fd4-31b7-4f91-b0a6-c111034f7407',
      };

      final result = LinksEtResult.fromJson(cbeJson);
      expect(result.ok, isTrue);
      expect(result.verified, isTrue);
      expect(result.bank, equals('cbe'));
      expect(result.amount, equals(200.0));
      expect(result.currency, equals('ETB'));
      expect(result.senderName, equals('Mr Abdisa Jemal Bulbula'));
      expect(result.receiverName, equals('Mr Abrham Teramed Nega'));
      expect(result.receiverAccount, equals('1****1237'));
      expect(result.referenceNumber, equals('FT26312J0K6V'));
      expect(result.requestId, equals('007a0fd4-31b7-4f91-b0a6-c111034f7407'));
    });

    test('LinksEtService.resolveReceiptInput normalizes lowercase ft26312j0k6v to uppercase FT26312J0K6V with 8-digit CBE suffix', () {
      final resolved = LinksEtService.resolveReceiptInput(
        input: 'ft26312j0k6v',
        bank: 'cbe',
      );
      expect(resolved.reference, equals('FT26312J0K6V'));
      expect(resolved.resolvedBank, equals('cbe'));
      expect(resolved.accountSuffix, equals('35011237'));
    });

    test('LinksEtResult userFriendlyErrorMessage formats "bank is not responding" nicely', () {
      final errJson = {
        'success': false,
        'message': 'The bank is not responding right now, please try again shortly.',
        'data': [],
        'providerKey': 'cbe',
      };
      final result = LinksEtResult.fromJson(errJson);
      expect(result.verified, isFalse);
      expect(result.userFriendlyErrorMessage, contains('taking longer than expected to respond'));
      expect(result.userFriendlyErrorMessage, contains('CBE'));
    });

    test('ReceiptTextParser.normalizeCbeFtReference corrects OCR letter I to digit 1 and handles formatting', () {
      // 1. OCR letter I instead of digit 1 in suffix
      expect(
        ReceiptTextParser.normalizeCbeFtReference('FT26316CIJMB'),
        equals('FT26316C1JMB'),
      );

      // 2. OCR pipe symbol | instead of digit 1
      expect(
        ReceiptTextParser.normalizeCbeFtReference('FT26316C|JMB'),
        equals('FT26316C1JMB'),
      );

      // 3. Lowercase with spaces and hyphens
      expect(
        ReceiptTextParser.normalizeCbeFtReference('ft 26316-c1jmb'),
        equals('FT26316C1JMB'),
      );

      // 4. Julian day has letter I instead of 1
      expect(
        ReceiptTextParser.normalizeCbeFtReference('FT263I6C1JMB'),
        equals('FT26316C1JMB'),
      );
    });

    test('ReceiptTextParser parses USSD confirmation popup screenshot text accurately', () {
      const ussdText = '''
x Recents Completed ETB200.61 transfer From Adisu Solomon Shenfana to Abrham Teramed Nega-1237. To 4455 on 12/11/2026 FT26316CIJMB Service Charge #:Next Cancel 23 4 1 a k O 567 Send fF Z 890 q rs 1m nop tuv w x AB English
''';

      final res = ReceiptTextParser.parse(ussdText, bankHint: 'cbe');
      expect(res.transactionId, equals('FT26316C1JMB'));
      expect(res.bank, equals('cbe'));
      expect(res.amount, equals(200.61));
      expect(res.senderName, equals('Adisu Solomon Shenfana'));
      expect(res.receiverName, equals('Abrham Teramed Nega'));
      expect(res.receiverAccount, equals('1237'));
      expect(res.date, equals('12/11/2026'));
      expect(res.hasTransactionId, isTrue);
    });

    test('ReceiptExtractorService extracts FT26316C1JMB directly from user uploaded image bytes', () async {
      final imageFile = File('C:/Users/HP/.gemini/antigravity/brain/b835c9a1-dc89-4e78-8640-2e73f07e8058/.user_uploaded/media_1794490679267_c2e0e950.jpg');
      if (await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        final res = await ReceiptExtractorService.instance.extractFromBytes(
          bytes,
          bankHint: 'cbe',
        );

        expect(res, isNotNull);
        expect(res!.hasTransactionId, isTrue);
        expect(res.transactionId, equals('FT26316C1JMB'));
        expect(res.bank, equals('cbe'));
      }
    });

    testWidgets('PaymentVerifyChecker displays Account Suffix field for Bank of Abyssinia without overflow on 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const review = PaymentReview(
        id: 'rev-boa-narrow',
        userId: 'user-boa',
        userName: 'Dawit Bekele',
        userEmail: 'dawit@test.com',
        userStream: 'natural',
        subscriptionStatus: 'inactive',
        receiptPath: 'receipts/boa.jpg',
        receiptUrl: 'https://example.com/boa.jpg',
        verificationUrl: 'FT24250000000000A',
        paymentMethod: 'abyssinia',
        status: 'pending',
        amount: 300,
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

      expect(find.text('🦁 Verify with Abyssinia'), findsOneWidget);
      expect(find.text('Account Suffix (5 digits for BOA) *'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '93089'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('VerifyEtView renders on 320px narrow mobile without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      Get.put(VerifyEtController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerifyEtView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Instant Bank Verification'), findsOneWidget);
      expect(find.textContaining('verify.et'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
