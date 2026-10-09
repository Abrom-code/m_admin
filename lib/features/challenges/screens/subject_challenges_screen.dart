import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
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

  final _challengeRepo = ChallengeRepository();
  final _questionSets = <ChallengeQuestionSetModel>[].obs;
  final _isLoadingSets = false.obs;
  final _setSearchCtrl = TextEditingController();
  final _setSearchQuery = ''.obs;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<ChallengesListController>()) {
      _ctrl = Get.find<ChallengesListController>();
    } else {
      _ctrl = Get.put(ChallengesListController());
    }
    _loadQuestionSets();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _setSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestionSets() async {
    try {
      _isLoadingSets.value = true;
      final sets = await _challengeRepo.fetchQuestionSetsForSubject(widget.subjectId);
      _questionSets.assignAll(sets);
    } catch (_) {
    } finally {
      _isLoadingSets.value = false;
    }
  }

  List<ChallengeQuestionSetModel> get _filteredSets {
    final q = _setSearchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return _questionSets;
    return _questionSets.where((s) => s.title.toLowerCase().contains(q)).toList();
  }

  void _openSetDialog({ChallengeQuestionSetModel? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    var isPrem = existing?.isPremium ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing != null ? 'Edit Question Set' : 'Create Question Set'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Set Title *',
                    hintText: 'e.g. Mechanics & Waves Set 1',
                    prefixIcon: Icon(Iconsax.folder_2_copy, size: 18),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwInputFields),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isPrem,
                  onChanged: (val) => setDlgState(() => isPrem = val),
                  title: const Text('Premium Question Set', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Accessible only to premium subscribers', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final t = titleCtrl.text.trim();
                if (t.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  await _challengeRepo.upsertQuestionSet({
                    if (existing != null && existing.id.isNotEmpty) 'id': existing.id,
                    'subject_id': widget.subjectId,
                    'title': t,
                    'is_premium': isPrem,
                  });
                  SnackbarHelper.success('Saved', 'Question set saved successfully.');
                  _loadQuestionSets();
                } catch (e) {
                  SnackbarHelper.error('Error', e.toString());
                }
              },
              child: const Text('Save Set'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSet(ChallengeQuestionSetModel set) async {
    final confirmed = await AppDialogBoxes.confirm(
      title: 'Delete Question Set',
      message: 'Are you sure you want to delete "${set.title}"?\n'
          'All questions in this set will also be deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await _challengeRepo.deleteQuestionSet(set.id);
      SnackbarHelper.success('Deleted', 'Question set removed.');
      _loadQuestionSets();
    } catch (e) {
      SnackbarHelper.error('Delete failed', e.toString());
    }
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

  void _confirmClose(BuildContext context, LeaderboardChallengeModel challenge) {
    FocusManager.instance.primaryFocus?.unfocus();
    AppDialogBoxes.showOkCancelDialog(
      context: context,
      title: 'Close Live Challenge?',
      subtitle: 'Are you sure you want to close "${challenge.title}" from live now?\n\n'
          'Students will immediately no longer be able to attempt this challenge, '
          'and the round will be marked as CLOSED.',
      onPressed: () {
        Navigator.pop(context);
        _ctrl.closeChallenge(challenge.id);
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
      child: DefaultTabController(
        length: 2,
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
                  _loadQuestionSets();
                },
              ),
              const SizedBox(width: AppSizes.sm),
            ],
            bottom: TabBar(
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.cup_copy, size: 15),
                      SizedBox(width: 6),
                      Text('Challenges'),
                    ],
                  ),
                ),
                Obx(
                  () => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.document_copy, size: 15),
                        const SizedBox(width: 6),
                        Text('Question Sets (${_questionSets.length})'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              // ── TAB 1: Challenges ────────────────────────────────────
              Padding(
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
                          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
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
                          onClose: () => _confirmClose(context, challenge),
                          onDelete: () => _confirmDelete(context, challenge),
                          onStatusChange: (newStatus) => _ctrl.updateChallengeStatus(challenge.id, newStatus),
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        // ── TAB 2: Question Sets ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkCard : AppColors.white,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                  border: Border.all(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _setSearchCtrl,
                          onChanged: (v) => _setSearchQuery.value = v,
                          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          style: const TextStyle(fontSize: 11.5),
                          decoration: InputDecoration(
                            hintText: 'Search question sets in ${widget.subjectName}...',
                            hintStyle: const TextStyle(fontSize: 11),
                            prefixIcon: const Icon(Iconsax.search_normal_copy, size: 13),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                              borderSide: BorderSide(
                                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: streamColor,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _openSetDialog(),
                      icon: const Icon(Iconsax.add_circle_copy, size: 14),
                      label: const Text('Create Set', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Obx(() {
                  if (_isLoadingSets.value && _questionSets.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sets = _filteredSets;
                  if (sets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.folder_2_copy, size: 40, color: dark ? Colors.white30 : AppColors.darkGrey),
                          const SizedBox(height: 8),
                          const Text('No Question Sets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text(
                            'Create reusable question sets that challenges can pull from.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _openSetDialog(),
                            icon: const Icon(Iconsax.add_copy, size: 16),
                            label: const Text('New Question Set'),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadQuestionSets,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 460,
                        mainAxisExtent: 136,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: sets.length,
                      itemBuilder: (context, index) {
                        final s = sets[index];
                        return Container(
                          padding: const EdgeInsets.all(AppSizes.md),
                          decoration: BoxDecoration(
                            color: dark ? AppColors.darkCard : AppColors.white,
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                            border: Border.all(
                              color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: s.isPremium
                                          ? AppColors.warning.withValues(alpha: 0.12)
                                          : AppColors.success.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      s.isPremium ? 'PREMIUM' : 'FREE',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: s.isPremium ? AppColors.warning : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${s.questionCount} Questions • ${_dateFormat.format(s.createdAt)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _openSetDialog(existing: s),
                                    icon: const Icon(Iconsax.edit_2_copy, size: 13),
                                    label: const Text('Edit / Rename', style: TextStyle(fontSize: 11)),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Iconsax.trash_copy, size: 16, color: AppColors.error),
                                    onPressed: () => _deleteSet(s),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
),
);
  }
}
