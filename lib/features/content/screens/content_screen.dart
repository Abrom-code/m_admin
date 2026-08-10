import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

// ── Controller ───────────────────────────────────────────────────────

class ContentController extends GetxController {
  static ContentController get instance => Get.find();

  final _sb = Supabase.instance.client;

  final subjects = <SubjectRow>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

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
}

// ── Screen ───────────────────────────────────────────────────────────

class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ContentController());

    return AdminScaffold(
      pageIndex: 4,
      onRefresh: controller.loadSubjects,
      scrollable: false,
      body: _SubjectsPanel(controller: controller),
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
        onRefresh: controller.loadSubjects,
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
        onRowTap: (subject) => Get.toNamed(
          AdminRoutes.contentSubject,
          arguments: {'subject': subject},
        ),
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

// ── Model ─────────────────────────────────────────────────────────────

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
