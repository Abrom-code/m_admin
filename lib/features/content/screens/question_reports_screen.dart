import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
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

    return AdminScaffold(
      pageIndex: 4,
      onRefresh: () async {
        await controller.loadReports();
        await controller.loadPendingCount();
      },
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar ──────────────────────────────────────────
          _HeaderBar(controller: controller, dark: dark),
          const SizedBox(height: AppSizes.spaceBtwItems),

          // ── Filter & Search Bar ──────────────────────────────────
          _FilterSearchBar(controller: controller, dark: dark),
          const SizedBox(height: AppSizes.spaceBtwItems),

          // ── Reports List ─────────────────────────────────────────
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

              if (controller.reports.isEmpty) {
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
                itemCount: controller.reports.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final report = controller.reports[i];
                  return _QuestionReportCard(
                    report: report,
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
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Question Reports',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Obx(() {
                    final p = controller.pendingCount.value;
                    if (p <= 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$p PENDING',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Review and resolve student error reports on questions and choices.',
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                ),
              ),
            ],
          ),
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

          // Search Field
          Container(
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
              style: const TextStyle(fontSize: 12.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search by question, student name, or comment...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                prefixIcon: Icon(Iconsax.search_normal_copy, size: 16, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
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
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white,
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

class _QuestionReportCard extends StatelessWidget {
  const _QuestionReportCard({
    required this.report,
    required this.controller,
    required this.dark,
  });

  final QuestionReportAdminModel report;
  final QuestionReportsController controller;
  final bool dark;

  Color _reasonColor() {
    switch (report.reason) {
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
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;
    final rColor = _reasonColor();

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Header Row ──────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  report.reasonLabel.toUpperCase(),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: rColor),
                ),
              ),
              const SizedBox(width: 8),
              if (report.subjectName != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    report.subjectName!,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              if (report.createdAt != null)
                Text(
                  DateFormat('d MMM yyyy · HH:mm').format(report.createdAt!),
                  style: TextStyle(
                    fontSize: 11,
                    color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Student Feedback / Comment Box ──────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.user_copy, size: 14, color: dark ? AppColors.darkGrey : AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Reported by: ${report.userName} (${report.userEmail})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (report.comment != null && report.comment!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '“${report.comment}”',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: dark ? Colors.amber[200] : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Question Preview ────────────────────────────────────
          Text(
            report.testTitle != null ? 'Test: ${report.testTitle}' : 'Question Preview:',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            report.questionText,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 10),

          // Choices Preview
          if (report.choiceA != null) ...[
            _ChoicePreviewRow(letter: 'A', text: report.choiceA!, isCorrect: report.correctChoice == 'A', dark: dark),
            _ChoicePreviewRow(letter: 'B', text: report.choiceB!, isCorrect: report.correctChoice == 'B', dark: dark),
            if (report.choiceC != null)
              _ChoicePreviewRow(letter: 'C', text: report.choiceC!, isCorrect: report.correctChoice == 'C', dark: dark),
            if (report.choiceD != null)
              _ChoicePreviewRow(letter: 'D', text: report.choiceD!, isCorrect: report.correctChoice == 'D', dark: dark),
            const SizedBox(height: 8),
          ],

          if (report.explanation != null && report.explanation!.isNotEmpty) ...[
            Text(
              'Explanation: ${report.explanation}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: dark ? AppColors.darkGrey : AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
          ],

          // ── Resolution Notes if already resolved ────────────────
          if (!report.isPending && report.adminNotes != null && report.adminNotes!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (report.isResolved ? AppColors.success : AppColors.darkGrey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Admin Note: ${report.adminNotes}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: report.isResolved ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Actions Row ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (report.testId != null && report.subjectId != null) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Get.to(() => TestEditorScreen(
                          subjectId: report.subjectId!,
                          testId: report.testId,
                          subjectName: report.subjectName ?? '',
                        ));
                  },
                  icon: const Icon(Iconsax.edit_2_copy, size: 14),
                  label: const Text('Edit Test Questions', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (report.isPending) ...[
                OutlinedButton(
                  onPressed: () => _showActionDialog(
                    context,
                    title: 'Dismiss Report?',
                    confirmLabel: 'Dismiss',
                    confirmColor: AppColors.darkGrey,
                    onConfirm: (note) => controller.dismissReport(report, notes: note),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Dismiss', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showActionDialog(
                    context,
                    title: 'Resolve Question Report?',
                    confirmLabel: 'Mark Resolved',
                    confirmColor: AppColors.success,
                    onConfirm: (note) => controller.resolveReport(report, notes: note),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 14),
                  label: const Text('Resolve', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showActionDialog(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required Color confirmColor,
    required ValueChanged<String?> onConfirm,
  }) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add optional notes explaining what was fixed or why it was dismissed:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'e.g. Corrected choice B in question editor',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
            child: Text(confirmLabel),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
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
