import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/data/repositories/users_repository.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/features/notifications/controllers/notifications_controller.dart';
import 'package:m_admin/features/notifications/services/admin_notification_link_parser.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';
import 'package:m_admin/utils/validators/validators.dart';

class NotificationComposeScreen extends StatefulWidget {
  const NotificationComposeScreen({super.key, required this.controller});

  final NotificationsController controller;

  @override
  State<NotificationComposeScreen> createState() =>
      _NotificationComposeScreenState();
}

class _NotificationComposeScreenState extends State<NotificationComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();
  String _type = 'announcement';
  String _audience = 'all';

  // User-search state (lazily instantiated so no Supabase call occurs on init)
  UsersRepository? _usersRepo;
  UsersRepository get usersRepo => _usersRepo ??= UsersRepository();
  List<AdminUserModel> _userResults = [];
  AdminUserModel? _selectedUser;
  bool _isSearching = false;
  DateTime? _scheduledAt;

  static const _types = {
    'announcement': 'Announcement',
    'new_content': 'New content',
    'challenge': 'Challenge',
    'challenge_round': 'Challenge Round',
    'challenge_reward': 'Challenge Reward',
  };

  static const _audienceOptions = {
    'all': 'All students',
    'stream:Natural': 'Natural stream',
    'stream:Social': 'Social stream',
    'status:active': 'Active (premium)',
    'status:inactive': 'Inactive users',
    'status:pending': 'Pending users',
    'user': 'Specific user',
  };

  @override
  void initState() {
    super.initState();
    _titleCtrl.addListener(_onTextChanged);
    _bodyCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTextChanged);
    _bodyCtrl.removeListener(_onTextChanged);
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  void _insertTag(String prefix, String suffix, [String defaultText = '']) {
    final text = _bodyCtrl.text;
    final selection = _bodyCtrl.selection;
    if (selection.isValid && selection.start >= 0 && selection.end >= selection.start) {
      final selectedText = text.substring(selection.start, selection.end);
      final inner = selectedText.isNotEmpty ? selectedText : defaultText;
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$inner$suffix');
      final newCursor = selection.start + prefix.length + inner.length + suffix.length;
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    } else {
      final newText = '$text$prefix$defaultText$suffix';
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    setState(() {});
  }

  Future<void> _showChallengePickerDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _ChallengePickerModal(
        onSelect: (challenge) {
          _insertTag(
            '[a href="challenge:${challenge.id}"]',
            '[/a]',
            'Join Challenge',
          );
        },
      ),
    );
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _userResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await usersRepo.fetchUsers(search: query, pageSize: 8);
      if (mounted) setState(() => _userResults = results.users);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  String get _effectiveAudience {
    if (_audience == 'user') {
      return _selectedUser != null ? 'user:${_selectedUser!.id}' : 'user:';
    }
    return _audience;
  }

  String get _audienceLabel {
    if (_audience == 'user' && _selectedUser != null) {
      return _selectedUser!.displayName;
    }
    return _audienceOptions[_audience] ?? _audience;
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(now)) {
      SnackbarHelper.warning('Invalid Time', 'Scheduled time must be in the future.');
      return;
    }
    setState(() => _scheduledAt = picked);
  }

  Future<void> _submit() async {
    if (widget.controller.isSending.value) return;
    if (_audience == 'user' && _selectedUser == null) {
      SnackbarHelper.warning('User required', 'Please select a specific user to target.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_scheduledAt != null && _scheduledAt!.isBefore(DateTime.now())) {
      SnackbarHelper.warning('Invalid Time', 'Scheduled time must be in the future.');
      return;
    }

    final ok = await widget.controller.send(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: _type,
      audience: _effectiveAudience,
      scheduledAt: _scheduledAt,
    );

    if (ok && mounted) {
      if (_scheduledAt != null) {
        SnackbarHelper.success(
          'Notification Scheduled',
          'Notification scheduled for ${EthiopianTimeHelper.formatDateTimeWithEth(_scheduledAt!)} to $_audienceLabel',
        );
      } else {
        SnackbarHelper.success(
          'Notification Sent',
          'Notification successfully sent to $_audienceLabel',
        );
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _userSearchCtrl.clear();
        setState(() {
          _type = 'announcement';
          _audience = 'all';
          _selectedUser = null;
          _userResults = [];
          _scheduledAt = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Notification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildComposeTab(dark),
    );
  }

  Widget _buildComposeTab(bool dark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.defaultSpace),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _type,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                prefixIcon: Icon(Iconsax.category_copy, size: 20),
                              ),
                              items: [
                                for (final e in _types.entries)
                                  DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _type = v ?? _type),
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _audienceOptions.containsKey(_audience)
                                  ? _audience
                                  : 'all',
                              decoration: const InputDecoration(
                                labelText: 'Audience',
                                prefixIcon: Icon(Iconsax.people_copy, size: 20),
                              ),
                              items: [
                                for (final e in _audienceOptions.entries)
                                  DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() {
                                _audience = v ?? _audience;
                                if (_audience != 'user') {
                                  _selectedUser = null;
                                  _userResults = [];
                                  _userSearchCtrl.clear();
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                      // User picker — visible only when audience = 'user'
                      if (_audience == 'user') ...[
                        const SizedBox(height: AppSizes.spaceBtwItems),
                        if (_selectedUser != null)
                          _SelectedUserChip(
                            user: _selectedUser!,
                            onRemove: () => setState(() {
                              _selectedUser = null;
                              _userResults = [];
                              _userSearchCtrl.clear();
                            }),
                          )
                        else ...[
                          TextField(
                            controller: _userSearchCtrl,
                            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: InputDecoration(
                              labelText: 'Search by name or email',
                              prefixIcon: const Icon(
                                Iconsax.search_normal_copy,
                                size: 20,
                              ),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            onChanged: _searchUsers,
                          ),
                          if (_userResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.grey.withValues(alpha: 0.3),
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.borderRadiusMd,
                                ),
                              ),
                              child: Column(
                                children: [
                                  for (int i = 0;
                                      i < _userResults.length;
                                      i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        color: AppColors.grey
                                            .withValues(alpha: 0.2),
                                      ),
                                    _UserResultTile(
                                      user: _userResults[i],
                                      onTap: () => setState(() {
                                        _selectedUser = _userResults[i];
                                        _userResults = [];
                                        _userSearchCtrl.clear();
                                      }),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ],
                      const SizedBox(height: AppSizes.spaceBtwItems),
                      TextFormField(
                        controller: _titleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Enter notification title',
                          prefixIcon: Icon(Iconsax.text_copy, size: 20),
                        ),
                        validator: (v) =>
                            AppValidator.validateEmptyText('Title', v) == null
                            ? null
                            : 'Title is required',
                      ),
                      const SizedBox(height: AppSizes.spaceBtwItems),
                      _QuickInsertTagToolbar(
                        onInsertChallenge: _showChallengePickerDialog,
                        onInsertPlayStore: () => _insertTag(
                          '[a href="https://play.google.com/store/apps/details?id=com.abopia.matricet"]',
                          '[/a]',
                          'Update MatricET',
                        ),
                        onInsertTelegramChannel: () => _insertTag(
                          '[a href="https://t.me/MatricET"]',
                          '[/a]',
                          'Join Channel',
                        ),
                        onInsertTelegramSupport: () => _insertTag(
                          '[a href="https://t.me/matricetbot"]',
                          '[/a]',
                          'Contact Support',
                        ),
                        onFormatBold: () => _insertTag('[b]', '[/b]', 'bold text'),
                        onFormatItalic: () => _insertTag('[i]', '[/i]', 'italic text'),
                        onFormatUnderline: () => _insertTag('[u]', '[/u]', 'underlined text'),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      TextFormField(
                        controller: _bodyCtrl,
                        minLines: 8,
                        maxLines: 16,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Message Body',
                          hintText: 'Enter notification message (supports [b]bold[/b], links, etc.)...',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) =>
                            AppValidator.validateEmptyText('Message', v) == null
                            ? null
                            : 'Message is required',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwItems),
                _LiveStudentPreviewCard(
                  title: _titleCtrl.text,
                  body: _bodyCtrl.text,
                  type: _type,
                  audience: _effectiveAudience,
                ),
                const SizedBox(height: AppSizes.spaceBtwItems),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: dark
                        ? AppColors.darkCard
                        : AppColors.info.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(
                      AppSizes.borderRadiusLg,
                    ),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Iconsax.info_circle_copy,
                        size: 20,
                        color: AppColors.info,
                      ),
                      SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          'Notifications are sent instantly to all matching users. Make sure to review before sending.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_scheduledAt != null) ...[
                  const SizedBox(height: AppSizes.spaceBtwItems),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm + 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.calendar_1_copy, size: 20, color: AppColors.primary),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scheduled: ${DateFormat('EEE, MMM dd, yyyy • HH:mm').format(_scheduledAt!)} (EAT UTC+3)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ethiopian: ${EthiopianTimeHelper.formatDateTimeWithEth(_scheduledAt!)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Change Schedule Time',
                          icon: const Icon(Iconsax.edit_copy, size: 16, color: AppColors.primary),
                          onPressed: _pickScheduleDateTime,
                        ),
                        IconButton(
                          tooltip: 'Clear Schedule',
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () => setState(() => _scheduledAt = null),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.spaceBtwSections),
                Obx(
                  () => Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.sm,
                    children: [
                      OutlinedButton(
                        onPressed: widget.controller.isSending.value
                            ? null
                            : () {
                                _titleCtrl.clear();
                                _bodyCtrl.clear();
                                _userSearchCtrl.clear();
                                setState(() {
                                  _type = 'announcement';
                                  _audience = 'all';
                                  _selectedUser = null;
                                  _userResults = [];
                                  _scheduledAt = null;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(90, 44),
                        ),
                        child: const Text('Clear'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.controller.isSending.value
                            ? null
                            : _pickScheduleDateTime,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, 44),
                          side: BorderSide(
                            color: _scheduledAt != null
                                ? AppColors.primary
                                : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
                            width: _scheduledAt != null ? 1.5 : 1.0,
                          ),
                        ),
                        icon: Icon(
                          Iconsax.calendar_1_copy,
                          size: 16,
                          color: _scheduledAt != null ? AppColors.primary : null,
                        ),
                        label: Text(
                          _scheduledAt != null ? 'Change Schedule' : 'Schedule',
                          style: TextStyle(
                            color: _scheduledAt != null ? AppColors.primary : null,
                            fontWeight: _scheduledAt != null ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: widget.controller.isSending.value
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(140, 44),
                          backgroundColor: _scheduledAt != null
                              ? const Color(0xFF2563EB)
                              : AppColors.primary,
                        ),
                        icon: widget.controller.isSending.value
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _scheduledAt != null
                                    ? Iconsax.calendar_tick_copy
                                    : Iconsax.send_1_copy,
                                size: 18,
                              ),
                        label: Text(
                          widget.controller.isSending.value
                              ? (_scheduledAt != null ? 'Scheduling...' : 'Sending...')
                              : (_scheduledAt != null ? 'Schedule Notification' : 'Send Notification'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── User picker helper widgets ────────────────────────────────────────────────

class _SelectedUserChip extends StatelessWidget {
  const _SelectedUserChip({required this.user, required this.onRemove});

  final AdminUserModel user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              user.initials,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({required this.user, required this.onTap});

  final AdminUserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                user.initials,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${user.email}  ·  ${user.stream}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick-Insert Tag Toolbar & Helper Widgets ─────────────────────────────────

class _QuickInsertTagToolbar extends StatelessWidget {
  const _QuickInsertTagToolbar({
    required this.onInsertChallenge,
    required this.onInsertPlayStore,
    required this.onInsertTelegramChannel,
    required this.onInsertTelegramSupport,
    required this.onFormatBold,
    required this.onFormatItalic,
    required this.onFormatUnderline,
  });

  final VoidCallback onInsertChallenge;
  final VoidCallback onInsertPlayStore;
  final VoidCallback onInsertTelegramChannel;
  final VoidCallback onInsertTelegramSupport;
  final VoidCallback onFormatBold;
  final VoidCallback onFormatItalic;
  final VoidCallback onFormatUnderline;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.magicpen_copy, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Quick Tags & Link Actions',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white70 : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ToolbarChip(
                label: 'Challenge',
                icon: Iconsax.cup_copy,
                color: const Color(0xFFE65100),
                onTap: onInsertChallenge,
                tooltip: 'Select active/upcoming challenge & insert link',
              ),
              const SizedBox(width: 6),
              _ToolbarChip(
                label: 'Play Store',
                icon: Iconsax.shop_copy,
                color: const Color(0xFF2E7D32),
                onTap: onInsertPlayStore,
                tooltip: 'Insert MatricET Google Play Store link',
              ),
              const SizedBox(width: 6),
              _ToolbarChip(
                label: 'Telegram Channel',
                icon: Iconsax.send_2_copy,
                color: const Color(0xFF0097A7),
                onTap: onInsertTelegramChannel,
                tooltip: 'Insert official MatricET Telegram channel link',
              ),
              const SizedBox(width: 6),
              _ToolbarChip(
                label: 'Telegram Support',
                icon: Iconsax.message_question_copy,
                color: const Color(0xFF0288D1),
                onTap: onInsertTelegramSupport,
                tooltip: 'Insert Telegram bot support link',
              ),
              const SizedBox(width: 8),
              Container(
                height: 18,
                width: 1,
                color: dark ? Colors.white24 : Colors.black12,
              ),
              const SizedBox(width: 8),
              _FormatBtn(
                label: 'B',
                isBold: true,
                onTap: onFormatBold,
                tooltip: 'Bold: [b]text[/b]',
              ),
              const SizedBox(width: 4),
              _FormatBtn(
                label: 'I',
                isItalic: true,
                onTap: onFormatItalic,
                tooltip: 'Italic: [i]text[/i]',
              ),
              const SizedBox(width: 4),
              _FormatBtn(
                label: 'U',
                isUnderline: true,
                onTap: onFormatUnderline,
                tooltip: 'Underline: [u]text[/u]',
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: chip);
    }
    return chip;
  }
}

class _FormatBtn extends StatelessWidget {
  const _FormatBtn({
    required this.label,
    required this.onTap,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback onTap;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 25,
        decoration: BoxDecoration(
          color: dark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: dark ? Colors.white24 : Colors.black12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: isUnderline
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }
}

class _ChallengePickerModal extends StatefulWidget {
  const _ChallengePickerModal({required this.onSelect});

  final ValueChanged<LeaderboardChallengeModel> onSelect;

  @override
  State<_ChallengePickerModal> createState() => _ChallengePickerModalState();
}

class _ChallengePickerModalState extends State<_ChallengePickerModal> {
  final _repo = ChallengeRepository();
  bool _isLoading = true;
  List<LeaderboardChallengeModel> _challenges = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.fetchChallenges(pageSize: 30);
      if (mounted) {
        setState(() {
          _challenges = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final filtered = _filter.isEmpty
        ? _challenges
        : _challenges
            .where((c) => c.title.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return AlertDialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      title: Row(
        children: [
          const Icon(Iconsax.cup_copy, color: AppColors.warning, size: 22),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Text(
              'Select Challenge',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 380,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search challenge by title...',
                prefixIcon: Icon(Iconsax.search_normal_copy, size: 18),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter = v.trim()),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No challenges found',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return ListTile(
                              dense: true,
                              title: Text(
                                c.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                'Status: ${c.status} • ${c.durationMinutes}m',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 18),
                              onTap: () {
                                widget.onSelect(c);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live Student Mobile Preview Card ──────────────────────────────────────────

class _LiveStudentPreviewCard extends StatefulWidget {
  const _LiveStudentPreviewCard({
    required this.title,
    required this.body,
    required this.type,
    required this.audience,
  });

  final String title;
  final String body;
  final String type;
  final String audience;

  @override
  State<_LiveStudentPreviewCard> createState() =>
      _LiveStudentPreviewCardState();
}

class _LiveStudentPreviewCardState extends State<_LiveStudentPreviewCard> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final dark = AppHelperFunctions.isDark(context);
    final hasTitle = widget.title.trim().isNotEmpty;
    final hasBody = widget.body.trim().isNotEmpty;

    final primaryLink =
        AdminNotificationLinkParser.extractPrimaryLink(widget.body);

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.borderRadiusLg - 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Iconsax.mobile_copy,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSizes.xs),
                const Expanded(
                  child: Text(
                    'Student App Live Preview',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(
                      AppSizes.borderRadiusSm,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Live Sync',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF181C28) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                border: Border.all(
                  color: dark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Icon(
                            Iconsax.notification_copy,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'MatricET',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• Just now',
                        style: TextStyle(
                          fontSize: 11,
                          color: dark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasTitle ? widget.title : 'Notification Title...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: hasTitle
                          ? (dark ? Colors.white : Colors.black87)
                          : (dark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!hasBody)
                    Text(
                      'Notification message will be parsed with interactive links, bold, italic, and underline tags in real time...',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: dark ? Colors.white38 : Colors.black38,
                      ),
                    )
                  else
                    RichText(
                      text: TextSpan(
                        children: AdminNotificationLinkParser.buildSpans(
                          rawText: widget.body,
                          baseStyle: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: dark
                                ? Colors.white70
                                : const Color(0xFF334155),
                          ),
                          linkStyle: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizers: _recognizers,
                          onLinkTap: (url) {
                            SnackbarHelper.info(
                              'Student App Link Tap',
                              'Navigates to: $url',
                            );
                          },
                        ),
                      ),
                    ),
                  if (primaryLink != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.borderRadiusMd,
                            ),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Iconsax.link_21_copy, size: 16),
                        label: Text(
                          primaryLink.actionButtonLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          SnackbarHelper.info(
                            'Action Button Tap',
                            'Navigates to: ${primaryLink.url}',
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

