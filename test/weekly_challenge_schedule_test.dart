import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:m_admin/features/challenges/models/weekly_challenge_schedule_model.dart';
import 'package:m_admin/features/challenges/screens/weekly_challenge_schedule_screen.dart';
import 'package:m_admin/routes/app_routes.dart';
import 'package:m_admin/routes/routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
  });

  tearDown(() {
    Get.reset();
  });

  group('WeeklyChallengeSchedule Model & Timetable Tests', () {
    test('Default schedule contains exactly 7 days from Monday to Sunday', () {
      final schedule = WeeklyDaySchedule.defaultSchedule;
      expect(schedule.length, equals(7));

      expect(schedule[0].weekday, equals(DateTime.monday));
      expect(schedule[0].dayName, equals('Monday'));

      expect(schedule[1].weekday, equals(DateTime.tuesday));
      expect(schedule[1].dayName, equals('Tuesday'));

      expect(schedule[2].weekday, equals(DateTime.wednesday));
      expect(schedule[2].dayName, equals('Wednesday'));

      expect(schedule[3].weekday, equals(DateTime.thursday));
      expect(schedule[3].dayName, equals('Thursday'));

      expect(schedule[4].weekday, equals(DateTime.friday));
      expect(schedule[4].dayName, equals('Friday'));

      expect(schedule[5].weekday, equals(DateTime.saturday));
      expect(schedule[5].dayName, equals('Saturday'));

      expect(schedule[6].weekday, equals(DateTime.sunday));
      expect(schedule[6].dayName, equals('Sunday'));
      expect(schedule[6].isRestDay, isTrue);
    });

    test('Monday is English for all students (Common / both)', () {
      final mon = WeeklyDaySchedule.forWeekday(DateTime.monday);
      expect(mon.dayName, equals('Monday'));
      expect(mon.subjects.length, equals(1));
      expect(mon.subjects.first.name, equals('English'));
      expect(mon.subjects.first.audience, equals('both'));
      expect(mon.subjects.first.stream, contains('Common'));
    });

    test('Tuesday is Maths / Mathematics for all students (Common / both)', () {
      final tue = WeeklyDaySchedule.forWeekday(DateTime.tuesday);
      expect(tue.dayName, equals('Tuesday'));
      expect(tue.subjects.length, equals(1));
      expect(tue.subjects.first.name, equals('Mathematics'));
      expect(tue.subjects.first.audience, equals('both'));
    });

    test('Wednesday is Biology (Natural) and Economics (Social)', () {
      final wed = WeeklyDaySchedule.forWeekday(DateTime.wednesday);
      expect(wed.dayName, equals('Wednesday'));
      expect(wed.subjects.length, equals(2));

      final bio = wed.subjects.firstWhere((s) => s.name == 'Biology');
      expect(bio.audience, equals('natural'));
      expect(bio.stream, contains('Natural'));

      final econ = wed.subjects.firstWhere((s) => s.name == 'Economics');
      expect(econ.audience, equals('social'));
      expect(econ.stream, contains('Social'));
    });

    test('Thursday is Chemistry (Natural) and Geography (Social)', () {
      final thu = WeeklyDaySchedule.forWeekday(DateTime.thursday);
      expect(thu.dayName, equals('Thursday'));
      expect(thu.subjects.length, equals(2));

      final chem = thu.subjects.firstWhere((s) => s.name == 'Chemistry');
      expect(chem.audience, equals('natural'));
      expect(chem.stream, contains('Natural'));

      final geo = thu.subjects.firstWhere((s) => s.name == 'Geography');
      expect(geo.audience, equals('social'));
      expect(geo.stream, contains('Social'));
    });

    test('Friday is Physics (Natural) and History (Social)', () {
      final fri = WeeklyDaySchedule.forWeekday(DateTime.friday);
      expect(fri.dayName, equals('Friday'));
      expect(fri.subjects.length, equals(2));

      final phys = fri.subjects.firstWhere((s) => s.name == 'Physics');
      expect(phys.audience, equals('natural'));
      expect(phys.stream, contains('Natural'));

      final hist = fri.subjects.firstWhere((s) => s.name == 'History');
      expect(hist.audience, equals('social'));
      expect(hist.stream, contains('Social'));
    });

    test('Saturday is Aptitude for all students (Common / both)', () {
      final sat = WeeklyDaySchedule.forWeekday(DateTime.saturday);
      expect(sat.dayName, equals('Saturday'));
      expect(sat.subjects.length, equals(1));
      expect(sat.subjects.first.name, equals('Aptitude'));
      expect(sat.subjects.first.audience, equals('both'));
    });

    test('Sunday is designated for Weekly Review & Rest', () {
      final sun = WeeklyDaySchedule.forWeekday(DateTime.sunday);
      expect(sun.dayName, equals('Sunday'));
      expect(sun.isRestDay, isTrue);
    });

    test('resolveSubjectId correctly matches database subjects for all days', () {
      final mockSubjects = [
        {'id': 101, 'name': 'English Language', 'is_common': true},
        {'id': 102, 'name': 'Mathematics (Maths)', 'is_common': true},
        {'id': 103, 'name': 'General Biology', 'is_natural': true},
        {'id': 104, 'name': 'Economics', 'is_natural': false},
        {'id': 105, 'name': 'Chemistry', 'is_natural': true},
        {'id': 106, 'name': 'Geography', 'is_natural': false},
        {'id': 107, 'name': 'Physics', 'is_natural': true},
        {'id': 108, 'name': 'History', 'is_natural': false},
        {'id': 109, 'name': 'Scholastic Aptitude (SAT)', 'is_common': true},
      ];

      final mon = WeeklyDaySchedule.forWeekday(DateTime.monday);
      expect(mon.subjects.first.resolveSubjectId(mockSubjects), equals(101));

      final tue = WeeklyDaySchedule.forWeekday(DateTime.tuesday);
      expect(tue.subjects.first.resolveSubjectId(mockSubjects), equals(102));

      final wed = WeeklyDaySchedule.forWeekday(DateTime.wednesday);
      expect(wed.subjects[0].resolveSubjectId(mockSubjects), equals(103)); // Bio
      expect(wed.subjects[1].resolveSubjectId(mockSubjects), equals(104)); // Econ

      final thu = WeeklyDaySchedule.forWeekday(DateTime.thursday);
      expect(thu.subjects[0].resolveSubjectId(mockSubjects), equals(105)); // Chem
      expect(thu.subjects[1].resolveSubjectId(mockSubjects), equals(106)); // Geo

      final fri = WeeklyDaySchedule.forWeekday(DateTime.friday);
      expect(fri.subjects[0].resolveSubjectId(mockSubjects), equals(107)); // Phys
      expect(fri.subjects[1].resolveSubjectId(mockSubjects), equals(108)); // Hist

      final sat = WeeklyDaySchedule.forWeekday(DateTime.saturday);
      expect(sat.subjects.first.resolveSubjectId(mockSubjects), equals(109)); // Aptitude
    });

    test('AdminRoutes.challengeWeeklySchedule is registered in AdminAppRoutes', () {
      final page = AdminAppRoutes.pages.firstWhereOrNull(
        (p) => p.name == AdminRoutes.challengeWeeklySchedule,
      );
      expect(page, isNotNull);
      expect(page!.name, equals('/challenges/weekly-schedule'));
    });
  });

  group('WeeklyChallengeScheduleScreen Layout & Anti-Overflow Tests', () {
    testWidgets('Renders cleanly on desktop (1200x800) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: WeeklyChallengeScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly Challenge Schedule'), findsOneWidget);
      expect(find.text('Full Weekly Competition Timetable'), findsOneWidget);
      expect(find.text('Stream Schedules at a Glance'), findsOneWidget);
      expect(find.text('Monday'), findsWidgets);
      expect(find.text('Tuesday'), findsWidgets);
      expect(find.text('Wednesday'), findsWidgets);
      expect(find.text('Thursday'), findsWidgets);
      expect(find.text('Friday'), findsWidgets);
      expect(find.text('Saturday'), findsWidgets);
      expect(find.text('Sunday'), findsWidgets);

      expect(find.text('English'), findsWidgets);
      expect(find.text('Mathematics'), findsWidgets);
      expect(find.text('Biology'), findsWidgets);
      expect(find.text('Economics'), findsWidgets);
      expect(find.text('Chemistry'), findsWidgets);
      expect(find.text('Geography'), findsWidgets);
      expect(find.text('Physics'), findsWidgets);
      expect(find.text('History'), findsWidgets);
      expect(find.text('Aptitude'), findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on standard phone (360x640) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: WeeklyChallengeScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly Challenge Schedule'), findsOneWidget);
      expect(find.text('TODAY'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders cleanly on ultra-narrow phone (320x480) with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const GetMaterialApp(
          home: WeeklyChallengeScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly Challenge Schedule'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
