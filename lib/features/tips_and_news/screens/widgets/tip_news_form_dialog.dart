import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/features/tips_and_news/controllers/admin_tips_news_controller.dart';
import 'package:m_admin/features/tips_and_news/models/admin_tip_news_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Modal dialog for creating and editing a Tip or News entry.
///
/// Fully responsive and overflow-proof across all screen dimensions.
class TipNewsFormDialog extends StatefulWidget {
  const TipNewsFormDialog({super.key, this.item});

  final AdminTipNewsModel? item;

  static Future<void> show(BuildContext context, {AdminTipNewsModel? item}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TipNewsFormDialog(item: item),
    );
  }

  @override
  State<TipNewsFormDialog> createState() => _TipNewsFormDialogState();
}

class _TipNewsFormDialogState extends State<TipNewsFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _contentController;

  late String _category;
  late String _audience;
  late bool _isPinned;
  late bool _isPublished;

  bool get isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _authorController =
        TextEditingController(text: item?.author ?? 'MatricMate Team');
    _imageUrlController = TextEditingController(text: item?.imageUrl ?? '');
    _contentController = TextEditingController(text: item?.content ?? '');

    _category = item?.category ?? 'news';
    _audience = item?.audience ?? 'both';
    _isPinned = item?.isPinned ?? false;
    _isPublished = item?.isPublished ?? true;

    _imageUrlController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _imageUrlController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = AdminTipsNewsController.instance;

    final model = AdminTipNewsModel(
      id: widget.item?.id ?? 0,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      category: _category,
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      author: _authorController.text.trim().isEmpty
          ? 'MatricMate Team'
          : _authorController.text.trim(),
      audience: _audience,
      isPinned: _isPinned,
      isPublished: _isPublished,
      createdAt: widget.item?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await controller.saveItem(model);
    if (success && mounted) {
      Navigator.of(context).pop();
    }
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 850),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dialog Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadiusMd),
                    ),
                    child: Icon(
                      isEditing
                          ? Iconsax.edit_2_copy
                          : Iconsax.add_circle_copy,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Broadcast' : 'New Broadcast',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isEditing
                              ? 'Update tip or news published to students'
                              : 'Create and publish study tips or news announcements',
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

            // ── Scrollable Form Body ──────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Segment Selector
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: dark
                              ? AppColors.darkGrey
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 400;
                          final newsTile = _CategorySelectorTile(
                            label: 'News Announcement',
                            subtitle: 'Updates, events & alerts',
                            icon: Iconsax.document_copy,
                            isSelected: _category == 'news',
                            onTap: () => setState(() => _category = 'news'),
                          );
                          final tipTile = _CategorySelectorTile(
                            label: 'Study Tip',
                            subtitle: 'Techniques & strategies',
                            icon: Iconsax.lamp_on_copy,
                            isSelected: _category == 'tip',
                            onTap: () => setState(() => _category = 'tip'),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                newsTile,
                                const SizedBox(height: 8),
                                tipTile,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: newsTile),
                              const SizedBox(width: 10),
                              Expanded(child: tipTile),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Target Audience & Author Row
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 450;
                          if (isNarrow) {
                            return Column(
                              children: [
                                _buildAudienceDropdown(dark),
                                const SizedBox(height: 12),
                                _buildAuthorField(),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: _buildAudienceDropdown(dark)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildAuthorField()),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Title Field
                      Text(
                        'Title (English or Amharic)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: dark
                              ? AppColors.darkGrey
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        maxLines: 2,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'e.g. 2019 E.C. National Exam Registration Guidelines',
                          isDense: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Banner Image URL Field & Live Preview
                      Text(
                        'Cover / Banner Image URL (Optional)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: dark
                              ? AppColors.darkGrey
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: InputDecoration(
                          hintText: 'https://example.com/banner.jpg',
                          isDense: true,
                          prefixIcon: const Icon(Iconsax.image_copy, size: 18),
                          suffixIcon: _imageUrlController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => _imageUrlController.clear(),
                                )
                              : null,
                        ),
                      ),
                      if (_imageUrlController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildImagePreview(dark),
                      ],
                      const SizedBox(height: 16),

                      // Content Body Field
                      Text(
                        'Content Body (Supports multi-paragraph Amharic & English)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: dark
                              ? AppColors.darkGrey
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _contentController,
                        maxLines: 9,
                        minLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Write or paste the full announcement or tip content here...',
                          isDense: true,
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter content body';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Switches: Pin & Publish
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF8FAFC),
                          borderRadius:
                              BorderRadius.circular(AppSizes.borderRadiusMd),
                          border: Border.all(
                            color: dark
                                ? AppColors.darkBorder
                                : AppColors.borderPrimary,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Row(
                                  children: [
                                    Icon(Iconsax.stickynote_copy,
                                        size: 16, color: Color(0xFFF59E0B)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Pin to Top of Student Feed',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: const Text(
                                  'Highlighted at the top of the Tips & News screen in the student app',
                                  style: TextStyle(fontSize: 11),
                                ),
                                value: _isPinned,
                                activeTrackColor: const Color(0xFFF59E0B),
                                onChanged: (val) =>
                                    setState(() => _isPinned = val),
                              ),
                              const Divider(height: 8),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Row(
                                  children: [
                                    Icon(Iconsax.eye_copy,
                                        size: 16, color: AppColors.success),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Publish Immediately',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: const Text(
                                  'If disabled, this item is stored as a draft hidden from students',
                                  style: TextStyle(fontSize: 11),
                                ),
                                value: _isPublished,
                                activeTrackColor: AppColors.success,
                                onChanged: (val) =>
                                    setState(() => _isPublished = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // ── Dialog Footer Actions ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  Obx(() {
                    final saving = controller.isSaving.value;
                    return ElevatedButton.icon(
                      onPressed: saving ? null : _submit,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isEditing
                                  ? Iconsax.tick_circle_copy
                                  : Iconsax.send_2_copy,
                              size: 16,
                            ),
                      label: Text(
                        saving
                            ? 'Saving...'
                            : (isEditing ? 'Save Changes' : 'Publish Broadcast'),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceDropdown(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Stream',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: dark ? AppColors.darkGrey : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _audience,
          isExpanded: true,
          isDense: true,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Iconsax.profile_2user_copy, size: 18),
          ),
          items: const [
            DropdownMenuItem(
              value: 'both',
              child: Text(
                'All Students (Both Streams)',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'natural',
              child: Text(
                'Natural Science',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'social',
              child: Text(
                'Social Science',
                style: TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _audience = val);
          },
        ),
      ],
    );
  }

  Widget _buildAuthorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Author / Department',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _authorController,
          decoration: const InputDecoration(
            hintText: 'e.g. MatricMate Team',
            isDense: true,
            prefixIcon: Icon(Iconsax.user_edit_copy, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(bool dark) {
    final url = _imageUrlController.text.trim();
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: dark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined,
                      size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Invalid or unreachable image URL',
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Live Preview',
                style: TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySelectorTile extends StatelessWidget {
  const _CategorySelectorTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: dark ? 0.2 : 0.08)
              : (dark ? AppColors.darkCard : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (dark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (dark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
