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
        return AppColors.info;
      case 'model':
        return AppColors.success;
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
      type: j['type']?.toString() ?? '',
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
    final dark = AppHelperFunctions.isDark(context);
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
          'test_id': testId,
        },
      )?.then((_) => controller.loadTests());
    }

    return Scaffold(
      backgroundColor: dark ? AppColors.dark : AppColors.light,
      appBar: AppBar(
        backgroundColor: dark ? AppColors.darkSurface : AppColors.white,
        title: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    subject.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Obx(
                    () => Text(
                      '${controller.tests.length} tests · ${controller.tests.fold(0, (sum, t) => sum + t.questionCount)} questions',
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
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = MediaQuery.sizeOf(context).width < 500;

                if (isCompact) {
                  return IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () => openTest(null),
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    tooltip: 'Create Test',
                  );
                }

                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => openTest(null),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Create Test',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              },
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
            emptyTitle: 'No tests found',
            emptyMessage: 'Tap "Create Test" to add the first test for ${subject.name}.',
            minWidth: 680,
            columns: [
              AdminColumn<TestRow>(
                label: 'TEST TITLE',
                flex: 4,
                cell: (_, row) => Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: row.typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Iconsax.clipboard_text_copy,
                        size: 14,
                        color: row.typeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            row.title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (row.description != null &&
                              row.description!.trim().isNotEmpty)
                            Text(
                              row.description!.trim(),
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
                  ],
                ),
              ),
              AdminColumn<TestRow>(
                label: 'ACCESS',
                width: 75,
                cell: (_, row) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: row.isPremium
                        ? Colors.amber.withValues(alpha: 0.12)
                        : AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: row.isPremium
                          ? Colors.amber.withValues(alpha: 0.3)
                          : AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    row.isPremium ? 'PRO' : 'FREE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: row.isPremium ? Colors.amber[800] : AppColors.success,
                    ),
                  ),
                ),
              ),
              AdminColumn<TestRow>(
                label: 'ACCESS',
                width: 75,
                cell: (_, row) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: row.isPremium
                        ? Colors.amber.withValues(alpha: 0.12)
                        : AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: row.isPremium
                          ? Colors.amber.withValues(alpha: 0.3)
                          : AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    row.isPremium ? 'PRO' : 'FREE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: row.isPremium ? Colors.amber[800] : AppColors.success,
                    ),
                  ),
                ),
              ),
              AdminColumn<TestRow>(
                label: 'TYPE',
                width: 95,
                cell: (_, row) => _TestTypeChip(label: row.type, color: row.typeColor),
              ),
              AdminColumn<TestRow>(
                label: 'GRADE',
                width: 65,
                numeric: true,
                cell: (_, row) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    row.grade != null ? 'G${row.grade}' : '—',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              AdminColumn<TestRow>(
                label: 'TIME LIMIT',
                width: 95,
                numeric: true,
                cell: (_, row) => Text(
                  row.isUntimed ? 'Untimed (∞)' : '${row.time}m',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
              AdminColumn<TestRow>(
                label: 'QUESTIONS',
                width: 90,
                numeric: true,
                cell: (_, row) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${row.questionCount} Qs',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
            rowActions: (ctx, row) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit Test',
                  icon: const Icon(Iconsax.edit_2_copy, size: 16),
                  onPressed: () => openTest(row.id),
                ),
                IconButton(
                  tooltip: 'Delete Test',
                  icon: const Icon(
                    Iconsax.trash_copy,
                    size: 16,
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
        title: const Text('Delete Test?'),
        content: Text(
          'Are you sure you want to delete "${row.title}" and all its ${row.questionCount} question(s)? '
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
}

// ── Badge chip ────────────────────────────────────────────────────────

class _TestTypeChip extends StatelessWidget {
  const _TestTypeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
