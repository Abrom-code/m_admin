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
  });
}
