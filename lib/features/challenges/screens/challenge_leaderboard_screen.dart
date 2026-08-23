import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/features/challenges/controllers/admin_leaderboard_controller.dart';
import 'package:m_admin/features/challenges/models/challenge_leaderboard_entry.dart';
import 'package:m_admin/features/challenges/screens/widgets/grant_reward_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

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
      body: Column(
        children: [
          // ── Controls & Filter Bar (Overflow-proof) ─────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: AppSizes.sm),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkCard : AppColors.white,
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
              runSpacing: 8,
              children: [
                // View Selector
                Obx(
                  () => SegmentedButton<String>(
                    segments: [
                      if (widget.challengeId != null)
                        const ButtonSegment(
                          value: 'challenge',
                          label: Text('This Challenge'),
                          icon: Icon(Iconsax.cup_copy, size: 14),
                        ),
                      const ButtonSegment(
                        value: 'weekly',
                        label: Text('Weekly'),
                        icon: Icon(Iconsax.calendar_1_copy, size: 14),
                      ),
                      const ButtonSegment(
                        value: 'monthly',
                        label: Text('Monthly'),
                        icon: Icon(Iconsax.calendar_copy, size: 14),
                      ),
                    ],
                    selected: {_ctrl.selectedView.value},
                    onSelectionChanged: (set) => _ctrl.setView(set.first),
                  ),
                ),

                // Stream Filter
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Stream: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(width: AppSizes.xs),
                    Obx(
                      () => DropdownButton<String>(
                        value: _ctrl.selectedStream.value,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Streams')),
                          DropdownMenuItem(value: 'natural', child: Text('Natural Stream')),
                          DropdownMenuItem(value: 'social', child: Text('Social Stream')),
                        ],
                        onChanged: (val) {
                          if (val != null) _ctrl.setStream(val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Leaderboard Table ─────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (_ctrl.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_ctrl.entries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.ranking_copy,
                        size: 48,
                        color: dark ? Colors.white24 : AppColors.textSecondary,
                      ),
                      const SizedBox(height: AppSizes.md),
                      const Text(
                        'No attempts submitted yet for this view.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      const Text(
                        'Once students complete their timed round, rankings will appear here automatically.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              return Scrollbar(
                controller: _scrollCtrl,
                child: ListView.separated(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(AppSizes.md),
                  itemCount: _ctrl.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
                  itemBuilder: (context, index) {
                    final entry = _ctrl.entries[index];
                    return _LeaderboardRow(
                      entry: entry,
                      isPeriodView: _ctrl.selectedView.value != 'challenge',
                      onGrantReward: () => GrantRewardDialog.show(
                        context,
                        entry: entry,
                        controller: _ctrl,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.isPeriodView,
    required this.onGrantReward,
  });

  final ChallengeLeaderboardEntry entry;
  final bool isPeriodView;
  final VoidCallback onGrantReward;

  Color _rankColor() {
    if (entry.rank == 1) return const Color(0xFFFFD700); // Gold
    if (entry.rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (entry.rank == 3) return const Color(0xFFCD7F32); // Bronze
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        side: BorderSide(
          color: entry.rank <= 3
              ? _rankColor().withValues(alpha: 0.5)
              : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
          width: entry.rank <= 3 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;

            final rankBadge = Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: entry.rank <= 3
                    ? _rankColor().withValues(alpha: 0.18)
                    : (dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.2)),
                shape: BoxShape.circle,
              ),
              child: Text(
                '#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: entry.rank <= 3 ? _rankColor() : (dark ? Colors.white : Colors.black87),
                ),
              ),
            );

            final studentInfo = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                Text(
                  '${entry.stream.toUpperCase()} Stream • ID: ${entry.userId.substring(0, entry.userId.length > 8 ? 8 : entry.userId.length)}...',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            );

            final countsBreakdown = !isPeriodView
                ? Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _CountChip(
                        label: '${entry.correctCount}',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        tooltip: 'Correct',
                      ),
                      _CountChip(
                        label: '${entry.incorrectCount}',
                        icon: Icons.cancel_rounded,
                        color: AppColors.error,
                        tooltip: 'Incorrect',
                      ),
                      _CountChip(
                        label: '${entry.notDoneCount}',
                        icon: Icons.remove_circle_outline_rounded,
                        color: AppColors.textSecondary,
                        tooltip: 'Unanswered / Not Done',
                      ),
                    ],
                  )
                : Text(
                    '${entry.challengesTaken} challenges taken',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                Text(
                  entry.formattedTime,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                ),
              ],
            );

            final grantButton = FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onGrantReward,
              icon: const Icon(Iconsax.gift_copy, size: 14),
              label: const Text('Grant Reward', style: TextStyle(fontSize: 11)),
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
                  const SizedBox(height: AppSizes.sm),
                  countsBreakdown,
                  const SizedBox(height: AppSizes.sm),
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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
