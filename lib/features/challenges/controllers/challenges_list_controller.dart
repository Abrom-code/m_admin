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

  final isLoading = false.obs;
  final isRefreshing = false.obs;

  final challenges = <LeaderboardChallengeModel>[].obs;
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
  int get draftCount => challenges.where((c) => c.isDraft).length;

  // Top Section: Live, Scheduled, and Draft challenges (or filtered by status if not 'all')
  List<LeaderboardChallengeModel> get topChallenges {
    final list = filteredChallenges;
    if (statusFilter.value == 'all') {
      return list.where((c) => c.isLive || c.isDraft || c.isScheduled).toList();
    }
    return list;
  }

  // Challenges belonging to a specific subject
  List<LeaderboardChallengeModel> challengesForSubject(int subjectId, {bool applyStatusFilter = true}) {
    final query = searchQuery.value.trim().toLowerCase();
    return challenges.where((c) {
      if (c.subjectId != subjectId) return false;
      if (applyStatusFilter && statusFilter.value != 'all') {
        if (c.status.toLowerCase() != statusFilter.value.toLowerCase()) return false;
      }
      if (query.isNotEmpty) {
        final matchTitle = c.title.toLowerCase().contains(query);
        final matchSub = c.subjectName?.toLowerCase().contains(query) ?? false;
        final matchId = c.id.toLowerCase().contains(query);
        return matchTitle || matchSub || matchId;
      }
      return true;
    }).toList();
  }

  // Total challenge stats across all subjects
  Map<String, int> get allSubjectsStats {
    return {
      'total': challenges.length,
      'live': liveCount,
      'scheduled': scheduledCount,
      'draft': draftCount,
      'closed': closedCount,
    };
  }

  // Count challenges by status for a subject
  Map<String, int> getSubjectStats(int subjectId) {
    final subChallenges = challenges.where((c) => c.subjectId == subjectId).toList();
    return {
      'total': subChallenges.length,
      'live': subChallenges.where((c) => c.isLive).length,
      'scheduled': subChallenges.where((c) => c.isScheduled).length,
      'draft': subChallenges.where((c) => c.isDraft).length,
      'closed': subChallenges.where((c) => c.isClosed || c.isArchived).length,
    };
  }

  // Subjects filtered by selected dropdown, status, or search
  List<Map<String, dynamic>> get filteredSubjectsList {
    final query = searchQuery.value.trim().toLowerCase();
    var list = subjects.toList();
    if (selectedSubjectId.value != null) {
      list = list.where((s) {
        final sid = (s['id'] as num?)?.toInt() ?? int.tryParse(s['id']?.toString() ?? '') ?? 0;
        return sid == selectedSubjectId.value;
      }).toList();
    }
    // If status filter is active, only show subjects that contain challenges matching that status
    if (statusFilter.value != 'all') {
      list = list.where((s) {
        final sid = (s['id'] as num?)?.toInt() ?? int.tryParse(s['id']?.toString() ?? '') ?? 0;
        return challengesForSubject(sid, applyStatusFilter: true).isNotEmpty;
      }).toList();
    }
    if (query.isNotEmpty) {
      list = list.where((s) {
        final sid = (s['id'] as num?)?.toInt() ?? int.tryParse(s['id']?.toString() ?? '') ?? 0;
        final name = (s['name']?.toString() ?? '').toLowerCase();
        final hasMatchingChallenges = challengesForSubject(sid, applyStatusFilter: false).isNotEmpty;
        return name.contains(query) || hasMatchingChallenges;
      }).toList();
    }
    return list;
  }

  List<LeaderboardChallengeModel> get filteredChallenges {
    final query = searchQuery.value.trim().toLowerCase();
    var list = challenges.toList();

    if (query.isNotEmpty) {
      list = list.where((c) {
        final matchTitle = c.title.toLowerCase().contains(query);
        final matchSub = c.subjectName?.toLowerCase().contains(query) ?? false;
        final matchId = c.id.toLowerCase().contains(query);
        return matchTitle || matchSub || matchId;
      }).toList();
    }

    if (statusFilter.value != 'all') {
      list = list.where((c) => c.status.toLowerCase() == statusFilter.value.toLowerCase()).toList();
    }

    if (selectedSubjectId.value != null) {
      list = list.where((c) => c.subjectId == selectedSubjectId.value).toList();
    }

    return list;
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
          .channel('admin_challenge_realtime_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'leaderboard_challenges',
            callback: (_) => loadChallenges(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'challenge_questions',
            callback: (_) => loadChallenges(),
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
      final rows = await _repo.fetchChallenges();
      challenges.value = rows;
    } catch (e) {
      SnackbarHelper.error('Error loading challenges', AppExceptionHandler.handle(e).message);
    }
  }

  void onSearch(String q) {
    searchQuery.value = q;
  }

  void setStatusFilter(String status) {
    statusFilter.value = status;
  }

  void setSubjectFilter(int? subjectId) {
    selectedSubjectId.value = subjectId;
  }

  Future<void> deleteChallenge(String id) async {
    try {
      await _repo.deleteChallenge(id);
      challenges.removeWhere((c) => c.id == id);
      SnackbarHelper.success('Deleted', 'Challenge deleted successfully');
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    }
  }

  Future<void> publishChallenge(String id, {bool forceLive = false}) async {
    try {
      final ch = challenges.firstWhereOrNull((c) => c.id == id);
      if (ch != null && ch.questionCount == 0) {
        SnackbarHelper.warning(
          'Questions Required',
          'Please edit the challenge and add at least 1 question before publishing.',
        );
        return;
      }
      isLoading.value = true;
      final newStatus = await _repo.publishChallenge(id, forceLive: forceLive);
      await loadChallenges();
      SnackbarHelper.success('Published', 'Challenge status is now ${newStatus.toUpperCase()}');
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateChallengeStatus(String id, String newStatus) async {
    try {
      await _repo.updateChallengeStatus(id, newStatus);
      await loadChallenges();
      SnackbarHelper.success('Updated', 'Challenge status set to $newStatus');
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    }
  }
}
