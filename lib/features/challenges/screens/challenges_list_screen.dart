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
            // ── Top Header Toolbar ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                border: Border.all(
                  color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title + Live Count Badge
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.cup_copy, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'National Challenges',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Obx(() {
                        if (_ctrl.liveCount == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_ctrl.liveCount} LIVE',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),

                  // Actions: Create Challenge & Refresh
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          final ok = await Get.to(() => const ChallengeEditorScreen());
                          if (ok == true || ok is String) {
                            _ctrl.loadChallenges();
                          }
                        },
                        icon: const Icon(Iconsax.add_circle_copy, size: 15),
                        label: const Text('Create Challenge', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Refresh from Supabase',
                        visualDensity: VisualDensity.compact,
                        icon: Obx(
                          () => _ctrl.isRefreshing.value
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                        ),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _ctrl.loadAll(showLoading: false);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Search & Filter Bar ─────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 6),
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
                    // Search bar
                    SizedBox(
                      width: 210,
                      height: 32,
                      child: TextField(
                        controller: _ctrl.searchCtrl,
                        onChanged: _ctrl.onSearch,
                        autofocus: false,
                        style: const TextStyle(fontSize: 11.5),
                        decoration: InputDecoration(
                          hintText: 'Search title, subject, ID...',
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

            const SizedBox(height: 6),

            // ── Main Challenges List ────────────────────────────────
            Expanded(
              child: Obx(() {
                if (_ctrl.isLoading.value && _ctrl.challenges.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final list = _ctrl.filteredChallenges;

                if (list.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => _ctrl.loadAll(showLoading: false),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.cup_copy, size: 44, color: dark ? Colors.white24 : AppColors.textSecondary),
                            const SizedBox(height: AppSizes.md),
                            const Text('No challenges found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text(
                              'Create a new challenge or adjust your filters above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSizes.md),
                            FilledButton.icon(
                              onPressed: () => Get.to(() => const ChallengeEditorScreen()),
                              icon: const Icon(Iconsax.add_circle_copy, size: 15),
                              label: const Text('Create Challenge'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => _ctrl.loadAll(showLoading: false),
                  child: Scrollbar(
                    controller: _scrollCtrl,
                    child: ListView.separated(
                      controller: _scrollCtrl,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final c = list[idx];
                        return _ChallengeRoundCard(
                          challenge: c,
                          dateFormat: _dateFormat,
                          dark: dark,
                          onEdit: () async {
                            final ok = await Get.to(() => ChallengeEditorScreen(challengeId: c.id));
                            if (ok == true || ok is String) _ctrl.loadChallenges();
                          },
                          onDelete: () => _confirmDeleteChallenge(c),
                        );
                      },
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

  Future<void> _confirmDeleteChallenge(LeaderboardChallengeModel c) async {
    final confirmed = await AppDialogBoxes.confirm(
      title: 'Delete Challenge',
      message: 'Are you sure you want to delete "${c.title}"? All student attempts, leaderboard rankings, and questions will also be removed.',
      isDestructive: true,
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      _ctrl.deleteChallenge(c.id);
    }
  }
}

// ── Helpers & Components ─────────────────────────────────────────────────────

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'live':
      return const Color(0xFF10B981);
    case 'scheduled':
      return const Color(0xFF3B82F6);
    case 'closed':
    case 'archived':
      return const Color(0xFF8B5CF6);
    case 'draft':
    default:
      return const Color(0xFF6B7280);
  }
}

// ── Challenge Round Card ─────────────────────────────────────────────────────

class _ChallengeRoundCard extends StatelessWidget {
  const _ChallengeRoundCard({
    required this.challenge,
    required this.dateFormat,
    required this.dark,
    required this.onEdit,
    required this.onDelete,
  });

  final LeaderboardChallengeModel challenge;
  final DateFormat dateFormat;
  final bool dark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusCol = _statusColor(challenge.status);

    return Card(
      elevation: challenge.isLive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        side: BorderSide(
          color: challenge.isLive ? statusCol : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
          width: challenge.isLive ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Status Badge + Audience Badge + Copy ID
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: statusCol.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusCol.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    challenge.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: statusCol,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: (challenge.audience == 'social' ? AppColors.secondary : AppColors.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${challenge.audience.toUpperCase()} STREAM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: challenge.audience == 'social' ? AppColors.secondary : AppColors.primary,
                    ),
                  ),
                ),
                // One-tap copy ID
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: challenge.id));
                    SnackbarHelper.info('Copied!', 'Challenge ID copied to clipboard');
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
              '${challenge.subjectName ?? 'Subject'} • Duration: ${challenge.durationMinutes} mins',
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
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onEdit,
                  icon: const Icon(Iconsax.edit_2_copy, size: 12),
                  label: const Text('Edit & Questions', style: TextStyle(fontSize: 10.5)),
                ),
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
