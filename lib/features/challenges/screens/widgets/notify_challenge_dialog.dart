import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/data/repositories/notifications_repository.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class NotifyChallengeDialog extends StatefulWidget {
  const NotifyChallengeDialog({super.key, required this.challenge});

  final LeaderboardChallengeModel challenge;

  static Future<void> show(BuildContext context, LeaderboardChallengeModel challenge) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NotifyChallengeDialog(challenge: challenge),
    );
  }

  @override
  State<NotifyChallengeDialog> createState() => _NotifyChallengeDialogState();
}

class _NotifyChallengeDialogState extends State<NotifyChallengeDialog> {
  final _repo = NotificationsRepository();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late String _selectedAudience;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final ch = widget.challenge;
    final dateFormat = DateFormat('EEE, MMM d, yyyy · hh:mm a');

    _titleCtrl = TextEditingController(
      text: '🏆 New Challenge: ${ch.title}',
    );

    final timeDetails = StringBuffer();
    timeDetails.writeln('📚 Subject: ${ch.subjectName ?? 'General'}');
    timeDetails.writeln('⏱ Duration: ${ch.durationMinutes} mins • ${ch.questionCount} Questions');
    if (ch.startsAt != null) {
      timeDetails.writeln('📅 Starts: ${dateFormat.format(ch.startsAt!.toLocal())}');
    }
    if (ch.endsAt != null) {
      timeDetails.writeln('🏁 Ends: ${dateFormat.format(ch.endsAt!.toLocal())}');
    }

    _bodyCtrl = TextEditingController(text: timeDetails.toString().trim());

    // Default target audience based on challenge
    final aud = ch.audience.toLowerCase().trim();
    if (aud == 'natural') {
      _selectedAudience = 'stream:natural';
    } else if (aud == 'social') {
      _selectedAudience = 'stream:social';
    } else {
      _selectedAudience = 'all';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String _audienceLabel(String aud) {
    switch (aud) {
      case 'stream:natural':
        return 'Natural Stream Only';
      case 'stream:social':
        return 'Social Stream Only';
      default:
        return 'All Students (Natural & Social)';
    }
  }

  Color _audienceColor(String aud) {
    switch (aud) {
      case 'stream:natural':
        return AppColors.primary;
      case 'stream:social':
        return AppColors.secondary;
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty) {
      SnackbarHelper.error('Missing Title', 'Please enter a notification title.');
      return;
    }
    if (body.isEmpty) {
      SnackbarHelper.error('Missing Body', 'Please enter notification details.');
      return;
    }

    setState(() => _isSending = true);

    try {
      await _repo.sendBroadcast(
        title: title,
        body: body,
        type: 'announcement',
        audience: _selectedAudience,
        payload: {
          'type': 'challenge_round',
          'challenge_id': widget.challenge.id,
          'title': widget.challenge.title,
          'subject_id': widget.challenge.subjectId,
          'duration_seconds': widget.challenge.durationSeconds,
          if (widget.challenge.startsAt != null)
            'starts_at': widget.challenge.startsAt!.toUtc().toIso8601String(),
          if (widget.challenge.endsAt != null)
            'ends_at': widget.challenge.endsAt!.toUtc().toIso8601String(),
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
        SnackbarHelper.success(
          'Notification Sent',
          'Push notification delivered to ${_audienceLabel(_selectedAudience)}.',
        );
      }
    } catch (e) {
      SnackbarHelper.error('Failed to Send', e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final audColor = _audienceColor(_selectedAudience);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notify Students',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Send push notification with challenge time and details',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: AppSizes.md),

                // Target Audience Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: audColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: audColor.withValues(alpha: 0.25)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAudience,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: audColor),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: dark ? Colors.white : Colors.black87,
                      ),
                      dropdownColor: dark ? AppColors.darkCard : AppColors.white,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Students (Natural & Social)'),
                        ),
                        DropdownMenuItem(
                          value: 'stream:natural',
                          child: Text('Natural Stream Only'),
                        ),
                        DropdownMenuItem(
                          value: 'stream:social',
                          child: Text('Social Stream Only'),
                        ),
                      ],
                      onChanged: _isSending
                          ? null
                          : (val) {
                              if (val != null) setState(() => _selectedAudience = val);
                            },
                    ),
                  ),
                ),

                const SizedBox(height: AppSizes.md),

                // Title input
                TextField(
                  controller: _titleCtrl,
                  enabled: !_isSending,
                  decoration: InputDecoration(
                    labelText: 'Notification Title',
                    labelStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.title_rounded, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

                const SizedBox(height: AppSizes.sm),

                // Body input (multiline for basic details)
                TextField(
                  controller: _bodyCtrl,
                  enabled: !_isSending,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Basic Details (Subject, Date, Time, Duration)',
                    alignLabelWithHint: true,
                    labelStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 12.5, height: 1.4),
                ),

                const SizedBox(height: AppSizes.lg),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_isSending ? 'Sending...' : 'Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
