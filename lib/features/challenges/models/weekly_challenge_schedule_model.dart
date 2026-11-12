import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Single subject target assigned to a day in the weekly schedule.
class WeeklySubjectTarget {
  const WeeklySubjectTarget({
    required this.name,
    required this.stream,
    required this.audience,
    required this.icon,
    required this.color,
    this.description = '',
  });

  final String name;
  final String stream; // 'Common (Both Streams)', 'Natural Science', 'Social Science'
  final String audience; // 'both', 'natural', 'social'
  final IconData icon;
  final Color color;
  final String description;

  /// Matches the database subject map from the loaded subjects list.
  Map<String, dynamic>? resolveSubject(List<Map<String, dynamic>> subjects) {
    final clean = name.toLowerCase().trim();

    // First pass: stream-specific match for Mathematics and specific subject names
    final specificMatch = subjects.cast<Map<String, dynamic>?>().firstWhere(
      (s) {
        if (s == null) return false;
        final sName = (s['name']?.toString() ?? '').toLowerCase().trim();
        final isNat = s['is_natural'] == true || s['is_natural'] == 1 || s['is_natural'] == 'true';
        final isCom = s['is_common'] == true || s['is_common'] == 1 || s['is_common'] == 'true';

        if (clean.contains('math')) {
          if (audience == 'natural') {
            if (sName.contains('natural') && sName.contains('math')) return true;
            if (isNat && !isCom && sName.contains('math')) return true;
          } else if (audience == 'social') {
            if (sName.contains('social') && sName.contains('math')) return true;
            if (!isNat && !isCom && sName.contains('math')) return true;
          }
          return false;
        }

        if (sName == clean) return true;
        if (clean.contains('english') && sName.contains('english')) return true;
        if (clean.contains('biology') && sName.contains('bio')) return true;
        if (clean.contains('economics') && sName.contains('econ')) return true;
        if (clean.contains('chemistry') && sName.contains('chem')) return true;
        if (clean.contains('geography') && sName.contains('geo')) return true;
        if (clean.contains('physics') && sName.contains('phys')) return true;
        if (clean.contains('history') && sName.contains('hist')) return true;
        if (clean.contains('aptitude') &&
            (sName.contains('aptitude') || sName.contains('sat'))) {
          return true;
        }
        return false;
      },
      orElse: () => null,
    );

    if (specificMatch != null) return specificMatch;

    // Second pass: fallback for generic Mathematics when stream-specific subject is not configured in DB
    if (clean.contains('math')) {
      return subjects.cast<Map<String, dynamic>?>().firstWhere(
        (s) {
          if (s == null) return false;
          final sName = (s['name']?.toString() ?? '').toLowerCase().trim();
          return sName.contains('math');
        },
        orElse: () => null,
      );
    }

    return null;
  }

  /// Matches the database subject ID from the loaded subjects list.
  int? resolveSubjectId(List<Map<String, dynamic>> subjects) {
    final match = resolveSubject(subjects);
    if (match == null) return null;
    return (match['id'] as num?)?.toInt() ?? int.tryParse(match['id']?.toString() ?? '');
  }
}

/// Day entry in the weekly challenge schedule.
class WeeklyDaySchedule {
  const WeeklyDaySchedule({
    required this.weekday,
    required this.dayName,
    required this.shortName,
    required this.subjects,
    this.isRestDay = false,
  });

  final int weekday; // 1 = Monday ... 7 = Sunday (matching DateTime.monday .. DateTime.sunday)
  final String dayName;
  final String shortName;
  final List<WeeklySubjectTarget> subjects;
  final bool isRestDay;

