import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

// ── Controller ───────────────────────────────────────────────────────

class ContentController extends GetxController {
  static ContentController get instance => Get.find();

  final _sb = Supabase.instance.client;

  final allSubjects = <SubjectRow>[].obs;
  final filteredSubjects = <SubjectRow>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final searchController = TextEditingController();
  final streamFilter = RxnString();

  int get totalSubjects => allSubjects.length;
  int get naturalCount => allSubjects.where((s) => s.isNatural && !s.isCommon).length;
  int get socialCount => allSubjects.where((s) => !s.isNatural && !s.isCommon).length;
  int get commonCount => allSubjects.where((s) => s.isCommon).length;
  int get totalTests => allSubjects.fold(0, (sum, s) => sum + s.testCount);
  int get totalQuestions => allSubjects.fold(0, (sum, s) => sum + s.questionCount);

  @override
  void onInit() {
    super.onInit();
    loadSubjects();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
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
      allSubjects.value = result;
      _applyFilters();
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String _) => _applyFilters();

  void setStreamFilter(String? stream) {
    streamFilter.value = stream;
    _applyFilters();
  }

  void _applyFilters() {
    final query = searchController.text.trim().toLowerCase();
    final stream = streamFilter.value;

    filteredSubjects.value = allSubjects.where((s) {
      final matchesQuery = query.isEmpty || s.name.toLowerCase().contains(query);
      final matchesStream = stream == null ||
          (stream == 'Natural' && s.isNatural) ||
          (stream == 'Social' && !s.isNatural && !s.isCommon) ||
          (stream == 'Common' && s.isCommon);
      return matchesQuery && matchesStream;
    }).toList();
  }
}

// ── Screen ───────────────────────────────────────────────────────────

class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ContentController());

    return AdminScaffold(
      pageIndex: AdminNavPage.content,
      onRefresh: controller.loadSubjects,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContentMetricRibbon(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          _ContentFilterBar(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Expanded(child: _SubjectsPanel(controller: controller)),
        ],
      ),
    );
  }
}

// ── 1. Metrics Ribbon ──────────────────────────────────────────────────────

class _ContentMetricRibbon extends StatelessWidget {
  const _ContentMetricRibbon({required this.controller});

  final ContentController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Obx(() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ContentMetricCard(
              label: 'Subjects',
              value: '${controller.totalSubjects}',
              icon: Iconsax.book_copy,
              color: AppColors.primary,
              dark: dark,
            ),
            const SizedBox(width: 8),
            _ContentMetricCard(
              label: 'Natural Stream',
              value: '${controller.naturalCount}',
              icon: Icons.science_rounded,
              color: AppColors.success,
              dark: dark,
            ),
            const SizedBox(width: 8),
            _ContentMetricCard(
              label: 'Social Stream',
              value: '${controller.socialCount}',
              icon: Icons.menu_book_rounded,
              color: AppColors.warning,
              dark: dark,
            ),
            const SizedBox(width: 8),
            _ContentMetricCard(
              label: 'Total Tests',
              value: NumberFormat('#,##0').format(controller.totalTests),
              icon: Iconsax.clipboard_text_copy,
              color: AppColors.info,
              dark: dark,
            ),
            const SizedBox(width: 8),
            _ContentReportsCard(dark: dark),
            const SizedBox(width: 8),
            _ContentMetricCard(
              label: 'Total Questions',
              value: NumberFormat('#,##0').format(controller.totalQuestions),
              icon: Iconsax.document_text_copy,
              color: AppColors.primary,
              dark: dark,
            ),
          ],
        ),
      );
    });
  }
}

class _ContentMetricCard extends StatelessWidget {
  const _ContentMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.dark,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: dark ? AppColors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Filter Bar (Fully Responsive) ───────────────────────────────────────

class _ContentFilterBar extends StatelessWidget {
  const _ContentFilterBar({required this.controller});

  final ContentController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: AppSizes.xs),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 580;

