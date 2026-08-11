import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/data/repositories/users_repository.dart';
import 'package:m_admin/features/notifications/controllers/notifications_controller.dart';
import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/validators/validators.dart';

class NotificationComposeScreen extends StatefulWidget {
  const NotificationComposeScreen({super.key, required this.controller});

  final NotificationsController controller;

  @override
  State<NotificationComposeScreen> createState() =>
      _NotificationComposeScreenState();
}

class _NotificationComposeScreenState extends State<NotificationComposeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();
  String _type = 'announcement';
  String _audience = 'all';
  late TabController _tabController;

  // User-search state
  final _usersRepo = UsersRepository();
  List<AdminUserModel> _userResults = [];
  AdminUserModel? _selectedUser;
  bool _isSearching = false;

  static const _types = {
    'announcement': 'Announcement',
    'new_content': 'New content',
  };

  static const _audienceOptions = {
    'all': 'All students',
    'stream:Natural': 'Natural stream',
    'stream:Social': 'Social stream',
    'user': 'Specific user',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userSearchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _userResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _usersRepo.fetchUsers(search: query, pageSize: 8);
      if (mounted) setState(() => _userResults = results);
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

  Future<void> _submit() async {
    if (widget.controller.isSending.value) return;
    if (_audience == 'user' && _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user first.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final ok = await widget.controller.send(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: _type,
      audience: _effectiveAudience,
    );

    if (ok && mounted) {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _userSearchCtrl.clear();
      setState(() {
        _type = 'announcement';
        _audience = 'all';
        _selectedUser = null;
        _userResults = [];
      });
      _tabController.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Iconsax.edit_2_copy, size: 20), text: 'Compose'),
            Tab(icon: Icon(Iconsax.notification_copy, size: 20), text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildComposeTab(dark), _buildSentTab()],
      ),
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
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppSizes.borderRadiusMd,
                              ),
                            ),
                            child: const Icon(
                              Iconsax.notification_copy,
                              color: AppColors.info,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compose notification',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Send a push notification to students',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.spaceBtwItems),
                      const Divider(height: 1),
                      const SizedBox(height: AppSizes.spaceBtwItems),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final useColumn = constraints.maxWidth < 500;

                          final typeField = DropdownButtonFormField<String>(
                            initialValue: _type,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              prefixIcon: Icon(Iconsax.category_copy, size: 20),
                            ),
                            items: [
                              for (final e in _types.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v ?? _type),
                          );

                          final audienceField = DropdownButtonFormField<String>(
                            initialValue:
                                _audienceOptions.containsKey(_audience)
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
                                  child: Text(e.value),
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
                          );

                          if (useColumn) {
                            return Column(
                              children: [
                                typeField,
                                const SizedBox(height: AppSizes.spaceBtwItems),
                                audienceField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: typeField),
                              const SizedBox(width: AppSizes.md),
                              Expanded(child: audienceField),
                            ],
                          );
                        },
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
                      TextFormField(
                        controller: _bodyCtrl,
                        maxLines: 5,
                        minLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'Enter notification message',
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 60),
                            child: Icon(Iconsax.message_text_copy, size: 20),
                          ),
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
                const SizedBox(height: AppSizes.spaceBtwSections),
                Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, 44),
                        ),
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      ElevatedButton.icon(
                        onPressed: widget.controller.isSending.value
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(140, 44),
                          backgroundColor: AppColors.primary,
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
                            : const Icon(Iconsax.send_1_copy, size: 18),
                        label: Text(
                          widget.controller.isSending.value
                              ? 'Sending...'
                              : 'Send',
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

  Widget _buildSentTab() {
    return Obx(() {
      if (widget.controller.isLoading.value && widget.controller.rows.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (widget.controller.rows.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.notification_bing_copy,
                size: 64,
                color: AppColors.darkGrey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSizes.md),
              const Text(
                'No notifications sent yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(AppSizes.md),
        itemCount: widget.controller.rows.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.sm),
        itemBuilder: (context, index) {
          final notification = widget.controller.rows[index];
          return _NotificationCard(notification: notification);
        },
      );
    });
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AdminNotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    final (label, color) = switch (notification.type) {
      'announcement' => ('Announcement', AppColors.info),
      'new_content' => ('New content', AppColors.success),
      'payment' => ('Payment', AppColors.warning),
      _ => (notification.type, AppColors.darkGrey),
    };

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        border: Border.all(
          color: dark
              ? AppColors.darkGrey.withValues(alpha: 0.3)
              : AppColors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              Expanded(
                child: Text(
                  notification.audienceLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (notification.createdAt != null)
                Text(
                  DateFormat('MMM d, HH:mm').format(notification.createdAt!),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            notification.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            notification.body,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
