import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/features/challenges/controllers/admin_leaderboard_controller.dart';
import 'package:m_admin/features/challenges/models/challenge_leaderboard_entry.dart';
import 'package:m_admin/features/challenges/screens/widgets/grant_reward_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengeLeaderboardScreen extends StatefulWidget {
  const ChallengeLeaderboardScreen({
    super.key,
    this.challengeId,
    this.challengeTitle,
  });

  final String? challengeId;
  final String? challengeTitle;

  @override
  State<ChallengeLeaderboardScreen> createState() => _ChallengeLeaderboardScreenState();
}

class _ChallengeLeaderboardScreenState extends State<ChallengeLeaderboardScreen> {
  late final AdminLeaderboardController _ctrl;
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      AdminLeaderboardController(challengeId: widget.challengeId),
      tag: 'admin_lb_${widget.challengeId ?? 'global'}',
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.challengeTitle ?? 'Challenge Standings & Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh Rankings',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _ctrl.refreshLeaderboard(),
          ),
          const SizedBox(width: AppSizes.sm),
        ],
      ),
      body: Obx(() {
        final entries = _ctrl.filteredEntries;
        final isChallengeView = _ctrl.selectedView.value == 'challenge';
        final hasEntries = entries.isNotEmpty;
        final top3 = hasEntries && entries.length >= 2 ? entries.take(3).toList() : <ChallengeLeaderboardEntry>[];
        final rest = hasEntries && entries.length >= 2 ? entries.skip(3).toList() : entries;

        return Column(
          children: [
            // ── Top KPI Dashboard Metrics ──────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkCard : AppColors.white,
                border: Border(
                  bottom: BorderSide(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                alignment: WrapAlignment.spaceAround,
                children: [
                  _KpiStatCard(
                    icon: Iconsax.profile_2user_copy,
                    color: const Color(0xFF3B82F6),
                    label: 'Competitors',
                    value: '${_ctrl.totalParticipants}',
                  ),
                  _KpiStatCard(
                    icon: Iconsax.crown_copy,
                    color: const Color(0xFFFFD700),
                    label: 'Top Score',
                    value: '${_ctrl.topScore} pts',
                  ),
                  _KpiStatCard(
                    icon: Iconsax.chart_2_copy,
                    color: const Color(0xFF10B981),
                    label: 'Avg Score',
                    value: '${_ctrl.averageScore.toStringAsFixed(1)} pts',
                  ),
                  _KpiStatCard(
                    icon: Iconsax.timer_1_copy,
                    color: const Color(0xFF8B5CF6),
                    label: 'Fastest Time',
                    value: _ctrl.formattedFastestTime,
                  ),
                ],
              ),
            ),

            // ── Search & Filter Controls ───────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  // Period Selector Pills
                  Container(
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkCard : AppColors.white,
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
                      border: Border.all(
                        color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                      ),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.challengeId != null)
                          _ViewPill(
                            selected: _ctrl.selectedView.value == 'challenge',
                            icon: Iconsax.cup_copy,
                            label: 'This Challenge',
                            onTap: () => _ctrl.setView('challenge'),
                          ),
                        _ViewPill(
                          selected: _ctrl.selectedView.value == 'weekly',
                          icon: Iconsax.calendar_1_copy,
                          label: 'Weekly',
                          onTap: () => _ctrl.setView('weekly'),
                        ),
                        _ViewPill(
                          selected: _ctrl.selectedView.value == 'monthly',
                          icon: Iconsax.calendar_copy,
                          label: 'Monthly',
                          onTap: () => _ctrl.setView('monthly'),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar + Stream Filter
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search Box
                      SizedBox(
                        width: 200,
                        height: 36,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => _ctrl.searchQuery.value = v,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search student / ID...',
                            hintStyle: const TextStyle(fontSize: 11.5),
                            prefixIcon: const Icon(Iconsax.search_normal_copy, size: 15),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                              borderSide: BorderSide(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
                            ),
                          ),
                        ),
                      ),

                      // Stream Selector Chips
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Stream: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          ...['all', 'natural', 'social'].map((st) {
                            final isSel = _ctrl.selectedStream.value == st;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: FilterChip(
                                label: Text(st == 'all' ? 'All' : (st == 'natural' ? 'Natural' : 'Social')),
                                selected: isSel,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.white : AppColors.textSecondary,
                                ),
                                selectedColor: st == 'social' ? AppColors.secondary : AppColors.primary,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onSelected: (_) => _ctrl.setStream(st),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Main Content Area ──────────────────────────────────
            Expanded(
              child: Builder(builder: (context) {
                if (_ctrl.isLoading.value && _ctrl.entries.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!hasEntries) {
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
                          child: const Icon(Iconsax.ranking_copy, size: 48, color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSizes.md),
                        const Text(
                          'No leaderboard entries found',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Rankings will appear here as students complete the challenge round.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Scrollbar(
                  controller: _scrollCtrl,
                  child: ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(AppSizes.md),
                    children: [
                      // ── Interactive Top 3 Podium ─────────────────
                      if (top3.isNotEmpty && _ctrl.searchQuery.value.isEmpty) ...[
                        _AdminPodium(
                          top3: top3,
                          dark: dark,
                          onGrantReward: (entry) => GrantRewardDialog.show(
                            context,
                            entry: entry,
                            controller: _ctrl,
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceBtwSections),
                      ],

                      // ── Leaderboard Standings Table ───────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            top3.isNotEmpty && _ctrl.searchQuery.value.isEmpty
                              ? 'Remaining Standings (#4 - #${entries.length})'
                              : 'Standings (${entries.length} Students)',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            'Sorted by Score & Speed',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.sm),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rest.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, idx) {
                          final entry = rest[idx];
                          return _ModernLeaderboardRow(
                            entry: entry,
                            isChallengeView: isChallengeView,
                            onGrantReward: () => GrantRewardDialog.show(
                              context,
                              entry: entry,
                              controller: _ctrl,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        );
      }),
    );
  }
}

// ── KPI Stat Card Widget ─────────────────────────────────────────────────────

class _KpiStatCard extends StatelessWidget {
  const _KpiStatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color,
              ),
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

// ── View Tab Pill ────────────────────────────────────────────────────────────

class _ViewPill extends StatelessWidget {
  const _ViewPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : (dark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin Podium View (Top 3) ────────────────────────────────────────────────

class _AdminPodium extends StatelessWidget {
  const _AdminPodium({
    required this.top3,
    required this.dark,
    required this.onGrantReward,
  });

  final List<ChallengeLeaderboardEntry> top3;
  final bool dark;
  final ValueChanged<ChallengeLeaderboardEntry> onGrantReward;

  @override
  Widget build(BuildContext context) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Container(
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.medal_star_copy, color: Color(0xFFFFD700), size: 18),
              SizedBox(width: 6),
              Text(
                'Top 3 National Podium',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place (Silver)
              if (second != null)
                Expanded(
                  child: _AdminPodiumStep(
                    entry: second,
                    rank: 2,
                    color: const Color(0xFF94A3B8),
                    height: 120,
                    dark: dark,
                    onGrantReward: () => onGrantReward(second),
                  ),
                )
              else
                const Spacer(),

              const SizedBox(width: 8),

              // 1st Place (Gold)
              if (first != null)
                Expanded(
                  child: _AdminPodiumStep(
                    entry: first,
                    rank: 1,
                    color: const Color(0xFFF59E0B),
                    height: 150,
                    isFirst: true,
                    dark: dark,
                    onGrantReward: () => onGrantReward(first),
                  ),
                )
              else
                const Spacer(),

              const SizedBox(width: 8),

              // 3rd Place (Bronze)
              if (third != null)
                Expanded(
                  child: _AdminPodiumStep(
                    entry: third,
                    rank: 3,
                    color: const Color(0xFFD97706),
                    height: 105,
                    dark: dark,
                    onGrantReward: () => onGrantReward(third),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminPodiumStep extends StatelessWidget {
  const _AdminPodiumStep({
    required this.entry,
    required this.rank,
    required this.color,
    required this.height,
    this.isFirst = false,
    required this.dark,
    required this.onGrantReward,
  });

  final ChallengeLeaderboardEntry entry;
  final int rank;
  final Color color;
  final double height;
  final bool isFirst;
  final bool dark;
  final VoidCallback onGrantReward;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: isFirst ? 24 : 20,
              backgroundColor: color.withValues(alpha: 0.25),
              child: CircleAvatar(
                radius: isFirst ? 21 : 17,
                backgroundColor: color,
                child: Text(
                  entry.firstName.isNotEmpty ? entry.firstName[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            if (isFirst)
              const Positioned(
                top: -12,
                child: Icon(Iconsax.crown_copy, color: Color(0xFFFFD700), size: 18),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          entry.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isFirst ? 12 : 11,
          ),
        ),
        Text(
          '${entry.score} pts',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: isFirst ? 12.5 : 11,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          entry.formattedTime,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),

        // Step Pillar
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.06),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: isFirst ? 24 : 18,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onGrantReward,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Iconsax.gift_copy, size: 11),
                    SizedBox(width: 2),
                    Text('Reward', style: TextStyle(fontSize: 9.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Modern Standings Row ─────────────────────────────────────────────────────

class _ModernLeaderboardRow extends StatelessWidget {
  const _ModernLeaderboardRow({
    required this.entry,
    required this.isChallengeView,
    required this.onGrantReward,
  });

  final ChallengeLeaderboardEntry entry;
  final bool isChallengeView;
  final VoidCallback onGrantReward;

  Color _rankColor() {
    if (entry.rank == 1) return const Color(0xFFFFD700);
    if (entry.rank == 2) return const Color(0xFF94A3B8);
    if (entry.rank == 3) return const Color(0xFFD97706);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final isTop3 = entry.rank <= 3;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        side: BorderSide(
          color: isTop3
              ? _rankColor().withValues(alpha: 0.4)
              : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
          width: isTop3 ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 620;

            final rankBadge = Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTop3
                    ? _rankColor().withValues(alpha: 0.18)
                    : (dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.15)),
                shape: BoxShape.circle,
              ),
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: isTop3 ? _rankColor() : (dark ? Colors.white : Colors.black87),
                ),
              ),
            );

            final studentInfo = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (entry.stream == 'social' ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${entry.stream.toUpperCase()} STREAM',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: entry.stream == 'social' ? AppColors.secondary : AppColors.primary,
                        ),
                      ),
                    ),
                    // Copy User ID badge
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: entry.userId));
                        SnackbarHelper.info('Copied!', 'Student User ID: ${entry.userId}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy_rounded, size: 9, color: AppColors.textSecondary),
                            const SizedBox(width: 2),
                            Text(
                              'ID: ${entry.userId.length > 8 ? entry.userId.substring(0, 8) : entry.userId}...',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );

            final countsBreakdown = isChallengeView
                ? Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _CountChip(
                        label: '${entry.correctCount}',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        tooltip: 'Correct Answers',
                      ),
                      _CountChip(
                        label: '${entry.incorrectCount}',
                        icon: Icons.cancel_rounded,
                        color: AppColors.error,
                        tooltip: 'Incorrect Answers',
                      ),
                      if (entry.notDoneCount > 0)
                        _CountChip(
                          label: '${entry.notDoneCount}',
                          icon: Icons.remove_circle_outline_rounded,
                          color: AppColors.textSecondary,
                          tooltip: 'Unanswered',
                        ),
                    ],
                  )
                : Text(
                    '${entry.challengesTaken} challenges taken',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  );

            final scoreAndTime = Column(
              crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entry.score} pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppColors.primary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.clock_copy, size: 10, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      entry.formattedTime,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            );

            final grantButton = FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onGrantReward,
              icon: const Icon(Iconsax.gift_copy, size: 13),
              label: const Text('Reward', style: TextStyle(fontSize: 11)),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      rankBadge,
                      const SizedBox(width: AppSizes.sm),
                      Expanded(child: studentInfo),
                    ],
                  ),
                  const SizedBox(height: 8),
                  countsBreakdown,
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      scoreAndTime,
                      grantButton,
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                rankBadge,
                const SizedBox(width: AppSizes.md),
                Expanded(flex: 3, child: studentInfo),
                const SizedBox(width: AppSizes.sm),
                Expanded(flex: 3, child: countsBreakdown),
                const SizedBox(width: AppSizes.sm),
                scoreAndTime,
                const SizedBox(width: AppSizes.md),
                grantButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
