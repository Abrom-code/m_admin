import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/features/notifications/controllers/notifications_controller.dart';
import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
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
  String _type = 'announcement';
  String _audience = 'all';
  late TabController _tabController;

  static const _types = {
    'announcement': 'Announcement',
    'new_content': 'New content',
  };

  static const _audienceOptions = {
    'all': 'All students',
    'stream:Natural': 'Natural stream',
    'stream:Social': 'Social stream',
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
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.controller.isSending.value) return;
    if (!_formKey.currentState!.validate()) return;

    final ok = await widget.controller.send(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: _type,
      audience: _audience,
    );

    if (ok && mounted) {
      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() {
        _type = 'announcement';
        _audience = 'all';
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
                            onChanged: (v) =>
                                setState(() => _audience = v ?? _audience),
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
                                setState(() {
                                  _type = 'announcement';
                                  _audience = 'all';
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
