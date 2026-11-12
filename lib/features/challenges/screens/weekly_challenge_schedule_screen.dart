import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/controllers/challenges_list_controller.dart';
import 'package:m_admin/features/challenges/models/weekly_challenge_schedule_model.dart';
import 'package:m_admin/features/challenges/screens/challenge_editor_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Screen displaying the official weekly challenge timetable for MatricMate.
///
/// Timetable:
/// - Monday: English (Common)
/// - Tuesday: Maths (Common)
/// - Wednesday: Biology (Natural) & Economics (Social)
/// - Thursday: Chemistry (Natural) & Geography (Social)
/// - Friday: Physics (Natural) & History (Social)
/// - Saturday: Aptitude (Common)
/// - Sunday: Rest & Weekly Recap
class WeeklyChallengeScheduleScreen extends StatefulWidget {
  const WeeklyChallengeScheduleScreen({super.key, this.repository});

  final ChallengeRepository? repository;

  @override
  State<WeeklyChallengeScheduleScreen> createState() =>
      _WeeklyChallengeScheduleScreenState();
}

class _WeeklyChallengeScheduleScreenState
    extends State<WeeklyChallengeScheduleScreen> {
  ChallengeRepository? _repoInstance;
  ChallengeRepository? get _repo {
    if (widget.repository != null) return widget.repository;
    try {
      return _repoInstance ??= ChallengeRepository();
    } catch (_) {
      return null;
    }
  }

  final _subjects = <Map<String, dynamic>>[].obs;
  final _isLoadingSubjects = false.obs;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    // Re-use already loaded subjects from controller if present
    if (Get.isRegistered<ChallengesListController>()) {
      final ctrl = Get.find<ChallengesListController>();
      if (ctrl.subjects.isNotEmpty) {
        _subjects.assignAll(ctrl.subjects);
        return;
      }
    }

    try {
      _isLoadingSubjects.value = true;
      final repo = _repo;
      if (repo != null) {
        final fetched = await repo.fetchSubjects();
        _subjects.assignAll(fetched);
      }
    } catch (_) {
      // Graceful fallback to name matching (e.g. offline or test environment)
    } finally {
      _isLoadingSubjects.value = false;
    }
  }

  void _createChallengeForSubject(WeeklySubjectTarget target, String dayName) {
    final subId = target.resolveSubjectId(_subjects);
    Get.to(
      () => ChallengeEditorScreen(
        initialSubjectId: subId,
        initialAudience: target.audience,
      ),
    );
    SnackbarHelper.info(
      'Drafting Challenge',
      'Creating $dayName ${target.name} Challenge (${target.stream})',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final nowEat = EthiopianTimeHelper.nowInEastAfrica();
    final currentWeekday = nowEat.weekday;
    final todaySchedule = WeeklyDaySchedule.forWeekday(currentWeekday);
    final days = WeeklyDaySchedule.defaultSchedule;

    return Scaffold(
      backgroundColor: dark ? AppColors.dark : AppColors.light,
      appBar: AppBar(
        title: const Text('Weekly Challenge Schedule'),
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_copy, size: 20),
          tooltip: 'Back',
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadSubjects,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Today Highlight Banner ──────────────────────────────
            _buildTodayBanner(context, todaySchedule, dark),

            const SizedBox(height: 16),

            // ── Stream Tracks Overview ──────────────────────────────
            _buildStreamTracksCard(context, dark),

            const SizedBox(height: 20),

            // ── Section Header ──────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Iconsax.calendar_tick_copy,
                    size: 15,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Full Weekly Competition Timetable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── 7-Day Timetable Cards ───────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                // Wide screens (>= 900) use a 2-column masonry; narrow screens use single column
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  final leftCol = <WeeklyDaySchedule>[];
                  final rightCol = <WeeklyDaySchedule>[];
                  for (var i = 0; i < days.length; i++) {
                    if (i % 2 == 0) {
                      leftCol.add(days[i]);
                    } else {
                      rightCol.add(days[i]);
                    }
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: leftCol
                              .map(
                                (day) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildDayCard(
                                    context,
                                    day,
                                    day.weekday == currentWeekday,
                                    dark,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: rightCol
                              .map(
                                (day) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildDayCard(
                                    context,
                                    day,
                                    day.weekday == currentWeekday,
                                    dark,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final isToday = day.weekday == currentWeekday;
                    return _buildDayCard(context, day, isToday, dark);
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Helpful Notes & Competition Guidelines ───────────────
            _buildGuidelinesCard(context, dark),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Highlight banner for the current day's competition schedule.
  Widget _buildTodayBanner(
    BuildContext context,
    WeeklyDaySchedule today,
    bool dark,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [
                  const Color(0xFF0F766E).withValues(alpha: 0.45),
                  const Color(0xFF0D9488).withValues(alpha: 0.20),
                ]
              : [
                  const Color(0xFFCCFBF1),
                  const Color(0xFFE0F2FE),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: dark ? 0.4 : 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${today.dayName} Competition Schedule',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            today.isRestDay
                ? 'Sunday is designated for weekly review, leaderboard standings analysis, and student rest.'
                : 'Today’s scheduled challenge subject${today.subjects.length > 1 ? 's' : ''}: '
                    '${today.subjects.map((s) => '${s.name} (${s.stream})').join(' and ')}.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: dark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          if (!today.isRestDay) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: today.subjects.map((sub) {
                return FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: sub.color,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _createChallengeForSubject(sub, today.dayName),
                  icon: Icon(sub.icon, size: 13),
                  label: Text(
                    'Schedule ${sub.name}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Displays the Natural & Social tracks side by side.
  Widget _buildStreamTracksCard(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Iconsax.routing_copy, size: 14, color: Color(0xFF0284C7)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Stream Schedules at a Glance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTrackRow(
            trackName: 'Natural Science',
            badgeColor: AppColors.primary,
            subjects: 'English (Mon) → Maths (Tue) → Biology (Wed) → Chemistry (Thu) → Physics (Fri) → Aptitude (Sat)',
            dark: dark,
          ),
          const SizedBox(height: 6),
          _buildTrackRow(
            trackName: 'Social Science',
            badgeColor: AppColors.secondary,
            subjects: 'English (Mon) → Maths (Tue) → Economics (Wed) → Geography (Thu) → History (Fri) → Aptitude (Sat)',
            dark: dark,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackRow({
    required String trackName,
    required Color badgeColor,
    required String subjects,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: dark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              trackName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subjects,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: dark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Day card showing the subjects assigned to that day.
  Widget _buildDayCard(
    BuildContext context,
    WeeklyDaySchedule day,
    bool isToday,
    bool dark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: isToday
              ? AppColors.primary
              : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
          width: isToday ? 1.5 : 1.0,
        ),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Day Header Row
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        day.dayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isToday ? AppColors.primary : null,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TODAY',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                day.isRestDay
                    ? 'Rest & Recap'
                    : '${day.subjects.length} ${day.subjects.length == 1 ? 'Subject' : 'Subjects'}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isToday ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Subject Rows
          ...day.subjects.map((sub) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sub.color.withValues(alpha: dark ? 0.08 : 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sub.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: sub.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(sub.icon, size: 16, color: sub.color),
                    ),
                    const SizedBox(width: 8),

                    // Name + Stream + Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: 5,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                sub.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: sub.color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sub.stream,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: sub.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sub.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: dark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Schedule Button
                    if (!day.isRestDay) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Create challenge for ${sub.name}',
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: sub.color.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _createChallengeForSubject(sub, day.dayName),
                          child: Text(
                            '+ Schedule',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sub.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Bottom guidance card explaining the scheduling rules.
  Widget _buildGuidelinesCard(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Iconsax.info_circle_copy, size: 14, color: AppColors.primary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Competition Rules & Publishing Guidelines',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildBullet(
            'Common Subjects (Monday, Tuesday, Saturday)',
            'English, Mathematics, and Aptitude challenges are open to all students across Natural and Social streams.',
            dark,
          ),
          const SizedBox(height: 4),
          _buildBullet(
            'Stream Subjects (Wednesday, Thursday, Friday)',
            'Natural students compete in Biology, Chemistry, and Physics. Social students compete in Economics, Geography, and History.',
            dark,
          ),
          const SizedBox(height: 4),
          _buildBullet(
            'Standard Launch Window',
            'Rounds typically start at 8:00 PM (2:00 PM Ethiopian local time) in East Africa Time (UTC+3) and run for 48 hours before closing.',
            dark,
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String title, String body, bool dark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                color: dark ? Colors.white70 : AppColors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
