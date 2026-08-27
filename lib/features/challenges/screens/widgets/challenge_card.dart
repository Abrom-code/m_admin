import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/features/challenges/screens/challenge_leaderboard_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
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
        audienceLabel = 'Natural';
        break;
      case 'social':
        audienceBadgeColor = AppColors.secondary;
        audienceLabel = 'Social';
        break;
      default:
        audienceBadgeColor = const Color(0xFF0284C7);
        audienceLabel = 'Common';
    }

    final shortId = challenge.id.length > 8 ? challenge.id.substring(0, 8) : challenge.id;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        side: BorderSide(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
          width: 1,
        ),
      ),
      color: dark ? AppColors.darkCard : AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Row 1: Header (Badges + ID Pill + Delete Button) ──
            Row(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: statusBadgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    challenge.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: statusBadgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // Audience Stream Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: audienceBadgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    audienceLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: audienceBadgeColor,
                    ),
                  ),
                ),

                const Spacer(),

                // Copy ID pill
                Tooltip(
                  message: 'Click to copy full ID',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: challenge.id));
                      SnackbarHelper.success('Copied', 'Challenge ID copied to clipboard');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, size: 9, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            shortId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Compact Delete action
                Tooltip(
                  message: 'Delete Challenge',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        Iconsax.trash_copy,
                        size: 13,
                        color: AppColors.error.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Row 2: Challenge Title ──
            Tooltip(
              message: challenge.title,
              child: Text(
                challenge.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // ── Row 3: Important Metadata Pills/Info ──
            Row(
              children: [
                // Subject name
                const Icon(Iconsax.book_1_copy, size: 11, color: AppColors.primary),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    challenge.subjectName ?? 'Subject',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                const Text('•', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(width: 6),

                // Duration
                const Icon(Iconsax.clock_copy, size: 11, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  '${challenge.durationMinutes}m',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),

                const SizedBox(width: 6),
                const Text('•', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                const SizedBox(width: 6),

                // Question Count
                const Icon(Iconsax.document_text_copy, size: 11, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  '${challenge.questionCount} Qs',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),

                if (challenge.attemptCount > 0) ...[
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const SizedBox(width: 6),
                  const Icon(Iconsax.user_copy, size: 11, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    '${challenge.attemptCount}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),

            // ── Row 4: Timing Window & Action Buttons ──
            Row(
              children: [
                // Timing Window
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Iconsax.calendar_1_copy, size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          challenge.startsAt != null && challenge.endsAt != null
                              ? '${EthiopianTimeHelper.formatDateTimeWithEth(challenge.startsAt!)} → ${EthiopianTimeHelper.formatDateTimeWithEth(challenge.endsAt!)}'
                              : (challenge.startsAt != null
                                  ? 'Starts ${EthiopianTimeHelper.formatDateTimeWithEth(challenge.startsAt!)}'
                                  : 'No schedule set'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Action Buttons Row (single-line, ultra compact)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Notify button (Only for live/scheduled)
                    if (!isClosed && !isDraft) ...[
                      Tooltip(
                        message: 'Notify Students',
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                          ),
                          onPressed: onNotify,
                          icon: const Icon(Icons.notifications_active_outlined, size: 11, color: Color(0xFF0284C7)),
                          label: const Text(
                            'Notify',
                            style: TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    // 2. Edit button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onEdit,
                      icon: const Icon(Iconsax.edit_2_copy, size: 11),
                      label: const Text('Edit', style: TextStyle(fontSize: 10)),
                    ),

                    const SizedBox(width: 4),

                    // 3. Publish (Draft/Scheduled) OR Leaderboard (Live/Closed)
                    if (isScheduled || isDraft)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onPublish,
                        icon: const Icon(Iconsax.send_1_copy, size: 11),
                        label: const Text('Publish', style: TextStyle(fontSize: 10)),
                      )
                    else
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => Get.to(
                          () => ChallengeLeaderboardScreen(
                            challengeId: challenge.id,
                            challengeTitle: challenge.title,
                          ),
                        ),
                        icon: const Icon(Iconsax.ranking_copy, size: 11, color: Color(0xFF0284C7)),
                        label: const Text('Leaderboard', style: TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
