import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/data/repositories/admin_payment_repository.dart';
import 'package:m_admin/features/payments/controllers/payments_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Interactive modal dialog to inspect and clean uploaded receipt screenshots
/// to reclaim cloud storage quota without losing revenue accounting records.
class ReceiptCleanupDialog extends StatefulWidget {
  const ReceiptCleanupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ReceiptCleanupDialog(),
    );
  }

  @override
  State<ReceiptCleanupDialog> createState() => _ReceiptCleanupDialogState();
}

class _ReceiptCleanupDialogState extends State<ReceiptCleanupDialog> {
  final _controller = PaymentsController.instance;

  bool _loadingStats = true;
  bool _isProcessing = false;
  String _processingMessage = '';
  ReceiptStorageStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final s = await _controller.fetchCleanupStats();
      if (mounted) {
        setState(() {
          _stats = s;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _cleanOlderThanOneWeek() async {
    if (_stats == null || _stats!.olderThanOneWeekScreenshots == 0) {
      SnackbarHelper.info('No files', 'No active screenshots older than 7 days were found.');
      return;
    }

    final confirmed = await _confirmDialog(
      title: 'Delete Screenshots Older Than 1 Week?',
      message:
          'This will delete ${_stats!.olderThanOneWeekScreenshots} uploaded screenshot(s) older than 7 days from cloud storage (Cloudflare R2).\n\n'
          'All approved payments, subscription records, and revenue totals remain completely untouched in the database.',
      confirmLabel: 'Delete Old Screenshots',
      color: AppColors.primary,
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Deleting screenshots older than 7 days...';
    });

    try {
      final count = await _controller.deleteActiveScreenshots(olderThanOneWeekOnly: true);
      SnackbarHelper.success('Storage Reclaimed', 'Deleted $count old screenshot(s) from storage.');
      await _loadStats();
    } catch (e) {
      SnackbarHelper.error('Error', 'Failed to delete screenshots: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cleanAllActive() async {
    if (_stats == null || _stats!.totalActiveScreenshots == 0) {
      SnackbarHelper.info('No files', 'No active receipt screenshots to delete.');
      return;
    }

    final confirmed = await _confirmDialog(
      title: 'Delete All Active Screenshots?',
      message:
          'This will delete all ${_stats!.totalActiveScreenshots} uploaded screenshot(s) for approved subscribers from cloud storage (Cloudflare R2).\n\n'
          'Accounting data (amounts, plans, approval dates) will remain 100% intact in the database.',
      confirmLabel: 'Delete All Active Screenshots',
      color: AppColors.warning,
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Deleting all active subscriber screenshots...';
    });

    try {
      final count = await _controller.deleteActiveScreenshots(olderThanOneWeekOnly: false);
      SnackbarHelper.success('Storage Reclaimed', 'Deleted $count active screenshot(s) from storage.');
      await _loadStats();
    } catch (e) {
      SnackbarHelper.error('Error', 'Failed to delete screenshots: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _purgeRejected() async {
    if (_stats == null || _stats!.rejectedReceiptsCount == 0) {
      SnackbarHelper.info('Clean', 'There are no rejected receipts in the database.');
      return;
    }

    final confirmed = await _confirmDialog(
      title: 'Purge All Rejected Receipts?',
      message:
          'This will permanently delete ${_stats!.rejectedReceiptsCount} rejected receipt(s) and their storage screenshots from the database.\n\n'
          'This action cannot be undone.',
      confirmLabel: 'Purge Rejected Receipts',
      color: AppColors.error,
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Purging rejected receipts from database and storage...';
    });

    try {
      final count = await _controller.purgeAllRejected();
      SnackbarHelper.success('Purged', 'Removed $count rejected receipt(s) and storage files.');
      await _loadStats();
    } catch (e) {
      SnackbarHelper.error('Error', 'Failed to purge rejected receipts: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color color,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return AlertDialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, 0),
      contentPadding: const EdgeInsets.all(AppSizes.md),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cleaning_services_rounded,
              color: AppColors.primary,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Text(
              'Receipt Storage Cleanup',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reclaim cloud storage quota by cleaning uploaded screenshots. For approved subscribers, revenue records and audit logs are retained while heavy image files are purged.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: dark ? AppColors.textSecondary : AppColors.darkGrey,
                ),
              ),
              const SizedBox(height: AppSizes.md),

              // ── Live Metric Tiles ──────────────────────────────────────────
              if (_loadingStats)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_stats != null)
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Active Screenshots',
                        value: NumberFormat('#,##0').format(_stats!.totalActiveScreenshots),
                        icon: Iconsax.image_copy,
                        color: AppColors.primary,
                        subtitle: '~${(_stats!.totalActiveScreenshots * 0.25).toStringAsFixed(1)} MB',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: '> 1 Week Old',
                        value: NumberFormat('#,##0').format(_stats!.olderThanOneWeekScreenshots),
                        icon: Iconsax.timer_1_copy,
                        color: AppColors.warning,
                        subtitle: '~${(_stats!.olderThanOneWeekScreenshots * 0.25).toStringAsFixed(1)} MB',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        label: 'Rejected in DB',
                        value: NumberFormat('#,##0').format(_stats!.rejectedReceiptsCount),
                        icon: Iconsax.close_circle_copy,
                        color: AppColors.error,
                        subtitle: _stats!.rejectedReceiptsCount > 0 ? 'Purgeable' : 'Clean',
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSizes.md),

              if (_isProcessing)
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _processingMessage,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                // ── Action 1: Delete screenshots older than 1 week ─────────────
                _ActionTile(
                  icon: Iconsax.calendar_tick_copy,
                  iconColor: AppColors.primary,
                  title: 'Delete Active Screenshots > 7 Days Old',
                  subtitle:
                      'Safely deletes verified receipts older than 1 week from storage while keeping recent submissions.',
                  buttonLabel: 'Clean > 1 Week',
                  buttonColor: AppColors.primary,
                  enabled: (_stats?.olderThanOneWeekScreenshots ?? 0) > 0,
                  onTap: _cleanOlderThanOneWeek,
                ),
                const SizedBox(height: 8),

                // ── Action 2: Delete all active screenshots ───────────────────
                _ActionTile(
                  icon: Iconsax.trash_copy,
                  iconColor: AppColors.warning,
                  title: 'Delete All Active Screenshots',
                  subtitle:
                      'Purges screenshots for all approved subscribers. Full financial & subscription data stays intact.',
                  buttonLabel: 'Clean All Active',
                  buttonColor: AppColors.warning,
                  enabled: (_stats?.totalActiveScreenshots ?? 0) > 0,
                  onTap: _cleanAllActive,
                ),
                const SizedBox(height: 8),

                // ── Action 3: Purge remaining rejected receipts ───────────────
                _ActionTile(
                  icon: Iconsax.close_circle_copy,
                  iconColor: AppColors.error,
                  title: 'Purge All Rejected Receipts',
                  subtitle:
                      'Permanently deletes leftover rejected receipt rows and their screenshots from the database.',
                  buttonLabel: 'Purge Rejected',
                  buttonColor: AppColors.error,
                  enabled: (_stats?.rejectedReceiptsCount ?? 0) > 0,
                  onTap: _purgeRejected,
                ),
                const SizedBox(height: AppSizes.md),

                // ── Auto-cleanup toggle ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: AppSizes.xs),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSurface : AppColors.softGrey,
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                    border: Border.all(color: borderColor),
                  ),
                  child: Obx(() {
                    final autoEnabled = _controller.autoCleanupOneWeek.value;

                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: autoEnabled,
                      onChanged: _controller.toggleAutoCleanup,
                      title: const Text(
                        'Auto-delete active screenshots after 1 week',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Runs automatically in the background once per day when the app starts.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.softGrey,
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
              Icon(icon, size: 14, color: color),
              const Spacer(),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.softGrey,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              elevation: 0,
            ),
            onPressed: enabled ? onTap : null,
            child: Text(buttonLabel, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
