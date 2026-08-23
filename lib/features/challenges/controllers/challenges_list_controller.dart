import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChallengesListController extends GetxController {
  static ChallengesListController get instance => Get.find();

  final _repo = ChallengeRepository();
  final _sb = Supabase.instance.client;

  final selectedTab = 0.obs; // 0 = Rounds / Challenges, 1 = Question Sets
  final isLoading = false.obs;
  final isRefreshing = false.obs;

  final challenges = <LeaderboardChallengeModel>[].obs;
  final questionSets = <ChallengeQuestionSetModel>[].obs;
  final subjects = <Map<String, dynamic>>[].obs;

  // Filter states
  final statusFilter = 'all'.obs; // 'all', 'draft', 'scheduled', 'live', 'closed', 'archived'
  final audienceFilter = 'all'.obs; // 'all', 'natural', 'social', 'both'
  final selectedSubjectId = RxnInt();
  final searchCtrl = TextEditingController();
  final searchQuery = ''.obs;

  RealtimeChannel? _realtimeChannel;

  // KPI Getters
  int get liveCount => challenges.where((c) => c.isLive).length;
  int get scheduledCount => challenges.where((c) => c.isScheduled).length;
  int get closedCount => challenges.where((c) => c.isClosed || c.isArchived).length;
  int get totalSetsCount => questionSets.length;

  List<LeaderboardChallengeModel> get filteredChallenges {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return challenges;
    return challenges.where((c) {
      final matchTitle = c.title.toLowerCase().contains(query);
      final matchSub = c.subjectName?.toLowerCase().contains(query) ?? false;
      final matchId = c.id.toLowerCase().contains(query);
      return matchTitle || matchSub || matchId;
    }).toList();
  }

  List<ChallengeQuestionSetModel> get filteredQuestionSets {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return questionSets;
    return questionSets.where((s) {
      final matchTitle = s.title.toLowerCase().contains(query);
      final matchSub = s.subjectName?.toLowerCase().contains(query) ?? false;
      final matchId = s.id.toLowerCase().contains(query);
      return matchTitle || matchSub || matchId;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadAll();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    searchCtrl.dispose();
    if (_realtimeChannel != null) {
      _sb.removeChannel(_realtimeChannel!);
    }
    super.onClose();
  }

  void _subscribeRealtime() {
    try {
      _realtimeChannel = _sb
          .channel('admin_challenge_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'leaderboard_challenges',
            callback: (_) => loadChallenges(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'challenge_question_sets',
            callback: (_) => loadQuestionSets(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'challenge_questions',
            callback: (_) => loadQuestionSets(),
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> loadAll({bool showLoading = true}) async {
    if (showLoading) isLoading.value = true;
    isRefreshing.value = true;
    try {
      await Future.wait([
        loadSubjects(),
        loadChallenges(),
        loadQuestionSets(),
      ]);
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    } finally {
      if (showLoading) isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  Future<void> loadSubjects() async {
    try {
      subjects.value = await _repo.fetchSubjects();
    } catch (_) {}
  }

  Future<void> loadChallenges() async {
    try {
      final rows = await _repo.fetchChallenges(
        status: statusFilter.value == 'all' ? null : statusFilter.value,
        audience: audienceFilter.value == 'all' ? null : audienceFilter.value,
        subjectId: selectedSubjectId.value,
      );
      challenges.value = rows;
    } catch (e) {
      SnackbarHelper.error('Error loading challenges', AppExceptionHandler.handle(e).message);
    }
  }

  Future<void> loadQuestionSets() async {
    try {
      final rows = await _repo.fetchQuestionSets(
        subjectId: selectedSubjectId.value,
      );
      questionSets.value = rows;
    } catch (e) {
      SnackbarHelper.error('Error loading question sets', AppExceptionHandler.handle(e).message);
    }
  }

  void setTab(int index) {
    selectedTab.value = index;
  }

  void onSearch(String q) {
    searchQuery.value = q;
  }

  void setStatusFilter(String status) {
    statusFilter.value = status;
    loadChallenges();
  }

  void setAudienceFilter(String audience) {
    audienceFilter.value = audience;
    loadChallenges();
  }

  void setSubjectFilter(int? subjectId) {
    selectedSubjectId.value = subjectId;
    loadChallenges();
    loadQuestionSets();
  }

  Future<void> deleteChallenge(String id) async {
    try {
      await _repo.deleteChallenge(id);
      challenges.removeWhere((c) => c.id == id);
      SnackbarHelper.success('Deleted', 'Challenge round deleted successfully');
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    }
  }

  Future<void> deleteQuestionSet(String id) async {
    try {
      await _repo.deleteQuestionSet(id);
      questionSets.removeWhere((s) => s.id == id);
      SnackbarHelper.success('Deleted', 'Question set deleted successfully');
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    }
  }

  Future<void> updateChallengeStatus(String id, String newStatus) async {
    try {
      await _repo.updateChallengeStatus(id, newStatus);
      await loadChallenges();
      SnackbarHelper.success('Updated', 'Challenge status updated to $newStatus');
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    }
  }
}