  /// Returns the canonical weekly competition schedule for MatricMate.
  static List<WeeklyDaySchedule> get defaultSchedule => const [
        WeeklyDaySchedule(
          weekday: DateTime.monday,
          dayName: 'Monday',
          shortName: 'Mon',
          subjects: [
            WeeklySubjectTarget(
              name: 'English',
              stream: 'Common (Both Streams)',
              audience: 'both',
              icon: Iconsax.book_1_copy,
              color: Color(0xFF3B82F6),
              description: 'Grammar, reading comprehension & vocabulary.',
            ),
          ],
        ),
        WeeklyDaySchedule(
          weekday: DateTime.tuesday,
          dayName: 'Tuesday',
          shortName: 'Tue',
          subjects: [
            WeeklySubjectTarget(
              name: 'Mathematics (Natural)',
              stream: 'Natural Science',
              audience: 'natural',
              icon: Icons.calculate_rounded,
              color: Color(0xFF8B5CF6),
              description: 'Algebra, calculus, vectors & coordinate geometry.',
            ),
            WeeklySubjectTarget(
              name: 'Mathematics (Social)',
              stream: 'Social Science',
              audience: 'social',
              icon: Icons.functions_rounded,
              color: Color(0xFFA855F7),
              description: 'Commercial maths, statistics & financial logic.',
            ),
          ],
        ),
        WeeklyDaySchedule(
          weekday: DateTime.wednesday,
          dayName: 'Wednesday',
          shortName: 'Wed',
          subjects: [
            WeeklySubjectTarget(
              name: 'Biology',
              stream: 'Natural Science',
              audience: 'natural',
              icon: Icons.biotech_rounded,
              color: Color(0xFF10B981),
              description: 'Cell biology, genetics, physiology & ecology.',
            ),
            WeeklySubjectTarget(
              name: 'Economics',
              stream: 'Social Science',
              audience: 'social',
              icon: Icons.trending_up_rounded,
              color: Color(0xFFF59E0B),
              description: 'Microeconomics, macroeconomics & fiscal policy.',
            ),
          ],
        ),
        WeeklyDaySchedule(
          weekday: DateTime.thursday,
          dayName: 'Thursday',
          shortName: 'Thu',
          subjects: [
            WeeklySubjectTarget(
              name: 'Chemistry',
              stream: 'Natural Science',
              audience: 'natural',
              icon: Icons.science_rounded,
              color: Color(0xFF06B6D4),
              description: 'Atomic theory, organic chemistry & thermodynamics.',
            ),
            WeeklySubjectTarget(
              name: 'Geography',
              stream: 'Social Science',
              audience: 'social',
              icon: Icons.public_rounded,
              color: Color(0xFF84CC16),
              description: 'Physical geography, cartography & resources.',
            ),
          ],
        ),
        WeeklyDaySchedule(
          weekday: DateTime.friday,
          dayName: 'Friday',
          shortName: 'Fri',
          subjects: [
            WeeklySubjectTarget(
              name: 'Physics',
              stream: 'Natural Science',
              audience: 'natural',
              icon: Icons.bolt_rounded,
              color: Color(0xFFEF4444),
              description: 'Mechanics, electromagnetism & wave physics.',
            ),
            WeeklySubjectTarget(
              name: 'History',
              stream: 'Social Science',
              audience: 'social',
              icon: Icons.history_edu_rounded,
              color: Color(0xFFD97706),
              description: 'Ethiopian history & world civilizations.',
            ),
          ],
        ),
        WeeklyDaySchedule(
          weekday: DateTime.saturday,
          dayName: 'Saturday',
          shortName: 'Sat',
          subjects: [
            WeeklySubjectTarget(
              name: 'Aptitude',
              stream: 'Common (Both Streams)',
              audience: 'both',
              icon: Icons.psychology_rounded,
              color: Color(0xFFEAB308),
              description: 'Analytical reasoning & quantitative logic.',
            ),
          ],
        ),
        WeeklyDaySchedule(
          weekday: DateTime.sunday,
          dayName: 'Sunday',
          shortName: 'Sun',
          isRestDay: true,
          subjects: [
            WeeklySubjectTarget(
              name: 'Weekly Review & Rest',
              stream: 'All Students',
              audience: 'both',
              icon: Iconsax.cup_copy,
              color: Color(0xFF64748B),
              description: 'Weekly recap & leaderboard standings review.',
            ),
          ],
        ),
      ];

  /// Finds the schedule entry for a given weekday (1 = Monday ... 7 = Sunday).
  static WeeklyDaySchedule forWeekday(int weekday) {
    return defaultSchedule.firstWhere(
      (s) => s.weekday == weekday,
      orElse: () => defaultSchedule.first,
    );
  }
}
