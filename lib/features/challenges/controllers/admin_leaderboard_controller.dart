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
  final isGranting = false.obs;

  final challenge = Rxn<LeaderboardChallengeModel>();
  final entries = <ChallengeLeaderboardEntry>[].obs;

  final selectedView = 'challenge'.obs; // 'challenge', 'weekly', 'monthly'
  final selectedStream = 'all'.obs; // 'all', 'natural', 'social'

  @override
  void onInit() {
    super.onInit();
    if (initialStream != null) {
      selectedStream.value = initialStream!;
    }
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;
    try {
      if (challengeId != null && challengeId!.isNotEmpty) {
        challenge.value = await _repo.fetchChallengeDetail(challengeId!);
      }

      await refreshLeaderboard();
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshLeaderboard() async {
    try {
      if (selectedView.value == 'challenge' && challengeId != null) {
        final stream = selectedStream.value == 'all' ? null : selectedStream.value;
        entries.value = await _repo.fetchLeaderboard(
          challengeId: challengeId!,
          stream: stream,
          limit: 200,
        );
      } else if (selectedView.value == 'weekly') {
        final stream = selectedStream.value == 'all' ? 'natural' : selectedStream.value;
        entries.value = await _repo.fetchPeriodLeaderboard(
          stream: stream,
          period: 'week',
          limit: 200,
        );
      } else if (selectedView.value == 'monthly') {
        final stream = selectedStream.value == 'all' ? 'natural' : selectedStream.value;
        entries.value = await _repo.fetchPeriodLeaderboard(
          stream: stream,
          period: 'month',
          limit: 200,
        );
      }
    } catch (e) {
      SnackbarHelper.error('Leaderboard error', AppExceptionHandler.handle(e).message);
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
        challengeId: selectedView.value == 'challenge' ? challengeId : null,
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
