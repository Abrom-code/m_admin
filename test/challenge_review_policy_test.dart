import 'package:flutter_test/flutter_test.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';

void main() {
  group('LeaderboardChallengeModel Review Policy', () {
    test('defaults to on_completion when not provided in JSON', () {
      final json = {
        'id': 'chal-123',
        'set_id': 'set-123',
        'subject_id': 1,
        'title': 'Math Challenge',
        'audience': 'natural',
        'status': 'scheduled',
        'created_at': '2026-10-18T10:00:00Z',
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.reviewPolicy, equals('on_completion'));
      expect(model.canReviewImmediately, isTrue);
      expect(model.canReviewWhenClosed, isFalse);
      expect(model.reviewPolicyLabel, equals('Review immediately'));
    });

    test('correctly parses when_closed review policy', () {
      final json = {
        'id': 'chal-456',
        'set_id': 'set-456',
        'subject_id': 2,
        'title': 'Biology Grand Round',
        'audience': 'both',
        'status': 'live',
        'review_policy': 'when_closed',
        'created_at': '2026-10-18T10:00:00Z',
      };

      final model = LeaderboardChallengeModel.fromJson(json);
      expect(model.reviewPolicy, equals('when_closed'));
      expect(model.canReviewImmediately, isFalse);
      expect(model.canReviewWhenClosed, isTrue);
      expect(model.reviewPolicyLabel, equals('Review when closed'));
    });

    test('supports legacy closed/completed aliases', () {
      final modelClosed = LeaderboardChallengeModel(
        id: '1',
        setId: '1',
        subjectId: 1,
        audience: 'both',
        title: 'T1',
        status: 'closed',
        createdAt: DateTime.now(),
        reviewPolicy: 'closed',
      );
      expect(modelClosed.canReviewWhenClosed, isTrue);
      expect(modelClosed.canReviewImmediately, isFalse);

      final modelCompleted = LeaderboardChallengeModel(
        id: '2',
        setId: '2',
        subjectId: 1,
        audience: 'both',
        title: 'T2',
        status: 'draft',
        createdAt: DateTime.now(),
        reviewPolicy: 'completed',
      );
      expect(modelCompleted.canReviewImmediately, isTrue);
      expect(modelCompleted.canReviewWhenClosed, isFalse);
    });

    test('serializes review_policy to JSON', () {
      final model = LeaderboardChallengeModel(
        id: 'chal-789',
        setId: 'set-789',
        subjectId: 3,
        audience: 'social',
        title: 'History Challenge',
        status: 'scheduled',
        createdAt: DateTime.now(),
        reviewPolicy: 'when_closed',
      );

      final json = model.toJson();
      expect(json['review_policy'], equals('when_closed'));
    });

    test('copyWith preserves or updates reviewPolicy correctly', () {
      final initial = LeaderboardChallengeModel(
        id: 'c1',
        setId: 's1',
        subjectId: 1,
        audience: 'both',
        title: 'Sample',
        status: 'draft',
        createdAt: DateTime.now(),
        reviewPolicy: 'on_completion',
      );

      final updated = initial.copyWith(reviewPolicy: 'when_closed');
      expect(updated.reviewPolicy, equals('when_closed'));
      expect(updated.canReviewWhenClosed, isTrue);

      final unchanged = initial.copyWith(title: 'New Title');
      expect(unchanged.reviewPolicy, equals('on_completion'));
    });
  });
}
