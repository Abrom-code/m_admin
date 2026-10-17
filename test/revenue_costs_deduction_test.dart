import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/data/repositories/revenue_costs_repository.dart';
import 'package:m_admin/common/widgets/charts/bar_chart_painter.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/revenue/models/revenue_cost_record.dart';
import 'package:m_admin/features/revenue/screens/widgets/add_cost_dialog.dart';
import 'package:m_admin/features/revenue/screens/widgets/costs_management_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );
    Get.reset();
    await GetStorage.init('test_costs_deduction_box');
  });

  tearDown(() {
    Get.reset();
  });

  RevenueController createTestController({bool autoLoad = false}) {
    final storage = GetStorage('test_costs_deduction_box');
    return Get.put(
      RevenueController(
        storage: storage,
        costsRepo: RevenueCostsRepository(storage: storage),
        autoLoad: autoLoad,
      ),
    );
  }

  group('RevenueCostRecord Model & Categories', () {
    test('serializes to JSON and deserializes correctly', () {
      final now = DateTime(2026, 10, 15, 12, 0);
      final record = RevenueCostRecord(
        id: 'cost_123',
        title: 'Telegram Channel Promotion',
        amount: 2500.0,
        category: 'promotion',
        date: now,
        notes: 'Promoted in Grade 12 group',
        createdAt: now,
      );

      final json = record.toJson();
      expect(json['id'], 'cost_123');
      expect(json['title'], 'Telegram Channel Promotion');
      expect(json['amount'], 2500.0);
      expect(json['category'], 'promotion');

      final fromJson = RevenueCostRecord.fromJson(json);
      expect(fromJson.id, record.id);
      expect(fromJson.title, record.title);
      expect(fromJson.amount, record.amount);
      expect(fromJson.category, record.category);
      expect(fromJson.notes, record.notes);
    });

    test('category helpers provide correct labels, colors, and icons', () {
      expect(RevenueCostRecord.getCategoryLabel('promotion'), 'Promotion');
      expect(RevenueCostRecord.getCategoryLabel('social_ads'), 'Social Ads');
      expect(RevenueCostRecord.getCategoryLabel('server'), 'Server & Hosting');
      expect(RevenueCostRecord.getCategoryLabel('sms'), 'SMS Gateway');
      expect(RevenueCostRecord.getCategoryLabel('other'), 'Other Cost');

      expect(RevenueCostRecord.getCategoryColor('promotion'), const Color(0xFF8B5CF6));
      expect(RevenueCostRecord.getCategoryIcon('promotion'), isNotNull);
    });
  });

  group('RevenueController Cost Deductions & Net Revenue Calculations', () {
    test('entered costs decrease period revenue and calculate net revenue and margins', () async {
      final controller = createTestController();

      final today = DateTime.now();
      controller.revenueSeries.value = [
        DailyPoint(day: today.subtract(const Duration(days: 2)), value: 1000.0),
        DailyPoint(day: today.subtract(const Duration(days: 1)), value: 2000.0),
        DailyPoint(day: today, value: 3000.0),
      ];
      controller.totalRevenueAllTime.value = 10000.0;
      controller.rangeDays.value = 30;

      // Verify Initial Gross Totals
      expect(controller.primaryTotal, 6000.0);
      expect(controller.primaryTotalCosts, 0.0);
      expect(controller.primaryNetRevenue, 6000.0);
      expect(controller.primaryProfitMargin, 100.0);

      // Add Promotion Cost 1: 1,500 ETB
      await controller.addCostRecord(
        title: 'TikTok Influencer Ad',
        amount: 1500.0,
        category: 'influencer',
        date: today,
        notes: 'Campaign 1',
      );

      // Add Server Cost 2: 500 ETB
      await controller.addCostRecord(
        title: 'Supabase & Server',
        amount: 500.0,
        category: 'server',
        date: today.subtract(const Duration(days: 1)),
      );

      // Total costs should be 2000 ETB
      expect(controller.primaryTotalCosts, 2000.0);
      expect(controller.allTimeTotalCosts, 2000.0);

      // Net revenue should now be 6000 - 2000 = 4000 ETB
      expect(controller.primaryNetRevenue, 4000.0);
      expect(controller.allTimeNetRevenue, 8000.0); // 10000 - 2000

      // Net margin: (4000 / 6000) * 100 = 66.67%
      expect(controller.primaryProfitMargin, closeTo(66.67, 0.1));

      // Daily Cost lookup
      expect(controller.getCostForDay(today), 1500.0);
      expect(controller.getCostForDay(today.subtract(const Duration(days: 1))), 500.0);
      expect(controller.getCostForDay(today.subtract(const Duration(days: 2))), 0.0);

      // Effective series when chart mode is 'net'
      controller.setChartViewMode('net');
      final effectivePoints = controller.effectiveRevenueSeries;
      // Day 0: 1000 - 0 = 1000
      expect(effectivePoints[0].value, 1000.0);
      // Day 1: 2000 - 500 = 1500
      expect(effectivePoints[1].value, 1500.0);
      // Day 2: 3000 - 1500 = 1500
      expect(effectivePoints[2].value, 1500.0);

      // When chart mode is 'gross'
      controller.setChartViewMode('gross');
      final grossPoints = controller.effectiveRevenueSeries;
      expect(grossPoints[0].value, 1000.0);
      expect(grossPoints[1].value, 2000.0);
      expect(grossPoints[2].value, 3000.0);
    });

    test('updating and deleting cost record recalculates net revenue immediately', () async {
      final controller = createTestController();
      final today = DateTime.now();

      controller.revenueSeries.value = [
        DailyPoint(day: today, value: 5000.0),
      ];

      await controller.addCostRecord(
        title: 'Telegram Ad',
        amount: 1000.0,
        category: 'promotion',
        date: today,
      );

      expect(controller.primaryNetRevenue, 4000.0);

      // Edit cost amount to 1,500
      final record = controller.costRecords.first;
      await controller.updateCostRecord(record.copyWith(amount: 1500.0));
      expect(controller.primaryTotalCosts, 1500.0);
      expect(controller.primaryNetRevenue, 3500.0);

      // Delete cost
      await controller.deleteCostRecord(record.id);
      expect(controller.primaryTotalCosts, 0.0);
      expect(controller.primaryNetRevenue, 5000.0);
    });
  });

  group('CostsManagementCard and AddCostDialog Widget Tests', () {
    testWidgets('CostsManagementCard displays empty state and cost entries', (tester) async {
      final controller = createTestController();
      controller.isPriceHidden.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CostsManagementCard(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state prompt is visible
      expect(find.text('Promotion & Cost Deductions'), findsOneWidget);
      expect(find.textContaining('No costs recorded in this selected period'), findsOneWidget);

      // Add a cost
      await controller.addCostRecord(
        title: 'Influencer Shoutout',
        amount: 800.0,
        category: 'influencer',
        date: DateTime.now(),
      );
      await tester.pumpAndSettle();

      // Item appears in the list
      expect(find.text('Influencer Shoutout'), findsOneWidget);
      expect(find.textContaining('800.00'), findsWidgets);
    });

    testWidgets('AddCostDialog validates input and saves cost record', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createTestController();

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddCostDialog.show(ctx, controller),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Enter Promotion / Cost'), findsOneWidget);

      // Fill in amount
      await tester.enterText(find.byType(TextFormField).first, '1200');

      // Fill in purpose
      await tester.enterText(find.byType(TextFormField).at(1), 'Telegram Channel Promotion');

      // Scroll if necessary and tap submit button
      final submitButton = find.text('Deduct from Revenue');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);

      // Wait for dialog close and snackbar dismiss timer
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Dialog closed and record added
      expect(controller.costRecords.length, 1);
      expect(controller.costRecords.first.title, 'Telegram Channel Promotion');
      expect(controller.costRecords.first.amount, 1200.0);
    });

    test('when cost is greater than revenue on a day, effective series returns negative value (deficit)', () async {
      final controller = createTestController();
      final today = DateTime.now();

      controller.revenueSeries.value = [
        DailyPoint(day: today, value: 500.0),
      ];

      // Add cost greater than revenue: 1500 ETB > 500 ETB
      await controller.addCostRecord(
        title: 'Major Ad Campaign',
        amount: 1500.0,
        category: 'promotion',
        date: today,
      );

      controller.setChartViewMode('net');
      final series = controller.effectiveRevenueSeries;
      expect(series.length, 1);
      // Net revenue is 500 - 1500 = -1000.0 ETB (deficit)
      expect(series.first.value, -1000.0);
      expect(controller.primaryNetRevenue, -1000.0);
      expect(controller.primaryProfitMargin, -200.0);
    });

    testWidgets('AdminBarChart renders negative deficit bars and zero line without error', (tester) async {
      final today = DateTime.now();
      final points = [
        DailyPoint(day: today.subtract(const Duration(days: 2)), value: 1200.0),
        DailyPoint(day: today.subtract(const Duration(days: 1)), value: -800.0), // Deficit point!
        DailyPoint(day: today, value: 2000.0),
      ];

      int? selectedIdx;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminBarChart(
              points: points,
              height: 240,
              selectedIndex: null,
              onPointSelected: (idx) => selectedIdx = idx,
              tooltipContent: const Text('Deficit Tooltip'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CustomPaint is rendered without errors
      expect(find.byType(CustomPaint), findsWidgets);

      // Tap on chart to trigger onPointSelected
      await tester.tap(find.byType(AdminBarChart));
      await tester.pumpAndSettle();
      expect(selectedIdx, isNotNull);
    });

    testWidgets('AdminBarChart paired comparative mode renders negative points', (tester) async {
      final today = DateTime.now();
      final primary = [
        DailyPoint(day: today, value: -500.0), // Negative primary
      ];
      final comparison = [
        DailyPoint(day: today.subtract(const Duration(days: 7)), value: -300.0), // Negative comp
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminBarChart(
              points: primary,
              comparisonPoints: comparison,
              height: 240,
              selectedIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
