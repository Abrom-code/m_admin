import 'package:flutter_test/flutter_test.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';

void main() {
  group('LeaderboardChallengeModel Auto-Premium on Completion', () {
    test('remains free when status is scheduled and not ended', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'chal-scheduled-1',
        'set_id': 'set-1',
        'subject_id': 1,
        'title': 'Math Scheduled Challenge',
        'audience': 'natural',
        'status': 'scheduled',
        'is_premium': false,
        'starts_at': now.add(const Duration(hours: 2)).toIso8601String(),
        'ends_at': now.add(const Duration(hours: 14)).toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.isPremium, isFalse);
      expect(model.isScheduled, isTrue);
      expect(model.isClosed, isFalse);
    });

    test('remains free when status is live and not ended', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'chal-live-1',
        'set_id': 'set-1',
        'subject_id': 1,
        'title': 'Math Live Challenge',
        'audience': 'both',
        'status': 'live',
        'is_premium': false,
        'starts_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'ends_at': now.add(const Duration(hours: 5)).toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.isPremium, isFalse);
      expect(model.isLive, isTrue);
      expect(model.isClosed, isFalse);
    });

    test('auto-converts free challenge to premium when status is closed', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'chal-closed-1',
        'set_id': 'set-1',
        'subject_id': 1,
        'title': 'Closed Math Challenge',
        'audience': 'both',
        'status': 'closed',
        'is_premium': false, // Was free when live or scheduled
        'starts_at': now.subtract(const Duration(hours: 12)).toIso8601String(),
        'ends_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.isPremium, isTrue, reason: 'Completed/closed challenge must convert to premium');
      expect(model.isClosed, isTrue);
      expect(model.toJson()['is_premium'], isTrue);
    });

    test('auto-converts free challenge to premium when status is completed alias', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'chal-completed-1',
        'set_id': 'set-1',
        'subject_id': 1,
        'title': 'Completed Chemistry Challenge',
        'audience': 'natural',
        'status': 'completed',
        'is_premium': false,
        'created_at': now.toIso8601String(),
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.isPremium, isTrue);
      expect(model.isClosed, isTrue);
    });

    test('auto-converts free challenge to premium when status is archived', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'chal-archived-1',
        'set_id': 'set-1',
        'subject_id': 1,
        'title': 'Archived History Challenge',
        'audience': 'social',
        'status': 'archived',
        'is_premium': false,
        'created_at': now.toIso8601String(),
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.isPremium, isTrue);
      expect(model.isClosed, isTrue);
      expect(model.isArchived, isTrue);
    });

    test('auto-converts live challenge to premium when ends_at has passed', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'chal-expired-1',
        'set_id': 'set-1',
        'subject_id': 1,
        'title': 'Expired Live Challenge',
        'audience': 'both',
        'status': 'live', // still marked live in raw row, but ends_at has passed
        'is_premium': false,
        'starts_at': now.subtract(const Duration(hours: 10)).toIso8601String(),
        'ends_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'created_at': now.subtract(const Duration(hours: 12)).toIso8601String(),
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.isClosed, isTrue);
      expect(model.isLive, isFalse);
      expect(model.isPremium, isTrue, reason: 'Expired challenge round must be premium');
    });

    test('preserves draft status and free state even if ends_at was set', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'chal-draft-1',
        'set_id': 'set-1',
        'subject_id': 1,
        'title': 'Unpublished Draft',
        'audience': 'both',
        'status': 'draft',
        'is_premium': false,
        'starts_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'ends_at': now.subtract(const Duration(days: 1)).toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.isDraft, isTrue);
      expect(model.isClosed, isFalse);
      expect(model.isPremium, isFalse, reason: 'Draft challenges should not be auto-converted');
    });

    test('already premium challenge remains premium', () {
      final now = DateTime.now().toUtc();
      final json = {
        'id': 'chal-prem-1',
        'set_id': 'set-1',
        'subject_id': 1,
        'title': 'VIP Biology Challenge',
        'audience': 'both',
        'status': 'live',
        'is_premium': true,
        'starts_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'ends_at': now.add(const Duration(hours: 5)).toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.isPremium, isTrue);
    });

    test('copyWith updates isPremium to true when status transitions to closed', () {
      final liveModel = LeaderboardChallengeModel(
        id: 'c-copy-1',
        setId: 's-1',
        subjectId: 1,
        audience: 'both',
        title: 'Physics Live',
        status: 'live',
        createdAt: DateTime.now(),
        isPremium: false,
      );
      expect(liveModel.isPremium, isFalse);

      final closedModel = liveModel.copyWith(status: 'closed');
      expect(closedModel.status, equals('closed'));
      expect(closedModel.isPremium, isTrue);
    });
  });
}
