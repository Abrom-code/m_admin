import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/admin_tips_news_repository.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/features/tips_and_news/controllers/admin_tips_news_controller.dart';
import 'package:m_admin/features/tips_and_news/models/admin_tip_news_model.dart';
import 'package:m_admin/features/tips_and_news/screens/tips_and_news_screen.dart';
import 'package:m_admin/features/tips_and_news/screens/widgets/tip_news_detail_dialog.dart';
import 'package:m_admin/features/tips_and_news/screens/widgets/tip_news_form_dialog.dart';

/// In-memory mock repository for Tips & News testing.
class MockTipsNewsRepository extends AdminTipsNewsRepository {
  MockTipsNewsRepository({List<AdminTipNewsModel>? initialItems})
      : inMemoryItems = List.from(initialItems ?? []);

  final List<AdminTipNewsModel> inMemoryItems;

  @override
  Future<List<AdminTipNewsModel>> fetchAll({
    String? search,
    String? category,
    String? audience,
  }) async {
    return List.from(inMemoryItems);
  }

  @override
  Future<AdminTipNewsModel> create(AdminTipNewsModel item) async {
    final newItem = item.copyWith(
      id: inMemoryItems.isEmpty
          ? 1
          : inMemoryItems.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    inMemoryItems.add(newItem);
    return newItem;
  }

  @override
  Future<AdminTipNewsModel> update(AdminTipNewsModel item) async {
    final index = inMemoryItems.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      final updated = item.copyWith(updatedAt: DateTime.now());
      inMemoryItems[index] = updated;
      return updated;
    }
    return item;
  }

  @override
  Future<void> togglePin(int id, bool isPinned) async {
    final index = inMemoryItems.indexWhere((e) => e.id == id);
    if (index != -1) {
      inMemoryItems[index] = inMemoryItems[index].copyWith(isPinned: isPinned);
    }
  }

  @override
  Future<void> togglePublish(int id, bool isPublished) async {
    final index = inMemoryItems.indexWhere((e) => e.id == id);
    if (index != -1) {
      inMemoryItems[index] =
          inMemoryItems[index].copyWith(isPublished: isPublished);
    }
  }

  @override
  Future<void> deleteSingle(int id) async {
    inMemoryItems.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> deleteBatch(List<int> ids) async {
    inMemoryItems.removeWhere((e) => ids.contains(e.id));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    Get.put(AdminNavController());
  });

  tearDown(() {
    Get.reset();
  });

