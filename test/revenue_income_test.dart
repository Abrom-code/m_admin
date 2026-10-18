import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/data/repositories/revenue_costs_repository.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/revenue/models/revenue_income_record.dart';
import 'package:m_admin/features/revenue/screens/widgets/add_revenue_dialog.dart';
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
    await GetStorage.init('test_revenue_income_box');
  });

  tearDown(() {
    Get.reset();
  });

  RevenueController createTestController({bool autoLoad = false}) {
    final storage = GetStorage('test_revenue_income_box');
    return Get.put(
      RevenueController(
        storage: storage,
        costsRepo: RevenueCostsRepository(storage: storage),
        autoLoad: autoLoad,
      ),
    );
  }

  group('RevenueIncomeRecord Model & Methods', () {
    test('serializes to JSON and deserializes correctly', () {
      final now = DateTime(2026, 10, 18, 14, 30);
      final record = RevenueIncomeRecord(
        id: 'inc_123',
        title: 'School Bulk License (50 Students)',
        amount: 15000.0,
        paymentMethod: 'cbe',
        date: now,
        notes: 'Deposit slip verified',
        createdAt: now,
      );

      final json = record.toJson();
      expect(json['id'], 'inc_123');
      expect(json['title'], 'School Bulk License (50 Students)');
      expect(json['amount'], 15000.0);
      expect(json['payment_method'], 'cbe');

      final fromJson = RevenueIncomeRecord.fromJson(json);
      expect(fromJson.id, record.id);
      expect(fromJson.title, record.title);
      expect(fromJson.amount, record.amount);
      expect(fromJson.paymentMethod, record.paymentMethod);
      expect(fromJson.notes, record.notes);
    });

    test('resolves payment method labels and colors correctly', () {
      expect(RevenueIncomeRecord.getMethodLabel('telebirr'), 'Telebirr');
      expect(RevenueIncomeRecord.getMethodLabel('cbe'), contains('Commercial Bank'));
      expect(RevenueIncomeRecord.getMethodLabel('cash'), 'Direct Cash');
      expect(RevenueIncomeRecord.getMethodLabel('other'), 'Other Income');

      expect(RevenueIncomeRecord.getMethodColor('telebirr'), const Color(0xFF005EB8));
      expect(RevenueIncomeRecord.getMethodColor('cash'), const Color(0xFF10B981));
    });
  });

  group('RevenueController Manual Income Integration', () {
    test('adding income record increases manual income and primaryTotal', () async {
      final controller = createTestController();
      controller.rangeDays.value = 30;

      expect(controller.incomeRecords.length, 0);
      expect(controller.primaryManualIncome, 0.0);
      expect(controller.primaryTotal, 0.0);

      await controller.addIncomeRecord(
        title: 'Direct Cash Registration',
        amount: 1200.0,
        paymentMethod: 'cash',
        date: DateTime.now(),
      );

      expect(controller.incomeRecords.length, 1);
      expect(controller.incomeRecords.first.title, 'Direct Cash Registration');
      expect(controller.primaryManualIncome, 1200.0);
      expect(controller.allTimeManualIncome, 1200.0);
      expect(controller.primaryTotal, 1200.0);
    });

    test('updating and deleting income records operates accurately', () async {
      final controller = createTestController();

      await controller.addIncomeRecord(
        title: 'Initial Deposit',
        amount: 500.0,
        paymentMethod: 'telebirr',
        date: DateTime.now(),
      );

      final record = controller.incomeRecords.first;
      final updated = record.copyWith(title: 'Updated Deposit', amount: 900.0);
      await controller.updateIncomeRecord(updated);

      expect(controller.incomeRecords.first.title, 'Updated Deposit');
      expect(controller.incomeRecords.first.amount, 900.0);
      expect(controller.primaryManualIncome, 900.0);

      await controller.deleteIncomeRecord(record.id);
      expect(controller.incomeRecords.length, 0);
      expect(controller.primaryManualIncome, 0.0);
    });
  });

  group('AddRevenueDialog Widget Tests', () {
    testWidgets('AddRevenueDialog validates input and saves income record', (tester) async {
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
              builder: (context) => ElevatedButton(
                onPressed: () => AddRevenueDialog.show(context, controller),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Record Revenue / Income'), findsOneWidget);
      expect(find.text('Amount (ETB) *'), findsOneWidget);

      // Select quick amount 2500
      await tester.tap(find.text('2500'));
      await tester.pumpAndSettle();

      // Enter source description
      await tester.enterText(
        find.widgetWithText(TextFormField, 'e.g. Direct CBE transfer, School bulk license'),
        'Direct Bank Deposit Test',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Record Revenue'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(controller.incomeRecords.length, 1);
      expect(controller.incomeRecords.first.title, 'Direct Bank Deposit Test');
      expect(controller.incomeRecords.first.amount, 2500.0);
    });

    testWidgets('AddRevenueDialog shows exactly 4 payment methods and description samples in one row', (tester) async {
      final controller = createTestController();

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddRevenueDialog.show(context, controller),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify the 4 payment options: Telebirr, CBE, Abyssinia, Other
      expect(find.text('Telebirr'), findsOneWidget);
      expect(find.text('CBE'), findsOneWidget);
      expect(find.text('Abyssinia'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      // Verify old options are not present as method chips
      expect(find.text('M-Pesa'), findsNothing);
      expect(find.text('Direct Cash'), findsNothing);

      // Verify description samples exist in the scrollable row and tapping one fills description field
      expect(find.text('Direct Bank Deposit'), findsOneWidget);
      await tester.tap(find.text('Direct Bank Deposit'));
      await tester.pumpAndSettle();

      final titleField = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'Direct Bank Deposit',
      );
      expect(titleField, findsOneWidget);
    });

    testWidgets('CostsManagementCard toggles to Manual Revenue tab and displays income', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createTestController();
      controller.isPriceHidden.value = false;

      await controller.addIncomeRecord(
        title: 'School Sponsorship',
        amount: 8000.0,
        paymentMethod: 'cbe',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CostsManagementCard(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Manual Revenue tab
      final incomeTab = find.textContaining('Manual Revenue');
      expect(incomeTab, findsWidgets);
      await tester.tap(incomeTab.first);
      await tester.pumpAndSettle();

      // Expect School Sponsorship item to be rendered
      expect(find.text('School Sponsorship'), findsOneWidget);
      expect(find.textContaining('8,000.00'), findsWidgets);
    });

    testWidgets('CostsManagementCard and AddRevenueDialog render without overflow on narrow screens (360x640)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = createTestController();
      controller.isPriceHidden.value = false;

      await controller.addIncomeRecord(
        title: 'Direct Cash Registration',
        amount: 2500.0,
        paymentMethod: 'cash',
        date: DateTime.now(),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CostsManagementCard(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card renders Promotion & Cost Deductions header without overflow
      expect(find.text('Promotion & Cost Deductions'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Open AddRevenueDialog on 360px screen
      await tester.tap(find.text('Add Revenue').first);
      await tester.pumpAndSettle();

      // Dialog opens cleanly with no overflow
      expect(find.text('Record Revenue / Income'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

