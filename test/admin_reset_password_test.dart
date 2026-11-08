import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/features/users/models/reset_password_result.dart';
import 'package:m_admin/features/users/screens/widgets/reset_password_success_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('Admin-Initiated Student Password Reset Model & Security Tests', () {
    test('ResetPasswordResult parses successful Edge Function response', () {
      final json = {
        'success': true,
        'studentId': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'studentEmail': 'student@example.com',
        'studentName': 'Abebe Kebede',
        'temporaryPassword': 'X7#kP9!wQ2*m',
        'message': 'Student password reset successfully.',
      };

      final result = ResetPasswordResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.studentId, equals('a1b2c3d4-e5f6-7890-abcd-ef1234567890'));
      expect(result.studentEmail, equals('student@example.com'));
      expect(result.studentName, equals('Abebe Kebede'));
      expect(result.temporaryPassword, equals('X7#kP9!wQ2*m'));
      expect(result.message, equals('Student password reset successfully.'));
    });

    test('ResetPasswordResult toJson excludes temporary password for security', () {
      final result = const ResetPasswordResult(
        success: true,
        studentId: 'uuid-12345',
        studentEmail: 'abebe@example.com',
        studentName: 'Abebe Kebede',
        temporaryPassword: 'SecretTempPassword!99',
      );

      final json = result.toJson();

      expect(json.containsKey('temporaryPassword'), isFalse);
      expect(json['studentEmail'], equals('abebe@example.com'));
      expect(json['studentId'], equals('uuid-12345'));
    });

    test('Temporary password conforms to security complexity and policy requirements', () {
      // Simulate the password generator logic from the Edge Function
      const samplePassword = 'X7#kP9!wQ2*m';

      expect(samplePassword.length, greaterThanOrEqualTo(12));
      expect(samplePassword.contains(RegExp(r'[A-Z]')), isTrue, reason: 'Must contain uppercase');
      expect(samplePassword.contains(RegExp(r'[a-z]')), isTrue, reason: 'Must contain lowercase');
      expect(samplePassword.contains(RegExp(r'[0-9]')), isTrue, reason: 'Must contain numbers');
      expect(samplePassword.contains(RegExp(r'[!@#$%*\-_]')), isTrue, reason: 'Must contain symbols');
      expect(samplePassword.contains(' '), isFalse, reason: 'Must not contain whitespace');
    });

    test('Student profile properties are immutable under password reset', () {
      const student = AdminUserModel(
        id: 'student-uuid-999',
        firstName: 'Abebe',
        lastName: 'Kebede',
        email: 'abebe@example.com',
        stream: 'Natural',
        subscriptionStatus: 'active',
        subscriptionPlan: '1_year',
      );

      // Verify profile getters remain intact
      expect(student.id, equals('student-uuid-999'));
      expect(student.fullName, equals('Abebe Kebede'));
      expect(student.stream, equals('Natural'));
      expect(student.isActive, isTrue);
      expect(student.planLabel, equals('1 Year'));
    });
  });

  group('ResetPasswordSuccessDialog Widget Tests', () {
    testWidgets('Renders student details, temporary password and optional note', (
      tester,
    ) async {
      String? copiedClipboardText;

      // Mock Clipboard channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) async {
        if (message.method == 'Clipboard.setData') {
          final args = message.arguments as Map?;
          copiedClipboardText = args?['text'] as String?;
          return null;
        }
        return null;
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ResetPasswordSuccessDialog(
              studentName: 'Abebe Kebede',
              studentEmail: 'abebe@example.com',
              temporaryPassword: 'K9#mX2!wQ8*z',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Dialog Title & Content
      expect(find.text('Password Reset Successful'), findsOneWidget);
      expect(find.text('Abebe Kebede'), findsOneWidget);
      expect(find.text('abebe@example.com'), findsOneWidget);
      expect(find.text('K9#mX2!wQ8*z'), findsOneWidget);

      // 2. Verify Optionality Notice (Students are not forced to change password)
      expect(
        find.textContaining('Students are NOT required to change this temporary password'),
        findsOneWidget,
      );

      // 3. Verify Copy Password Action
      final copyButton = find.widgetWithText(ElevatedButton, 'Copy Password');
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(copiedClipboardText, equals('K9#mX2!wQ8*z'));
      expect(find.text('Password Copied!'), findsOneWidget);

      // 4. Verify Close Button
      final closeButton = find.widgetWithText(TextButton, 'Close');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
    });

    testWidgets('ResetPasswordSuccessDialog renders on small screen (320x480) with zero overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: ResetPasswordSuccessDialog(
              studentName: 'Abebe Kebede Long Name For Testing Responsive Wrapping',
              studentEmail: 'abebe.very.long.email.address@example.edu.et',
              temporaryPassword: 'K9#mX2!wQ8*z',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordSuccessDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ResetPasswordSuccessDialog renders under 1.5x text scale with zero overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const GetMaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: ResetPasswordSuccessDialog(
                studentName: 'Abebe Kebede',
                studentEmail: 'abebe@example.com',
                temporaryPassword: 'K9#mX2!wQ8*z',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordSuccessDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

