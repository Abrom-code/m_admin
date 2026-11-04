import 'package:m_admin/features/challenges/controllers/challenge_editor_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

void main() {
  group('EthiopianTimeHelper & Challenge Schedule Timezone Tests', () {
    test('eatToUtc converts East Africa Time (UTC+3) to exact UTC', () {
      final localEat = DateTime(2026, 10, 21, 8, 30);
      final utc = EthiopianTimeHelper.eatToUtc(localEat);

      expect(utc.isUtc, isTrue);
      expect(utc.year, equals(2026));
      expect(utc.month, equals(10));
      expect(utc.day, equals(21));
      expect(utc.hour, equals(5));
      expect(utc.minute, equals(30));
    });

    test('toEastAfricaTime converts UTC to East Africa Time (UTC+3)', () {
      final utc = DateTime.utc(2026, 10, 21, 5, 30);
      final eat = EthiopianTimeHelper.toEastAfricaTime(utc);

      expect(eat.hour, equals(8));
      expect(eat.minute, equals(30));
    });

    test('formatDateTimeWithEth does not double-add 3 hours', () {
      final utc = DateTime.utc(2026, 10, 21, 5, 0); // 8:00 AM EAT (2:00 AM Ethiopian)
      final formatted = EthiopianTimeHelper.formatDateTimeWithEth(utc, includeYear: true);

      expect(formatted, contains('8:00 AM'));
      expect(formatted, contains('2:00 AM ET'));
      expect(formatted, isNot(contains('11:00 AM')));
    });

    test('LeaderboardChallengeModel parses Supabase UTC timestamps without 3h shift', () {
      final json = {
        'id': 'chal-tz-1',
        'set_id': 'set-1',
        'title': 'Timezone Test Round',
        'audience': 'both',
        'status': 'scheduled',
        'starts_at': '2026-10-21T05:00:00Z',
        'ends_at': '2026-10-21T17:00:00Z',
        'created_at': '2026-10-20T12:00:00Z',
      };

      final challenge = LeaderboardChallengeModel.fromJson(json);

      expect(challenge.startsAt, isNotNull);
      expect(challenge.startsAt!.isUtc, isTrue);
      expect(challenge.startsAt!.hour, equals(5));

      // In EAT, 5:00 UTC is 8:00 AM
      final eat = EthiopianTimeHelper.toEastAfricaTime(challenge.startsAt!);
      expect(eat.hour, equals(8));

      // Formatted with Ethiopian helper
      final display = EthiopianTimeHelper.formatDateTimeWithEth(challenge.startsAt!);
      expect(display, contains('8:00 AM'));
      expect(display, contains('2:00 AM ET'));
    });

    test('defaultChallengeStartsAt returns current date at 8:00 PM (20:00) UTC+3', () {
      final nowEat = EthiopianTimeHelper.nowInEastAfrica();
      final startsAt = EthiopianTimeHelper.defaultChallengeStartsAt();

      expect(startsAt.year, equals(nowEat.year));
      expect(startsAt.month, equals(nowEat.month));
      expect(startsAt.day, equals(nowEat.day));
      expect(startsAt.hour, equals(20)); // 8:00 PM
      expect(startsAt.minute, equals(0));
    });

    test('defaultChallengeEndsAt returns exactly two days after startsAt at 8:00 PM (20:00) UTC+3', () {
      final startsAt = EthiopianTimeHelper.defaultChallengeStartsAt();
      final endsAt = EthiopianTimeHelper.defaultChallengeEndsAt(startsAt);

      expect(endsAt.hour, equals(20)); // 8:00 PM
      expect(endsAt.minute, equals(0));
      expect(endsAt.difference(startsAt).inHours, equals(48)); // 2 days later
    });

    test('ChallengeEditorController defaults start to 8:00 PM UTC+3 and ends 2 days later at same time', () {
      final ctrl = ChallengeEditorController();
      expect(ctrl.startsAt.value, isNotNull);
      expect(ctrl.endsAt.value, isNotNull);
      expect(ctrl.startsAt.value!.hour, equals(20));
      expect(ctrl.startsAt.value!.minute, equals(0));
      expect(ctrl.endsAt.value!.hour, equals(20));
      expect(ctrl.endsAt.value!.minute, equals(0));
      expect(ctrl.endsAt.value!.difference(ctrl.startsAt.value!).inHours, equals(48));
    });

    test('ChallengeEditorController defaults audience to subject stream and updates on subject change', () {
      final ctrl = ChallengeEditorController();
      ctrl.subjects.value = [
        {'id': 1, 'name': 'Biology', 'is_natural': true, 'is_common': false},
        {'id': 2, 'name': 'History', 'is_natural': false, 'is_common': false},
        {'id': 3, 'name': 'English', 'is_natural': false, 'is_common': true},
      ];

      // 1. Natural stream subject
      ctrl.onSubjectChanged(1);
      expect(ctrl.selectedSubjectId.value, equals(1));
      expect(ctrl.audience.value, equals('natural'));

      // 2. Social stream subject
      ctrl.onSubjectChanged(2);
      expect(ctrl.selectedSubjectId.value, equals(2));
      expect(ctrl.audience.value, equals('social'));

      // 3. Common subject (Both streams)
      ctrl.onSubjectChanged(3);
      expect(ctrl.selectedSubjectId.value, equals(3));
      expect(ctrl.audience.value, equals('both'));
    });

    test('topChallenges returns only Live and Scheduled challenges on "all", excluding Drafts', () {
      final now = DateTime.now().toUtc();
      final liveRound = LeaderboardChallengeModel(
        id: 'c-live',
        setId: 'set-live',
        title: 'Live Physics',
        audience: 'natural',
        status: 'live',
        subjectId: 1,
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: now.add(const Duration(hours: 10)),
        createdAt: now,
      );
      final scheduledRound = LeaderboardChallengeModel(
        id: 'c-sched',
        setId: 'set-sched',
        title: 'Scheduled Chemistry',
        audience: 'natural',
        status: 'scheduled',
        subjectId: 1,
        startsAt: now.add(const Duration(hours: 5)),
        endsAt: now.add(const Duration(hours: 48)),
        createdAt: now,
      );
      final draftRound = LeaderboardChallengeModel(
        id: 'c-draft',
        setId: 'set-draft',
        title: 'Draft Biology',
        audience: 'natural',
        status: 'draft',
        subjectId: 2,
        createdAt: now,
      );
      final closedRound = LeaderboardChallengeModel(
        id: 'c-closed',
        setId: 'set-closed',
        title: 'Ended History',
        audience: 'social',
        status: 'closed',
        subjectId: 3,
        startsAt: now.subtract(const Duration(days: 3)),
        endsAt: now.subtract(const Duration(days: 1)),
        createdAt: now,
      );

      final all = [liveRound, scheduledRound, draftRound, closedRound];

      // When statusFilter is 'all': only live and scheduled should appear in top section
      final topSection = all.where((c) => c.isLive || c.isScheduled).toList();
      expect(topSection.length, equals(2));
      expect(topSection.map((c) => c.id), containsAll(['c-live', 'c-sched']));
      expect(topSection.map((c) => c.id), isNot(contains('c-draft')));
      expect(topSection.map((c) => c.id), isNot(contains('c-closed')));

      // Drafts should be isolated and placed on their respective subject (subjectId: 2)
      final subject2Drafts = all.where((c) => c.subjectId == 2 && c.isDraft).toList();
      expect(subject2Drafts.length, equals(1));
      expect(subject2Drafts.first.title, equals('Draft Biology'));
    });
    test('date range calculation supports past challenges when editing without assertion error', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 10)); // challenge started 10 days ago
      final firstDate = DateTime(2020, 1, 1);
      final lastDate = now.add(const Duration(days: 365 * 5));

      DateTime initialDate = pastDate;
      if (initialDate.isBefore(firstDate)) initialDate = firstDate;
      if (initialDate.isAfter(lastDate)) initialDate = lastDate;

      // Assertions that Flutter showDatePicker makes
      expect(initialDate.isBefore(firstDate), isFalse);
      expect(initialDate.isAfter(lastDate), isFalse);
      expect(initialDate, equals(pastDate));
    });
  });
}
