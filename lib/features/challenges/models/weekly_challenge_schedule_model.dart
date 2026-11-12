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
    required this.description,
  });

  final String name;
  final String stream; // 'Common (Both Streams)', 'Natural Science', 'Social Science'
  final String audience; // 'both', 'natural', 'social'
  final IconData icon;
  final Color color;
  final String description;

  /// Matches the database subject ID from the loaded subjects list.
  int? resolveSubjectId(List<Map<String, dynamic>> subjects) {
    final clean = name.toLowerCase().trim();
    final match = subjects.cast<Map<String, dynamic>?>().firstWhere(
      (s) {
        if (s == null) return false;
        final sName = (s['name']?.toString() ?? '').toLowerCase().trim();
        if (sName == clean) return true;
        if (clean == 'mathematics' &&
            (sName == 'math' || sName == 'maths' || sName.contains('math'))) {
          return true;
        }
        if (clean == 'english' && sName.contains('english')) return true;
        if (clean == 'biology' && sName.contains('bio')) return true;
        if (clean == 'economics' && sName.contains('econ')) return true;
        if (clean == 'chemistry' && sName.contains('chem')) return true;
        if (clean == 'geography' && sName.contains('geo')) return true;
        if (clean == 'physics' && sName.contains('phys')) return true;
        if (clean == 'history' && sName.contains('hist')) return true;
        if (clean == 'aptitude' &&
            (sName.contains('aptitude') || sName.contains('sat'))) {
          return true;
        }
        return false;
      },
      orElse: () => null,
    );
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
              description:
                  'Grammar, vocabulary, reading comprehension & communication skills.',
            ),
          ],
        ),
        WeeklyDaySchedule(
          weekday: DateTime.tuesday,
          dayName: 'Tuesday',
          shortName: 'Tue',
          subjects: [
            WeeklySubjectTarget(
              name: 'Mathematics',
              stream: 'Common (Both Streams)',
              audience: 'both',
              icon: Icons.calculate_rounded,
              color: Color(0xFF8B5CF6),
              description:
                  'Core algebra, calculus, trigonometry, coordinate geometry & quantitative logic.',
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
              description:
                  'Cell biology, genetics, human physiology, biotechnology & ecology.',
            ),
            WeeklySubjectTarget(
              name: 'Economics',
              stream: 'Social Science',
              audience: 'social',
              icon: Icons.trending_up_rounded,
              color: Color(0xFFF59E0B),
              description:
                  'Microeconomics, macroeconomics, fiscal monetary policy & economic development.',
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
              description:
                  'Atomic theory, chemical bonding, organic compounds, thermodynamics & equilibrium.',
            ),
            WeeklySubjectTarget(
              name: 'Geography',
              stream: 'Social Science',
              audience: 'social',
              icon: Icons.public_rounded,
              color: Color(0xFF84CC16),
              description:
                  'Physical geography, cartography, climate zones, population & natural resources.',
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
              description:
                  'Mechanics, electromagnetism, wave physics, optics & modern physical concepts.',
            ),
            WeeklySubjectTarget(
              name: 'History',
              stream: 'Social Science',
              audience: 'social',
              icon: Icons.history_edu_rounded,
              color: Color(0xFFD97706),
              description:
                  'Ethiopian history, ancient and medieval civilizations & major world events.',
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
              description:
                  'Scholastic aptitude, analytical reasoning, numerical logic & verbal acumen.',
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
              description:
                  'Review weekly leaderboard standings, question explanations and exam preparation.',
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
