import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/features/notifications/controllers/notifications_controller.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/validators/validators.dart';

/// Compose a broadcast notification. Shown as a dialog on wide screens and a
/// bottom sheet on narrow ones.
class NotificationComposeScreen extends StatefulWidget {
  const NotificationComposeScreen({super.key, required this.controller});

  final NotificationsController controller;

  @override
  State<NotificationComposeScreen> createState() =>
      _NotificationComposeScreenState();
}

class _NotificationComposeScreenState
    extends State<NotificationComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _type = 'announcement';
  String _audience = 'all';

  static const _types = {
    'announcement': 'Announcement',
    'new_content': 'New content',
  };

  // Audience options shown in the dropdown.
  // Streams are loaded from the controller's parent UsersController
  // after the first user-list load, but here we keep it simple and allow
  // the operator to type a stream name directly.
  static const _audienceOptions = {
    'all': 'All students',
    'stream:Natural': 'Natural stream',
    'stream:Social': 'Social stream',
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await widget.controller.send(
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: _type,
      audience: _audience,
    );

    if (ok && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Send notification',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── Type ──────────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final e in _types.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── Audience ──────────────────────────────────────────
            DropdownButtonFormField<String>(
              initialValue: _audienceOptions.containsKey(_audience) ? _audience : 'all',
              decoration: const InputDecoration(labelText: 'Audience'),
              items: [
                for (final e in _audienceOptions.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _audience = v ?? _audience),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── Title ─────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  AppValidator.validateEmptyText('Title', v) == null
                      ? null
                      : 'Required',
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── Body ──────────────────────────────────────────────
            TextFormField(
              controller: _bodyCtrl,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  AppValidator.validateEmptyText('Message', v) == null
                      ? null
                      : 'Required',
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── Actions ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSizes.sm),
                Obx(
                  () => ElevatedButton.icon(
                    onPressed: widget.controller.isSending.value
                        ? null
                        : _submit,
                    icon: widget.controller.isSending.value
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            size: AppSizes.iconSm,
                          ),
                    label: const Text('Send'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(110, 44),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
