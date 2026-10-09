import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/features/notes/controllers/notes_controller.dart';
import 'package:m_admin/features/notes/models/admin_note_model.dart';
import 'package:m_admin/features/notes/screens/note_pdf_preview_screen.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(NotesController());
    final dark = AppHelperFunctions.isDark(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return AdminScaffold(
      pageIndex: AdminNavPage.notes,
      onRefresh: ctrl.loadNotes,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Stat Summary Ribbon ─────────────────────────────────────────
          Obx(() {
            final all = ctrl.notes;
            final premiumCount = all.where((n) => n.isPremium).length;
            final freeCount = all.length - premiumCount;
            final subjectCount = all.map((n) => n.subjectId).toSet().length;
            final pFilter = ctrl.premiumFilter.value;
            final rFilter = ctrl.ratingFilter.value;
            final needsAttention = ctrl.needsAttentionCount;
            final totalReviews = ctrl.totalStudentReviewsCount;

            return SingleChildScrollView(
              primary: false,
              physics: const ClampingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CompactRibbonCard(
                    label: 'Total Notes',
                    value: NumberFormat('#,##0').format(all.length),
                    dotColor: AppColors.primary,
                    icon: Iconsax.document_copy,
                    isSelected: pFilter == null && rFilter == null,
                    onTap: () {
                      ctrl.setPremiumFilter(null);
                      ctrl.setRatingFilter(null);
                    },
                  ),
                  const SizedBox(width: 8),
                  // High urgency alert card for notes needing attention
                  _CompactRibbonCard(
                    label: 'Needs Review',
                    value: NumberFormat('#,##0').format(needsAttention),
                    dotColor: AppColors.error,
                    icon: Iconsax.warning_2_copy,
                    isSelected: rFilter == 'needs_attention',
                    onTap: () {
                      if (rFilter == 'needs_attention') {
                        ctrl.setRatingFilter(null);
                        ctrl.setSortOption('default');
                      } else {
                        ctrl.setRatingFilter('needs_attention');
                        ctrl.setSortOption('urgency');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // Student Reviews card
                  _CompactRibbonCard(
                    label: 'Student Reviews',
                    value: NumberFormat('#,##0').format(totalReviews),
                    dotColor: const Color(0xFFF59E0B),
                    icon: Iconsax.star_1_copy,
                    isSelected: rFilter == 'rated',
                    onTap: () {
                      ctrl.setRatingFilter(rFilter == 'rated' ? null : 'rated');
                    },
                  ),
                  const SizedBox(width: 8),
                  _CompactRibbonCard(
                    label: 'Premium',
                    value: NumberFormat('#,##0').format(premiumCount),
                    dotColor: AppColors.warning,
                    icon: Iconsax.crown_copy,
                    isSelected: pFilter == true,
                    onTap: () => ctrl.setPremiumFilter(pFilter == true ? null : true),
                  ),
                  const SizedBox(width: 8),
                  _CompactRibbonCard(
                    label: 'Free',
                    value: NumberFormat('#,##0').format(freeCount),
                    dotColor: AppColors.success,
                    icon: Iconsax.unlock_copy,
                    isSelected: pFilter == false,
                    onTap: () => ctrl.setPremiumFilter(pFilter == false ? null : false),
                  ),
                  const SizedBox(width: 8),
                  _CompactRibbonCard(
                    label: 'Subjects',
                    value: NumberFormat('#,##0').format(subjectCount),
                    dotColor: AppColors.info,
                    icon: Iconsax.book_copy,
                    isSelected: false,
                    onTap: null,
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppSizes.spaceBtwSections),

          // ── Filter & Search Toolbar ────────────────────────────────────
          AdminCard(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: ctrl.searchController,
                          decoration: InputDecoration(
                            hintText: 'Search notes by title or subject...',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Iconsax.search_normal_1_copy, size: 16),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sm,
                              vertical: 8,
                            ),
                            suffixIcon: Obx(() {
                              if (ctrl.searchQuery.value.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  ctrl.searchController.clear();
                                  ctrl.searchQuery.value = '';
                                  FocusManager.instance.primaryFocus?.unfocus();
                                },
                              );
                            }),
                          ),
                          style: const TextStyle(fontSize: 12.5),
                          onChanged: (val) => ctrl.searchQuery.value = val,
                          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Get.toNamed(AdminRoutes.noteEditor),
                      icon: const Icon(Iconsax.add_copy, size: 15),
                      label: const Text('New Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm + 4),

                // Filters Row: Grade Chips, Subject Dropdown, Sort Dropdown
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Grade:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    _GradeChip(
                      label: 'All',
                      grade: null,
                      controller: ctrl,
                    ),
                    _GradeChip(
                      label: 'G9',
                      grade: 9,
                      controller: ctrl,
                      tooltip: 'Grade 9',
                    ),
                    _GradeChip(
                      label: 'G10',
                      grade: 10,
                      controller: ctrl,
                      tooltip: 'Grade 10',
                    ),
                    _GradeChip(
                      label: 'G11',
                      grade: 11,
                      controller: ctrl,
                      tooltip: 'Grade 11',
                    ),
                    _GradeChip(
                      label: 'G12',
                      grade: 12,
                      controller: ctrl,
                      tooltip: 'Grade 12',
                    ),
                    const SizedBox(width: 4),

                    // Subject dropdown
                    Obx(() {
                      final subjects = ctrl.subjects;
                      return Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                          border: Border.all(
                            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: ctrl.selectedSubjectId.value,
                            isDense: true,
                            hint: const Text('All Subjects', style: TextStyle(fontSize: 11)),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Subjects', style: TextStyle(fontSize: 11)),
                              ),
                              ...subjects.map((s) => DropdownMenuItem<int?>(
                                    value: s['id'] as int?,
                                    child: Text(
                                      s['name']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  )),
                            ],
                            onChanged: ctrl.setSubjectFilter,
                          ),
                        ),
                      );
                    }),

                    // Sort dropdown
                    Obx(() {
                      return Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                          border: Border.all(
                            color: ctrl.sortOption.value == 'urgency'
                                ? AppColors.error
                                : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
                            width: ctrl.sortOption.value == 'urgency' ? 1.2 : 1.0,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: ctrl.sortOption.value,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'default',
                                child: Text('Sort: Default', style: TextStyle(fontSize: 11)),
                              ),
                              DropdownMenuItem(
                                value: 'urgency',
                                child: Text(
                                  'Sort: ⚠️ Low Rating (High Reviews)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'lowest_rating',
                                child: Text('Sort: Lowest Rated', style: TextStyle(fontSize: 11)),
                              ),
                              DropdownMenuItem(
                                value: 'highest_rating',
                                child: Text('Sort: Highest Rated', style: TextStyle(fontSize: 11)),
                              ),
                              DropdownMenuItem(
                                value: 'most_rated',
                                child: Text('Sort: Most Reviews', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) ctrl.setSortOption(val);
                            },
                          ),
                        ),
                      );
                    }),

                    Obx(() {
                      final hasFilter = ctrl.selectedGrade.value != null ||
                          ctrl.selectedSubjectId.value != null ||
                          ctrl.premiumFilter.value != null ||
                          ctrl.ratingFilter.value != null ||
                          ctrl.sortOption.value != 'default' ||
                          ctrl.searchQuery.value.isNotEmpty;
                      if (!hasFilter) return const SizedBox.shrink();

                      return TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: ctrl.clearFilters,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset', style: TextStyle(fontSize: 12)),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.spaceBtwSections),

          // ── Notes List Grouped by Subject ──────────────────────────────
          Obx(() {
            if (ctrl.isLoading.value && ctrl.notes.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.defaultSpace),
                  child: AppCircularLoading(),
                ),
              );
            }

            final grouped = ctrl.notesGroupedBySubject;

            if (grouped.isEmpty) {
              return AdminCard(
                padding: const EdgeInsets.all(AppSizes.defaultSpace * 1.5),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Iconsax.document_text_copy,
                        size: 48,
                        color: dark ? Colors.white30 : AppColors.darkGrey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSizes.md),
                      const Text(
                        'No Notes Found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      const Text(
                        'Try clearing your filters or create a new note for students.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSizes.md),
                      ElevatedButton.icon(
                        onPressed: () => Get.toNamed(AdminRoutes.noteEditor),
                        icon: const Icon(Iconsax.add_copy, size: 18),
                        label: const Text('Add Note'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: grouped.entries.map((entry) {
                final subjectName = entry.key;
                final subjectNotes = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spaceBtwSections),
                  child: AdminSection(
                    title: '$subjectName (${subjectNotes.length})',
                    child: Column(
                      children: subjectNotes.map((note) {
                        return _NoteTile(
                          note: note,
                          controller: ctrl,
                          isNarrow: isNarrow,
                        );
                      }).toList(),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _CompactRibbonCard extends StatelessWidget {
  const _CompactRibbonCard({
    required this.label,
    required this.value,
    required this.dotColor,
    required this.isSelected,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color dotColor;
  final bool isSelected;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? dotColor.withValues(alpha: dark ? 0.18 : 0.08)
            : (dark ? AppColors.darkCard : AppColors.white),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(
          color: isSelected
              ? dotColor
              : (dark
                  ? AppColors.darkGrey.withValues(alpha: 0.25)
                  : AppColors.borderPrimary.withValues(alpha: 0.7)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: dotColor),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (dark ? AppColors.white : AppColors.textPrimary)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: dotColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: card,
    );
  }
}

class _GradeChip extends StatelessWidget {
  const _GradeChip({
    required this.label,
    required this.grade,
    required this.controller,
    this.tooltip,
  });

  final String label;
  final int? grade;
  final NotesController controller;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedGrade.value == grade;
      final dark = AppHelperFunctions.isDark(context);

      final chip = FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        onSelected: (_) => controller.setGradeFilter(selected ? null : grade),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        backgroundColor: dark ? AppColors.darkSurface : AppColors.lightGrey,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        checkmarkColor: AppColors.primary,
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
        ),
      );

      if (tooltip == null) return chip;
      return Tooltip(message: tooltip, child: chip);
    });
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.controller,
    required this.isNarrow,
  });

  final AdminNoteModel note;
  final NotesController controller;
  final bool isNarrow;

  void _showRatingBreakdownDialog(BuildContext context, AdminNoteModel note, bool dark) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dist = note.ratingDistribution ?? {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        final total = note.ratingCount > 0 ? note.ratingCount : 1;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: dark ? const Color(0xFF1E1E24) : Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rating Breakdown',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              // Big Score Banner
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      note.hasRatings ? note.averageRating.toStringAsFixed(1) : '—',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            final fill = (index + 1) <= note.averageRating.round();
                            return Icon(
                              fill ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 16,
                              color: const Color(0xFFF59E0B),
                            );
                          }),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${note.ratingCount} student ${note.ratingCount == 1 ? "review" : "reviews"}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Attention Warning if student ratings are low with high responses
              if (note.isNeedsAttention) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Iconsax.warning_2_copy, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Multiple students rated this note poorly (${note.averageRating.toStringAsFixed(1)}/5 avg). Consider reviewing this note for errors, clarity, or missing explanations.',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Star bars 5 to 1
              ...List.generate(5, (i) {
                final star = 5 - i;
                final count = dist[star] ?? 0;
                final pct = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$star ★',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 7,
                            backgroundColor: dark ? Colors.white12 : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              star >= 4
                                  ? const Color(0xFF10B981)
                                  : (star == 3 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Get.toNamed(AdminRoutes.noteEditor, arguments: {'note': note});
              },
              icon: const Icon(Iconsax.edit_2_copy, size: 15),
              label: const Text('Edit Note'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    Widget buildDocIcon() {
      return const Icon(
        Iconsax.document_text_copy,
        color: AppColors.primary,
        size: 18,
      );
    }

    List<Widget> buildActions() {
      final hasFile = note.fileKey.isNotEmpty ||
          (note.fileUrl != null && note.fileUrl!.isNotEmpty);

      return [
        // 1. Premium toggle: icon only with confirmation modal
        Obx(() {
          final isUpdating = controller.isUpdatingPremium[note.id] == true;
          if (isUpdating) {
            return const SizedBox(
              width: 32,
              height: 32,
              child: Padding(
                padding: EdgeInsets.all(7),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          return IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: note.isPremium
                ? 'Premium note (tap to set Free)'
                : 'Free note (tap to set Premium)',
            icon: Icon(
              note.isPremium ? Iconsax.crown_copy : Iconsax.unlock_copy,
              size: 18,
              color: note.isPremium ? AppColors.warning : AppColors.success,
            ),
            onPressed: () async {
              final targetIsPremium = !note.isPremium;
              final confirmed = await AppDialogBoxes.confirm(
                title: targetIsPremium ? 'Change to Premium' : 'Change to Free',
                message: targetIsPremium
                    ? 'Are you sure you want to change "${note.title}" to Premium?\nOnly students with an active subscription will be able to access it.'
                    : 'Are you sure you want to change "${note.title}" to Free?\nAll students will be able to access this note.',
                confirmLabel: targetIsPremium ? 'Make Premium' : 'Make Free',
              );
              if (confirmed) {
                await controller.togglePremium(note);
              }
            },
          );
        }),

        // 2. View PDF
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: hasFile ? 'View PDF' : 'No PDF attached',
          icon: Icon(
            Icons.visibility_outlined,
            size: 18,
            color: hasFile
                ? (dark ? AppColors.white : AppColors.textPrimary)
                : (dark ? Colors.white30 : Colors.black26),
          ),
          onPressed: hasFile
              ? () {
                  Get.to(
                    () => NotePdfPreviewScreen(
                      noteId: note.id,
                      title: note.title,
                      fileName: note.fileKey.isNotEmpty
                          ? note.fileKey.split('/').last
                          : 'document.pdf',
                      fileUrl: note.fileUrl,
                      fileKey: note.fileKey,
                      fileSizeBytes: note.fileSizeBytes,
                      pageCount: note.pageCount,
                      grade: note.grade,
                      subjectName: note.subjectName,
                      chapterNumber: note.chapterNumber,
                      isPremium: note.isPremium,
                    ),
                  );
                }
              : null,
        ),

        // 3. Edit note
        IconButton(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(5),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Edit note',
          icon: const Icon(Iconsax.edit_2_copy, size: 18),
          onPressed: () => Get.toNamed(
            AdminRoutes.noteEditor,
            arguments: {'note': note},
          ),
        ),

        // 4. Delete note
        Obx(() {
          final isDeleting = controller.isDeleting[note.id] == true;
          if (isDeleting) {
            return const SizedBox(
              width: 32,
              height: 32,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          return IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Delete note',
            icon: const Icon(
              Iconsax.trash_copy,
              size: 18,
              color: AppColors.error,
            ),
            onPressed: () async {
              final confirmed = await AppDialogBoxes.confirm(
                title: 'Delete Note',
                message:
                    'Are you sure you want to delete "${note.title}"?\n'
                    'This will also remove the PDF file from storage.',
                confirmLabel: 'Delete',
                isDestructive: true,
              );
              if (confirmed) {
                controller.deleteNote(note);
              }
            },
          );
        }),
      ];
    }

    final subject = (note.subjectName != null && note.subjectName!.trim().isNotEmpty)
        ? note.subjectName!.trim()
        : (controller.subjects.firstWhereOrNull((s) => s['id'] == note.subjectId)?['name'] as String?);

    final details = <Widget>[
      if (subject != null && subject.isNotEmpty)
        _DetailChip(
          icon: Iconsax.book_copy,
          label: subject,
          color: AppColors.primary,
        ),
      if (note.grade > 0)
        _DetailChip(
          icon: Iconsax.teacher_copy,
          label: 'Grade ${note.grade}',
        ),
      if (note.chapterNumber > 0)
        _DetailChip(
          icon: Iconsax.folder_2_copy,
          label: (note.chapterTitle != null && note.chapterTitle!.trim().isNotEmpty)
              ? 'Ch. ${note.chapterNumber}: ${note.chapterTitle!.trim()}'
              : 'Chapter ${note.chapterNumber}',
        ),
      if (note.fileSizeBytes > 0 || (note.formattedSize.isNotEmpty && note.formattedSize != '0 MB'))
        _DetailChip(
          icon: Iconsax.document_upload_copy,
          label: note.formattedSize,
        ),
      if (note.pageCount > 0)
        _DetailChip(
          icon: Iconsax.document_text_copy,
          label: note.formattedPages,
        ),
      // ── Rating Detail Chip (interactive) ──
      _RatingDetailChip(
        note: note,
        dark: dark,
        onTap: () => _showRatingBreakdownDialog(context, note, dark),
      ),
      if (note.orderIndex > 0)
        _DetailChip(
          icon: Iconsax.sort_copy,
          label: 'Order: ${note.orderIndex}',
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightGrey,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: note.isNeedsAttention
              ? AppColors.error.withValues(alpha: 0.6)
              : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
          width: note.isNeedsAttention ? 1.3 : 1.0,
        ),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    buildDocIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.isNeedsAttention) ...[
                      const SizedBox(width: 6),
                      _NeedsAttentionBadge(note: note),
                    ],
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: details,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: buildActions(),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                buildDocIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (note.isNeedsAttention) ...[
                            const SizedBox(width: 8),
                            _NeedsAttentionBadge(note: note),
                          ],
                        ],
                      ),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: details,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: buildActions(),
                ),
              ],
            ),
    );
  }
}

class _NeedsAttentionBadge extends StatelessWidget {
  const _NeedsAttentionBadge({required this.note});

  final AdminNoteModel note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.warning_2_copy, size: 11, color: AppColors.error),
          const SizedBox(width: 4),
          Text(
            'Needs Review: ${note.averageRating.toStringAsFixed(1)}★ (${note.ratingCount})',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingDetailChip extends StatelessWidget {
  const _RatingDetailChip({
    required this.note,
    required this.dark,
    required this.onTap,
  });

  final AdminNoteModel note;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!note.hasRatings) {
      return const _DetailChip(
        icon: Icons.star_border_rounded,
        label: 'No reviews',
      );
    }

    final isLow = note.isNeedsAttention;
    final color = isLow
        ? AppColors.error
        : (note.averageRating >= 4.0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.20 : 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withValues(alpha: 0.45),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 3.5),
            Text(
              '${note.averageRating.toStringAsFixed(1)} ★ (${note.ratingCount})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: dark
              ? AppColors.darkBorder
              : AppColors.borderPrimary.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11.5,
            color: color ?? (dark ? AppColors.textSecondary : AppColors.darkGrey),
          ),
          const SizedBox(width: 4.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color ??
                  (dark
                      ? AppColors.textSecondary
                      : AppColors.textPrimary.withValues(alpha: 0.85)),
            ),
          ),
        ],
      ),
    );
  }
}