          final searchInput = Container(
            height: 36,
            decoration: BoxDecoration(
              color: dark
                  ? AppColors.darkGrey.withValues(alpha: 0.3)
                  : AppColors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
            ),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.onSearchChanged,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search subjects...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
                prefixIcon: const Icon(
                  Iconsax.search_normal_copy,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller.searchController,
                  builder: (_, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        controller.searchController.clear();
                        controller.onSearchChanged('');
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          );

          final streamDropdown = Obx(
            () => Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkSurface : AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: isNarrow,
                  value: controller.streamFilter.value,
                  isDense: true,
                  hint: const Text('All Streams', style: TextStyle(fontSize: 12)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Streams', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Natural', child: Text('Natural', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Social', child: Text('Social', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Common', child: Text('Common', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: controller.setStreamFilter,
                ),
              ),
            ),
          );

          final refreshBtn = IconButton(
            tooltip: 'Refresh Content',
            visualDensity: VisualDensity.compact,
            onPressed: controller.loadSubjects,
            icon: const Icon(Icons.refresh_rounded, size: AppSizes.iconSm),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchInput,
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: streamDropdown),
                    const SizedBox(width: AppSizes.xs),
                    refreshBtn,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchInput),
              const SizedBox(width: AppSizes.sm),
              streamDropdown,
              const SizedBox(width: AppSizes.xs),
              refreshBtn,
            ],
          );
        },
      ),
    );
  }
}

// ── 3. Subjects Panel ──────────────────────────────────────────────────────

class _SubjectsPanel extends StatelessWidget {
  const _SubjectsPanel({required this.controller});
  final ContentController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AdminDataTable<SubjectRow>(
        rows: controller.filteredSubjects.toList(),
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.loadSubjects,
        onRefresh: controller.loadSubjects,
        emptyTitle: 'No subjects found',
        emptyMessage: 'Try adjusting your search query or stream filters.',
        minWidth: 620,
        columns: [
          AdminColumn<SubjectRow>(
            label: 'SUBJECT',
            flex: 3,
            cell: (_, row) => _SubjectNameCell(row: row),
          ),
          AdminColumn<SubjectRow>(
            label: 'STREAM',
            width: 100,
            cell: (_, row) => _SubjectStreamBadge(row: row),
          ),
          AdminColumn<SubjectRow>(
            label: 'TESTS',
            width: 85,
            numeric: true,
            cell: (_, row) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${row.testCount} tests',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ),
          ),
          AdminColumn<SubjectRow>(
            label: 'QUESTIONS',
            width: 90,
            numeric: true,
            cell: (_, row) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${row.questionCount} Qs',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
        rowActions: (context, subject) => IconButton(
          tooltip: 'Manage Tests',
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Get.toNamed(
              AdminRoutes.contentSubject,
              arguments: {'subject': subject},
            );
          },
        ),
        onRowTap: (subject) {
          FocusManager.instance.primaryFocus?.unfocus();
          Get.toNamed(
            AdminRoutes.contentSubject,
            arguments: {'subject': subject},
          );
        },
      ),
    );
  }
}

class _SubjectNameCell extends StatelessWidget {
  const _SubjectNameCell({required this.row});
  final SubjectRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          ),
          child: const Icon(
            Iconsax.book_1_copy,
            size: 15,
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
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${row.chapterCount} chapters',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectStreamBadge extends StatelessWidget {
  const _SubjectStreamBadge({required this.row});
  final SubjectRow row;

  @override
  Widget build(BuildContext context) {
    final color = row.isCommon
        ? AppColors.info
        : row.isNatural
            ? AppColors.success
            : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        row.streamLabel,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
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

class _ContentReportsCard extends StatelessWidget {
  const _ContentReportsCard({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (Get.isRegistered<AdminNavController>()) {
            AdminNavController.instance.changePage(AdminNavPage.reportedQuestions);
          } else {
            Get.toNamed(AdminRoutes.questionReports);
          }
        },
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: dark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.flag_copy, size: 18, color: AppColors.error),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Question Reports',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                Text(
                  'Review student feedback',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.error),
          ],
        ),
      ),
    ),
  );
}
}
