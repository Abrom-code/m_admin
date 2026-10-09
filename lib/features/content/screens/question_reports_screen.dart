import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/features/content/controllers/question_reports_controller.dart';
import 'package:m_admin/features/content/models/question_report_admin_model.dart';
import 'package:m_admin/features/content/screens/test_editor_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class QuestionReportsScreen extends StatelessWidget {
  const QuestionReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(QuestionReportsController());
    final dark = AppHelperFunctions.isDark(context);
    final canPop = Navigator.of(context).canPop();

    final content = AdminScaffold(
      pageIndex: AdminNavPage.reportedQuestions,
      onRefresh: () async {
        await controller.loadReports();
        await controller.loadPendingCount();
      },
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar (only if opened as a push route with back button) ──
          if (canPop) ...[
            _HeaderBar(controller: controller, dark: dark),
            const SizedBox(height: AppSizes.xs),
          ],

          // ── Filter & Search Bar ──────────────────────────────────
          _FilterSearchBar(controller: controller, dark: dark),
          const SizedBox(height: AppSizes.spaceBtwItems),

          // ── Reports List (One-line questions with report count) ───
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.errorMessage.value != null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(
                        controller.errorMessage.value!,
                        style: const TextStyle(fontSize: 13, color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: controller.loadReports,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final groups = controller.groupedReports;

              if (groups.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 28, color: AppColors.success),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No Question Reports Found',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        controller.selectedStatus.value == 'pending'
                            ? 'All caught up! No pending question errors reported by students.'
                            : 'No reports found matching the selected filter criteria.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final group = groups[i];
                  return _QuestionReportRowItem(
                    group: group,
                    controller: controller,
                    dark: dark,
                  );
                },
              );
            }),
          ),
        ],
      ),
    );

    if (canPop) {
      return Scaffold(
        backgroundColor: dark ? AppColors.dark : AppColors.light,
        body: SafeArea(child: content),
      );
    }

    return Material(
      color: Colors.transparent,
      child: content,
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.controller, required this.dark});
  final QuestionReportsController controller;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
      ],
    );
  }
}

