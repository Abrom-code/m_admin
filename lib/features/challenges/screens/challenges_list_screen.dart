import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/features/challenges/controllers/challenges_list_controller.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/features/challenges/screens/challenge_editor_screen.dart';
import 'package:m_admin/features/challenges/screens/challenge_leaderboard_screen.dart';
import 'package:m_admin/features/challenges/screens/subject_challenges_screen.dart';
import 'package:m_admin/features/challenges/screens/widgets/challenge_card.dart';
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
            // ── Single Ultra-Clean Toolbar ──
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
                      icon: const Icon(Iconsax.ranking_copy, size: 15, color: Color(0xFF0284C7)),
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
                          suffixIcon: Obx(() => _ctrl.searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 13),
                                  onPressed: () {
                                    _ctrl.searchCtrl.clear();
                                    _ctrl.onSearch('');
                                    FocusManager.instance.primaryFocus?.unfocus();
                                  },
                                )
                              : const SizedBox.shrink()),
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
                        // ── SECTION 1: LIVE, SCHEDULED & DRAFT CHALLENGES ─────
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
                            Text(
                              _ctrl.statusFilter.value == 'all'
                                  ? 'Live, Scheduled & Draft Challenges'
                                  : '${_ctrl.statusFilter.value.capitalizeFirst} Challenges',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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
                                Text(
                                  _ctrl.statusFilter.value == 'all'
                                      ? 'No live, scheduled, or draft challenges'
                                      : 'No ${_ctrl.statusFilter.value} challenges found',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                const Text('Create a challenge to see active and upcoming rounds here.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 460,
                              mainAxisExtent: 148,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _ctrl.topChallenges.length,
                            itemBuilder: (context, index) {
                              final challenge = _ctrl.topChallenges[index];
                              return ChallengeCard(
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
                                onClose: () => _confirmClose(context, challenge),
                                onDelete: () => _confirmDelete(context, challenge),
                              );
                            },
                          ),

                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── SECTION 2: SUBJECTS ──────────────────────────────
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Iconsax.book_1_copy, size: 15, color: Color(0xFF0284C7)),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Subjects',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_ctrl.filteredSubjectsList.length} Subjects',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                              ),
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
                            itemCount: _ctrl.filteredSubjectsList.length + (_ctrl.selectedSubjectId.value == null ? 1 : 0),
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              // Render "All Subjects" tile first when not filtered to a single subject
                              if (_ctrl.selectedSubjectId.value == null && index == 0) {
                                return _SubjectTile(
                                  subjectId: 0,
                                  subjectName: 'All Subjects',
                                  isNatural: false,
                                  isCommon: true,
                                  isAllSubjects: true,
                                  stats: _ctrl.allSubjectsStats,
                                  onTap: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    Get.to(() => const SubjectChallengesScreen(
                                          subjectId: 0,
                                          subjectName: 'All Subjects',
                                          isNatural: false,
                                          isCommon: true,
                                        ));
                                  },
                                  onCreateChallenge: () async {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    await Get.to(() => const ChallengeEditorScreen());
                                    _ctrl.loadAll(showLoading: false);
                                  },
                                );
                              }

                              final actualIndex = _ctrl.selectedSubjectId.value == null ? index - 1 : index;
                              final sub = _ctrl.filteredSubjectsList[actualIndex];
                              final subId = (sub['id'] as num?)?.toInt() ?? int.tryParse(sub['id']?.toString() ?? '') ?? 0;
                              final subName = sub['name']?.toString() ?? 'Subject';
                              final isNatural = sub['is_natural'] == true;
                              final isCommon = sub['is_common'] == true;

                              return _SubjectTile(
                                subjectId: subId,
                                subjectName: subName,
                                isNatural: isNatural,
                                isCommon: isCommon,
                                stats: _ctrl.getSubjectStats(subId),
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Get.to(() => SubjectChallengesScreen(
                                        subjectId: subId,
                                        subjectName: subName,
                                        isNatural: isNatural,
                                        isCommon: isCommon,
                                      ));
                                },
                                onCreateChallenge: () async {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  await Get.to(() => ChallengeEditorScreen(initialSubjectId: subId));
                                  _ctrl.loadAll(showLoading: false);
                                },
                              );
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

  void _confirmClose(BuildContext context, LeaderboardChallengeModel challenge) {
    FocusManager.instance.primaryFocus?.unfocus();
    AppDialogBoxes.showOkCancelDialog(
      context: context,
      title: 'Close Live Challenge?',
      subtitle: 'Are you sure you want to close "${challenge.title}" from live now?\n\n'
          'Students will immediately no longer be able to attempt this challenge, '
          'and the round will be marked as CLOSED.',
      onPressed: () {
        Navigator.pop(context);
        _ctrl.closeChallenge(challenge.id);
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

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.subjectId,
    required this.subjectName,
    required this.isNatural,
    required this.isCommon,
    this.isAllSubjects = false,
    required this.stats,
    required this.onTap,
    required this.onCreateChallenge,
  });

  final int subjectId;
  final String subjectName;
  final bool isNatural;
  final bool isCommon;
  final bool isAllSubjects;
  final Map<String, int> stats;
  final VoidCallback onTap;
  final VoidCallback onCreateChallenge;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    Color streamColor;
    String streamLabel;
    if (isAllSubjects) {
      streamColor = const Color(0xFF0284C7);
      streamLabel = 'All Streams & Common';
    } else if (isCommon) {
      streamColor = const Color(0xFF0284C7);
      streamLabel = 'Common';
    } else if (isNatural) {
      streamColor = AppColors.primary;
      streamLabel = 'Natural Stream';
    } else {
      streamColor = AppColors.secondary;
      streamLabel = 'Social Stream';
    }

    final total = stats['total'] ?? 0;
    final live = stats['live'] ?? 0;
    final scheduled = stats['scheduled'] ?? 0;
    final draft = stats['draft'] ?? 0;
    final closed = stats['closed'] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            border: Border.all(
              color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;

              return Row(
                children: [
                  // Icon Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: streamColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Iconsax.book_1_copy, size: 18, color: streamColor),
                  ),
                  const SizedBox(width: 12),

                  // Subject Name, Stream Badge & Stats Summary
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
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
                        const SizedBox(height: 4),
                        Text(
                          total == 0
                              ? 'No challenges created yet'
                              : '$total Challenges • $live Live • $scheduled Sched • $draft Draft • $closed Ended',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Quick Create Challenge button
                  if (isNarrow)
                    IconButton(
                      tooltip: 'New Challenge',
                      style: IconButton.styleFrom(
                        backgroundColor: streamColor.withValues(alpha: 0.12),
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

                  const SizedBox(width: 8),

                  // Forward chevron indicating navigation to screen
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
