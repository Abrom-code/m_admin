import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/screens/app_lock_screen.dart';
import 'package:m_admin/features/security/screens/passcode_setup_dialog.dart';
import 'package:m_admin/features/security/widgets/pin_pad_view.dart';

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
}
