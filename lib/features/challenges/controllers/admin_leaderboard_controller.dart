import 'package:get/get.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/models/challenge_leaderboard_entry.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class AdminLeaderboardController extends GetxController {
  AdminLeaderboardController({this.challengeId, this.initialStream});

  final String? challengeId;
  final String? initialStream;

  final _repo = ChallengeRepository();

  final isLoading = false.obs;
  final isManualRefreshing = false.obs;
  final isGranting = false.obs;

  final allChallenges = <LeaderboardChallengeModel>[].obs;
  final currentChallengeId = RxnString();
  final challenge = Rxn<LeaderboardChallengeModel>();
  final entries = <ChallengeLeaderboardEntry>[].obs;
  final searchQuery = ''.obs;

  final selectedView = 'challenge'.obs; // 'challenge', 'weekly', 'monthly'
  final selectedStream = 'all'.obs; // 'all', 'natural', 'social'

  @override
  void onInit() {
    super.onInit();
    currentChallengeId.value = challengeId;
    if (initialStream != null) {
      selectedStream.value = initialStream!;
    }
    loadData();
  }

  List<ChallengeLeaderboardEntry> get filteredEntries {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((e) {
      final nameMatches = e.fullName.toLowerCase().contains(query);
      final idMatches = e.userId.toLowerCase().contains(query);
      final rankMatches = '#${e.rank}'.contains(query) || '${e.rank}'.contains(query);
      return nameMatches || idMatches || rankMatches;
    }).toList();
  }

  int get totalParticipants => filteredEntries.length;
  int get topScore => filteredEntries.isNotEmpty ? filteredEntries.first.score : 0;
  double get averageScore => filteredEntries.isNotEmpty
      ? (filteredEntries.map((e) => e.score).reduce((a, b) => a + b) / filteredEntries.length)
      : 0.0;
  int get fastestTimeSeconds {
    final nonZero = filteredEntries.map((e) => e.totalTimeSeconds).where((t) => t > 0).toList();
    if (nonZero.isEmpty) return 0;
    return nonZero.reduce((a, b) => a < b ? a : b);
  }

  String get formattedFastestTime {
    if (fastestTimeSeconds <= 0) return '--';
    final m = fastestTimeSeconds ~/ 60;
    final s = fastestTimeSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> loadData() async {
    isLoading.value = true;
    try {
      allChallenges.value = await _repo.fetchChallenges();

      if (currentChallengeId.value != null && currentChallengeId.value!.isNotEmpty) {
        try {
          challenge.value = await _repo.fetchChallengeDetail(currentChallengeId.value!);
        } catch (_) {
          final found = allChallenges.firstWhereOrNull((c) => c.id == currentChallengeId.value);
          if (found != null) challenge.value = found;
        }
      } else if (allChallenges.isNotEmpty) {
        currentChallengeId.value = allChallenges.first.id;
        challenge.value = allChallenges.first;
      }

      await refreshLeaderboard();
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
    }
  }

  void selectChallenge(String id) {
    currentChallengeId.value = id;
    challenge.value = allChallenges.firstWhereOrNull((c) => c.id == id);
    selectedView.value = 'challenge';
    refreshLeaderboard();
  }

  Future<void> refreshLeaderboard({bool isManual = false}) async {
    try {
      if (isManual) {
        isManualRefreshing.value = true;
      } else {
        isLoading.value = true;
      }
      final stream = selectedStream.value == 'all' ? null : selectedStream.value;
      if (selectedView.value == 'challenge') {
        if (currentChallengeId.value != null && currentChallengeId.value!.isNotEmpty) {
          entries.value = await _repo.fetchLeaderboard(
            challengeId: currentChallengeId.value!,
            stream: stream,
            limit: 200,
          );
        } else {
          entries.value = [];
        }
      } else if (selectedView.value == 'weekly') {
        entries.value = await _repo.fetchPeriodLeaderboard(
          stream: stream ?? 'all',
          period: 'week',
          limit: 200,
        );
      } else if (selectedView.value == 'monthly') {
        entries.value = await _repo.fetchPeriodLeaderboard(
          stream: stream ?? 'all',
          period: 'month',
          limit: 200,
        );
      }
    } catch (e) {
      SnackbarHelper.error('Leaderboard error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
      isManualRefreshing.value = false;
    }
  }

  void setView(String view) {
    selectedView.value = view;
    refreshLeaderboard();
  }

  void setStream(String stream) {
    selectedStream.value = stream;
    refreshLeaderboard();
  }

  Future<bool> grantReward({
    required String userId,
    required int rank,
    required String rewardType,
    String? rewardValue,
  }) async {
    try {
      isGranting.value = true;
      await _repo.grantReward(
        challengeId: selectedView.value == 'challenge' ? currentChallengeId.value : null,
        userId: userId,
        rank: rank,
        rewardType: rewardType,
        rewardValue: rewardValue,
        period: selectedView.value != 'challenge' ? selectedView.value : null,
      );
      SnackbarHelper.success('Granted', 'Reward successfully granted to student');
      return true;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      return false;
    } finally {
      isGranting.value = false;
    }
  }
}
