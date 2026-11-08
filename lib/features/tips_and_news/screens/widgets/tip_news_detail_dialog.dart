import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/features/tips_and_news/controllers/admin_tips_news_controller.dart';
import 'package:m_admin/features/tips_and_news/models/admin_tip_news_model.dart';
import 'package:m_admin/features/tips_and_news/screens/widgets/tip_news_form_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Modal dialog for viewing full details of a Tip or News entry.
///
/// Provides a clear, high-fidelity preview of the broadcast exactly
/// as students see it, with quick admin management actions.
class TipNewsDetailDialog extends StatelessWidget {
  const TipNewsDetailDialog({super.key, required this.item});

  final AdminTipNewsModel item;

  static Future<void> show(BuildContext context, {required AdminTipNewsModel item}) {
    return showDialog<void>(
      context: context,
      builder: (context) => TipNewsDetailDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final controller = AdminTipsNewsController.instance;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      backgroundColor: dark ? AppColors.darkSurface : AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dialog Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (item.isNews
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF8B5CF6))
                          .withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadiusMd),
                    ),
                    child: Icon(
                      item.isNews
                          ? Iconsax.document_copy
                          : Iconsax.lamp_on_copy,
                      color: item.isNews
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF8B5CF6),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.categoryLabel} Broadcast',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Target: ${item.audienceLabel}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: dark
                                ? AppColors.darkGrey
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Scrollable Body ───────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Optional Cover Image
                    if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSizes.borderRadiusMd),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 240),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF1F5F9),
                          ),
                          child: Image.network(
                            item.imageUrl!.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 120,
                              alignment: Alignment.center,
                              color: dark ? Colors.white10 : Colors.black12,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.broken_image_outlined,
                                      size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Image unreachable',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: dark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Badges Ribbon
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _categoryBadge(item.isNews),
                        _audienceBadge(item.audience),
                        if (item.isPinned) _pinnedBadge(),
                        _publishBadge(item.isPublished),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Full Title
                    SelectableText(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Author & Date Information Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF8FAFC),
                        borderRadius:
                            BorderRadius.circular(AppSizes.borderRadiusSm),
                        border: Border.all(
                          color: dark
                              ? AppColors.darkBorder
                              : AppColors.borderPrimary,
                        ),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.user_copy,
                                  size: 14,
                                  color: dark
                                      ? AppColors.darkGrey
                                      : AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  item.author,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.calendar_1_copy,
                                  size: 14,
                                  color: dark
                                      ? AppColors.darkGrey
                                      : AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  item.formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: dark
                                        ? AppColors.darkGrey
                                        : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Content Section Header
                    Text(
                      'Content Body',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            dark ? AppColors.darkGrey : AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Full Content (Selectable with clean typography)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkCard : const Color(0xFFFBFBFB),
                        borderRadius:
                            BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(
                          color: dark
                              ? AppColors.darkBorder
                              : AppColors.borderPrimary,
                        ),
                      ),
                      child: SelectableText(
                        item.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: dark ? AppColors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // ── Dialog Footer Actions ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Destructive Delete Button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      controller.deleteItem(item);
                    },
                    icon: const Icon(Iconsax.trash_copy,
                        size: 16, color: AppColors.error),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),

                  // Toggle Pin
                  OutlinedButton.icon(
                    onPressed: () {
                      controller.togglePin(item);
                      Navigator.of(context).pop();
                    },
                    icon: Icon(
                      Iconsax.stickynote_copy,
                      size: 15,
                      color: item.isPinned
                          ? const Color(0xFFF59E0B)
                          : Colors.grey,
                    ),
                    label: Text(
                      item.isPinned ? 'Unpin' : 'Pin to Top',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),

                  // Toggle Publish
                  OutlinedButton.icon(
                    onPressed: () {
                      controller.togglePublish(item);
                      Navigator.of(context).pop();
                    },
                    icon: Icon(
                      item.isPublished
                          ? Iconsax.eye_slash_copy
                          : Iconsax.eye_copy,
                      size: 15,
                      color: item.isPublished
                          ? AppColors.success
                          : Colors.grey,
                    ),
                    label: Text(
                      item.isPublished ? 'Move to Draft' : 'Publish',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),

                  // Edit Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      TipNewsFormDialog.show(context, item: item);
                    },
                    icon: const Icon(Iconsax.edit_2_copy, size: 15),
                    label: const Text('Edit Broadcast',
                        style: TextStyle(fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Badges ────────────────────────────────────────────────────────────────
  Widget _categoryBadge(bool isNews) {
    final color = isNews ? const Color(0xFF2563EB) : const Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isNews ? 'NEWS ANNOUNCEMENT' : 'STUDY TIP',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _audienceBadge(String audience) {
    String label;
    Color color;

    switch (audience.toLowerCase().trim()) {
      case 'natural':
        label = 'Natural Science';
        color = const Color(0xFF10B981);
        break;
      case 'social':
        label = 'Social Science';
        color = const Color(0xFF06B6D4);
        break;
      case 'both':
      default:
        label = 'All Streams';
        color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _pinnedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.stickynote_copy,
              size: 11, color: Color(0xFFD97706)),
          SizedBox(width: 4),
          Text(
            'PINNED BROADCAST',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD97706),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _publishBadge(bool isPublished) {
    final color = isPublished ? AppColors.success : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isPublished ? 'Published to Students' : 'Draft (Hidden)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
