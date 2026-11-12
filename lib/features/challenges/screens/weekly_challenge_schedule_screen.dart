import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/controllers/challenges_list_controller.dart';
import 'package:m_admin/features/challenges/models/weekly_challenge_schedule_model.dart';
import 'package:m_admin/features/challenges/screens/subject_challenges_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Screen displaying the clean weekly challenge timetable for MatricMate.
///
/// Timetable:
/// - Monday: English (Common)
/// - Tuesday: Mathematics (Natural) & Mathematics (Social)
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
      // Graceful fallback
    } finally {
      _isLoadingSubjects.value = false;
    }
  }

  /// Redirects to the list of draft challenges for that subject with an additional Create Challenge button.
  void _openDraftChallengesForSubject(WeeklySubjectTarget target, String dayName) {
    final match = target.resolveSubject(_subjects);
    final subId = match != null
        ? ((match['id'] as num?)?.toInt() ?? int.tryParse(match['id']?.toString() ?? '') ?? 0)
        : 0;
    final subName = match != null ? (match['name']?.toString() ?? target.name) : target.name;
    final isNat = target.audience == 'natural' || (match?['is_natural'] == true);
    final isCom = target.audience == 'both' || (match?['is_common'] == true);

    Get.to(
      () => SubjectChallengesScreen(
        subjectId: subId,
        subjectName: subName,
        isNatural: isNat,
        isCommon: isCom,
        initialStatusFilter: 'draft',
      ),
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
        title: const Text('Challenge Schedule'),
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
            // ── Today Highlight Banner (Clean & Concise) ──────────────
            _buildTodayBanner(context, todaySchedule, dark),

            const SizedBox(height: 14),

            // ── Stream Tracks Overview (Clean) ───────────────────────
            _buildStreamTracksCard(context, dark),

            const SizedBox(height: 16),

            // ── Section Header ──────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Iconsax.calendar_tick_copy,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Weekly Competition Timetable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
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

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Clean highlight banner for today's scheduled challenge subject(s).
  Widget _buildTodayBanner(
    BuildContext context,
    WeeklyDaySchedule today,
    bool dark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: dark ? 0.35 : 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 11, color: Colors.white),
                    SizedBox(width: 2),
                    Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 9.5,
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
                  '${today.dayName} Scheduled Challenges',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (today.isRestDay)
            Row(
              children: [
                const Icon(Iconsax.cup_copy, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Weekly Review & Rest Day',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white70 : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: today.subjects.map((sub) {
                return FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: sub.color.withValues(alpha: dark ? 0.22 : 0.12),
                    foregroundColor: sub.color,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _openDraftChallengesForSubject(sub, today.dayName),
                  icon: Icon(sub.icon, size: 13),
                  label: Text(
                    'Create ${sub.name} Challenge',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Clean stream track breakdown without verbose paragraph text.
  Widget _buildStreamTracksCard(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(10),
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
          _buildTrackRow(
            trackName: 'Natural',
            badgeColor: AppColors.primary,
            subjects: 'English (Mon) • Maths (Tue) • Biology (Wed) • Chemistry (Thu) • Physics (Fri) • Aptitude (Sat)',
            dark: dark,
          ),
          const SizedBox(height: 6),
          _buildTrackRow(
            trackName: 'Social',
            badgeColor: AppColors.secondary,
            subjects: 'English (Mon) • Maths (Tue) • Economics (Wed) • Geography (Thu) • History (Fri) • Aptitude (Sat)',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: dark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              trackName,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subjects,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.25,
                color: dark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Day card showing the subjects assigned to that day in a clean, minimalist layout.
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
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 6,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isToday ? AppColors.primary : AppColors.grey).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  day.isRestDay
                      ? 'Rest Day'
                      : '${day.subjects.length} ${day.subjects.length == 1 ? 'Subject' : 'Subjects'}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isToday ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Rest Day row
          if (day.isRestDay)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF64748B).withValues(alpha: dark ? 0.08 : 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Iconsax.cup_copy, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Weekly Review & Rest',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else
            // Subject Rows with responsive LayoutBuilder (Zero overflow on any screen!)
            ...day.subjects.map((sub) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: sub.color.withValues(alpha: dark ? 0.08 : 0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: sub.color.withValues(alpha: 0.18),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final isCompact = cardConstraints.maxWidth < 450;
                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: sub.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(sub.icon, size: 14, color: sub.color),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          sub.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
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
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: sub.color.withValues(alpha: dark ? 0.22 : 0.12),
                                foregroundColor: sub.color,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _openDraftChallengesForSubject(sub, day.dayName),
                              icon: const Icon(Iconsax.add_circle_copy, size: 13),
                              label: const Text(
                                'Create Challenge',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: sub.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(sub.icon, size: 14, color: sub.color),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sub.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
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
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: sub.color.withValues(alpha: dark ? 0.22 : 0.12),
                              foregroundColor: sub.color,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _openDraftChallengesForSubject(sub, day.dayName),
                            icon: const Icon(Iconsax.add_circle_copy, size: 13),
                            label: const Text(
                              'Create Challenge',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
