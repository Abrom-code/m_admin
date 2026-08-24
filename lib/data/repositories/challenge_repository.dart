import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/challenges/models/challenge_leaderboard_entry.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/features/challenges/models/challenge_question_model.dart';
import 'package:m_admin/features/challenges/models/challenge_reward_model.dart';

class ChallengeRepository {
  final _sb = Supabase.instance.client;

  String? get _adminUid => AdminSessionService.instance.adminUid;

  // ── Legacy Question Sets Compatibility Stub ──────────────────────────────

  Future<List<ChallengeQuestionSetModel>> fetchQuestionSets({int? subjectId}) async {
    return [];
  }

  // ── Questions ──────────────────────────────────────────────────────────────

  Future<List<ChallengeQuestionModel>> fetchQuestionsForChallenge(String challengeId, {String? setId}) async {
    final rows = await _sb
        .from('challenge_questions')
        .select('*')
        .eq('challenge_id', challengeId)
        .order('order_index', ascending: true);

    return (rows as List)
        .map((r) => ChallengeQuestionModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertQuestion(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    try {
      await _sb.from('challenge_questions').upsert(payload);
    } on PostgrestException catch (e) {
      if (e.message.contains('set_id') && payload.containsKey('set_id')) {
        payload.remove('set_id');
        await _sb.from('challenge_questions').upsert(payload);
      } else if (e.message.contains('challenge_id') && payload.containsKey('challenge_id')) {
        payload.remove('challenge_id');
        await _sb.from('challenge_questions').upsert(payload);
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    await _sb.from('challenge_questions').delete().eq('id', questionId);
  }

  // ── Challenges (Rounds) ───────────────────────────────────────────────────

  Future<List<LeaderboardChallengeModel>> fetchChallenges({
    String? status,
    String? audience,
    int? subjectId,
  }) async {
    var query = _sb
        .from('leaderboard_challenges')
        .select('*, subjects(name), challenge_questions(id)');

    if (status != null && status.isNotEmpty && status != 'all') {
      query = query.eq('status', status);
    }
    if (audience != null && audience.isNotEmpty && audience != 'all') {
      query = query.eq('audience', audience);
    }
    if (subjectId != null) {
      query = query.eq('subject_id', subjectId);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => LeaderboardChallengeModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<LeaderboardChallengeModel> fetchChallengeDetail(String challengeId) async {
    final row = await _sb
        .from('leaderboard_challenges')
        .select('*, subjects(name), challenge_questions(id)')
        .eq('id', challengeId)
        .single();
    return LeaderboardChallengeModel.fromJson(row);
  }

  Future<LeaderboardChallengeModel> upsertChallenge(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    payload.remove('question_set_id');
    payload.remove('created_by');

    final subjectId = (payload['subject_id'] as num?)?.toInt() ?? 0;
    final title = payload['title']?.toString() ?? 'Challenge';
    String? setId = payload['set_id']?.toString();

    // 1. Try upserting directly
    try {
      final row = await _sb
          .from('leaderboard_challenges')
          .upsert(payload)
          .select('*, subjects(name), challenge_questions(id)')
          .single();

      return LeaderboardChallengeModel.fromJson(row);
    } on PostgrestException catch (e) {
      // If DB requires set_id (not-null constraint violation):
      final msg = e.message.toLowerCase();
      final details = e.details?.toString().toLowerCase() ?? '';
      if (msg.contains('set_id') || details.contains('set_id') || e.code == '23502') {
        try {
          if (setId == null || setId.isEmpty) {
            final setRow = await _sb.from('challenge_question_sets').insert({
              'subject_id': subjectId,
              'title': title,
            }).select('id').single();
            setId = setRow['id']?.toString();
          }
          if (setId != null && setId.isNotEmpty) {
            payload['set_id'] = setId;
            final row = await _sb
                .from('leaderboard_challenges')
                .upsert(payload)
                .select('*, subjects(name), challenge_questions(id)')
                .single();
            return LeaderboardChallengeModel.fromJson(row);
          }
        } catch (_) {}
      }

      // If DB doesn't have set_id column at all:
      if (payload.containsKey('set_id')) {
        payload.remove('set_id');
        final row = await _sb
            .from('leaderboard_challenges')
            .upsert(payload)
            .select('*, subjects(name), challenge_questions(id)')
            .single();
        return LeaderboardChallengeModel.fromJson(row);
      }

      rethrow;
    }
  }

  Future<String> publishChallenge(String challengeId) async {
    final ch = await fetchChallengeDetail(challengeId);
    final now = DateTime.now();
    final starts = ch.startsAt ?? now;
    final ends = ch.endsAt ?? starts.add(const Duration(hours: 12));

    final newStatus = (now.isAfter(starts) && now.isBefore(ends)) ? 'live' : 'scheduled';
    await updateChallengeStatus(challengeId, newStatus);
    return newStatus;
  }

  Future<void> updateChallengeStatus(String challengeId, String newStatus) async {
    await _sb
        .from('leaderboard_challenges')
        .update({'status': newStatus})
        .eq('id', challengeId);
  }

  Future<void> deleteChallenge(String challengeId) async {
    await _sb.from('leaderboard_challenges').delete().eq('id', challengeId);
  }

  Future<void> archiveChallenge(String challengeId) async {
    await updateChallengeStatus(challengeId, 'archived');
  }

  // ── Leaderboard & Rewards ─────────────────────────────────────────────────

  Future<List<ChallengeLeaderboardEntry>> fetchLeaderboard({
    required String challengeId,
    String? stream,
    int limit = 100,
  }) async {
    try {
      final res = await _sb.rpc('rpc_get_leaderboard', params: {
        'p_challenge_id': challengeId,
        if (stream != null && stream.isNotEmpty && stream != 'all')
          'p_stream': stream,
        'p_limit': limit,
      });

      if (res is List) {
        return res
            .map((r) => ChallengeLeaderboardEntry.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback: direct query on challenge_attempts with users relation if RPC throws legacy schema error
    }

    try {
      var query = _sb
          .from('challenge_attempts')
          .select('*, users(first_name, last_name)')
          .eq('challenge_id', challengeId)
          .eq('status', 'submitted');

      if (stream != null && stream.isNotEmpty && stream != 'all') {
        query = query.eq('stream', stream);
      }

      final rows = await query
          .order('score', ascending: false)
          .order('total_time_seconds', ascending: true)
          .order('submitted_at', ascending: true)
          .limit(limit);

      final list = <ChallengeLeaderboardEntry>[];
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        final user = r['users'] as Map<String, dynamic>? ?? {};
        final sc = (r['score'] as num?)?.toInt() ?? 0;
        list.add(ChallengeLeaderboardEntry(
          rank: i + 1,
          userId: r['user_id']?.toString() ?? '',
          firstName: user['first_name']?.toString() ?? 'Student',
          lastName: user['last_name']?.toString() ?? '',
          stream: r['stream']?.toString() ?? '',
          score: sc,
          totalTimeSeconds: (r['total_time_seconds'] as num?)?.toInt() ?? 0,
          correctCount: sc,
          incorrectCount: (r['incorrect_count'] as num?)?.toInt() ?? 0,
          notDoneCount: (r['not_done_count'] as num?)?.toInt() ?? 0,
          challengesTaken: 1,
        ));
      }
      return list;
    } catch (_) {}

    return [];
  }

  Future<List<ChallengeLeaderboardEntry>> fetchPeriodLeaderboard({
    required String stream,
    required String period, // 'week' or 'month'
    DateTime? periodStart,
    int limit = 100,
  }) async {
    // 1. Try RPC first
    try {
      final res = await _sb.rpc('rpc_get_period_leaderboard', params: {
        'p_stream': (stream.isEmpty || stream == 'all') ? 'all' : stream,
        'p_period': period,
        if (periodStart != null)
          'p_period_start': periodStart.toIso8601String().split('T').first,
        'p_limit': limit,
      });

      if (res is List && res.isNotEmpty) {
        return res
            .map((r) => ChallengeLeaderboardEntry.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // 2. Direct aggregation from challenge_attempts (100% resilient fallback)
    try {
      final now = DateTime.now();
      DateTime startDate;
      if (periodStart != null) {
        startDate = periodStart;
      } else if (period == 'week') {
        final daysFromMon = (now.weekday - 1);
        startDate = DateTime(now.year, now.month, now.day - daysFromMon);
      } else {
        startDate = DateTime(now.year, now.month, 1);
      }

      var query = _sb
          .from('challenge_attempts')
          .select('*, users(first_name, last_name)')
          .eq('status', 'submitted');

      if (stream.isNotEmpty && stream != 'all') {
        query = query.eq('stream', stream);
      }

      final rows = await query.order('submitted_at', ascending: false);

      final userMap = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        final userId = r['user_id']?.toString() ?? '';
        if (userId.isEmpty) continue;

        final submittedAtStr = r['submitted_at']?.toString();
        if (submittedAtStr != null) {
          final submittedAt = DateTime.tryParse(submittedAtStr);
          if (submittedAt != null && submittedAt.isBefore(startDate)) {
            continue;
          }
        }

        final user = r['users'] as Map<String, dynamic>? ?? {};
        final score = (r['score'] as num?)?.toInt() ?? 0;
        final timeSec = (r['total_time_seconds'] as num?)?.toInt() ?? 0;
        final st = r['stream']?.toString() ?? stream;

        if (!userMap.containsKey(userId)) {
          userMap[userId] = {
            'user_id': userId,
            'first_name': user['first_name']?.toString() ?? 'Student',
            'last_name': user['last_name']?.toString() ?? '',
            'stream': st,
            'total_score': score,
            'total_time_seconds': timeSec,
            'challenges_taken': 1,
          };
        } else {
          final existing = userMap[userId]!;
          existing['total_score'] = (existing['total_score'] as int) + score;
          existing['total_time_seconds'] = (existing['total_time_seconds'] as int) + timeSec;
          existing['challenges_taken'] = (existing['challenges_taken'] as int) + 1;
        }
      }

      if (userMap.isEmpty && rows.isNotEmpty) {
        for (final r in rows) {
          final userId = r['user_id']?.toString() ?? '';
          if (userId.isEmpty) continue;

          final user = r['users'] as Map<String, dynamic>? ?? {};
          final score = (r['score'] as num?)?.toInt() ?? 0;
          final timeSec = (r['total_time_seconds'] as num?)?.toInt() ?? 0;
          final st = r['stream']?.toString() ?? stream;

          if (!userMap.containsKey(userId)) {
            userMap[userId] = {
              'user_id': userId,
              'first_name': user['first_name']?.toString() ?? 'Student',
              'last_name': user['last_name']?.toString() ?? '',
              'stream': st,
              'total_score': score,
              'total_time_seconds': timeSec,
              'challenges_taken': 1,
            };
          } else {
            final existing = userMap[userId]!;
            existing['total_score'] = (existing['total_score'] as int) + score;
            existing['total_time_seconds'] = (existing['total_time_seconds'] as int) + timeSec;
            existing['challenges_taken'] = (existing['challenges_taken'] as int) + 1;
          }
        }
      }

      final sortedList = userMap.values.toList()
        ..sort((a, b) {
          final scoreComp = (b['total_score'] as int).compareTo(a['total_score'] as int);
          if (scoreComp != 0) return scoreComp;
          return (a['total_time_seconds'] as int).compareTo(b['total_time_seconds'] as int);
        });

      final result = <ChallengeLeaderboardEntry>[];
      for (int i = 0; i < sortedList.length && i < limit; i++) {
        final item = sortedList[i];
        result.add(ChallengeLeaderboardEntry(
          rank: i + 1,
          userId: item['user_id'] as String,
          firstName: item['first_name'] as String,
          lastName: item['last_name'] as String,
          stream: item['stream'] as String,
          score: item['total_score'] as int,
          totalTimeSeconds: item['total_time_seconds'] as int,
          correctCount: item['total_score'] as int,
          challengesTaken: item['challenges_taken'] as int,
          periodStart: startDate.toIso8601String().split('T').first,
        ));
      }

      return result;
    } catch (_) {}

    return [];
  }

  Future<void> grantReward({
    required String? challengeId,
    required String userId,
    required int rank,
    required String rewardType,
    String? rewardValue,
    String? period,
    String? periodStart,
  }) async {
    await _sb.rpc('rpc_grant_reward', params: {
      'p_challenge_id': ?challengeId,
      'p_user_id': userId,
      'p_rank': rank,
      'p_reward_type': rewardType,
      'p_reward_value': rewardValue ?? '',
      'p_admin_uid': _adminUid ?? '',
      'p_period': ?period,
      'p_period_start': ?periodStart,
    });
  }

  Future<List<ChallengeRewardModel>> fetchRewardsForChallenge(String challengeId) async {
    final rows = await _sb
        .from('challenge_rewards')
        .select('*')
        .eq('challenge_id', challengeId)
        .order('granted_at', ascending: false);

    return (rows as List)
        .map((r) => ChallengeRewardModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchSubjects() async {
    final rows = await _sb.from('subjects').select('id, name, is_natural, is_common').order('name');
    return (rows as List).cast<Map<String, dynamic>>();
  }
}
