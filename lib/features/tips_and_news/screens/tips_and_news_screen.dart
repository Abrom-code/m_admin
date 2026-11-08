import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/features/tips_and_news/controllers/admin_tips_news_controller.dart';
import 'package:m_admin/features/tips_and_news/models/admin_tip_news_model.dart';
import 'package:m_admin/features/tips_and_news/screens/widgets/tip_news_detail_dialog.dart';
import 'package:m_admin/features/tips_and_news/screens/widgets/tip_news_form_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Admin screen for managing Tips and News broadcasts.
class TipsAndNewsScreen extends StatelessWidget {
  const TipsAndNewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AdminTipsNewsController());
    final dark = AppHelperFunctions.isDark(context);

    return AdminScaffold(
      pageIndex: AdminNavPage.tipsAndNews,
      onRefresh: ctrl.loadItems,
      physics: const ClampingScrollPhysics(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Stat Summary Ribbon ─────────────────────────────────────────
          Obx(() {
            final catFilter = ctrl.selectedCategory.value;
            final pubFilter = ctrl.selectedPublishStatus.value;

            return SingleChildScrollView(
              primary: false,
              physics: const ClampingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SummaryRibbonCard(
                    label: 'Total Items',
                    value: NumberFormat('#,##0').format(ctrl.totalCount),
                    dotColor: AppColors.primary,
                    icon: Iconsax.lamp_charge_copy,
                    isSelected: catFilter == 'all' && pubFilter == 'all',
                    onTap: () {
                      ctrl.selectedCategory.value = 'all';
                      ctrl.selectedPublishStatus.value = 'all';
                    },
                  ),
                  const SizedBox(width: 8),
                  _SummaryRibbonCard(
                    label: 'News',
                    value: NumberFormat('#,##0').format(ctrl.newsCount),
                    dotColor: const Color(0xFF2563EB),
                    icon: Iconsax.document_copy,
                    isSelected: catFilter == 'news',
                    onTap: () {
                      ctrl.selectedCategory.value =
                          catFilter == 'news' ? 'all' : 'news';
                    },
                  ),
                  const SizedBox(width: 8),
                  _SummaryRibbonCard(
                    label: 'Study Tips',
                    value: NumberFormat('#,##0').format(ctrl.tipsCount),
                    dotColor: const Color(0xFF8B5CF6),
                    icon: Iconsax.lamp_on_copy,
                    isSelected: catFilter == 'tip',
                    onTap: () {
                      ctrl.selectedCategory.value =
                          catFilter == 'tip' ? 'all' : 'tip';
                    },
                  ),
                  const SizedBox(width: 8),
                  _SummaryRibbonCard(
                    label: 'Published',
                    value: NumberFormat('#,##0').format(ctrl.publishedCount),
                    dotColor: AppColors.success,
                    icon: Iconsax.eye_copy,
                    isSelected: pubFilter == 'published',
                    onTap: () {
                      ctrl.selectedPublishStatus.value =
                          pubFilter == 'published' ? 'all' : 'published';
                    },
                  ),
                  const SizedBox(width: 8),
                  _SummaryRibbonCard(
                    label: 'Pinned',
                    value: NumberFormat('#,##0').format(ctrl.pinnedCount),
                    dotColor: const Color(0xFFF59E0B),
                    icon: Iconsax.stickynote_copy,
                    isSelected: false,
                    onTap: () {},
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSizes.spaceBtwSections),

          // ── Search & Filter Bar ─────────────────────────────────────────
          _buildFilterBar(context, ctrl, dark),
          const SizedBox(height: AppSizes.md),

          // ── Batch Selection Bar ─────────────────────────────────────────
          Obx(() {
            if (!ctrl.isSelectionMode) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.md),
              child: _buildBatchBar(context, ctrl, dark),
            );
          }),

          // ── Content Area: List or Empty / Loader ────────────────────────
          Obx(() {
            if (ctrl.isLoading.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: AppCircularLoading(title: 'Loading broadcasts...'),
                ),
              );
            }

            final items = ctrl.filteredItems;
            if (items.isEmpty) {
              return _buildEmptyState(context, ctrl, dark);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return _buildWideList(context, ctrl, items, dark);
                }
                return _buildMobileList(context, ctrl, items, dark);
              },
            );
          }),
        ],
      ),
    );
  }

  // ── Filter & Search Bar ───────────────────────────────────────────────────
  Widget _buildFilterBar(
      BuildContext context, AdminTipsNewsController ctrl, bool dark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        final searchField = SizedBox(
          width: isNarrow ? double.infinity : 280,
          child: TextField(
            onChanged: (val) => ctrl.searchQuery.value = val,
            decoration: InputDecoration(
              hintText: 'Search title, content, author...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon:
                  const Icon(Iconsax.search_normal_1_copy, size: 16),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: Obx(() {
                if (ctrl.searchQuery.value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => ctrl.searchQuery.value = '',
                );
              }),
            ),
          ),
        );

        final audienceDropdown = Obx(() => DropdownButton<String>(
              value: ctrl.selectedAudience.value,
              isDense: true,
              underline: const SizedBox.shrink(),
              dropdownColor: dark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Streams', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'both',
                  child: Text('Both (Common)', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'natural',
                  child:
                      Text('Natural Science', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'social',
                  child:
                      Text('Social Science', style: TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (val) {
                if (val != null) ctrl.selectedAudience.value = val;
              },
            ));

        final categoryDropdown = Obx(() => DropdownButton<String>(
              value: ctrl.selectedCategory.value,
              isDense: true,
              underline: const SizedBox.shrink(),
              dropdownColor: dark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child:
                      Text('All Categories', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'news',
                  child: Text('News Only', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'tip',
                  child: Text('Tips Only', style: TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (val) {
                if (val != null) ctrl.selectedCategory.value = val;
              },
            ));

        final statusDropdown = Obx(() => DropdownButton<String>(
              value: ctrl.selectedPublishStatus.value,
              isDense: true,
              underline: const SizedBox.shrink(),
              dropdownColor: dark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Status', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'published',
                  child: Text('Published', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'draft',
                  child: Text('Draft', style: TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (val) {
                if (val != null) ctrl.selectedPublishStatus.value = val;
              },
            ));

        final newButton = ElevatedButton.icon(
          onPressed: () => TipNewsFormDialog.show(context),
          icon: const Icon(Iconsax.add_circle_copy, size: 16),
          label: const Text('New Broadcast'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 8),
                  newButton,
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: [
                    _filterChipContainer(dark, audienceDropdown),
                    const SizedBox(width: 8),
                    _filterChipContainer(dark, categoryDropdown),
                    const SizedBox(width: 8),
                    _filterChipContainer(dark, statusDropdown),
                  ],
                ),
              ),
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            searchField,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _filterChipContainer(dark, audienceDropdown),
                _filterChipContainer(dark, categoryDropdown),
                _filterChipContainer(dark, statusDropdown),
                Obx(() {
                  final hasFilters = ctrl.selectedCategory.value != 'all' ||
                      ctrl.selectedAudience.value != 'all' ||
                      ctrl.selectedPublishStatus.value != 'all' ||
                      ctrl.searchQuery.value.isNotEmpty;
                  if (!hasFilters) return const SizedBox.shrink();

                  return TextButton.icon(
                    onPressed: () {
                      ctrl.selectedCategory.value = 'all';
                      ctrl.selectedAudience.value = 'all';
                      ctrl.selectedPublishStatus.value = 'all';
                      ctrl.searchQuery.value = '';
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label:
                        const Text('Reset', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }),
              ],
            ),
            newButton,
          ],
        );
      },
    );
  }

  Widget _filterChipContainer(bool dark, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      child: child,
    );
  }

  // ── Batch Bar ─────────────────────────────────────────────────────────────
  Widget _buildBatchBar(
      BuildContext context, AdminTipsNewsController ctrl, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: dark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.tick_circle_copy,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${ctrl.selectedIds.length} item(s) selected',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: ctrl.selectAll,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Select All', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: ctrl.deselectAll,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: () => ctrl.batchPinSelected(true),
                icon: const Icon(Iconsax.stickynote_copy,
                    size: 13, color: Color(0xFFF59E0B)),
                label:
                    const Text('Pin All', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => ctrl.batchPublishSelected(true),
                icon: const Icon(Iconsax.eye_copy,
                    size: 13, color: AppColors.success),
                label:
                    const Text('Publish All', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              ElevatedButton.icon(
                onPressed: ctrl.deleteSelected,
                icon: const Icon(Iconsax.trash_copy, size: 13),
                label: const Text('Delete Selected',
                    style: TextStyle(fontSize: 11.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Wide Screen List (Desktop / Tablet) ───────────────────────────────────
  Widget _buildWideList(
    BuildContext context,
    AdminTipsNewsController ctrl,
    List<AdminTipNewsModel> items,
    bool dark,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _TipNewsCard(item: item, ctrl: ctrl, isWide: true);
      },
    );
  }

  // ── Mobile Screen List ────────────────────────────────────────────────────
  Widget _buildMobileList(
    BuildContext context,
    AdminTipsNewsController ctrl,
    List<AdminTipNewsModel> items,
    bool dark,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _TipNewsCard(item: item, ctrl: ctrl, isWide: false);
      },
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(
      BuildContext context, AdminTipsNewsController ctrl, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.lamp_charge_copy,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Tips or News Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            ctrl.searchQuery.value.isNotEmpty ||
                    ctrl.selectedCategory.value != 'all' ||
                    ctrl.selectedAudience.value != 'all'
                ? 'Try adjusting your search query or active filter chips.'
                : 'Share study strategies, updates, and exam announcements with students.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: dark ? AppColors.darkGrey : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => TipNewsFormDialog.show(context),
            icon: const Icon(Iconsax.add_circle_copy, size: 16),
            label: const Text('Create First Broadcast'),
          ),
        ],
      ),
    );
  }
}

// ── Summary Ribbon Card ─────────────────────────────────────────────────────
class _SummaryRibbonCard extends StatelessWidget {
  const _SummaryRibbonCard({
    required this.label,
    required this.value,
    required this.dotColor,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color dotColor;
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? dotColor.withValues(alpha: dark ? 0.22 : 0.1)
              : (dark ? AppColors.darkSurface : AppColors.white),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(
            color: isSelected
                ? dotColor
                : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: dotColor),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? dotColor : null,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: dark ? AppColors.darkGrey : AppColors.textSecondary,
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

// ── Broadcast Item Card ─────────────────────────────────────────────────────
class _TipNewsCard extends StatelessWidget {
  const _TipNewsCard({
    required this.item,
    required this.ctrl,
    required this.isWide,
  });

  final AdminTipNewsModel item;
  final AdminTipsNewsController ctrl;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Obx(() {
      final isSelected = ctrl.selectedIds.contains(item.id);

      return Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: dark ? 0.18 : 0.08)
              : (dark ? AppColors.darkSurface : AppColors.white),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (item.isPinned
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                    : (dark ? AppColors.darkBorder : AppColors.borderPrimary)),
            width: isSelected ? 2.0 : (item.isPinned ? 1.5 : 1.0),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            else if (item.isPinned)
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: InkWell(
          onTap: () {
            if (ctrl.isSelectionMode) {
              ctrl.toggleSelection(item.id);
            } else {
              TipNewsDetailDialog.show(context, item: item);
            }
          },
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: isWide
                ? _buildWideRow(context, dark, isSelected)
                : _buildMobileColumn(context, dark, isSelected),
          ),
        ),
      );
    });
  }

  // ── Wide Layout (Desktop / Tablet) ────────────────────────────────────────
  Widget _buildWideRow(BuildContext context, bool dark, bool isSelected) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selection checkbox
        Checkbox(
          value: isSelected,
          activeColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (_) => ctrl.toggleSelection(item.id),
        ),
        const SizedBox(width: 8),

        // Optional Thumbnail Image
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
              border: Border.all(
                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 24, color: Colors.grey.withValues(alpha: 0.6)),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],

        // Main Content (Title, Snippet, Metadata)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Row
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _categoryBadge(item.isNews),
                        _audienceBadge(item.audience),
                        if (item.isPinned) _pinnedBadge(),
                        _publishBadge(item.isPublished),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.formattedDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Title
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Content snippet
              Text(
                item.snippet,
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Bottom Info: Author & Read Time
              Row(
                children: [
                  Icon(Iconsax.user_copy,
                      size: 13,
                      color: dark
                          ? AppColors.darkGrey
                          : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: dark
                            ? AppColors.darkGrey
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Action Buttons Row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // View Details
            IconButton(
              icon: const Icon(Iconsax.eye_copy, size: 18),
              tooltip: 'View Details',
              onPressed: () => TipNewsDetailDialog.show(context, item: item),
            ),

            // Pin Toggle
            IconButton(
              icon: Icon(
                item.isPinned
                    ? Iconsax.stickynote_copy
                    : Iconsax.stickynote_copy,
                size: 18,
                color: item.isPinned
                    ? const Color(0xFFF59E0B)
                    : (dark ? Colors.white38 : Colors.grey),
              ),
              tooltip: item.isPinned ? 'Unpin Broadcast' : 'Pin to Top',
              onPressed: () => ctrl.togglePin(item),
            ),

            // Publish Toggle
            IconButton(
              icon: Icon(
                item.isPublished
                    ? Iconsax.eye_slash_copy
                    : Iconsax.eye_copy,
                size: 18,
                color: item.isPublished
                    ? AppColors.success
                    : (dark ? Colors.white38 : Colors.grey),
              ),
              tooltip: item.isPublished ? 'Move to Draft' : 'Publish',
              onPressed: () => ctrl.togglePublish(item),
            ),

            // Edit
            IconButton(
              icon: const Icon(Iconsax.edit_2_copy, size: 18),
              tooltip: 'Edit Broadcast',
              onPressed: () => TipNewsFormDialog.show(context, item: item),
            ),

            // Delete
            IconButton(
              icon: const Icon(Iconsax.trash_copy,
                  size: 18, color: AppColors.error),
              tooltip: 'Delete Broadcast',
              onPressed: () => ctrl.deleteItem(item),
            ),
          ],
        ),
      ],
    );
  }

  // ── Mobile Layout (Cards for Narrow Screens) ──────────────────────────────
  Widget _buildMobileColumn(BuildContext context, bool dark, bool isSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Badges & Actions
        Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => ctrl.toggleSelection(item.id),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _categoryBadge(item.isNews),
                  _audienceBadge(item.audience),
                  if (item.isPinned) _pinnedBadge(),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.formattedDate,
              style: TextStyle(
                fontSize: 10.5,
                color: dark ? AppColors.darkGrey : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          item.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Snippet
        Text(
          item.snippet,
          style: TextStyle(
            fontSize: 11.5,
            color: dark ? AppColors.darkGrey : AppColors.textSecondary,
            height: 1.35,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),

        // Bottom Row: Publish Status + Quick Actions
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _publishBadge(item.isPublished),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Button
                InkWell(
                  onTap: () => TipNewsDetailDialog.show(context, item: item),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Iconsax.eye_copy, size: 16),
                  ),
                ),
                const SizedBox(width: 6),

                // Pin Button
                InkWell(
                  onTap: () => ctrl.togglePin(item),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Iconsax.stickynote_copy,
                      size: 16,
                      color: item.isPinned
                          ? const Color(0xFFF59E0B)
                          : (dark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Publish Button
                InkWell(
                  onTap: () => ctrl.togglePublish(item),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      item.isPublished
                          ? Iconsax.eye_slash_copy
                          : Iconsax.eye_copy,
                      size: 16,
                      color: item.isPublished
                          ? AppColors.success
                          : (dark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Edit Button
                InkWell(
                  onTap: () => TipNewsFormDialog.show(context, item: item),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Iconsax.edit_2_copy, size: 16),
                  ),
                ),
                const SizedBox(width: 6),

                // Delete Button
                InkWell(
                  onTap: () => ctrl.deleteItem(item),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Iconsax.trash_copy,
                        size: 16, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Badges ────────────────────────────────────────────────────────────────
  Widget _categoryBadge(bool isNews) {
    final color = isNews ? const Color(0xFF2563EB) : const Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isNews ? 'NEWS' : 'TIP',
        style: TextStyle(
          fontSize: 9.5,
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
        label = 'Natural';
        color = const Color(0xFF10B981);
        break;
      case 'social':
        label = 'Social';
        color = const Color(0xFF06B6D4);
        break;
      case 'both':
      default:
        label = 'All Streams';
        color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _pinnedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              size: 10, color: Color(0xFFD97706)),
          SizedBox(width: 3),
          Text(
            'PINNED',
            style: TextStyle(
              fontSize: 9,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isPublished ? 'Published' : 'Draft',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
