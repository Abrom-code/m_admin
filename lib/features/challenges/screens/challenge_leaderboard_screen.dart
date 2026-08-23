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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.challengeTitle ?? 'Challenge Leaderboard'),
          actions: [
            IconButton(
              tooltip: 'Refresh Standings',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _ctrl.refreshLeaderboard();
              },
            ),
            const SizedBox(width: AppSizes.sm),
          ],
        ),
        body: Obx(() {
          final entries = _ctrl.filteredEntries;
          final isChallengeView = _ctrl.selectedView.value == 'challenge';
          final hasEntries = entries.isNotEmpty;

          return Column(
            children: [
              // ── Single Clean, Streamlined Header Bar ────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: 12),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkCard : AppColors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Row 1: View Period Tabs & Stream Filter
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        // Clean View Tabs
                        Container(
                          decoration: BoxDecoration(
                            color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.challengeId != null)
                                _CleanPill(
                                  selected: _ctrl.selectedView.value == 'challenge',
                                  icon: Iconsax.cup_copy,
                                  label: 'This Round',
                                  onTap: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    _ctrl.setView('challenge');
                                  },
                                ),
                              _CleanPill(
                                selected: _ctrl.selectedView.value == 'weekly',
                                icon: Iconsax.calendar_1_copy,
                                label: 'Weekly',
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  _ctrl.setView('weekly');
                                },
                              ),
                              _CleanPill(
                                selected: _ctrl.selectedView.value == 'monthly',
                                icon: Iconsax.calendar_copy,
                                label: 'Monthly',
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  _ctrl.setView('monthly');
                                },
                              ),
                            ],
                          ),
                        ),

                        // Stream Chips
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Stream: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ...['all', 'natural', 'social'].map((st) {
                              final isSel = _ctrl.selectedStream.value == st;
                              return ChoiceChip(
                                label: Text(
                                  st == 'all' ? 'All' : (st == 'natural' ? 'Natural' : 'Social'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel
                                        ? (st == 'social' ? AppColors.secondary : AppColors.primary)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: (st == 'social' ? AppColors.secondary : AppColors.primary)
                                    .withValues(alpha: 0.15),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onSelected: (_) {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  _ctrl.setStream(st);
                                },
                              );
                            }),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Row 2: Search Bar & Quick Stats Tag
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: false,
                              onChanged: (v) => _ctrl.searchQuery.value = v,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Search student name, ID or rank...',
                                hintStyle: const TextStyle(fontSize: 12),
                                prefixIcon: const Icon(Iconsax.search_normal_copy, size: 16),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _ctrl.searchQuery.value = '';
                                          FocusManager.instance.primaryFocus?.unfocus();
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                                  borderSide: BorderSide(
                                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (hasEntries) ...[
                          const SizedBox(width: AppSizes.md),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Iconsax.profile_2user_copy, size: 14, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Text(
                                  '${_ctrl.totalParticipants} students',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (_ctrl.topScore > 0) ...[
                                  const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                                  Text(
                                    'Top: ${_ctrl.topScore} pts',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Clean Standings List with Generous Padding ──────────
              Expanded(
                child: Builder(builder: (context) {
                  if (_ctrl.isLoading.value && _ctrl.entries.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!hasEntries) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Iconsax.ranking_copy, size: 44, color: AppColors.primary),
                            ),
                            const SizedBox(height: AppSizes.md),
                            const Text(
                              'No student attempts recorded yet',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Standings will automatically populate as students submit their challenge rounds.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Scrollbar(
                    controller: _scrollCtrl,
                    child: ListView.separated(
                      controller: _scrollCtrl,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(AppSizes.lg),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final entry = entries[idx];
                        return _CleanLeaderboardTile(
                          entry: entry,
                          isChallengeView: isChallengeView,
                          onGrantReward: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            GrantRewardDialog.show(
                              context,
                              entry: entry,
                              controller: _ctrl,
                            );
                          },
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Clean View Tab Pill ──────────────────────────────────────────────────────

class _CleanPill extends StatelessWidget {
  const _CleanPill({
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
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (dark ? AppColors.darkCard : AppColors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
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
              size: 13,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
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

// ── Clean Standings Tile ─────────────────────────────────────────────────────

class _CleanLeaderboardTile extends StatelessWidget {
  const _CleanLeaderboardTile({
    required this.entry,
    required this.isChallengeView,
    required this.onGrantReward,
  });

  final ChallengeLeaderboardEntry entry;
  final bool isChallengeView;
  final VoidCallback onGrantReward;

  Color _rankBadgeColor() {
    if (entry.rank == 1) return const Color(0xFFFFD700); // Gold
    if (entry.rank == 2) return const Color(0xFF94A3B8); // Silver
    if (entry.rank == 3) return const Color(0xFFD97706); // Bronze
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final isTop3 = entry.rank <= 3;
    final badgeColor = _rankBadgeColor();

    return Card(
      elevation: isTop3 ? 1.5 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        side: BorderSide(
          color: isTop3 ? badgeColor.withValues(alpha: 0.5) : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
          width: isTop3 ? 1.5 : 1.0,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          gradient: isTop3
              ? LinearGradient(
                  colors: [
                    badgeColor.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 640;

            // Rank Badge
            final rankWidget = Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTop3
                    ? badgeColor.withValues(alpha: 0.16)
                    : (dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.14)),
                shape: BoxShape.circle,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.rank == 1)
                    const Icon(Iconsax.crown_copy, size: 13, color: Color(0xFFFFD700))
                  else
                    Text(
                      '#${entry.rank}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isTop3 ? badgeColor : (dark ? Colors.white : Colors.black87),
                      ),
                    ),
                ],
              ),
            );

            // Student Information
            final studentInfo = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (entry.stream == 'social' ? AppColors.secondary : AppColors.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.stream.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: entry.stream == 'social' ? AppColors.secondary : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Copy User ID Button
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.userId));
                    SnackbarHelper.info('Copied!', 'Student User ID: ${entry.userId}');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_rounded, size: 10, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        'ID: ${entry.userId.length > 8 ? entry.userId.substring(0, 8) : entry.userId}...',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            // Accuracy Breakdown
            final countsBreakdown = isChallengeView
                ? Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _StatChip(
                        label: '${entry.correctCount}',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        tooltip: 'Correct Answers',
                      ),
                      _StatChip(
                        label: '${entry.incorrectCount}',
                        icon: Icons.cancel_rounded,
                        color: AppColors.error,
                        tooltip: 'Incorrect Answers',
                      ),
                      if (entry.notDoneCount > 0)
                        _StatChip(
                          label: '${entry.notDoneCount}',
                          icon: Icons.remove_circle_outline_rounded,
                          color: AppColors.textSecondary,
                          tooltip: 'Unanswered',
                        ),
                    ],
                  )
                : Text(
                    '${entry.challengesTaken} rounds completed',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  );

            // Score & Time
            final scoreWidget = Column(
              crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${entry.score} pts',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.clock_copy, size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      entry.formattedTime,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            );

            // Reward Action Button
            final rewardButton = FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onGrantReward,
              icon: const Icon(Iconsax.gift_copy, size: 13),
              label: const Text('Reward', style: TextStyle(fontSize: 11.5)),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      rankWidget,
                      const SizedBox(width: AppSizes.md),
                      Expanded(child: studentInfo),
                    ],
                  ),
                  const SizedBox(height: 8),
                  countsBreakdown,
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      scoreWidget,
                      rewardButton,
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                rankWidget,
                const SizedBox(width: AppSizes.md),
                Expanded(flex: 3, child: studentInfo),
                const SizedBox(width: AppSizes.sm),
                Expanded(flex: 2, child: countsBreakdown),
                const SizedBox(width: AppSizes.sm),
                scoreWidget,
                const SizedBox(width: AppSizes.md),
                rewardButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
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
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
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
