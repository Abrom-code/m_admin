import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/screens/app_lock_screen.dart';
import 'package:m_admin/features/security/screens/passcode_setup_dialog.dart';
import 'package:m_admin/features/security/screens/passcode_verification_dialog.dart';
import 'package:m_admin/features/security/widgets/pin_pad_view.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAvailableBiometrics') {
          return <String>['fingerprint', 'face'];
        }
        if (methodCall.method == 'isDeviceSupported') {
          return true;
        }
        if (methodCall.method == 'authenticate') {
          return true;
        }
        return false;
      },
    );
    Get.reset();
    await GetStorage.init();
    Get.put(AppLockController());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('AppLockScreen renders without overflow on phone sizes',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AppLockScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppLockScreen renders without overflow on small heights',
      (tester) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AppLockScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppLockScreen renders with 6-digit PIN and biometrics enabled',
      (tester) async {
    final ctrl = AppLockController.instance;
    ctrl.pinLength.value = 6;
    ctrl.isBiometricEnabled.value = true;
    ctrl.canUseBiometrics.value = true;

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AppLockScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppLockScreen renders with pattern lock', (tester) async {
    final ctrl = AppLockController.instance;
    ctrl.lockType.value = AppLockType.pattern;
    ctrl.isBiometricEnabled.value = true;
    ctrl.canUseBiometrics.value = true;

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AppLockScreen(),
      ),
    );
    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PasscodeSetupDialog renders without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: PasscodeSetupDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PasscodeSetupDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppLockScreen with Windows scaling (1.5x text scaler)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(
          size: Size(800, 600),
          textScaler: TextScaler.linear(1.5),
        ),
        child: GetMaterialApp(
          home: AppLockScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PinPadView standalone with biometrics and various constraints',
      (tester) async {
    for (final width in [220.0, 260.0, 300.0, 360.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: PinPadView(
                  pinLength: 4,
                  onCompleted: (_) {},
                  showBiometricButton: true,
                  onBiometricPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Failed at width $width with biometrics');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: PinPadView(
                  pinLength: 6,
                  onCompleted: (_) {},
                  showBiometricButton: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Failed at width $width without biometrics');
    }
  });

  testWidgets('Forgot Passcode button opens recovery dialog and validates',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const GetMaterialApp(
        home: AppLockScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Forgot Passcode button is present
    final forgotBtn = find.text('Forgot Passcode?');
    expect(forgotBtn, findsOneWidget);

    // Tap Forgot Passcode button
    await tester.tap(forgotBtn);
    await tester.pumpAndSettle();

    // Verify dialog opened with required fields
    expect(find.text('Admin Identity Verification'), findsOneWidget);
    expect(find.text('Admin Email'), findsOneWidget);
    expect(find.text('Admin Password'), findsOneWidget);
    expect(find.text('Reset forgotten passcode lock'), findsOneWidget);
    expect(find.text('Verify & Unlock'), findsOneWidget);

    // Try tapping Verify & Unlock with empty fields to trigger validation
    await tester.tap(find.text('Verify & Unlock'));
    await tester.pumpAndSettle();

    // Form should fail validation and not crash
    expect(tester.takeException(), isNull);

    // Toggle reset passcode checkbox
    final checkbox = find.byType(Checkbox);
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    // Close dialog
    final closeBtn = find.byIcon(Icons.close_rounded);
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.text('Admin Identity Verification'), findsNothing);
  });

  test('Biometric dismissal prevents repeated auto-prompting until re-lock or user tap',
      () async {
    final ctrl = AppLockController.instance;
    ctrl.isPasscodeEnabled.value = true;
    ctrl.isBiometricEnabled.value = true;
    ctrl.canUseBiometrics.value = true;
    ctrl.isLocked.value = true;

    int authCalls = 0;
    bool shouldSucceed = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'authenticate') {
          authCalls++;
          return shouldSucceed;
        }
        if (methodCall.method == 'getAvailableBiometrics') {
          return <String>['fingerprint'];
        }
        if (methodCall.method == 'isDeviceSupported') {
          return true;
        }
        return false;
      },
    );

    // Initial state: not dismissed
    expect(ctrl.hasUserDismissedBiometrics, isFalse);

    // 1. First auto-prompt: user cancels (authenticate returns false)
    shouldSucceed = false;
    final result1 = await ctrl.authenticateWithBiometrics(userInitiated: false);
    expect(result1, isFalse);
    expect(authCalls, 1);
    expect(ctrl.hasUserDismissedBiometrics, isTrue);

    // 2. Second auto-prompt (e.g. from lifecycle resumed or post frame):
    // Should NOT call authenticate again because user dismissed
    final result2 = await ctrl.authenticateWithBiometrics(userInitiated: false);
    expect(result2, isFalse);
    expect(authCalls, 1, reason: 'Authenticate should not have been called again');

    // 3. User explicitly taps the biometric icon on the pad (userInitiated: true)
    // Should trigger authentication even though it was previously dismissed
    shouldSucceed = true;
    final result3 = await ctrl.authenticateWithBiometrics(userInitiated: true);
    expect(result3, isTrue);
    expect(authCalls, 2);
    expect(ctrl.hasUserDismissedBiometrics, isFalse);

    // 4. Lock again resets dismissal state
    ctrl.isLocked.value = true;
    ctrl.lock();
    expect(ctrl.hasUserDismissedBiometrics, isFalse);
  });

  testWidgets('PasscodeVerificationDialog verifies previous PIN and returns true',
      (tester) async {
    final ctrl = AppLockController.instance;
    await ctrl.setPasscode(
      passcode: '1234',
      type: AppLockType.pin,
      length: 4,
    );

    bool? dialogResult;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              dialogResult = await PasscodeVerificationDialog.show(context);
            },
            child: const Text('Verify'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap verify button to launch dialog
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('Security Verification'), findsOneWidget);
    expect(find.text('Previous PIN'), findsOneWidget);

    // Enter correct PIN digits: 1, 2, 3, 4
    await tester.tap(find.widgetWithText(InkWell, '1'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(InkWell, '2'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(InkWell, '3'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.widgetWithText(InkWell, '4'));
    await tester.pumpAndSettle();

    // Dialog should dismiss and return true
    expect(find.text('Security Verification'), findsNothing);
    expect(dialogResult, isTrue);
  });

  test('EthiopianTimeHelper strictly converts to East Africa Time (UTC+3)', () {
    // 17:30 UTC -> 20:30 EAT (+3 hours)
    final utcDate = DateTime.utc(2026, 10, 17, 17, 30);
    final eatDate = EthiopianTimeHelper.toEastAfricaTime(utcDate);

    expect(eatDate.hour, 20);
    expect(eatDate.minute, 30);
    expect(eatDate.day, 17);

    // Formatted EAT date-time
    final formatted = EthiopianTimeHelper.formatEatDateTime(utcDate);
    expect(formatted, '17 Oct, 20:30');

    // 22:00 UTC on Oct 17 -> 01:00 EAT on Oct 18 (+3 hours advances date)
    final lateUtc = DateTime.utc(2026, 10, 17, 22, 0);
    final lateEat = EthiopianTimeHelper.toEastAfricaTime(lateUtc);
    expect(lateEat.day, 18);
    expect(lateEat.hour, 1);
  });

  test('EthiopianTimeHelper.parseSupabaseUtc & parseToEastAfricaTime handle un-suffixed UTC strings', () {
    // String from Supabase REST JSON without trailing 'Z'
    const rawSupabaseStr = '2026-10-17T18:51:38.241548';
    final parsedUtc = EthiopianTimeHelper.parseSupabaseUtc(rawSupabaseStr);
    expect(parsedUtc, isNotNull);
    expect(parsedUtc!.isUtc, isTrue);
    expect(parsedUtc.hour, 18);

    // Converted to East Africa Time (+3 hours: 18:51 UTC -> 21:51 EAT)
    final eat = EthiopianTimeHelper.parseToEastAfricaTime(rawSupabaseStr);
    expect(eat, isNotNull);
    expect(eat!.hour, 21);
    expect(eat.minute, 51);

    // Also works with explicit 'Z' and '+00:00'
    final eatWithZ = EthiopianTimeHelper.parseToEastAfricaTime('2026-10-17T18:51:38.241548Z');
    expect(eatWithZ!.hour, 21);

    final eatWithOffset = EthiopianTimeHelper.parseToEastAfricaTime('2026-10-17T18:51:38.241548+00:00');
    expect(eatWithOffset!.hour, 21);
  });
}