class _FilterSearchBar extends StatelessWidget {
  const _FilterSearchBar({required this.controller, required this.dark});
  final QuestionReportsController controller;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Obx(() {
              return Row(
                children: [
                  _StatusTab(
                    label: 'Pending',
                    count: controller.pendingCount.value,
                    isSelected: controller.selectedStatus.value == 'pending',
                    onTap: () => controller.changeStatusFilter('pending'),
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  _StatusTab(
                    label: 'Resolved',
                    isSelected: controller.selectedStatus.value == 'resolved',
                    onTap: () => controller.changeStatusFilter('resolved'),
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _StatusTab(
                    label: 'Dismissed',
                    isSelected: controller.selectedStatus.value == 'dismissed',
                    onTap: () => controller.changeStatusFilter('dismissed'),
                    color: AppColors.darkGrey,
                  ),
                  const SizedBox(width: 8),
                  _StatusTab(
                    label: 'All Reports',
                    isSelected: controller.selectedStatus.value == 'all',
                    onTap: () => controller.changeStatusFilter('all'),
                    color: AppColors.primary,
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 10),

          // Search Field + Sort Controls
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final searchField = Container(
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
                    hintText: 'Search by question, student name, or comment...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Iconsax.search_normal_copy, size: 16, color: AppColors.textSecondary),
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

              final sortDropdown = Obx(() => Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurface : AppColors.white,
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: controller.sortBy.value,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                        items: const [
                          DropdownMenuItem(
                            value: 'count_desc',
                            child: Text('Most Reported (Top)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          DropdownMenuItem(
                            value: 'date_desc',
                            child: Text('Newest First', style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: 'date_asc',
                            child: Text('Oldest First', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) controller.changeSortBy(v);
                        },
                      ),
                    ),
                  ));

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    sortDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 8),
                  sortDropdown,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ── One-Line Question Row: Question Text + Number of Reports ──
class _QuestionReportRowItem extends StatelessWidget {
  const _QuestionReportRowItem({
    required this.group,
    required this.controller,
    required this.dark,
  });

  final QuestionReportGroupModel group;
  final QuestionReportsController controller;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;
    final count = group.reportCount;
    final isMultiple = count > 1;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: isMultiple
              ? (dark ? AppColors.error.withValues(alpha: 0.45) : AppColors.error.withValues(alpha: 0.28))
              : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.15 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetailDialog(context),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Subject Tag
                if (group.subjectName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      group.subjectName!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],

                // Question Text (Strictly 1 line with ellipsis)
                Expanded(
                  child: Text(
                    group.questionText.replaceAll(RegExp(r'\s+'), ' ').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dark ? AppColors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Number of reports in the line
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isMultiple
                        ? AppColors.error.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMultiple
                          ? AppColors.error.withValues(alpha: 0.3)
                          : AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.flag_copy,
                        size: 11,
                        color: isMultiple ? AppColors.error : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        count == 1 ? '1 Report' : '$count Reports',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMultiple ? AppColors.error : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Click hint arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _QuestionReportDetailDialog(
        group: group,
        controller: controller,
        dark: dark,
      ),
    );
  }
}

/// ── Full Detail Modal: Triggered upon clicking any question ──
class _QuestionReportDetailDialog extends StatelessWidget {
  const _QuestionReportDetailDialog({
    required this.group,
    required this.controller,
    required this.dark,
  });

  final QuestionReportGroupModel group;
  final QuestionReportsController controller;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final count = group.reportCount;
    final isMultiple = count > 1;

    final hasEn = group.explanationEn != null && group.explanationEn!.trim().isNotEmpty;
    final hasAm = group.explanationAm != null && group.explanationAm!.trim().isNotEmpty;
    final fallbackExpl = group.explanation != null && group.explanation!.trim().isNotEmpty;

    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dialog Header (Overflow-Proof with Wrap) ──────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMultiple
                                ? AppColors.error.withValues(alpha: 0.15)
                                : AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.flag_copy,
                                size: 12,
                                color: isMultiple ? AppColors.error : AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                count == 1 ? '1 STUDENT REPORT' : '$count STUDENT REPORTS',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isMultiple ? AppColors.error : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (group.subjectName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              group.subjectName!,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        if (group.testTitle != null)
                          Text(
                            group.testTitle!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Scrollable Body ───────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    const Text(
                      'QUESTION',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.questionText,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Choices
                    if (group.choiceA != null) ...[
                      const Text(
                        'ANSWER CHOICES',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ChoicePreviewRow(letter: 'A', text: group.choiceA!, isCorrect: group.correctChoice == 'A', dark: dark),
                      _ChoicePreviewRow(letter: 'B', text: group.choiceB!, isCorrect: group.correctChoice == 'B', dark: dark),
                      if (group.choiceC != null)
                        _ChoicePreviewRow(letter: 'C', text: group.choiceC!, isCorrect: group.correctChoice == 'C', dark: dark),
                      if (group.choiceD != null)
                        _ChoicePreviewRow(letter: 'D', text: group.choiceD!, isCorrect: group.correctChoice == 'D', dark: dark),
                      const SizedBox(height: 14),
                    ],

                    // ── Both Explanations (EN & AM) ──────────────────────
                    if (hasEn || hasAm || fallbackExpl) ...[
                      const Text(
                        'EXPLANATIONS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // English Explanation Card
                      if (hasEn)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: dark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'EN',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'English Explanation',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group.explanationEn!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: dark ? AppColors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Amharic Explanation Card
                      if (hasAm)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: dark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'አማ',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Amharic Explanation',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group.explanationAm!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: dark ? AppColors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Fallback single explanation if neither specific was set
                      if (!hasEn && !hasAm && fallbackExpl)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: dark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            group.explanation!,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: dark ? AppColors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],

                    // Student Reports
                    const Text(
                      'STUDENT FEEDBACK & COMMENTS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...group.reports.map((report) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _ReasonBadge(reason: report.reason, label: report.reasonLabel),
                                    Text(
                                      report.userName.isNotEmpty && report.userName != 'Anonymous Student'
                                          ? '${report.userName} (${report.userEmail})'
                                          : report.userEmail,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: dark ? AppColors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                    if (report.createdAt != null)
                                      Text(
                                        '• ${DateFormat('d MMM, HH:mm').format(report.createdAt!)}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                                if (report.comment != null && report.comment!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '“${report.comment}”',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                      color: dark ? Colors.amber[200] : const Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // ── Dialog Footer Actions (Wrap to avoid overflow) ────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  if (group.testId != null && group.subjectId != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.to(() => TestEditorScreen(
                              subjectId: group.subjectId!,
                              testId: group.testId,
                              subjectName: group.subjectName ?? '',
                            ));
                      },
                      icon: const Icon(Iconsax.edit_2_copy, size: 14),
                      label: const Text('Edit in Test Editor', style: TextStyle(fontSize: 12)),
                    ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmFixAndRemove(context);
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 14),
                    label: Text(
                      count > 1 ? 'Fixed (Remove $count from DB)' : 'Fixed (Remove from DB)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmFixAndRemove(BuildContext context) {
    final count = group.reportCount;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Question Fixed & Ready to Remove?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Marking this question as fixed will permanently remove ${count == 1 ? 'this student report' : 'all $count student reports for this question'} from the database.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.fixAndRemoveQuestionGroup(group);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Confirm & Delete from DB'),
          ),
        ],
      ),
    );
  }
}

class _ReasonBadge extends StatelessWidget {
  const _ReasonBadge({required this.reason, required this.label});
  final String reason;
  final String label;

  Color _reasonColor() {
    switch (reason) {
      case 'wrong_answer':
        return AppColors.error;
      case 'typo':
        return AppColors.warning;
      case 'unclear':
        return const Color(0xFF6366F1);
      case 'broken_image':
        return Colors.teal;
      case 'bad_explanation':
        return Colors.deepPurple;
      default:
        return AppColors.darkGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rColor = _reasonColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: rColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rColor),
      ),
    );
  }
}

class _ChoicePreviewRow extends StatelessWidget {
  const _ChoicePreviewRow({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.dark,
  });

  final String letter;
  final String text;
  final bool isCorrect;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isCorrect
                  ? AppColors.success
                  : (dark ? Colors.white12 : Colors.black12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.white : (dark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400,
                color: isCorrect
                    ? AppColors.success
                    : (dark ? AppColors.white : const Color(0xFF1E293B)),
              ),
            ),
          ),
          if (isCorrect) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_rounded, size: 14, color: AppColors.success),
          ],
        ],
      ),
    );
  }
}
