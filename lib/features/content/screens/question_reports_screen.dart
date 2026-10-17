import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

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

    final String? idLabel = group.questionId != null
        ? 'ID: #${group.questionId}'
        : (group.challengeQuestionId != null
            ? (group.challengeQuestionId!.length > 8
                ? 'ID: #${group.challengeQuestionId!.substring(0, 8)}'
                : 'ID: #${group.challengeQuestionId}')
            : null);

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
                // Question ID Badge (Copiable)
                if (idLabel != null) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final rawId = group.questionId?.toString() ?? group.challengeQuestionId?.toString() ?? '';
                        if (rawId.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: rawId));
                          SnackbarHelper.success('Copied', 'Question ID "$rawId" copied to clipboard.');
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Tooltip(
                        message: 'Click to copy ID',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: dark ? AppColors.darkCard : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: dark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Text(
                            idLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: dark ? AppColors.white : const Color(0xFF334155),
                            ),
                          ),
                        ),
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
class _QuestionReportDetailDialog extends StatefulWidget {
  const _QuestionReportDetailDialog({
    required this.group,
    required this.controller,
    required this.dark,
  });

  final QuestionReportGroupModel group;
  final QuestionReportsController controller;
  final bool dark;

  @override
  State<_QuestionReportDetailDialog> createState() => _QuestionReportDetailDialogState();
}

