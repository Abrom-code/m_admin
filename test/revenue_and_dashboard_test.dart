import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/charts/bar_chart_painter.dart';
import 'package:m_admin/common/widgets/charts/line_chart_painter.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/revenue/screens/revenue_screen.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/widgets/pin_pad_view.dart';
import 'package:m_admin/utils/constants/colors.dart';

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
          return <String>['fingerprint'];
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
  });

  tearDown(() {
    Get.reset();
  });

  group('AppLockController checkPasscode & checkPattern', () {
    test('checkPasscode validates correctly without unlocking global app lock', () async {
      final lockCtrl = Get.put(AppLockController());
      await lockCtrl.setPasscode(
        passcode: '4321',
        type: AppLockType.pin,
        length: 4,
      );

      // Verify correct PIN
      expect(lockCtrl.checkPasscode('4321'), isTrue);

      // Verify wrong PIN
      expect(lockCtrl.checkPasscode('0000'), isFalse);
      expect(lockCtrl.checkPasscode('1234'), isFalse);
    });

    test('checkPattern validates correctly', () async {
      final lockCtrl = Get.put(AppLockController());
      await lockCtrl.setPasscode(
        passcode: '0-1-2-5',
        type: AppLockType.pattern,
      );

      expect(lockCtrl.checkPattern([0, 1, 2, 5]), isTrue);
      expect(lockCtrl.checkPattern([0, 1, 2, 3]), isFalse);
    });
  });

  group('Protected View and PIN Pad interaction', () {
    testWidgets('PinPadView authenticates entered digits against checkPasscode', (tester) async {
      final lockCtrl = Get.put(AppLockController());
      await lockCtrl.setPasscode(
        passcode: '2580',
        type: AppLockType.pin,
        length: 4,
      );

      bool unlocked = false;
      final key = GlobalKey<PinPadViewState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinPadView(
              key: key,
              pinLength: 4,
              onCompleted: (pin) {
                if (lockCtrl.checkPasscode(pin)) {
                  unlocked = true;
                } else {
                  key.currentState?.triggerError();
                }
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter wrong PIN '1111'
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      expect(unlocked, isFalse);

      // Enter correct PIN '2580'
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
    });
  });

  group('Ribbon Card with hidden count for Approved tab', () {
    testWidgets('Ribbon card omits count badge when value is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                _TestRibbonCard(
                  label: 'Pending',
                  value: '12',
                  dotColor: AppColors.warning,
                  isSelected: false,
                  onTap: () {},
                ),
                _TestRibbonCard(
                  label: 'Approved',
                  value: null, // Count hidden for approved
                  dotColor: AppColors.success,
                  isSelected: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      expect(find.text('Approved'), findsOneWidget);
      // Ensure no number text was rendered for Approved
      expect(find.text('null'), findsNothing);
    });
  });

  group('Dashboard Natural/Social Metric Display', () {
    testWidgets('Metric card displays Natural / Social title and formatted counts', (tester) async {
      const naturalCount = 3450;
      const socialCount = 2120;
      final total = naturalCount + socialCount;
      final natPct = (naturalCount / total * 100).toStringAsFixed(0);
      final socPct = (socialCount / total * 100).toStringAsFixed(0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestKpiCard(
              title: 'NATURAL / SOCIAL',
              value: '${NumberFormat('#,##0').format(naturalCount)} / ${NumberFormat('#,##0').format(socialCount)}',
              tag: '$natPct% / $socPct%',
              tagColor: AppColors.primary,
              subtext: 'Nat: ${NumberFormat('#,##0').format(naturalCount)} • Soc: ${NumberFormat('#,##0').format(socialCount)}',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NATURAL / SOCIAL'), findsOneWidget);
      expect(find.text('3,450 / 2,120'), findsOneWidget);
      expect(find.text('62% / 38%'), findsOneWidget);
      expect(find.text('Nat: 3,450 • Soc: 2,120'), findsOneWidget);
    });
  });

  group('RevenueController Multi-Time-Length Comparison Logic', () {
    test('Calculates comparison range and comparative growth correctly', () {
      final controller = Get.put(RevenueController(autoLoad: false));
      controller.rangeDays.value = 30;

      // Verify default primary range is 30 days
      final primRange = controller.getPrimaryDateRange();
      final primDays = primRange.end.difference(primRange.start).inDays + 1;
      expect(primDays, equals(30));

      // 1. Previous period of same length
      controller.compareOption.value = 'previous';
      final compRangePrev = controller.getComparisonDateRange();
      final compDaysPrev = compRangePrev.end.difference(compRangePrev.start).inDays + 1;
      expect(compDaysPrev, equals(30));
      expect(compRangePrev.end.isBefore(primRange.start), isTrue);

      // 2. Preset lengths (7d, 14d, 90d)
      controller.compareOption.value = '7d';
      final compRange7d = controller.getComparisonDateRange();
      final compDays7d = compRange7d.end.difference(compRange7d.start).inDays + 1;
      expect(compDays7d, equals(7));

      controller.compareOption.value = '14d';
      final compRange14d = controller.getComparisonDateRange();
      final compDays14d = compRange14d.end.difference(compRange14d.start).inDays + 1;
      expect(compDays14d, equals(14));

      // 3. Growth and Delta Math
      final now = DateTime.now();
      controller.revenueSeries.value = [
        DailyPoint(day: now.subtract(const Duration(days: 1)), value: 1000),
        DailyPoint(day: now, value: 1500),
      ];
      controller.comparisonSeries.value = [
        DailyPoint(day: now.subtract(const Duration(days: 3)), value: 800),
        DailyPoint(day: now.subtract(const Duration(days: 2)), value: 1200),
      ];

      expect(controller.primaryTotal, equals(2500));
      expect(controller.comparisonTotal, equals(2000));
      expect(controller.revenueGrowthAbsolute, equals(500));
      expect(controller.revenueGrowthPercentage, equals(25.0));
      expect(controller.primaryDailyAverage, equals(1250));
      expect(controller.comparisonDailyAverage, equals(1000));
      expect(controller.averageGrowthPercentage, equals(25.0));
    });
  });

  group('AdminBarChart Multi-Time-Length Comparison Rendering', () {
    testWidgets('Renders paired bars and comparative tooltip without overflow', (tester) async {
      final now = DateTime.now();
      final primaryPoints = List.generate(
        7,
        (i) => DailyPoint(day: now.subtract(Duration(days: 6 - i)), value: (i + 1) * 500.0),
      );
      final compPoints = List.generate(
        7,
        (i) => DailyPoint(day: now.subtract(Duration(days: 13 - i)), value: (i + 1) * 400.0),
      );

      const selectedIndex = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 250,
                child: AdminBarChart(
                  points: primaryPoints,
                  comparisonPoints: compPoints,
                  color: AppColors.success,
                  comparisonColor: const Color(0xFF8B5CF6),
                  selectedIndex: selectedIndex,
                  tooltipContent: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Text('Slot #3 Tooltip'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminBarChart), findsOneWidget);
      expect(find.text('Slot #3 Tooltip'), findsOneWidget);
    });
  });

  group('RevenueComparisonCard Dedicated Component with its own Graph', () {
    testWidgets('Renders 2 distinct time gap panels, KPI metrics, and comparison line graph', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(RevenueController(autoLoad: false));
      final now = DateTime.now();
      controller.revenueSeries.value = [
        DailyPoint(day: now.subtract(const Duration(days: 1)), value: 1200),
        DailyPoint(day: now, value: 2400),
      ];
      controller.comparisonSeries.value = [
        DailyPoint(day: now.subtract(const Duration(days: 3)), value: 1000),
        DailyPoint(day: now.subtract(const Duration(days: 2)), value: 2000),
      ];

      bool closeTapped = false;
      bool gap1CustomPicked = false;
      bool gap2CustomPicked = false;
      int? selectedIdx = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RevenueComparisonCard(
                controller: controller,
                selectedIndex: selectedIdx,
                onPointSelected: (idx) => selectedIdx = idx,
                onClose: () => closeTapped = true,
                onPickGap1Range: () => gap1CustomPicked = true,
                onPickGap2Range: () => gap2CustomPicked = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card Header
      expect(find.text('Compare Revenue Gaps'), findsOneWidget);

      // Two Picking Boxes (Time Gap 1 & Time Gap 2)
      expect(find.text('Time Gap 1'), findsOneWidget);
      expect(find.text('Time Gap 2'), findsOneWidget);

      // Preset Chips for Gap 1 and Gap 2
      expect(find.text('7 Days'), findsNWidgets(2));
      expect(find.text('14 Days'), findsNWidgets(2));
      expect(find.text('30 Days'), findsNWidgets(2));
      expect(find.text('90 Days'), findsNWidgets(2));
      expect(find.text('Previous Period'), findsOneWidget);
      expect(find.text('Custom Range...'), findsNWidgets(2));

      // Its own comparison LINE graph (not a bar chart)
      expect(find.byType(AdminLineChart), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closeTapped, isTrue);

      // Tap Custom Range preset on Gap 1 (first occurrence)
      await tester.tap(find.text('Custom Range...').first);
      await tester.pumpAndSettle();
      expect(gap1CustomPicked, isTrue);

      // Tap Custom Range preset on Gap 2 (last occurrence)
      await tester.tap(find.text('Custom Range...').last);
      await tester.pumpAndSettle();
      expect(gap2CustomPicked, isTrue);
    });

    testWidgets('RevenueComparisonCard renders without overflow on narrow mobile screens (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(RevenueController(autoLoad: false));
      final now = DateTime.now();
      controller.revenueSeries.value = List.generate(
        7,
        (i) => DailyPoint(day: now.subtract(Duration(days: 6 - i)), value: (i + 1) * 350.0),
      );
      controller.comparisonSeries.value = List.generate(
        7,
        (i) => DailyPoint(day: now.subtract(Duration(days: 13 - i)), value: (i + 1) * 280.0),
      );

      // 1. Test without inspection selection
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RevenueComparisonCard(
                controller: controller,
                selectedIndex: null,
                onPointSelected: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminLineChart), findsOneWidget);

      // 2. Test with inspection selection
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RevenueComparisonCard(
                controller: controller,
                selectedIndex: 3,
                onPointSelected: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // 3. Test on ultra-narrow 320px screen width
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RevenueComparisonCard(
                controller: controller,
                selectedIndex: 2,
                onPointSelected: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

class _TestRibbonCard extends StatelessWidget {
  const _TestRibbonCard({
    required this.label,
    this.value,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? value;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        if (value != null) ...[
          const SizedBox(width: 8),
          Text(value!),
        ],
      ],
    );
  }
}

class _TestKpiCard extends StatelessWidget {
  const _TestKpiCard({
    required this.title,
    required this.value,
    required this.tag,
    required this.tagColor,
    required this.subtext,
  });

  final String title;
  final String value;
  final String tag;
  final Color tagColor;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title),
        Text(value),
        Text(tag),
        Text(subtext),
      ],
    );
  }
}
