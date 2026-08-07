import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/data/repositories/content_repository.dart';
import 'package:m_admin/features/content/screens/content_screen.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

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

class SubjectTestsController extends GetxController {
  SubjectTestsController({required this.subject});

  final SubjectRow subject;
  final _repo = ContentRepository();

  final tests = <TestRow>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadTests();
  }

  Future<void> loadTests() async {
    try {
      isLoading.value = true;
      error.value = null;
      final rows = await _repo.fetchTestsForSubject(subject.id);
      tests.value = rows.map(TestRow.fromJson).toList();
    } catch (e) {
      error.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteTest(int testId) async {
    try {
      await _repo.deleteTest(testId);
      await loadTests();
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

class SubjectTestsScreen extends StatelessWidget {
  const SubjectTestsScreen({super.key, required this.subject});
  final SubjectRow subject;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      SubjectTestsController(subject: subject),
      tag: 'subject_tests_${subject.id}',
    );

    void openTest(int? testId) {
      Get.toNamed(
        AdminRoutes.contentTest,
        arguments: {
          'subject_id': subject.id,
          'subject_name': subject.name,
          if (testId != null) 'test_id': testId,
        },
      )?.then((_) => controller.loadTests());
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subject.name, overflow: TextOverflow.ellipsis),
            Text(
              '${subject.testCount} tests · ${subject.questionCount} questions',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.md),
            child: FilledButton.icon(
              onPressed: () => openTest(null),
              icon: const Icon(Icons.add_rounded, size: AppSizes.iconSm),
              label: const Text('New Test'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Obx(
          () => AdminDataTable<TestRow>(
            rows: controller.tests.toList(),
            isLoading: controller.isLoading.value,
            error: controller.error.value,
            onRetry: controller.loadTests,
            emptyTitle: 'No tests yet',
            emptyMessage:
                'Tap "New Test" to create the first test for this subject.',
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
                cell: (_, row) =>
                    _Chip(label: row.type, color: row.typeColor),
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
                  onPressed: () => openTest(row.id),
                ),
                IconButton(
                  tooltip: 'Delete test',
                  icon: const Icon(
                    Iconsax.trash,
                    size: AppSizes.iconSm,
                    color: AppColors.error,
                  ),
                  onPressed: () => _confirmDelete(ctx, row, controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    TestRow row,
    SubjectTestsController controller,
  ) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete test?'),
        content: Text(
          '"${row.title}" and all its ${row.questionCount} question(s) '
          'will be permanently deleted.',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
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

// ── Badge chip ────────────────────────────────────────────────────────

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
