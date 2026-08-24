import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/features/challenges/controllers/challenges_list_controller.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/features/challenges/screens/challenge_editor_screen.dart';
import 'package:m_admin/features/challenges/screens/challenge_leaderboard_screen.dart';
import 'package:m_admin/features/challenges/screens/widgets/notify_challenge_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengesListScreen extends StatefulWidget {
  const ChallengesListScreen({super.key});

  @override
  State<ChallengesListScreen> createState() => _ChallengesListScreenState();
}

class _ChallengesListScreenState extends State<ChallengesListScreen> {
  final _ctrl = Get.put(ChallengesListController());
  final _dateFormat = DateFormat('MMM dd, HH:mm');
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: AdminScaffold(
        pageIndex: 5,
        scrollable: false,
        onRefresh: _ctrl.loadAll,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Single Ultra-Clean Toolbar (AppBar handles refresh) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                border: Border.all(
                  color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Create Challenge Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await Get.to(() => const ChallengeEditorScreen());
                        _ctrl.loadAll(showLoading: false);
                      },
                      icon: const Icon(Iconsax.add_circle_copy, size: 15),
                      label: const Text('Create', style: TextStyle(fontSize: 12)),
                    ),

                    const SizedBox(width: 8),

                    // Leaderboards Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Get.to(() => const ChallengeLeaderboardScreen());
                      },
                      icon: const Icon(Iconsax.ranking_copy, size: 15, color: Color(0xFF8B5CF6)),
                      label: const Text('Leaderboard', style: TextStyle(fontSize: 12)),
                    ),

                    const SizedBox(width: 8),

                    // Refresh Button
                    IconButton(
                      tooltip: 'Refresh',
                      visualDensity: VisualDensity.compact,
                      icon: Obx(() => _ctrl.isRefreshing.value
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16)),
                      onPressed: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        _ctrl.loadAll();
                      },
                    ),

                    const SizedBox(width: AppSizes.md),

                    // Search input
                    SizedBox(
                      width: 190,
                      height: 32,
                      child: TextField(
                        controller: _ctrl.searchCtrl,
                        onChanged: _ctrl.onSearch,
                        autofocus: false,
                        style: const TextStyle(fontSize: 11.5),
                        decoration: InputDecoration(
                          hintText: 'Search title, subject...',
                          hintStyle: const TextStyle(fontSize: 11),
                          prefixIcon: const Icon(Iconsax.search_normal_copy, size: 13),
                          suffixIcon: _ctrl.searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 13),
                                  onPressed: () {
                                    _ctrl.searchCtrl.clear();
                                    _ctrl.onSearch('');
                                    FocusManager.instance.primaryFocus?.unfocus();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                            borderSide: BorderSide(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSizes.md),

                    // Subject dropdown
                    const Icon(Iconsax.filter_copy, size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text('Subject: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    Obx(
                      () => DropdownButton<int?>(
                        value: _ctrl.selectedSubjectId.value,
                        underline: const SizedBox.shrink(),
                        hint: const Text('All Subjects', style: TextStyle(fontSize: 11)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Subjects', style: TextStyle(fontSize: 11)),
                          ),
                          ..._ctrl.subjects.map(
                            (s) => DropdownMenuItem<int?>(
                              value: s['id'] as int,
                              child: Text(s['name']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _ctrl.setSubjectFilter(v);
                        },
                      ),
                    ),

                    const SizedBox(width: AppSizes.md),
                    const Text('Status: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),

                    // Status filter chips
                    Obx(() {
                      final statusOptions = [
                        {'key': 'all', 'label': 'All (${_ctrl.challenges.length})'},
                        {'key': 'live', 'label': 'Live (${_ctrl.liveCount})'},
                        {'key': 'scheduled', 'label': 'Scheduled (${_ctrl.scheduledCount})'},
                        {'key': 'closed', 'label': 'Closed (${_ctrl.closedCount})'},
                        {'key': 'draft', 'label': 'Draft (${_ctrl.draftCount})'},
                      ];

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: statusOptions.map((opt) {
                          final key = opt['key']!;
                          final label = opt['label']!;
                          final isSel = _ctrl.statusFilter.value == key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: FilterChip(
                              label: Text(label),
                              selected: isSel,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                fontSize: 10,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? Colors.white : AppColors.textSecondary,
                              ),
                              selectedColor: _statusColor(key),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onSelected: (_) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                _ctrl.setStatusFilter(key);
                              },
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Main Challenges & Subjects View ────────────────────────
            Expanded(
              child: Obx(() {
                if (_ctrl.isLoading.value && _ctrl.challenges.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return RefreshIndicator(
                  onRefresh: _ctrl.loadAll,
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 32, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── SECTION 1: LIVE & DRAFT CHALLENGES ─────────────────
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Iconsax.flash_1_copy, size: 15, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Live & Draft Challenges',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_ctrl.topChallenges.length}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_ctrl.topChallenges.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkCard : AppColors.white,
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                              border: Border.all(
                                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Iconsax.cup_copy, size: 32, color: dark ? Colors.white24 : AppColors.textSecondary),
                                const SizedBox(height: 8),
                                const Text('No live or draft challenges', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                const Text('Create a challenge to see active rounds here.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 440,
                              mainAxisExtent: 225,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _ctrl.topChallenges.length,
                            itemBuilder: (context, index) {
                              final challenge = _ctrl.topChallenges[index];
                              return _ChallengeCard(
                                challenge: challenge,
                                dateFormat: _dateFormat,
                                onEdit: () async {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  await Get.to(() => ChallengeEditorScreen(challengeId: challenge.id));
                                  _ctrl.loadAll(showLoading: false);
                                },
                                onNotify: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  NotifyChallengeDialog.show(context, challenge);
                                },
                                onPublish: () => _confirmPublish(context, challenge),
                                onDelete: () => _confirmDelete(context, challenge),
                              );
                            },
                          ),

                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── SECTION 2: CHALLENGES BY SUBJECT ──────────────────
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Iconsax.book_1_copy, size: 15, color: Color(0xFF8B5CF6)),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Challenges by Subject',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_ctrl.filteredSubjectsList.length} Subjects',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: _ctrl.expandAllSubjects,
                                  icon: const Icon(Icons.unfold_more_rounded, size: 14),
                                  label: const Text('Expand All', style: TextStyle(fontSize: 11)),
                                ),
                                const SizedBox(width: 4),
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: _ctrl.collapseAllSubjects,
                                  icon: const Icon(Icons.unfold_less_rounded, size: 14),
                                  label: const Text('Collapse All', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_ctrl.filteredSubjectsList.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkCard : AppColors.white,
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                              border: Border.all(
                                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              ),
                            ),
                            child: const Center(
                              child: Text('No subjects found matching your filters', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _ctrl.filteredSubjectsList.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final sub = _ctrl.filteredSubjectsList[index];
                              final subId = (sub['id'] as num?)?.toInt() ?? int.tryParse(sub['id']?.toString() ?? '') ?? 0;
                              final subName = sub['name']?.toString() ?? 'Subject';
                              final isNatural = sub['is_natural'] == true;
                              final isCommon = sub['is_common'] == true;

                              return Obx(() {
                                final subChallenges = _ctrl.challengesForSubject(subId);
                                final isExpanded = _ctrl.expandedSubjectIds.contains(subId);

                                return _SubjectChallengeAccordion(
                                  subjectId: subId,
                                  subjectName: subName,
                                  isNatural: isNatural,
                                  isCommon: isCommon,
                                  challenges: subChallenges,
                                  isExpanded: isExpanded,
                                  dateFormat: _dateFormat,
                                  onToggle: () => _ctrl.toggleSubjectExpanded(subId),
                                  onCreateChallenge: () async {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    await Get.to(() => ChallengeEditorScreen(initialSubjectId: subId));
                                    _ctrl.loadAll(showLoading: false);
                                  },
                                  onEditChallenge: (challenge) async {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    await Get.to(() => ChallengeEditorScreen(challengeId: challenge.id));
                                    _ctrl.loadAll(showLoading: false);
                                  },
                                  onNotifyChallenge: (challenge) {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    NotifyChallengeDialog.show(context, challenge);
                                  },
                                  onPublishChallenge: (challenge) => _confirmPublish(context, challenge),
                                  onDeleteChallenge: (challenge) => _confirmDelete(context, challenge),
                                );
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmPublish(BuildContext context, LeaderboardChallengeModel challenge) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (challenge.questionCount == 0) {
      SnackbarHelper.warning('Questions Required', 'Please add questions to "${challenge.title}" before publishing.');
      return;
    }
    AppDialogBoxes.showOkCancelDialog(
      context: context,
      title: 'Publish Challenge?',
      subtitle: challenge.isScheduled
          ? 'Make "${challenge.title}" LIVE now for all students?'
          : 'Publish "${challenge.title}" now?',
      onPressed: () {
        Navigator.pop(context);
        _ctrl.publishChallenge(challenge.id, forceLive: challenge.isScheduled);
      },
    );
  }

  void _confirmDelete(BuildContext context, LeaderboardChallengeModel challenge) {
    FocusManager.instance.primaryFocus?.unfocus();
    AppDialogBoxes.showOkCancelDialog(
      context: context,
      title: 'Delete Challenge?',
      subtitle: 'Are you sure you want to delete "${challenge.title}"? This cannot be undone.',
      onPressed: () {
        Navigator.pop(context);
        _ctrl.deleteChallenge(challenge.id);
      },
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'live':
        return AppColors.success;
      case 'scheduled':
        return AppColors.secondary;
      case 'closed':
        return AppColors.grey;
      case 'draft':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}

class _SubjectChallengeAccordion extends StatelessWidget {
  const _SubjectChallengeAccordion({
    required this.subjectId,
    required this.subjectName,
    required this.isNatural,
    required this.isCommon,
    required this.challenges,
    required this.isExpanded,
    required this.dateFormat,
    required this.onToggle,
    required this.onCreateChallenge,
    required this.onEditChallenge,
    required this.onNotifyChallenge,
    required this.onPublishChallenge,
    required this.onDeleteChallenge,
  });

  final int subjectId;
  final String subjectName;
  final bool isNatural;
  final bool isCommon;
  final List<LeaderboardChallengeModel> challenges;
  final bool isExpanded;
  final DateFormat dateFormat;
  final VoidCallback onToggle;
  final VoidCallback onCreateChallenge;
  final void Function(LeaderboardChallengeModel) onEditChallenge;
  final void Function(LeaderboardChallengeModel) onNotifyChallenge;
  final void Function(LeaderboardChallengeModel) onPublishChallenge;
  final void Function(LeaderboardChallengeModel) onDeleteChallenge;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    Color streamColor;
    String streamLabel;
    if (isCommon) {
      streamColor = const Color(0xFF8B5CF6);
      streamLabel = 'Common';
    } else if (isNatural) {
      streamColor = AppColors.primary;
      streamLabel = 'Natural Stream';
    } else {
      streamColor = AppColors.secondary;
      streamLabel = 'Social Stream';
    }

    final liveCount = challenges.where((c) => c.isLive).length;
    final draftCount = challenges.where((c) => c.isDraft).length;
    final scheduledCount = challenges.where((c) => c.isScheduled).length;
    final closedCount = challenges.where((c) => c.isClosed || c.isArchived).length;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: isExpanded
              ? streamColor.withValues(alpha: 0.4)
              : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(AppSizes.borderRadiusMd),
              bottom: isExpanded ? Radius.zero : const Radius.circular(AppSizes.borderRadiusMd),
            ),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 460;

                  return Row(
                    children: [
                      // Icon Avatar
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: streamColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Iconsax.book_1_copy, size: 18, color: streamColor),
                      ),
                      const SizedBox(width: 12),

                      // Subject Name & Stream & Counts
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    subjectName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: streamColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    streamLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: streamColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              challenges.isEmpty
                                  ? 'No challenges yet'
                                  : '${challenges.length} Challenges • $liveCount Live • $scheduledCount Sched • $draftCount Draft • $closedCount Ended',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Create Challenge button for this subject
                      if (isNarrow)
                        IconButton(
                          tooltip: 'New Challenge',
                          style: IconButton.styleFrom(
                            backgroundColor: streamColor.withValues(alpha: 0.15),
                            padding: const EdgeInsets.all(6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: onCreateChallenge,
                          icon: Icon(Iconsax.add_circle_copy, size: 16, color: streamColor),
                        )
                      else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: streamColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: onCreateChallenge,
                          icon: const Icon(Iconsax.add_circle_copy, size: 13),
                          label: const Text('New Challenge', style: TextStyle(fontSize: 11)),
                        ),
                      const SizedBox(width: 4),

                      // Chevron
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: challenges.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.document_copy, size: 28, color: dark ? Colors.white24 : AppColors.textSecondary),
                          const SizedBox(height: 6),
                          Text(
                            'No challenges created for $subjectName yet',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: onCreateChallenge,
                            icon: const Icon(Iconsax.add_circle_copy, size: 13),
                            label: const Text('Create First Challenge', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 440,
                        mainAxisExtent: 225,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: challenges.length,
                      itemBuilder: (context, index) {
                        final challenge = challenges[index];
                        return _ChallengeCard(
                          challenge: challenge,
                          dateFormat: dateFormat,
                          onEdit: () => onEditChallenge(challenge),
                          onNotify: () => onNotifyChallenge(challenge),
                          onPublish: () => onPublishChallenge(challenge),
                          onDelete: () => onDeleteChallenge(challenge),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.dateFormat,
    required this.onEdit,
    required this.onNotify,
    required this.onPublish,
    required this.onDelete,
  });

  final LeaderboardChallengeModel challenge;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onNotify;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final statusLower = challenge.status.toLowerCase();
    final isScheduled = challenge.isScheduled || statusLower == 'scheduled';
    final isDraft = challenge.isDraft || statusLower == 'draft';
    final isClosed = challenge.isClosed || challenge.isArchived || statusLower == 'closed' || statusLower == 'archived';

    Color statusBadgeColor;
    switch (statusLower) {
      case 'live':
        statusBadgeColor = AppColors.success;
        break;
      case 'scheduled':
        statusBadgeColor = AppColors.secondary;
        break;
      case 'closed':
        statusBadgeColor = AppColors.grey;
        break;
      default:
        statusBadgeColor = AppColors.warning;
    }

    Color audienceBadgeColor;
    String audienceLabel;
    switch (challenge.audience.toLowerCase()) {
      case 'natural':
        audienceBadgeColor = AppColors.primary;
        audienceLabel = 'Natural Stream';
        break;
      case 'social':
        audienceBadgeColor = AppColors.secondary;
        audienceLabel = 'Social Stream';
        break;
      default:
        audienceBadgeColor = const Color(0xFF8B5CF6);
        audienceLabel = 'Both Streams';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        side: BorderSide(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
          width: 1,
        ),
      ),
      color: dark ? AppColors.darkCard : AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header Row: Status, Stream, ID
            Row(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusBadgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    challenge.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: statusBadgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // Audience Stream Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: audienceBadgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    audienceLabel,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: audienceBadgeColor,
                    ),
                  ),
                ),

                const Spacer(),

                // Copy ID pill
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: challenge.id));
                    SnackbarHelper.success('Copied', 'Challenge ID copied to clipboard');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, size: 10, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          'ID: ${challenge.id.substring(0, challenge.id.length > 8 ? 8 : challenge.id.length)}...',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Title & Subject
            Text(
              challenge.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            const SizedBox(height: 2),
            Text(
              '${challenge.subjectName ?? 'Subject'} • Duration: ${challenge.durationMinutes} mins • ${challenge.questionCount} Questions',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 6),

            // Time Window
            Row(
              children: [
                const Icon(Iconsax.calendar_1_copy, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${challenge.startsAt != null ? dateFormat.format(challenge.startsAt!) : '--'} → ${challenge.endsAt != null ? dateFormat.format(challenge.endsAt!) : '--'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Action Buttons Row (Wrap to avoid overflow)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 1. Notify button: Shown for Live and Scheduled challenges, NOT for ended/closed or draft
                if (!isClosed && !isDraft)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onNotify,
                    icon: const Icon(Icons.notifications_active_outlined, size: 12, color: Color(0xFF8B5CF6)),
                    label: const Text('Notify', style: TextStyle(fontSize: 10.5, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
                  ),

                // 2. Edit button: Kept for every challenge status
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Iconsax.edit_2_copy, size: 12),
                  label: const Text('Edit', style: TextStyle(fontSize: 10.5)),
                ),

                // 3. If scheduled or draft -> Publish button (Leaderboard removed)
                //    If live or closed -> Leaderboard button (replaces Publish)
                if (isScheduled || isDraft)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onPublish,
                    icon: const Icon(Iconsax.send_1_copy, size: 12),
                    label: const Text('Publish', style: TextStyle(fontSize: 10.5)),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => Get.to(
                      () => ChallengeLeaderboardScreen(
                        challengeId: challenge.id,
                        challengeTitle: challenge.title,
                      ),
                    ),
                    icon: const Icon(Iconsax.ranking_copy, size: 12),
                    label: const Text('Leaderboard', style: TextStyle(fontSize: 10.5)),
                  ),

                // 4. Delete Challenge
                IconButton(
                  tooltip: 'Delete Challenge',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Iconsax.trash_copy, size: 15, color: AppColors.error),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
