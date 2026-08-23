import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/features/challenges/controllers/challenges_list_controller.dart';
import 'package:m_admin/features/challenges/screens/challenge_editor_screen.dart';
import 'package:m_admin/features/challenges/screens/challenge_leaderboard_screen.dart';
import 'package:m_admin/features/challenges/screens/challenge_scheduler_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      body: AdminScaffold(
        pageIndex: 5,
        scrollable: false,
        onRefresh: _ctrl.loadAll,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Modern KPI Dashboard Metrics ──────────────────────
            Obx(
              () => Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkCard : AppColors.white,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
                  border: Border.all(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceAround,
                  children: [
                    _ModernKpiStat(
                      icon: Iconsax.play_circle_copy,
                      gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                      label: 'Live Now',
                      value: '${_ctrl.liveCount}',
                      isLive: _ctrl.liveCount > 0,
                    ),
                    _ModernKpiStat(
                      icon: Iconsax.clock_copy,
                      gradientColors: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      label: 'Scheduled',
                      value: '${_ctrl.scheduledCount}',
                    ),
                    _ModernKpiStat(
                      icon: Iconsax.cup_copy,
                      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      label: 'Closed / Standings',
                      value: '${_ctrl.closedCount}',
                    ),
                    _ModernKpiStat(
                      icon: Iconsax.document_text_copy,
                      gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                      label: 'Question Sets',
                      value: '${_ctrl.totalSetsCount}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── Top Header & Tab Switcher ──────────────────────────
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Obx(
                  () => Container(
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TabPill(
                          selected: _ctrl.selectedTab.value == 0,
                          icon: Iconsax.cup_copy,
                          label: 'Challenge Rounds (${_ctrl.challenges.length})',
                          onTap: () => _ctrl.setTab(0),
                        ),
                        _TabPill(
                          selected: _ctrl.selectedTab.value == 1,
                          icon: Iconsax.document_copy,
                          label: 'Question Sets (${_ctrl.questionSets.length})',
                          onTap: () => _ctrl.setTab(1),
                        ),
                      ],
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () async {
                        final ok = await Get.to(() => const ChallengeEditorScreen());
                        if (ok == true || ok is String) {
                          _ctrl.loadQuestionSets();
                        }
                      },
                      icon: const Icon(Iconsax.add_circle_copy, size: 16),
                      label: const Text('New Question Set'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () async {
                        final ok = await Get.to(() => const ChallengeSchedulerScreen());
                        if (ok == true) _ctrl.loadChallenges();
                      },
                      icon: const Icon(Iconsax.calendar_add_copy, size: 16),
                      label: const Text('Schedule Round'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── Modern Search & Filter Bar ──────────────────────────
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
                  children: [
                    // Search bar
                    SizedBox(
                      width: 210,
                      height: 38,
                      child: TextField(
                        controller: _ctrl.searchCtrl,
                        onChanged: _ctrl.onSearch,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Search title or subject...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Iconsax.search_normal_copy, size: 16),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                            borderSide: BorderSide(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),

                    // Subject dropdown
                    const Icon(Iconsax.filter_copy, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text('Subject: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Obx(
                      () => DropdownButton<int?>(
                        value: _ctrl.selectedSubjectId.value,
                        underline: const SizedBox.shrink(),
                        hint: const Text('All Subjects', style: TextStyle(fontSize: 12)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Subjects', style: TextStyle(fontSize: 12)),
                          ),
                          ..._ctrl.subjects.map(
                            (s) => DropdownMenuItem<int?>(
                              value: s['id'] as int,
                              child: Text(s['name']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                        onChanged: _ctrl.setSubjectFilter,
                      ),
                    ),

                    // If Rounds tab: status and audience filter chips
                    Obx(() {
                      if (_ctrl.selectedTab.value != 0) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: AppSizes.md),
                          const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          ...['all', 'live', 'scheduled', 'closed', 'draft'].map((st) {
                            final isSel = _ctrl.statusFilter.value == st;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: FilterChip(
                                label: Text(st == 'all' ? 'All' : st.toUpperCase()),
                                selected: isSel,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.white : AppColors.textSecondary,
                                ),
                                selectedColor: _statusColor(st),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onSelected: (_) => _ctrl.setStatusFilter(st),
                              ),
                            );
                          }),

                          const SizedBox(width: AppSizes.sm),
                          const Text('Stream: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          ...['all', 'both', 'natural', 'social'].map((aud) {
                            final isSel = _ctrl.audienceFilter.value == aud;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: FilterChip(
                                label: Text(aud == 'all' ? 'All' : aud.toUpperCase()),
                                selected: isSel,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.white : AppColors.textSecondary,
                                ),
                                selectedColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onSelected: (_) => _ctrl.setAudienceFilter(aud),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── Main List Content ──────────────────────────────────
            Expanded(
              child: Obx(() {
                if (_ctrl.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_ctrl.selectedTab.value == 0) {
                  return _buildRoundsList(dark);
                } else {
                  return _buildQuestionSetsList(dark);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundsList(bool dark) {
    final list = _ctrl.filteredChallenges;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.cup_copy, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: AppSizes.md),
            const Text('No challenge rounds found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Schedule a live challenge round for students nationwide.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.md),
            FilledButton.icon(
              onPressed: () async {
                final ok = await Get.to(() => const ChallengeSchedulerScreen());
                if (ok == true) _ctrl.loadChallenges();
              },
              icon: const Icon(Iconsax.calendar_add_copy, size: 16),
              label: const Text('Schedule First Round'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (context, idx) {
        final ch = list[idx];
        final isLive = ch.isLive;

        return Card(
          elevation: isLive ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            side: BorderSide(
              color: isLive ? AppColors.success : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
              width: isLive ? 1.8 : 1.0,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
              gradient: isLive
                  ? LinearGradient(
                      colors: [
                        AppColors.success.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
            ),
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Avatar + Title + Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _statusColor(ch.status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                      ),
                      child: Icon(_statusIcon(ch.status), color: _statusColor(ch.status), size: 22),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _BadgeChip(
                                label: isLive ? '● LIVE NOW' : ch.status.toUpperCase(),
                                color: _statusColor(ch.status),
                              ),
                              _BadgeChip(
                                label: '${ch.audience.toUpperCase()} STREAM',
                                color: ch.audience == 'both' ? AppColors.secondary : AppColors.primary,
                              ),
                              _BadgeChip(
                                label: ch.subjectName?.toUpperCase() ?? 'SUBJECT',
                                color: AppColors.primary,
                              ),
                              // Copy Set ID badge
                              InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: ch.setId));
                                  SnackbarHelper.info('Copied!', 'Set ID: ${ch.setId}');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.copy_rounded, size: 10, color: AppColors.textSecondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Set: ${ch.setId.length > 8 ? ch.setId.substring(0, 8) : ch.setId}...',
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Timing & Meta Row
                Row(
                  children: [
                    Icon(Iconsax.clock_copy, size: 13, color: isLive ? AppColors.success : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ch.startsAt != null && ch.endsAt != null
                            ? '${_dateFormat.format(ch.startsAt!)} → ${_dateFormat.format(ch.endsAt!)}  •  ${ch.durationSeconds ~/ 60}m attempt'
                            : '${ch.durationSeconds ~/ 60} mins attempt limit',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isLive ? FontWeight.bold : FontWeight.w500,
                          color: isLive ? AppColors.success : AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Action Buttons Row (Responsive Wrap)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Get.to(
                        () => ChallengeLeaderboardScreen(
                          challengeId: ch.id,
                          challengeTitle: ch.title,
                        ),
                      ),
                      icon: const Icon(Iconsax.ranking_copy, size: 14),
                      label: const Text('Leaderboard', style: TextStyle(fontSize: 11.5)),
                    ),
                    if (ch.isScheduled || ch.isDraft)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _ctrl.makeLiveNow(ch.id),
                        icon: const Icon(Icons.bolt, size: 14),
                        label: const Text('Go Live Now', style: TextStyle(fontSize: 11.5)),
                      ),
                    if (ch.isLive)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          final ok = await AppDialogBoxes.confirm(
                            title: 'End Live Round',
                            message: 'Close this challenge round now and finalize leaderboards for all students?',
                            confirmLabel: 'End Round',
                            isDestructive: true,
                          );
                          if (ok) _ctrl.closeRoundNow(ch.id);
                        },
                        icon: const Icon(Icons.stop_circle_outlined, size: 14),
                        label: const Text('End Round', style: TextStyle(fontSize: 11.5)),
                      ),
                    if (ch.isDraft || ch.isScheduled)
                      IconButton(
                        tooltip: 'Edit Schedule',
                        icon: const Icon(Iconsax.edit_copy, size: 18),
                        onPressed: () async {
                          final ok = await Get.to(
                            () => ChallengeSchedulerScreen(challengeId: ch.id),
                          );
                          if (ok == true) _ctrl.loadChallenges();
                        },
                      ),
                    if (ch.isClosed)
                      IconButton(
                        tooltip: 'Archive challenge',
                        icon: const Icon(Iconsax.archive_copy, size: 18),
                        onPressed: () => _ctrl.archiveChallenge(ch.id),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionSetsList(bool dark) {
    final list = _ctrl.filteredQuestionSets;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.document_copy, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: AppSizes.md),
            const Text('No question sets found', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Create a question set with 30-50 questions for challenges.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.md),
            FilledButton.icon(
              onPressed: () async {
                final ok = await Get.to(() => const ChallengeEditorScreen());
                if (ok == true || ok is String) {
                  _ctrl.loadQuestionSets();
                }
              },
              icon: const Icon(Iconsax.add_copy, size: 16),
              label: const Text('Create First Question Set'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (context, idx) {
        final set = list[idx];
        final isReady = set.questionCount >= 30;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            side: BorderSide(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                      ),
                      child: const Icon(Iconsax.note_2_copy, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            set.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _BadgeChip(
                                label: set.subjectName?.toUpperCase() ?? 'SUBJECT',
                                color: AppColors.primary,
                              ),
                              _BadgeChip(
                                label: isReady ? '${set.questionCount} QUESTIONS (READY)' : '${set.questionCount} QUESTIONS',
                                color: isReady ? AppColors.success : AppColors.warning,
                              ),
                              // Copy Set ID badge for SQL
                              InkWell(
                                borderRadius: BorderRadius.circular(4),
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: set.id));
                                  SnackbarHelper.success('Copied!', 'Set ID: ${set.id} (Ready for SQL)');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.copy_rounded, size: 10, color: AppColors.primary),
                                      const SizedBox(width: 3),
                                      Text(
                                        'ID: ${set.id.length > 8 ? set.id.substring(0, 8) : set.id}...',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Created: ${_dateFormat.format(set.createdAt)}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        final ok = await Get.to(
                          () => ChallengeSchedulerScreen(
                            preselectedSetId: set.id,
                            preselectedSubjectId: set.subjectId,
                          ),
                        );
                        if (ok == true) {
                          _ctrl.selectedTab.value = 0;
                          _ctrl.loadChallenges();
                        }
                      },
                      icon: const Icon(Iconsax.calendar_tick_copy, size: 14),
                      label: const Text('Schedule Round', style: TextStyle(fontSize: 11.5)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        final ok = await Get.to(
                          () => ChallengeEditorScreen(
                            setId: set.id,
                            subjectId: set.subjectId,
                            subjectName: set.subjectName ?? '',
                          ),
                        );
                        if (ok == true || ok is String) {
                          _ctrl.loadQuestionSets();
                        }
                      },
                      icon: const Icon(Iconsax.edit_copy, size: 14),
                      label: const Text('Edit Questions', style: TextStyle(fontSize: 11.5)),
                    ),
                    IconButton(
                      tooltip: 'Delete set',
                      icon: const Icon(Iconsax.trash_copy, size: 18, color: AppColors.error),
                      onPressed: () async {
                        final ok = await AppDialogBoxes.confirm(
                          title: 'Delete Question Set',
                          message: 'Are you sure you want to delete "${set.title}" and its ${set.questionCount} questions?',
                          confirmLabel: 'Delete',
                          isDestructive: true,
                        );
                        if (ok) _ctrl.deleteQuestionSet(set.id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'live':
        return AppColors.success;
      case 'scheduled':
        return const Color(0xFF2563EB);
      case 'closed':
        return const Color(0xFF7C3AED);
      case 'archived':
        return AppColors.textSecondary;
      case 'draft':
      default:
        return AppColors.warning;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'live':
        return Iconsax.play_circle_copy;
      case 'scheduled':
        return Iconsax.clock_copy;
      case 'closed':
        return Iconsax.tick_circle_copy;
      case 'archived':
        return Iconsax.archive_copy;
      case 'draft':
      default:
        return Iconsax.edit_2_copy;
    }
  }
}

class _ModernKpiStat extends StatelessWidget {
  const _ModernKpiStat({
    required this.icon,
    required this.gradientColors,
    required this.label,
    required this.value,
    this.isLive = false,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final String label;
  final String value;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: gradientColors.first,
                  ),
                ),
                if (isLive) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (dark ? AppColors.darkCard : AppColors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.2 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? (dark ? Colors.white : Colors.black87) : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