  group('AdminTipNewsModel Unit Tests', () {
    test('Parses fromJson correctly with complete fields', () {
      final json = {
        'id': 101,
        'title': '2019 E.C. National Exam Registration Guidelines',
        'content':
            'Detailed instructions for grade 12 admission cards and stream selection.',
        'category': 'news',
        'image_url': 'https://example.com/banner.png',
        'author': 'MatricMate Lead',
        'audience': 'natural',
        'is_pinned': true,
        'is_published': true,
        'created_at': '2026-10-15T10:00:00Z',
        'updated_at': '2026-10-15T11:00:00Z',
      };

      final model = AdminTipNewsModel.fromJson(json);

      expect(model.id, equals(101));
      expect(model.title,
          equals('2019 E.C. National Exam Registration Guidelines'));
      expect(model.isNews, isTrue);
      expect(model.isTip, isFalse);
      expect(model.categoryLabel, equals('News'));
      expect(model.audience, equals('natural'));
      expect(model.audienceLabel, equals('Natural Science'));
      expect(model.isPinned, isTrue);
      expect(model.isPublished, isTrue);
      expect(model.imageUrl, equals('https://example.com/banner.png'));
      expect(model.author, equals('MatricMate Lead'));
    });

    test('Parses fromJson correctly with Amharic body and missing optional fields', () {
      final json = {
        'id': 102,
        'title': 'የ2019 ዓ.ም የፈተና መመሪያ',
        'content': 'ለተፈጥሮ እና ማህበራዊ ሳይንስ ተማሪዎች የተዘጋጀ አጠቃላይ መመሪያ እና ስትራቴጂ።',
        'category': 'tip',
      };

      final model = AdminTipNewsModel.fromJson(json);

      expect(model.id, equals(102));
      expect(model.title, equals('የ2019 ዓ.ም የፈተና መመሪያ'));
      expect(model.content, contains('ለተፈጥሮ'));
      expect(model.isNews, isFalse);
      expect(model.isTip, isTrue);
      expect(model.categoryLabel, equals('Study Tip'));
      expect(model.audience, equals('both'));
      expect(model.audienceLabel, equals('All Students'));
      expect(model.author, equals('MatricMate Team'));
      expect(model.isPinned, isFalse);
      expect(model.isPublished, isTrue);
    });

    test('toUpsertJson produces clean payload for Supabase database', () {
      final model = AdminTipNewsModel(
        id: 5,
        title: 'Effective Recall',
        content: 'Close your book and test yourself actively.',
        category: 'tip',
        imageUrl: '',
        author: ' Academic Advisor ',
        audience: 'social',
        isPinned: false,
        isPublished: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final payload = model.toUpsertJson();

      expect(payload.containsKey('id'), isFalse);
      expect(payload['title'], equals('Effective Recall'));
      expect(payload['category'], equals('tip'));
      expect(payload['audience'], equals('social'));
      expect(payload['image_url'], isNull);
      expect(payload['author'], equals('Academic Advisor'));
      expect(payload['is_pinned'], isFalse);
      expect(payload['is_published'], isTrue);
      expect(payload.containsKey('updated_at'), isTrue);
    });

    test('Snippet behaves accurately', () {
      final shortModel = AdminTipNewsModel(
        id: 1,
        title: 'Short',
        content: 'This is a short message.',
        category: 'news',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(shortModel.snippet, equals('This is a short message.'));

      final words = List.generate(300, (i) => 'word$i').join(' ');
      final longModel = AdminTipNewsModel(
        id: 2,
        title: 'Long',
        content: words,
        category: 'tip',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(longModel.snippet.length, lessThanOrEqualTo(100));
      expect(longModel.snippet.endsWith('...'), isTrue);
    });

    test('copyWith creates new instances with modified values', () {
      final original = AdminTipNewsModel(
        id: 10,
        title: 'Title',
        content: 'Content',
        category: 'news',
        isPinned: false,
        isPublished: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = original.copyWith(isPinned: true, isPublished: true);

      expect(updated.id, equals(10));
      expect(updated.isPinned, isTrue);
      expect(updated.isPublished, isTrue);
      expect(original.isPinned, isFalse);
    });
  });

  group('AdminTipsNewsController Unit Tests', () {
    late MockTipsNewsRepository mockRepo;
    late AdminTipsNewsController controller;

    final sampleItems = [
      AdminTipNewsModel(
        id: 1,
        title: 'National Exam News',
        content: 'Important updates for national exam candidates.',
        category: 'news',
        author: 'MatricMate Team',
        audience: 'both',
        isPinned: true,
        isPublished: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now(),
      ),
      AdminTipNewsModel(
        id: 2,
        title: 'Physics 3-Pass Technique',
        content: 'Solve easy questions first in natural science exams.',
        category: 'tip',
        author: 'Academic Mentors',
        audience: 'natural',
        isPinned: false,
        isPublished: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now(),
      ),
      AdminTipNewsModel(
        id: 3,
        title: 'History Timeline Memorization',
        content: 'Key strategies for social science history chapters.',
        category: 'tip',
        author: 'Social Mentor',
        audience: 'social',
        isPinned: false,
        isPublished: false, // Draft
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now(),
      ),
      AdminTipNewsModel(
        id: 4,
        title: 'የፈተና ወቅት ዝግጅት',
        content: 'ለፈተና ጥሩ ውጤት ለማምጣት የሚረዱ ዋና ዋና ዘዴዎች።',
        category: 'news',
        author: 'አዘጋጅ ክፍል',
        audience: 'both',
        isPinned: false,
        isPublished: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        updatedAt: DateTime.now(),
      ),
    ];

    setUp(() async {
      mockRepo = MockTipsNewsRepository(initialItems: sampleItems);
      controller = AdminTipsNewsController(repository: mockRepo);
      Get.put(controller);
      await controller.loadItems();
    });

    test('Initial loading loads items and computes counts correctly', () {
      expect(controller.items.length, equals(4));
      expect(controller.totalCount, equals(4));
      expect(controller.newsCount, equals(2));
      expect(controller.tipsCount, equals(2));
      expect(controller.publishedCount, equals(3));
      expect(controller.draftCount, equals(1));
      expect(controller.pinnedCount, equals(1));
    });

    test('Filter by category filters correctly', () {
      controller.selectedCategory.value = 'news';
      expect(controller.filteredItems.length, equals(2));
      expect(controller.filteredItems.every((i) => i.isNews), isTrue);

      controller.selectedCategory.value = 'tip';
      expect(controller.filteredItems.length, equals(2));
      expect(controller.filteredItems.every((i) => i.isTip), isTrue);

      controller.selectedCategory.value = 'all';
      expect(controller.filteredItems.length, equals(4));
    });

    test('Filter by audience filters correctly', () {
      controller.selectedAudience.value = 'natural';
      expect(controller.filteredItems.length, equals(1));
      expect(controller.filteredItems.first.title, contains('Physics'));

      controller.selectedAudience.value = 'social';
      expect(controller.filteredItems.length, equals(1));
      expect(controller.filteredItems.first.title, contains('History'));

      controller.selectedAudience.value = 'both';
      expect(controller.filteredItems.length, equals(2));

      controller.selectedAudience.value = 'all';
      expect(controller.filteredItems.length, equals(4));
    });

    test('Filter by publish status (published vs draft) filters correctly', () {
      controller.selectedPublishStatus.value = 'draft';
      expect(controller.filteredItems.length, equals(1));
      expect(controller.filteredItems.first.id, equals(3));

      controller.selectedPublishStatus.value = 'published';
      expect(controller.filteredItems.length, equals(3));

      controller.selectedPublishStatus.value = 'all';
      expect(controller.filteredItems.length, equals(4));
    });

    test('Search query matches title, content, or author in English and Amharic', () {
      controller.searchQuery.value = 'timeline';
      expect(controller.filteredItems.length, equals(1));
      expect(controller.filteredItems.first.id, equals(3));

      controller.searchQuery.value = 'ዝግጅት';
      expect(controller.filteredItems.length, equals(1));
      expect(controller.filteredItems.first.id, equals(4));

      controller.searchQuery.value = 'nonexistent keyword';
      expect(controller.filteredItems.isEmpty, isTrue);

      controller.searchQuery.value = '';
      expect(controller.filteredItems.length, equals(4));
    });

    test('Selection mode toggling and batch operations', () {
      expect(controller.isSelectionMode, isFalse);

      controller.toggleSelection(1);
      expect(controller.isSelectionMode, isTrue);
      expect(controller.selectedIds.contains(1), isTrue);

      controller.toggleSelection(1);
      expect(controller.isSelectionMode, isFalse);

      controller.selectAll();
      expect(controller.selectedIds.length, equals(4));

      controller.deselectAll();
      expect(controller.selectedIds.isEmpty, isTrue);
    });

    test('saveItem adds a new broadcast and sorts pinned to top', () async {
      final newItem = AdminTipNewsModel(
        id: 0,
        title: 'Brand New Study Tip',
        content: 'Feynman technique explanation.',
        category: 'tip',
        author: 'MatricMate Team',
        audience: 'both',
        isPinned: true, // Pinned!
        isPublished: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await controller.saveItem(newItem);

      expect(success, isTrue);
      expect(controller.items.length, equals(5));
      expect(controller.items.first.title, equals('Brand New Study Tip'));
      expect(controller.items.first.isPinned, isTrue);
    });

    test('togglePin updates optimistic UI and keeps pinned sorted first', () async {
      final item = controller.items.firstWhere((i) => i.id == 2);
      expect(item.isPinned, isFalse);

      await controller.togglePin(item);

      final updated = controller.items.firstWhere((i) => i.id == 2);
      expect(updated.isPinned, isTrue);
      expect(controller.pinnedCount, equals(2));
    });

    test('togglePublish updates optimistic UI publish state', () async {
      final item = controller.items.firstWhere((i) => i.id == 3);
      expect(item.isPublished, isFalse);

      await controller.togglePublish(item);

      final updated = controller.items.firstWhere((i) => i.id == 3);
      expect(updated.isPublished, isTrue);
      expect(controller.publishedCount, equals(4));
    });

    test('batchPinSelected and batchPublishSelected update multiple selected items', () async {
      controller.selectedIds.addAll([2, 3]);

      await controller.batchPinSelected(true);
      expect(controller.items.firstWhere((i) => i.id == 2).isPinned, isTrue);
      expect(controller.items.firstWhere((i) => i.id == 3).isPinned, isTrue);

      await controller.batchPublishSelected(true);
      expect(controller.items.firstWhere((i) => i.id == 3).isPublished, isTrue);
    });
  });

  group('Widget & Overflow Layout Tests', () {
    testWidgets('TipNewsFormDialog renders without overflow on mobile (320x480)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockTipsNewsRepository();
      Get.put(AdminTipsNewsController(repository: mockRepo));

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: TipNewsFormDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Broadcast'), findsOneWidget);
      expect(find.text('News Announcement'), findsOneWidget);
      expect(find.text('Study Tip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TipsAndNewsScreen renders cleanly without overflow on mobile (360x640)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleItems = [
        AdminTipNewsModel(
          id: 1,
          title: '2019 E.C. Guidelines',
          content: 'Important news for candidates.',
          category: 'news',
          isPinned: true,
          isPublished: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final mockRepo = MockTipsNewsRepository(initialItems: sampleItems);
      Get.put(AdminNavController());
      final ctrl = AdminTipsNewsController(repository: mockRepo);
      Get.put(ctrl);
      await ctrl.loadItems();

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: TipsAndNewsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2019 E.C. Guidelines'), findsOneWidget);
      expect(find.text('PINNED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TipsAndNewsScreen renders wide desktop layout (1200x800) with 0 issues', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleItems = [
        AdminTipNewsModel(
          id: 1,
          title: 'Physics 3-Pass Method',
          content: 'Solve easy problems in Pass 1.',
          category: 'tip',
          author: 'Mentor Team',
          audience: 'natural',
          isPinned: false,
          isPublished: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final mockRepo = MockTipsNewsRepository(initialItems: sampleItems);
      Get.put(AdminNavController());
      final ctrl = AdminTipsNewsController(repository: mockRepo);
      Get.put(ctrl);
      await ctrl.loadItems();

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(
            body: TipsAndNewsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Physics 3-Pass Method'), findsOneWidget);
      expect(find.text('TIP'), findsOneWidget);
      expect(find.text('Natural'), findsOneWidget);
      expect(find.text('New Broadcast'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TipNewsDetailDialog renders cleanly with zero overflow on mobile (320x480)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockTipsNewsRepository();
      Get.put(AdminTipsNewsController(repository: mockRepo));

      final testItem = AdminTipNewsModel(
        id: 99,
        title: 'የ2019 ዓ.ም የፈተና መመሪያ',
        content: 'ለተፈጥሮ እና ማህበራዊ ሳይንስ ተማሪዎች የተዘጋጀ አጠቃላይ መመሪያ እና ስትራቴጂ።',
        category: 'tip',
        author: 'MatricMate Lead',
        audience: 'both',
        isPinned: true,
        isPublished: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: TipNewsDetailDialog(item: testItem),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Study Tip Broadcast'), findsOneWidget);
      expect(find.text('የ2019 ዓ.ም የፈተና መመሪያ'), findsOneWidget);
      expect(find.text('Edit Broadcast'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
