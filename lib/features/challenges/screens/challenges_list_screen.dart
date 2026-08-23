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
                      label: const Text('Create Challenge', style: TextStyle(fontSize: 12)),
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

            // ── Main Challenges List ────────────────────────────────
            Expanded(
              child: Obx(() {
                if (_ctrl.isLoading.value && _ctrl.challenges.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_ctrl.filteredChallenges.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.cup_copy, size: 48, color: dark ? Colors.white24 : AppColors.textSecondary),
                        const SizedBox(height: AppSizes.md),
                        const Text(
                          'No challenges found',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try clearing filters or create a new challenge round.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 24, top: 4),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 440,
                    mainAxisExtent: 185,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _ctrl.filteredChallenges.length,
                  itemBuilder: (context, index) {
                    final challenge = _ctrl.filteredChallenges[index];
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
                      onDelete: () => _confirmDelete(context, challenge),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
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

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.dateFormat,
    required this.onEdit,
    required this.onNotify,
    required this.onDelete,
  });

  final LeaderboardChallengeModel challenge;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onNotify;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    Color statusBadgeColor;
    switch (challenge.status.toLowerCase()) {
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
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onNotify,
                  icon: const Icon(Icons.notifications_active_outlined, size: 12, color: Color(0xFF8B5CF6)),
                  label: const Text('Notify', style: TextStyle(fontSize: 10.5, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
                ),
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
