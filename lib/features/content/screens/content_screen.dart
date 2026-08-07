import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/repositories/content_repository.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

// ── Models ───────────────────────────────────────────────────────────

class SubjectRow {
  const SubjectRow({
    required this.id,
    required this.name,
    required this.isNatural,
    required this.isCommon,
    required this.chapterCount,
    required this.testCount,
    required this.questionCount,
    this.updatedAt,
  });

  final int id;
  final String name;
  final bool isNatural;
  final bool isCommon;
  final int chapterCount;
  final int testCount;
  final int questionCount;
  final DateTime? updatedAt;

  String get streamLabel {
    if (isCommon) return 'Common';
    return isNatural ? 'Natural' : 'Social';
  }

  factory SubjectRow.fromJson(Map<String, dynamic> j) => SubjectRow(
    id: AppHelperFunctions.toInt(j['id']) ?? 0,
    name: j['name']?.toString() ?? '',
    isNatural: j['is_natural'] == true,
    isCommon: j['is_common'] == true,
    chapterCount: AppHelperFunctions.toInt(j['chapter_count']) ?? 0,
    testCount: AppHelperFunctions.toInt(j['test_count']) ?? 0,
    questionCount: AppHelperFunctions.toInt(j['question_count']) ?? 0,
    updatedAt: j['updated_at'] == null
        ? null
        : DateTime.tryParse(j['updated_at'].toString()),
  );
}

