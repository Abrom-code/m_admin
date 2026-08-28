import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/features/challenges/controllers/challenges_list_controller.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/features/challenges/screens/challenge_editor_screen.dart';
import 'package:m_admin/features/challenges/screens/widgets/challenge_card.dart';
import 'package:m_admin/features/challenges/screens/widgets/notify_challenge_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class SubjectChallengesScreen extends StatefulWidget {
  const SubjectChallengesScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.isNatural,
    required this.isCommon,
  });

  final int subjectId;
  final String subjectName;
  final bool isNatural;
  final bool isCommon;

  @override
  State<SubjectChallengesScreen> createState() => _SubjectChallengesScreenState();
}

class _SubjectChallengesScreenState extends State<SubjectChallengesScreen> {
  late final ChallengesListController _ctrl;
  final _dateFormat = DateFormat('MMM dd, HH:mm');
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  final _searchQuery = ''.obs;
  final _statusFilter = 'all'.obs; // 'all', 'live', 'scheduled', 'closed', 'draft'

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<ChallengesListController>()) {
      _ctrl = Get.find<ChallengesListController>();
    } else {
      _ctrl = Get.put(ChallengesListController());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LeaderboardChallengeModel> get _subjectChallenges {
    final query = _searchQuery.value.trim().toLowerCase();
    final status = _statusFilter.value.toLowerCase();

    return _ctrl.challenges.where((c) {
      if (widget.subjectId != 0 && c.subjectId != widget.subjectId) return false;
      if (status != 'all' && c.status.toLowerCase() != status) return false;
      if (query.isNotEmpty) {
        final matchTitle = c.title.toLowerCase().contains(query);
        final matchId = c.id.toLowerCase().contains(query);
        return matchTitle || matchId;
      }
      return true;
    }).toList();
  }

  int _countByStatus(String status) {
    final allForSubject = widget.subjectId != 0 ? _ctrl.challenges.where((c) => c.subjectId == widget.subjectId) : _ctrl.challenges;
    if (status == 'all') return allForSubject.length;
    if (status == 'live') return allForSubject.where((c) => c.isLive).length;
    if (status == 'scheduled') return allForSubject.where((c) => c.isScheduled).length;
    if (status == 'closed') return allForSubject.where((c) => c.isClosed || c.isArchived).length;
    if (status == 'draft') return allForSubject.where((c) => c.isDraft).length;
    return 0;
  }

  void _confirmPublish(BuildContext context, LeaderboardChallengeModel challenge) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (challenge.questionCount == 0) {
      SnackbarHelper.warning('Questions Required', 'Please add questions to "${challenge.title}" before publishing.');
      return;
    }
    AppDialogBoxes.showOkCancelDialog(
      context: context,
      title: 'Publish Challenge?',
      subtitle: challenge.isScheduled
          ? 'Make "${challenge.title}" LIVE now for all students?'
          : 'Publish "${challenge.title}" now?',
      onPressed: () {
        Navigator.pop(context);
        _ctrl.publishChallenge(challenge.id, forceLive: challenge.isScheduled);
      },
    );
  }

  void _confirmDelete(BuildContext context, LeaderboardChallengeModel challenge) {
    FocusManager.instance.primaryFocus?.unfocus();
    AppDialogBoxes.showOkCancelDialog(
      context: context,
      title: 'Delete Challenge?',
      subtitle: 'Are you sure you want to delete "${challenge.title}"? This cannot be undone.',
      onPressed: () {
        Navigator.pop(context);
        _ctrl.deleteChallenge(challenge.id);
      },
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'live':
        return AppColors.success;
      case 'scheduled':
        return AppColors.secondary;
      case 'closed':
        return AppColors.grey;
      case 'draft':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    Color streamColor;
    String streamLabel;
    if (widget.isCommon) {
      streamColor = const Color(0xFF0284C7);
      streamLabel = 'Common';
    } else if (widget.isNatural) {
      streamColor = AppColors.primary;
      streamLabel = 'Natural Stream';
    } else {
      streamColor = AppColors.secondary;
      streamLabel = 'Social Stream';
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Get.back(),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: streamColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Iconsax.book_1_copy, size: 16, color: streamColor),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: streamColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  streamLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: streamColor,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: streamColor,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                await Get.to(() => ChallengeEditorScreen(initialSubjectId: widget.subjectId));
                _ctrl.loadAll(showLoading: false);
              },
              icon: const Icon(Iconsax.add_circle_copy, size: 14),
              label: const Text('Create', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Refresh',
              visualDensity: VisualDensity.compact,
              icon: Obx(() => _ctrl.isRefreshing.value
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18)),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _ctrl.loadAll();
              },
            ),
            const SizedBox(width: AppSizes.sm),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Toolbar: Search & Status Filter Chips ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkCard : AppColors.white,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                  border: Border.all(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search input
                      SizedBox(
                        width: 220,
                        height: 32,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => _searchQuery.value = v,
                          autofocus: false,
                          style: const TextStyle(fontSize: 11.5),
                          decoration: InputDecoration(
                            hintText: 'Search in ${widget.subjectName}...',
                            hintStyle: const TextStyle(fontSize: 11),
                            prefixIcon: const Icon(Iconsax.search_normal_copy, size: 13),
                            suffixIcon: Obx(() => _searchQuery.value.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 13),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _searchQuery.value = '';
                                      FocusManager.instance.primaryFocus?.unfocus();
                                    },
                                  )
                                : const SizedBox.shrink()),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                              borderSide: BorderSide(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: AppSizes.md),
                      const Text('Status: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),

                      // Status filter chips
                      Obx(() {
                        final statusOptions = [
                          {'key': 'all', 'label': 'All (${_countByStatus('all')})'},
                          {'key': 'live', 'label': 'Live (${_countByStatus('live')})'},
                          {'key': 'scheduled', 'label': 'Scheduled (${_countByStatus('scheduled')})'},
                          {'key': 'closed', 'label': 'Closed (${_countByStatus('closed')})'},
                          {'key': 'draft', 'label': 'Draft (${_countByStatus('draft')})'},
                        ];

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: statusOptions.map((opt) {
                            final key = opt['key']!;
                            final label = opt['label']!;
                            final isSel = _statusFilter.value == key;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: FilterChip(
                                label: Text(label),
                                selected: isSel,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.white : AppColors.textSecondary,
                                ),
                                selectedColor: _statusColor(key),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                onSelected: (_) {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  _statusFilter.value = key;
                                },
                              ),
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Challenges Grid ──
              Expanded(
                child: Obx(() {
                  if (_ctrl.isLoading.value && _ctrl.challenges.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final list = _subjectChallenges;

                  if (list.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkCard : AppColors.white,
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                          border: Border.all(
                            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: streamColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Iconsax.document_copy, size: 32, color: streamColor),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No challenges found for ${widget.subjectName}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create a new challenge or adjust your status/search filters.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: streamColor,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onPressed: () async {
                                FocusManager.instance.primaryFocus?.unfocus();
                                await Get.to(() => ChallengeEditorScreen(initialSubjectId: widget.subjectId));
                                _ctrl.loadAll(showLoading: false);
                              },
                              icon: const Icon(Iconsax.add_circle_copy, size: 16),
                              label: const Text('Create Challenge', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _ctrl.loadAll,
                    child: GridView.builder(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 460,
                        mainAxisExtent: 148,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final challenge = list[index];
                        return ChallengeCard(
                          challenge: challenge,
                          dateFormat: _dateFormat,
                          onEdit: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            await Get.to(() => ChallengeEditorScreen(challengeId: challenge.id));
                            _ctrl.loadAll(showLoading: false);
                          },
                          onNotify: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            NotifyChallengeDialog.show(context, challenge);
                          },
                          onPublish: () => _confirmPublish(context, challenge),
                          onDelete: () => _confirmDelete(context, challenge),
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
