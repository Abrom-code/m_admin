import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/data/repositories/content_repository.dart';
import 'package:m_admin/features/content/screens/content_screen.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

// ── Model ─────────────────────────────────────────────────────────────

class TestRow {
  const TestRow({
    required this.id,
    required this.title,
    required this.type,
    this.grade,
    this.chapterId,
    required this.time,
    required this.questionCount,
    this.isPremium = true,
    this.updatedAt,
    this.description,
  });

  final int id;
  final String title;
  final String type;
  final int? grade;
  final int? chapterId;
  final int time; // -1 = untimed
  final int questionCount;
  final bool isPremium;
  final DateTime? updatedAt;
  final String? description;

  bool get isUntimed => time == -1;

  Color get typeColor {
    switch (type.toLowerCase()) {
      case 'chapter':
        return AppColors.primary;
      case 'entrance':
        return const Color(0xFF2563EB);
      case 'model':
        return const Color(0xFF059669);
      case 'grade':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  factory TestRow.fromJson(Map<String, dynamic> j) {
    final rawPremium = j['is_premium'];
    final isPremium = rawPremium == null
        ? true
        : (rawPremium == true ||
            rawPremium == 1 ||
            rawPremium == 'true' ||
            rawPremium == '1');
    return TestRow(
      id: AppHelperFunctions.toInt(j['id']) ?? 0,
      title: j['title']?.toString() ?? '',
      type: j['type']?.toString() ?? 'chapter',
      grade: AppHelperFunctions.toInt(j['grade']),
      chapterId: AppHelperFunctions.toInt(j['chapter_id']),
      time: AppHelperFunctions.toInt(j['time']) ?? -1,
      questionCount: AppHelperFunctions.toInt(j['question_count']) ?? 0,
      isPremium: isPremium,
      updatedAt: j['updated_at'] == null
          ? null
          : DateTime.tryParse(j['updated_at'].toString()),
      description: j['description']?.toString(),
    );
  }
}

// ── Controller ───────────────────────────────────────────────────────

class SubjectTestsController extends GetxController {
  SubjectTestsController({required this.subject});

  final SubjectRow subject;
  final _repo = ContentRepository();

  final tests = <TestRow>[].obs;
  final chapters = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  // Filters
  final searchQuery = ''.obs;
  final selectedChapterGrade = RxnInt(); // null = all
  final selectedGradeTestGrade = RxnInt(); // null = all
  final selectedExamType = 'all'.obs; // 'all', 'entrance', 'model'

  // Categorized getters
  List<TestRow> get chapterTests =>
      tests.where((t) => t.type.toLowerCase() == 'chapter').toList();

  List<TestRow> get gradeTests =>
      tests.where((t) => t.type.toLowerCase() == 'grade').toList();

  List<TestRow> get entranceAndModelTests => tests
      .where((t) =>
          t.type.toLowerCase() == 'entrance' || t.type.toLowerCase() == 'model')
      .toList();

  int get entranceCount =>
      tests.where((t) => t.type.toLowerCase() == 'entrance').length;

  int get modelCount =>
      tests.where((t) => t.type.toLowerCase() == 'model').length;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    try {
      isLoading.value = true;
      error.value = null;

      final testRows = await _repo.fetchTestsForSubject(subject.id);
      final chapterRows = await _repo.fetchChaptersForSubject(subject.id);

      tests.value = testRows.map(TestRow.fromJson).toList();
      chapters.value = chapterRows;
    } catch (e) {
      error.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteTest(int testId) async {
    try {
      await _repo.deleteTest(testId);
      await loadAll();
      SnackbarHelper.success('Deleted', 'Test removed successfully.');
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────

class SubjectTestsScreen extends StatelessWidget {
  const SubjectTestsScreen({super.key, required this.subject});
  final SubjectRow subject;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final controller = Get.put(
      SubjectTestsController(subject: subject),
      tag: 'subject_tests_${subject.id}',
    );

    Color streamColor;
    String streamLabel;
    if (subject.isCommon) {
      streamColor = const Color(0xFF0284C7);
      streamLabel = 'Common';
    } else if (subject.isNatural) {
      streamColor = AppColors.primary;
      streamLabel = 'Natural Stream';
    } else {
      streamColor = AppColors.secondary;
      streamLabel = 'Social Stream';
    }

    void openTest({
      int? testId,
      String? initialType,
      int? initialGrade,
      int? initialChapterId,
    }) {
      Get.toNamed(
        AdminRoutes.contentTest,
        arguments: {
          'subject_id': subject.id,
          'subject_name': subject.name,
          'test_id': testId,
          'initial_type': initialType,
          'initial_grade': initialGrade,
          'initial_chapter_id': initialChapterId,
        },
      )?.then((_) => controller.loadAll());
    }

    void showCreateTypeDialog() {
      showModalBottomSheet(
        context: context,
        backgroundColor: dark ? AppColors.darkSurface : AppColors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.defaultSpace,
                vertical: AppSizes.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.add_circle_copy,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Create New Test in ${subject.name}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Select the test type to pre-fill the form correctly:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceBtwItems),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: AppColors.primary.withValues(alpha: 0.08),
                    leading: const Icon(Iconsax.folder_2_copy,
                        color: AppColors.primary),
                    title: const Text(
                      'Chapter Practice Test',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Section or chapter-specific quiz mapped to textbook syllabus',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      openTest(initialType: 'chapter');
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: AppColors.warning.withValues(alpha: 0.08),
                    leading: const Icon(Iconsax.teacher_copy,
                        color: AppColors.warning),
                    title: const Text(
                      'Grade Assessment Test',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Comprehensive full-grade mock test (Grades 9 – 12)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      openTest(initialType: 'grade', initialGrade: 12);
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    leading: const Icon(Icons.school_rounded,
                        color: Color(0xFF2563EB)),
                    title: const Text(
                      'National Entrance Exam',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Past university entrance exam paper (e.g. 2016 EUEE)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      openTest(initialType: 'entrance');
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    tileColor: const Color(0xFF059669).withValues(alpha: 0.08),
                    leading: const Icon(Iconsax.award_copy,
                        color: Color(0xFF059669)),
                    title: const Text(
                      'Model Exam Paper',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'National or regional mock model entrance examination',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      openTest(initialType: 'model');
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: dark ? AppColors.dark : AppColors.light,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.darkSurface : AppColors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Get.back(),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: streamColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Iconsax.book_1_copy, size: 16, color: streamColor),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      subject.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Obx(
                      () => Text(
                        '${controller.tests.length} tests · ${controller.chapters.length} chapters · $streamLabel',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => Get.toNamed(
                AdminRoutes.contentChapter,
                arguments: {'subject': subject},
              )?.then((_) => controller.loadAll()),
              icon: const Icon(Iconsax.folder_2_copy, size: 14),
              label: const Text('Chapters', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: showCreateTypeDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Create Test',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: controller.loadAll,
            ),
            const SizedBox(width: AppSizes.sm),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Obx(
                () => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.folder_2_copy, size: 15),
                      const SizedBox(width: 6),
                      Text('Chapter Tests (${controller.chapterTests.length})'),
                    ],
                  ),
                ),
              ),
              Obx(
                () => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.teacher_copy, size: 15),
                      const SizedBox(width: 6),
                      Text('Grade Tests (${controller.gradeTests.length})'),
                    ],
                  ),
                ),
              ),
              Obx(
                () => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.award_copy, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Entrance & Model (${controller.entranceAndModelTests.length})',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.tests.isEmpty) {
            return const Center(child: AppCircularLoading());
          }

          if (controller.error.value != null && controller.tests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 40, color: AppColors.error),
                  const SizedBox(height: 8),
                  Text(
                    controller.error.value!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: controller.loadAll,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            children: [
              // ── TAB 1: Chapter Tests (Organized by Grade & Chapter) ──────
              _ChapterTestsView(
                controller: controller,
                subject: subject,
                onOpenTest: (testId, {type, grade, chapterId}) => openTest(
                  testId: testId,
                  initialType: type,
                  initialGrade: grade,
                  initialChapterId: chapterId,
                ),
              ),

              // ── TAB 2: Grade Tests (Organized by Grade 9 – 12) ───────────
              _GradeTestsView(
                controller: controller,
                subject: subject,
                onOpenTest: (testId, {type, grade}) => openTest(
                  testId: testId,
                  initialType: type,
                  initialGrade: grade,
                ),
              ),

              // ── TAB 3: Entrance & Model Exams (National Exam Format) ────
              _EntranceAndModelExamsView(
                controller: controller,
                subject: subject,
                onOpenTest: (testId, {type}) => openTest(
                  testId: testId,
                  initialType: type,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ── TAB 1: CHAPTER TESTS VIEW ───────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _ChapterTestsView extends StatefulWidget {
  const _ChapterTestsView({
    required this.controller,
    required this.subject,
    required this.onOpenTest,
  });

  final SubjectTestsController controller;
  final SubjectRow subject;
  final Function(int? testId, {String? type, int? grade, int? chapterId})
      onOpenTest;

  @override
  State<_ChapterTestsView> createState() => _ChapterTestsViewState();
}

class _ChapterTestsViewState extends State<_ChapterTestsView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final ctrl = widget.controller;

    return Column(
      children: [
        // ── Filter Toolbar ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.white,
            border: Border(
              bottom: BorderSide(
                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
              ),
            ),
          ),
          child: Row(
            children: [
              // Search input
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => ctrl.searchQuery.value = v.trim().toLowerCase(),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search chapter tests or titles...',
                      hintStyle: const TextStyle(fontSize: 11),
                      prefixIcon: const Icon(Iconsax.search_normal_copy, size: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),

              // Grade filter chips
              if (!widget.subject.isCommon)
                Obx(() {
                  final selGrade = ctrl.selectedChapterGrade.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Grade: ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      ...[null, 9, 10, 11, 12].map((g) {
                        final isSel = selGrade == g;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: Text(
                              g == null ? 'All' : 'G$g',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            onSelected: (_) => ctrl.selectedChapterGrade.value = g,
                          ),
                        );
                      }),
                    ],
                  );
                }),
            ],
          ),
        ),

        // ── Chapters & Tests List ───────────────────────────────────────────
        Expanded(
          child: Obx(() {
            final query = ctrl.searchQuery.value;
            final selectedGrade = ctrl.selectedChapterGrade.value;

            // Filter chapters by grade
            var chList = ctrl.chapters.toList();
            if (selectedGrade != null) {
              chList = chList.where((c) => c['grade'] == selectedGrade).toList();
            }

            // All chapter tests
            var chTests = ctrl.chapterTests;
            if (selectedGrade != null) {
              chTests = chTests.where((t) => t.grade == selectedGrade).toList();
            }
            if (query.isNotEmpty) {
              chTests = chTests
                  .where((t) => t.title.toLowerCase().contains(query))
                  .toList();
            }

            if (chList.isEmpty && chTests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.folder_2_copy,
                      size: 40,
                      color: dark ? Colors.white30 : AppColors.darkGrey,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No Chapters Found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create chapters first to organize chapter-based practice tests.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => Get.toNamed(
                        AdminRoutes.contentChapter,
                        arguments: {'subject': widget.subject},
                      )?.then((_) => ctrl.loadAll()),
                      icon: const Icon(Iconsax.folder_add_copy, size: 16),
                      label: const Text('Manage Chapters'),
                    ),
                  ],
                ),
              );
            }

            // Collect orphaned/unassigned tests
            final assignedChapterIds = chList.map((c) => c['id']).toSet();
            final unassignedTests = chTests
                .where((t) =>
                    t.chapterId == null || !assignedChapterIds.contains(t.chapterId))
                .toList();

            return ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: [
                // Render each chapter and its tests
                ...chList.map((chapter) {
                  final cid = chapter['id'];
                  final cNum = chapter['chapter_number'] ?? 1;
                  final cGrade = chapter['grade'] ?? 12;
                  final cTitle = chapter['title']?.toString() ?? 'Chapter $cNum';

                  final testsInChapter =
                      chTests.where((t) => t.chapterId == cid).toList();

                  // If user searched and this chapter has no matching tests and title doesn't match, skip
                  if (query.isNotEmpty &&
                      testsInChapter.isEmpty &&
                      !cTitle.toLowerCase().contains(query)) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.md),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkCard : AppColors.white,
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadiusMd),
                      border: Border.all(
                        color: dark
                            ? AppColors.darkBorder
                            : AppColors.borderPrimary,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Chapter Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: dark
                                ? AppColors.darkSurface
                                : AppColors.primary.withValues(alpha: 0.04),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppSizes.borderRadiusMd),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: dark
                                    ? AppColors.darkBorder
                                    : AppColors.borderPrimary,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.subject.isCommon
                                      ? 'Sec $cNum'
                                      : 'G$cGrade · Ch $cNum',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? AppColors.darkContainer
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${testsInChapter.length} tests',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                onPressed: () => widget.onOpenTest(
                                  null,
                                  type: 'chapter',
                                  grade: cGrade,
                                  chapterId: cid,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 14),
                                label: const Text('Add Test',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),

                        // Tests inside this chapter
                        if (testsInChapter.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSizes.md),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'No practice tests in this chapter.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => widget.onOpenTest(
                                    null,
                                    type: 'chapter',
                                    grade: cGrade,
                                    chapterId: cid,
                                  ),
                                  child: const Text(
                                    '+ Create first test',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: testsInChapter.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: dark
                                  ? AppColors.darkBorder
                                  : AppColors.borderPrimary,
                            ),
                            itemBuilder: (context, idx) {
                              final test = testsInChapter[idx];
                              return _TestRowItem(
                                test: test,
                                onEdit: () => widget.onOpenTest(test.id),
                                onDelete: () =>
                                    _confirmDelete(context, test, ctrl),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                }),

                // Unassigned Chapter Tests Card (if any exist)
                if (unassignedTests.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.md),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkCard : AppColors.white,
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadiusMd),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppSizes.borderRadiusMd),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: AppColors.warning),
                              const SizedBox(width: 8),
                              const Text(
                                'Unassigned Chapter Tests (Missing Chapter Link)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: AppColors.warning,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${unassignedTests.length} tests',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: unassignedTests.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: dark
                                ? AppColors.darkBorder
                                : AppColors.borderPrimary,
                          ),
                          itemBuilder: (context, idx) {
                            final test = unassignedTests[idx];
                            return _TestRowItem(
                              test: test,
                              onEdit: () => widget.onOpenTest(test.id),
                              onDelete: () =>
                                  _confirmDelete(context, test, ctrl),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ── TAB 2: GRADE TESTS VIEW ─────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _GradeTestsView extends StatefulWidget {
  const _GradeTestsView({
    required this.controller,
    required this.subject,
    required this.onOpenTest,
  });

  final SubjectTestsController controller;
  final SubjectRow subject;
  final Function(int? testId, {String? type, int? grade}) onOpenTest;

  @override
  State<_GradeTestsView> createState() => _GradeTestsViewState();
}

class _GradeTestsViewState extends State<_GradeTestsView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final ctrl = widget.controller;

    return Column(
      children: [
        // ── Toolbar ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.white,
            border: Border(
              bottom: BorderSide(
                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => ctrl.searchQuery.value = v.trim().toLowerCase(),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search grade assessment tests...',
                      hintStyle: const TextStyle(fontSize: 11),
                      prefixIcon: const Icon(Iconsax.search_normal_copy, size: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),

              // Grade filter chips
              Obx(() {
                final selGrade = ctrl.selectedGradeTestGrade.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Grade: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    ...[null, 9, 10, 11, 12].map((g) {
                      final isSel = selGrade == g;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text(
                            g == null ? 'All' : 'Grade $g',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: AppColors.warning,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          onSelected: (_) => ctrl.selectedGradeTestGrade.value = g,
                        ),
                      );
                    }),
                  ],
                );
              }),

              const SizedBox(width: AppSizes.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => widget.onOpenTest(
                  null,
                  type: 'grade',
                  grade: ctrl.selectedGradeTestGrade.value ?? 12,
                ),
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Add Grade Test',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // ── Grade Tests List ────────────────────────────────────────────────
        Expanded(
          child: Obx(() {
            final query = ctrl.searchQuery.value;
            final selectedGrade = ctrl.selectedGradeTestGrade.value;

            var gTests = ctrl.gradeTests;
            if (selectedGrade != null) {
              gTests = gTests.where((t) => t.grade == selectedGrade).toList();
            }
            if (query.isNotEmpty) {
              gTests = gTests
                  .where((t) => t.title.toLowerCase().contains(query))
                  .toList();
            }

            if (gTests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.teacher_copy,
                      size: 40,
                      color: dark ? Colors.white30 : AppColors.darkGrey,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No Grade Tests Found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Grade assessment tests cover entire syllabus for Grades 9 – 12.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => widget.onOpenTest(
                        null,
                        type: 'grade',
                        grade: selectedGrade ?? 12,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Create Grade Test'),
                    ),
                  ],
                ),
              );
            }

            // Group by Grade
            final Map<int, List<TestRow>> groupedByGrade = {};
            for (final t in gTests) {
              final g = t.grade ?? 0;
              groupedByGrade.putIfAbsent(g, () => []).add(t);
            }
            final sortedGrades = groupedByGrade.keys.toList()..sort();

            return ListView(
              padding: const EdgeInsets.all(AppSizes.md),
              children: sortedGrades.map((grade) {
                final testsForGrade = groupedByGrade[grade]!;
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSizes.md),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkCard : AppColors.white,
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                    border: Border.all(
                      color: dark
                          ? AppColors.darkBorder
                          : AppColors.borderPrimary,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColors.darkSurface
                              : AppColors.warning.withValues(alpha: 0.06),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppSizes.borderRadiusMd),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: dark
                                  ? AppColors.darkBorder
                                  : AppColors.borderPrimary,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                grade > 0 ? 'Grade $grade' : 'General Grade',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              grade > 0
                                  ? 'Comprehensive Grade $grade Practice & Mock Tests'
                                  : 'General Grade Practice Tests',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${testsForGrade.length} tests',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: testsForGrade.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: dark
                              ? AppColors.darkBorder
                              : AppColors.borderPrimary,
                        ),
                        itemBuilder: (context, idx) {
                          final test = testsForGrade[idx];
                          return _TestRowItem(
                            test: test,
                            onEdit: () => widget.onOpenTest(test.id),
                            onDelete: () =>
                                _confirmDelete(context, test, ctrl),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ── TAB 3: ENTRANCE & MODEL EXAMS VIEW (Formatted in Entrance Style) ─────────
// ═════════════════════════════════════════════════════════════════════════════

class _EntranceAndModelExamsView extends StatefulWidget {
  const _EntranceAndModelExamsView({
    required this.controller,
    required this.subject,
    required this.onOpenTest,
  });

  final SubjectTestsController controller;
  final SubjectRow subject;
  final Function(int? testId, {String? type}) onOpenTest;

  @override
  State<_EntranceAndModelExamsView> createState() =>
      _EntranceAndModelExamsViewState();
}

class _EntranceAndModelExamsViewState
    extends State<_EntranceAndModelExamsView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final ctrl = widget.controller;

    return Column(
      children: [
        // ── Toolbar ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.white,
            border: Border(
              bottom: BorderSide(
                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => ctrl.searchQuery.value = v.trim().toLowerCase(),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search entrance or model exams (year, title)...',
                      hintStyle: const TextStyle(fontSize: 11),
                      prefixIcon: const Icon(Iconsax.search_normal_copy, size: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),

              // Filter chips (All, Entrance, Model)
              Obx(() {
                final selType = ctrl.selectedExamType.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        'All (${ctrl.entranceAndModelTests.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selType == 'all'
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: selType == 'all'
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      selected: selType == 'all',
                      selectedColor: const Color(0xFF2563EB),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => ctrl.selectedExamType.value = 'all',
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        'Entrance (${ctrl.entranceCount})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selType == 'entrance'
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: selType == 'entrance'
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      selected: selType == 'entrance',
                      selectedColor: const Color(0xFF2563EB),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => ctrl.selectedExamType.value = 'entrance',
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        'Model (${ctrl.modelCount})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selType == 'model'
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: selType == 'model'
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      selected: selType == 'model',
                      selectedColor: const Color(0xFF059669),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => ctrl.selectedExamType.value = 'model',
                    ),
                  ],
                );
              }),

              const SizedBox(width: AppSizes.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => widget.onOpenTest(null, type: 'entrance'),
                icon: const Icon(Icons.school_rounded, size: 14),
                label: const Text('+ Entrance',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => widget.onOpenTest(null, type: 'model'),
                icon: const Icon(Iconsax.award_copy, size: 14),
                label: const Text('+ Model',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // ── Entrance & Model Cards Grid/List ────────────────────────────────
        Expanded(
          child: Obx(() {
            final query = ctrl.searchQuery.value;
            final typeFilter = ctrl.selectedExamType.value;

            var exams = ctrl.entranceAndModelTests;
            if (typeFilter == 'entrance') {
              exams = exams.where((t) => t.type.toLowerCase() == 'entrance').toList();
            } else if (typeFilter == 'model') {
              exams = exams.where((t) => t.type.toLowerCase() == 'model').toList();
            }

            if (query.isNotEmpty) {
              exams = exams
                  .where((t) => t.title.toLowerCase().contains(query))
                  .toList();
            }

            if (exams.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 44,
                      color: dark ? Colors.white30 : AppColors.darkGrey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      typeFilter == 'entrance'
                          ? 'No Entrance Exams Found'
                          : (typeFilter == 'model'
                              ? 'No Model Exams Found'
                              : 'No Entrance or Model Exams Found'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'National entrance past papers and mock model exams for this subject.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () =>
                              widget.onOpenTest(null, type: 'entrance'),
                          icon: const Icon(Icons.school_rounded, size: 15),
                          label: const Text('Add Entrance Exam'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => widget.onOpenTest(null, type: 'model'),
                          icon: const Icon(Iconsax.award_copy, size: 15),
                          label: const Text('Add Model Exam'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                // Responsive grid: 1 column on narrow, 2 columns on wide screens
                final isWide = constraints.maxWidth >= 720;

                return GridView.builder(
                  padding: const EdgeInsets.all(AppSizes.md),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 2 : 1,
                    mainAxisExtent: 160,
                    crossAxisSpacing: AppSizes.md,
                    mainAxisSpacing: AppSizes.md,
                  ),
                  itemCount: exams.length,
                  itemBuilder: (context, index) {
                    final exam = exams[index];
                    final isEntrance = exam.type.toLowerCase() == 'entrance';
                    final badgeColor = isEntrance
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF059669);

                    return Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkCard : AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(
                          color: dark
                              ? AppColors.darkBorder
                              : AppColors.borderPrimary,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Type badge + Access chip + Actions
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isEntrance
                                          ? Icons.school_rounded
                                          : Iconsax.award_copy,
                                      size: 13,
                                      color: badgeColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isEntrance
                                          ? 'NATIONAL ENTRANCE'
                                          : 'MODEL EXAM',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: exam.isPremium
                                      ? Colors.amber.withValues(alpha: 0.12)
                                      : AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  exam.isPremium ? 'PRO' : 'FREE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: exam.isPremium
                                        ? Colors.amber[800]
                                        : AppColors.success,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Edit Exam Details',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Iconsax.edit_2_copy, size: 15),
                                onPressed: () => widget.onOpenTest(exam.id),
                              ),
                              IconButton(
                                tooltip: 'Delete Exam',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Iconsax.trash_copy,
                                    size: 15, color: AppColors.error),
                                onPressed: () =>
                                    _confirmDelete(context, exam, ctrl),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Exam Title
                          Text(
                            exam.title.isNotEmpty
                                ? exam.title
                                : 'Untitled Exam #${exam.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (exam.description != null &&
                              exam.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              exam.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const Spacer(),

                          // Bottom metadata and Questions button
                          Row(
                            children: [
                              Row(
                                children: [
                                  Icon(Iconsax.clock_copy,
                                      size: 13,
                                      color: dark
                                          ? Colors.white54
                                          : AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    exam.isUntimed
                                        ? 'Untimed'
                                        : '${exam.time} mins',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  Icon(Iconsax.document_text_copy,
                                      size: 13,
                                      color: dark
                                          ? Colors.white54
                                          : AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${exam.questionCount} Questions',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => widget.onOpenTest(exam.id),
                                icon: const Icon(Iconsax.task_copy, size: 12),
                                label: const Text('Questions',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ── REUSABLE TEST ROW ITEM ───────────────────────────────────────────────────
// ═════════════════════════════════════════════════════════════════════════════

class _TestRowItem extends StatelessWidget {
  const _TestRowItem({
    required this.test,
    required this.onEdit,
    required this.onDelete,
  });

  final TestRow test;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: test.typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              Iconsax.clipboard_text_copy,
              size: 14,
              color: test.typeColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  test.title.isNotEmpty ? test.title : 'Untitled Test #${test.id}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (test.description != null &&
                    test.description!.trim().isNotEmpty)
                  Text(
                    test.description!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Duration pill
          Text(
            test.isUntimed ? 'Untimed' : '${test.time}m',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),

          // Question count pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${test.questionCount} Qs',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Access pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: test.isPremium
                  ? Colors.amber.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              test.isPremium ? 'PRO' : 'FREE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: test.isPremium ? Colors.amber[800] : AppColors.success,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Actions
          IconButton(
            tooltip: 'Manage Questions & Details',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Iconsax.edit_2_copy, size: 15),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete Test',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Iconsax.trash_copy, size: 15, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

void _confirmDelete(
  BuildContext context,
  TestRow row,
  SubjectTestsController controller,
) {
  Get.dialog(
    AlertDialog(
      title: const Text('Delete Test?'),
      content: Text(
        'Are you sure you want to delete "${row.title}" and all its ${row.questionCount} question(s)?\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            Get.back();
            controller.deleteTest(row.id);
          },
          child: const Text('Delete Test'),
        ),
      ],
    ),
  );
}
