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
    payload.remove('set_id');
    await _sb.from('challenge_questions').upsert(payload);
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
    payload.remove('set_id');
    payload.remove('question_set_id');
    payload.remove('created_by');

    final row = await _sb
        .from('leaderboard_challenges')
        .upsert(payload)
        .select('*, subjects(name), challenge_questions(id)')
        .single();

    return LeaderboardChallengeModel.fromJson(row);
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
    try {
      final res = await _sb.rpc('rpc_get_period_leaderboard', params: {
        'p_stream': stream,
        'p_period': period,
        if (periodStart != null)
          'p_period_start': periodStart.toIso8601String().split('T').first,
        'p_limit': limit,
      });

      if (res is List) {
        return res
            .map((r) => ChallengeLeaderboardEntry.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback: direct query on leaderboard view
    }

    try {
      final viewName = period == 'week'
          ? 'v_challenge_leaderboard_weekly'
          : 'v_challenge_leaderboard_monthly';
      var query = _sb
          .from(viewName)
          .select('*, users(first_name, last_name)');

      if (stream.isNotEmpty && stream != 'all') {
        query = query.eq('stream', stream);
      }

      final rows = await query
          .order('rank', ascending: true)
          .limit(limit);

      return rows.map((m) {
        final user = m['users'] as Map<String, dynamic>? ?? {};
        return ChallengeLeaderboardEntry(
          rank: (m['rank'] as num?)?.toInt() ?? 1,
          userId: m['user_id']?.toString() ?? '',
          firstName: user['first_name']?.toString() ?? 'Student',
          lastName: user['last_name']?.toString() ?? '',
          stream: m['stream']?.toString() ?? stream,
          score: (m['total_score'] as num?)?.toInt() ?? 0,
          totalTimeSeconds: (m['total_time_seconds'] as num?)?.toInt() ?? 0,
          correctCount: (m['total_score'] as num?)?.toInt() ?? 0,
          challengesTaken: (m['challenges_taken'] as num?)?.toInt() ?? 1,
          periodStart: m['period_start']?.toString(),
        );
      }).toList();
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