class _QuestionReportDetailDialogState extends State<_QuestionReportDetailDialog> {
  late QuestionReportGroupModel _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditReportedQuestionDialog(
        group: _group,
        controller: widget.controller,
        dark: widget.dark,
      ),
    );

    if (updated == true && mounted) {
      final currentGroups = widget.controller.groupedReports;
      final updatedGroup = currentGroups.firstWhereOrNull(
        (g) => g.targetKey == _group.targetKey,
      );
      if (updatedGroup != null) {
        setState(() {
          _group = updatedGroup;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final group = _group;
    final count = group.reportCount;
    final isMultiple = count > 1;

    final hasEn = group.explanationEn != null && group.explanationEn!.trim().isNotEmpty;
    final hasAm = group.explanationAm != null && group.explanationAm!.trim().isNotEmpty;
    final fallbackExpl = group.explanation != null && group.explanation!.trim().isNotEmpty;

    final choicesList = (group.options != null && group.options!.isNotEmpty)
        ? group.options!
        : [
            if (group.choiceA != null) group.choiceA!,
            if (group.choiceB != null) group.choiceB!,
            if (group.choiceC != null) group.choiceC!,
            if (group.choiceD != null) group.choiceD!,
          ];

    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 860),
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
                        if (group.questionId != null)
                          _TagChip(
                            text: 'ID: #${group.questionId}',
                            color: const Color(0xFF64748B),
                            icon: Icons.tag_rounded,
                            trailingIcon: Icons.copy_rounded,
                            copyableText: '${group.questionId}',
                            tooltip: 'Click to copy ID (${group.questionId})',
                          ),
                        if (group.challengeQuestionId != null)
                          _TagChip(
                            text: 'ID: #${group.challengeQuestionId!.length > 8 ? group.challengeQuestionId!.substring(0, 8) : group.challengeQuestionId}',
                            color: const Color(0xFF64748B),
                            icon: Icons.tag_rounded,
                            trailingIcon: Icons.copy_rounded,
                            copyableText: group.challengeQuestionId,
                            tooltip: 'Click to copy ID (${group.challengeQuestionId})',
                          ),
                        if (group.subjectName != null)
                          _TagChip(text: group.subjectName!, color: AppColors.primary, icon: Iconsax.book_1_copy),
                        if (group.formattedGrade != null)
                          _TagChip(text: group.formattedGrade!, color: const Color(0xFF6366F1), icon: Iconsax.teacher_copy),
                        if (group.formattedChapter != null)
                          _TagChip(text: group.formattedChapter!, color: const Color(0xFF0D9488), icon: Iconsax.folder_2_copy),
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
                    // ── Question Details Card (Subject, Chapter, Grade, Context) ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(
                          color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Iconsax.info_circle_copy, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'QUESTION CONTEXT & METADATA',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              if (group.questionOrder != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Q# ${group.questionOrder}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (group.questionId != null)
                                _TagChip(
                                  text: 'Question ID: #${group.questionId}',
                                  color: AppColors.primary,
                                  icon: Icons.tag_rounded,
                                  trailingIcon: Icons.copy_rounded,
                                  copyableText: '${group.questionId}',
                                  tooltip: 'Click to copy Question ID (${group.questionId})',
                                ),
                              if (group.challengeQuestionId != null)
                                _TagChip(
                                  text: 'Question ID: #${group.challengeQuestionId}',
                                  color: AppColors.primary,
                                  icon: Icons.tag_rounded,
                                  trailingIcon: Icons.copy_rounded,
                                  copyableText: group.challengeQuestionId,
                                  tooltip: 'Click to copy Question ID (${group.challengeQuestionId})',
                                  maxWidth: 240,
                                ),
                              if (group.subjectName != null)
                                _TagChip(
                                  text: group.subjectName!,
                                  color: AppColors.primary,
                                  icon: Iconsax.book_1_copy,
                                ),
                              if (group.formattedGrade != null)
                                _TagChip(
                                  text: group.formattedGrade!,
                                  color: const Color(0xFF6366F1),
                                  icon: Iconsax.teacher_copy,
                                ),
                              if (group.formattedChapter != null)
                                _TagChip(
                                  text: group.formattedChapter!,
                                  color: const Color(0xFF0D9488),
                                  icon: Iconsax.folder_2_copy,
                                ),
                              if (group.contextTitle != null)
                                _TagChip(
                                  text: group.contextTitle!,
                                  color: dark ? AppColors.darkGrey : const Color(0xFF475569),
                                  icon: Iconsax.document_text_copy,
                                ),
                              _TagChip(
                                text: group.isChallenge ? 'Challenge Question' : 'Standard Test Question',
                                color: group.isChallenge ? Colors.amber[800]! : Colors.blueGrey,
                                icon: Iconsax.category_copy,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Attached Question Image (if present) ──
                    if (group.imageUrl != null && group.imageUrl!.trim().isNotEmpty) ...[
                      const Text(
                        'ATTACHED QUESTION IMAGE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            group.imageUrl!.trim(),
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 120,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              );
                            },
                            errorBuilder: (_, _, _) => Container(
                              height: 80,
                              color: AppColors.error.withValues(alpha: 0.08),
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image_rounded, size: 20, color: AppColors.error),
                                    SizedBox(width: 8),
                                    Text(
                                      'Failed to load question image from URL',
                                      style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Question text
                    const Text(
                      'QUESTION TEXT',
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
                    if (choicesList.isNotEmpty) ...[
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
                      for (int i = 0; i < choicesList.length; i++) ...[
                        _ChoicePreviewRow(
                          letter: String.fromCharCode(65 + i),
                          text: choicesList[i],
                          isCorrect: group.correctChoice == String.fromCharCode(65 + i),
                          dark: dark,
                        ),
                      ],
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

                      // Explanation image preview
                      if (group.explanationImageUrl != null && group.explanationImageUrl!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              group.explanationImageUrl!.trim(),
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
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
                                        '• ${DateFormat('d MMM, HH:mm').format(report.createdAt!)} EAT',
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
                  ElevatedButton.icon(
                    onPressed: () => _openEditDialog(context),
                    icon: const Icon(Iconsax.edit_2_copy, size: 14),
                    label: const Text('Edit Question', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
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
                      icon: const Icon(Iconsax.document_copy, size: 14),
                      label: const Text('Open in Test Editor', style: TextStyle(fontSize: 12)),
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
    final count = _group.reportCount;
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
              widget.controller.fixAndRemoveQuestionGroup(_group);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Confirm & Delete from DB'),
          ),
        ],
      ),
    );
  }
}

/// ── Question Editor Dialog: Allows directly editing the reported question ──
class _EditReportedQuestionDialog extends StatefulWidget {
  const _EditReportedQuestionDialog({
    required this.group,
    required this.controller,
    required this.dark,
  });

  final QuestionReportGroupModel group;
  final QuestionReportsController controller;
  final bool dark;

  @override
  State<_EditReportedQuestionDialog> createState() => _EditReportedQuestionDialogState();
}

class _EditReportedQuestionDialogState extends State<_EditReportedQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionTextCtrl;
  late final TextEditingController _explanationEnCtrl;
  late final TextEditingController _explanationAmCtrl;
  late final TextEditingController _gradeCtrl;
  late final TextEditingController _imageUrlCtrl;
  final List<TextEditingController> _optionCtrls = [];
  String _correctChoice = 'A';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _questionTextCtrl = TextEditingController(text: g.questionText);
    _explanationEnCtrl = TextEditingController(text: g.explanationEn ?? '');
    _explanationAmCtrl = TextEditingController(text: g.explanationAm ?? '');
    _gradeCtrl = TextEditingController(text: g.grade != null && g.grade! > 0 ? '${g.grade}' : '');
    _imageUrlCtrl = TextEditingController(text: g.imageUrl ?? '');

    List<String> initialOptions = [];
    if (g.options != null && g.options!.isNotEmpty) {
      initialOptions = List<String>.from(g.options!);
    } else {
      if (g.choiceA != null) initialOptions.add(g.choiceA!);
      if (g.choiceB != null) initialOptions.add(g.choiceB!);
      if (g.choiceC != null) initialOptions.add(g.choiceC!);
      if (g.choiceD != null) initialOptions.add(g.choiceD!);
    }

    if (initialOptions.isEmpty) {
      initialOptions = ['', '', '', ''];
    } else {
      while (initialOptions.length < 2) {
        initialOptions.add('');
      }
    }

    for (final opt in initialOptions) {
      _optionCtrls.add(TextEditingController(text: opt));
    }

    _correctChoice = (g.correctChoice != null && g.correctChoice!.isNotEmpty)
        ? g.correctChoice!.toUpperCase()
        : 'A';
  }

  @override
  void dispose() {
    _questionTextCtrl.dispose();
    _explanationEnCtrl.dispose();
    _explanationAmCtrl.dispose();
    _gradeCtrl.dispose();
    _imageUrlCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length >= 6) return;
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) return;
    final ctrl = _optionCtrls.removeAt(index);
    ctrl.dispose();
    final letter = String.fromCharCode(65 + index);
    if (_correctChoice == letter || (_correctChoice.codeUnitAt(0) - 65) >= _optionCtrls.length) {
      _correctChoice = 'A';
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final options = _optionCtrls.map((c) => c.text.trim()).toList();
    if (options.any((o) => o.isEmpty)) {
      SnackbarHelper.warning('Incomplete Options', 'All option choices must have text.');
      return;
    }

    setState(() => _isSaving = true);

    final grade = int.tryParse(_gradeCtrl.text.trim());
    final imgUrl = _imageUrlCtrl.text.trim();

    final ok = await widget.controller.editAndSaveQuestion(
      group: widget.group,
      questionText: _questionTextCtrl.text.trim(),
      options: options,
      correctChoice: _correctChoice,
      explanationEn: _explanationEnCtrl.text.trim(),
      explanationAm: _explanationAmCtrl.text.trim(),
      grade: grade,
      imageUrl: imgUrl.isNotEmpty ? imgUrl : null,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;
    final group = widget.group;

    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 860),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.edit_2_copy, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Reported Question',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (group.subjectName != null)
                              _TagChip(text: group.subjectName!, color: AppColors.primary),
                            if (group.formattedGrade != null)
                              _TagChip(text: group.formattedGrade!, color: const Color(0xFF6366F1)),
                            if (group.formattedChapter != null)
                              _TagChip(text: group.formattedChapter!, color: const Color(0xFF0D9488)),
                            if (group.contextTitle != null)
                              _TagChip(text: group.contextTitle!, color: AppColors.textSecondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Text
                      const Text(
                        'QUESTION TEXT *',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _questionTextCtrl,
                        minLines: 3,
                        maxLines: 7,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Question text is required.' : null,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter question text...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          filled: true,
                          fillColor: dark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Choices / Options Header
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ANSWER CHOICES *',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tap a letter to set it as the correct answer',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (_optionCtrls.length < 6)
                            TextButton.icon(
                              onPressed: _addOption,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Option', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Options List
                      for (int i = 0; i < _optionCtrls.length; i++) ...[
                        _buildOptionRow(i, dark, borderColor),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 14),

                      // Explanations Section
                      const Text(
                        'EXPLANATIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // English Explanation
                      TextFormField(
                        controller: _explanationEnCtrl,
                        minLines: 2,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'English Explanation',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 30),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          filled: true,
                          fillColor: dark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Amharic Explanation
                      TextFormField(
                        controller: _explanationAmCtrl,
                        minLines: 2,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          labelText: 'Amharic Explanation (የማብራሪያ ጽሁፍ)',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 30),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          filled: true,
                          fillColor: dark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Additional details: Grade & Image URL
                      Row(
                        children: [
                          SizedBox(
                            width: 140,
                            child: TextFormField(
                              controller: _gradeCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                labelText: 'Grade',
                                hintText: '9-12',
                                prefixIcon: const Icon(Iconsax.teacher_copy, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                filled: true,
                                fillColor: dark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _imageUrlCtrl,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                labelText: 'Question Image URL (optional)',
                                prefixIcon: const Icon(Iconsax.image_copy, size: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                filled: true,
                                fillColor: dark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(int index, bool dark, Color borderColor) {
    final letter = String.fromCharCode(65 + index);
    final isCorrect = _correctChoice == letter;

    return Row(
      children: [
        // Correct Selector Button
        InkWell(
          onTap: () => setState(() => _correctChoice = letter),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCorrect
                  ? AppColors.success
                  : (dark ? AppColors.darkSurface : AppColors.softGrey),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCorrect ? AppColors.success : borderColor,
                width: isCorrect ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    letter,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? Colors.white : (dark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  if (isCorrect) ...[
                    const SizedBox(width: 2),
                    const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Option text field
        Expanded(
          child: TextFormField(
            controller: _optionCtrls[index],
            style: const TextStyle(fontSize: 12.5),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Option $letter text...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isCorrect ? AppColors.success : borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isCorrect ? AppColors.success : borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isCorrect ? AppColors.success : AppColors.primary,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: isCorrect
                  ? AppColors.success.withValues(alpha: 0.05)
                  : (dark ? AppColors.darkSurface : const Color(0xFFF8FAFC)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),

        // Remove button
        if (_optionCtrls.length > 2) ...[
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _removeOption(index),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.error,
            tooltip: 'Remove Option $letter',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.color,
    this.icon,
    this.trailingIcon,
    this.copyableText,
    this.tooltip,
    this.maxWidth = 280,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final IconData? trailingIcon;
  final String? copyableText;
  final String? tooltip;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = copyableText != null && copyableText!.isNotEmpty
        ? () {
            Clipboard.setData(ClipboardData(text: copyableText!));
            SnackbarHelper.success('Copied', 'Question ID "$copyableText" copied to clipboard.');
          }
        : null;

    Widget chipContent = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 10.5, color: color),
          ],
        ],
      ),
    );

    if (effectiveOnTap != null) {
      chipContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: BorderRadius.circular(4),
          child: chipContent,
        ),
      );
    }

    final message = tooltip ??
        (copyableText != null
            ? 'Click to copy: $copyableText'
            : (text.length > 28 ? text : null));

    if (message != null) {
      return Tooltip(
        message: message,
        child: chipContent,
      );
    }

    return chipContent;
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