class TestRow {
  const TestRow({
    required this.id,
    required this.title,
    required this.type,
    this.grade,
    this.chapterId,
    required this.time,
    required this.questionCount,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String type;
  final int? grade;
  final int? chapterId;
  final int time; // -1 = untimed
  final int questionCount;
  final DateTime? updatedAt;

  bool get isUntimed => time == -1;

  Color get typeColor {
    switch (type) {
      case 'chapter':
        return AppColors.primary;
      case 'entrance':
        return AppColors.info;
      case 'model':
        return AppColors.success;
      case 'grade':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  factory TestRow.fromJson(Map<String, dynamic> j) => TestRow(
    id: AppHelperFunctions.toInt(j['id']) ?? 0,
    title: j['title']?.toString() ?? '',
    type: j['type']?.toString() ?? '',
    grade: AppHelperFunctions.toInt(j['grade']),
    chapterId: AppHelperFunctions.toInt(j['chapter_id']),
    time: AppHelperFunctions.toInt(j['time']) ?? -1,
    questionCount: AppHelperFunctions.toInt(j['question_count']) ?? 0,
    updatedAt: j['updated_at'] == null
        ? null
        : DateTime.tryParse(j['updated_at'].toString()),
  );
}

// ── Controller ───────────────────────────────────────────────────────

class ContentController extends GetxController {
  static ContentController get instance => Get.find();

  final _repo = ContentRepository();
  final _sb = Supabase.instance.client;

  final subjects = <SubjectRow>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  final selectedSubject = Rxn<SubjectRow>();
  final tests = <TestRow>[].obs;
  final isLoadingTests = false.obs;
  final testsError = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadSubjects();
  }

  Future<void> loadSubjects() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final subRows = await _sb
          .from('subjects')
          .select('id, name, is_natural, is_common, updated_at')
          .order('name');

      final List<SubjectRow> result = [];
      for (final s in subRows) {
        final sid = AppHelperFunctions.toInt(s['id']) ?? 0;
        final counts = await Future.wait([
          _sb.from('chapters').select('id').eq('subject_id', sid).count(CountOption.exact),
          _sb.from('tests').select('id').eq('subject_id', sid).count(CountOption.exact),
          _sb.from('questions').select('id').eq('subject_id', sid).count(CountOption.exact),
        ]);
        result.add(SubjectRow(
          id: sid,
          name: s['name']?.toString() ?? '',
          isNatural: s['is_natural'] == true,
          isCommon: s['is_common'] == true,
          chapterCount: counts[0].count,
          testCount: counts[1].count,
          questionCount: counts[2].count,
          updatedAt: s['updated_at'] == null
              ? null
              : DateTime.tryParse(s['updated_at'].toString()),
        ));
      }
      subjects.value = result;
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectSubject(SubjectRow subject) async {
    selectedSubject.value = subject;
    await _loadTests(subject.id);
  }

  Future<void> reloadTests() async {
    final s = selectedSubject.value;
    if (s != null) await _loadTests(s.id);
    await loadSubjects();
    if (s != null) {
      selectedSubject.value =
          subjects.firstWhereOrNull((r) => r.id == s.id) ?? s;
    }
  }

  Future<void> _loadTests(int subjectId) async {
    try {
      isLoadingTests.value = true;
      testsError.value = null;
      final rows = await _repo.fetchTestsForSubject(subjectId);
      tests.value = rows.map(TestRow.fromJson).toList();
    } catch (e) {
      testsError.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoadingTests.value = false;
    }
  }

  Future<void> deleteTest(int testId) async {
    try {
      await _repo.deleteTest(testId);
      await reloadTests();
    } catch (e) {
      Get.snackbar(
        'Error',
        AppExceptionHandler.handle(e).message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────

class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ContentController());

    return AdminScaffold(
      title: 'Content',
      subtitle: 'Subjects, chapters, tests and questions',
      scrollable: false,
      actions: [
        Obx(
          () => IconButton(
            tooltip: 'Refresh',
            onPressed:
                controller.isLoading.value ? null : controller.loadSubjects,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 360,
            child: _SubjectsPanel(controller: controller),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _TestsPanel(controller: controller),
          ),
        ],
      ),
    );
  }
}

// ── Subjects panel ────────────────────────────────────────────────────

class _SubjectsPanel extends StatelessWidget {
  const _SubjectsPanel({required this.controller});
  final ContentController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AdminDataTable<SubjectRow>(
        rows: controller.subjects.toList(),
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.loadSubjects,
        emptyTitle: 'No subjects found',
        emptyMessage: 'Run the content migration to populate subjects.',
        minWidth: 320,
        columns: [
          AdminColumn<SubjectRow>(
            label: 'SUBJECT',
            flex: 3,
            cell: (_, row) => _SubjectNameCell(row: row),
          ),
          AdminColumn<SubjectRow>(
            label: 'TESTS',
            width: 56,
            numeric: true,
            cell: (_, row) => Text(
              '${row.testCount}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          AdminColumn<SubjectRow>(
            label: 'QS',
            width: 56,
            numeric: true,
            cell: (_, row) => Text(
              '${row.questionCount}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
        onRowTap: controller.selectSubject,
      ),
    );
  }
}

class _SubjectNameCell extends StatelessWidget {
  const _SubjectNameCell({required this.row});
  final SubjectRow row;

  @override
  Widget build(BuildContext context) {
    final color = row.isCommon
        ? AppColors.info
        : row.isNatural
            ? AppColors.success
            : AppColors.warning;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.xs),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          ),
          child: const Icon(
            Iconsax.book_copy,
            size: AppSizes.iconSm,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              _Chip(label: row.streamLabel, color: color),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TestsPanel extends StatelessWidget {
  const _TestsPanel({required this.controller});
  final ContentController controller;

  void _openTest(
    BuildContext context,
    int subjectId,
    String subjectName, {
    int? testId,
  }) {
    Get.toNamed(
      AdminRoutes.contentTest,
      arguments: {
        'subject_id': subjectId,
        'subject_name': subjectName,
        if (testId != null) 'test_id': testId,
      },
    )?.then((_) => controller.reloadTests());
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final subject = controller.selectedSubject.value;

      if (subject == null) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 48, color: AppColors.darkGrey),
              SizedBox(height: AppSizes.sm),
              Text(
                'Select a subject to view its tests',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${subject.testCount} tests · ${subject.questionCount} questions',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openTest(context, subject.id, subject.name),
                  icon: const Icon(Icons.add_rounded, size: AppSizes.iconSm),
                  label: const Text('New Test'),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),
            Expanded(
              child: AdminDataTable<TestRow>(
                rows: controller.tests.toList(),
                isLoading: controller.isLoadingTests.value,
                error: controller.testsError.value,
                onRetry: () => controller.selectSubject(subject),
                emptyTitle: 'No tests yet',
                emptyMessage: 'Tap "New Test" to create the first test for this subject.',
                minWidth: 500,
                columns: [
                  AdminColumn<TestRow>(
                    label: 'TITLE',
                    flex: 4,
                    cell: (_, row) => Text(
                      row.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AdminColumn<TestRow>(
                    label: 'TYPE',
                    width: 90,
                    cell: (_, row) => _Chip(label: row.type, color: row.typeColor),
                  ),
                  AdminColumn<TestRow>(
                    label: 'GRADE',
                    width: 60,
                    numeric: true,
                    cell: (_, row) => Text(
                      row.grade != null ? 'G${row.grade}' : '—',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  AdminColumn<TestRow>(
                    label: 'TIME',
                    width: 70,
                    numeric: true,
                    cell: (_, row) => Text(
                      row.isUntimed ? '∞' : '${row.time}m',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  AdminColumn<TestRow>(
                    label: 'QS',
                    width: 52,
                    numeric: true,
                    cell: (_, row) => Text(
                      '${row.questionCount}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                rowActions: (ctx, row) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit test',
                      icon: const Icon(Iconsax.edit, size: AppSizes.iconSm),
                      onPressed: () => _openTest(ctx, subject.id, subject.name, testId: row.id),
                    ),
                    IconButton(
                      tooltip: 'Delete test',
                      icon: const Icon(Iconsax.trash, size: AppSizes.iconSm, color: AppColors.error),
                      onPressed: () => _confirmDelete(ctx, row),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _confirmDelete(BuildContext context, TestRow row) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete test?'),
        content: Text(
          '"${row.title}" and all its ${row.questionCount} question(s) will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Get.back();
              controller.deleteTest(row.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

