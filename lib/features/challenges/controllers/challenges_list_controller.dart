import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengesListController extends GetxController {
  static ChallengesListController get instance => Get.find();

  final _repo = ChallengeRepository();

  final selectedTab = 0.obs; // 0 = Rounds / Challenges, 1 = Question Sets
  final isLoading = false.obs;

  final challenges = <LeaderboardChallengeModel>[].obs;
  final questionSets = <ChallengeQuestionSetModel>[].obs;
  final subjects = <Map<String, dynamic>>[].obs;

  // Filter states
  final statusFilter = 'all'.obs; // 'all', 'draft', 'scheduled', 'live', 'closed', 'archived'
  final audienceFilter = 'all'.obs; // 'all', 'natural', 'social', 'both'
  final selectedSubjectId = RxnInt();
  final searchCtrl = TextEditingController();
  final searchQuery = ''.obs;

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
      return matchTitle || matchSub;
    }).toList();
  }

  List<ChallengeQuestionSetModel> get filteredQuestionSets {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return questionSets;
    return questionSets.where((s) {
      final matchTitle = s.title.toLowerCase().contains(query);
      final matchSub = s.subjectName?.toLowerCase().contains(query) ?? false;
      return matchTitle || matchSub;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  @override
  void onClose() {
    searchCtrl.dispose();
    super.onClose();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    try {
      await Future.wait([
        loadSubjects(),
        loadChallenges(),
        loadQuestionSets(),
      ]);
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
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

  Future<void> makeLiveNow(String challengeId) async {
    try {
      await _repo.updateChallengeStatus(challengeId, 'live');
      SnackbarHelper.success('Live Now', 'Challenge has been set to LIVE status.');
      await loadChallenges();
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    }
  }

  Future<void> closeRoundNow(String challengeId) async {
    try {
      await _repo.updateChallengeStatus(challengeId, 'closed');
      SnackbarHelper.success('Closed', 'Challenge round has ended and final rankings are computed.');
      await loadChallenges();
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    }
  }

  Future<void> archiveChallenge(String challengeId) async {
    try {
      await _repo.archiveChallenge(challengeId);
      SnackbarHelper.success('Archived', 'Challenge moved to archive');
      loadChallenges();
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    }
  }

  Future<void> deleteQuestionSet(String setId) async {
    try {
      await _repo.deleteQuestionSet(setId);
      SnackbarHelper.success('Deleted', 'Question set removed');
      loadQuestionSets();
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    }
  }
}
