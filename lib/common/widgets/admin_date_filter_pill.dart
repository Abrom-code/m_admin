import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

enum DatePreset {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  custom,
}

class AdminDateFilterPill extends StatelessWidget {
  const AdminDateFilterPill({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
    this.defaultLabel = 'Date',
    this.firstDate,
    this.lastDate,
  });

  final DateTimeRange? selectedRange;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final String defaultLabel;
  final DateTime? firstDate;
  final DateTime? lastDate;

  static DateTimeRange normalize(DateTimeRange range) {
    return DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999),
    );
  }

  static DateTimeRange getPresetRange(DatePreset preset) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (preset) {
      case DatePreset.today:
        return DateTimeRange(start: todayStart, end: todayEnd);

      case DatePreset.yesterday:
        final yest = now.subtract(const Duration(days: 1));
        return DateTimeRange(
          start: DateTime(yest.year, yest.month, yest.day),
          end: DateTime(yest.year, yest.month, yest.day, 23, 59, 59, 999),
        );

      case DatePreset.last7Days:
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 6)),
          end: todayEnd,
        );

      case DatePreset.last30Days:
        return DateTimeRange(
          start: todayStart.subtract(const Duration(days: 29)),
          end: todayEnd,
        );

      case DatePreset.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: todayEnd,
        );

      case DatePreset.lastMonth:
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        final lastDayOfPrevMonth = DateTime(now.year, now.month, 0);
        return DateTimeRange(
          start: prevMonth,
          end: DateTime(
            lastDayOfPrevMonth.year,
            lastDayOfPrevMonth.month,
            lastDayOfPrevMonth.day,
            23,
            59,
            59,
            999,
          ),
        );

      case DatePreset.custom:
        return DateTimeRange(start: todayStart, end: todayEnd);
    }
  }

  String _formatLabel() {
    final range = selectedRange;
    if (range == null) return defaultLabel;

    final now = DateTime.now();
    final startDay = DateTime(range.start.year, range.start.month, range.start.day);
    final endDay = DateTime(range.end.year, range.end.month, range.end.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (startDay == today && endDay == today) return 'Today';
    if (startDay == yesterday && endDay == yesterday) return 'Yesterday';

    final daysDiff = endDay.difference(startDay).inDays;
    if (endDay == today && daysDiff == 6) return 'Last 7 Days';
    if (endDay == today && daysDiff == 29) return 'Last 30 Days';
    if (startDay == DateTime(now.year, now.month, 1) && endDay == today) {
      return 'This Month';
    }

    if (startDay.year == endDay.year && startDay.year == now.year) {
      return '${DateFormat('d MMM').format(startDay)} – ${DateFormat('d MMM').format(endDay)}';
    }
    return '${DateFormat('d MMM yy').format(startDay)} – ${DateFormat('d MMM yy').format(endDay)}';
  }

  Future<void> _pickCustom(BuildContext context) async {
    final initial = selectedRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate ?? DateTime(2023),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initial,
      builder: (context, child) {
        final dark = AppHelperFunctions.isDark(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              surface: dark ? AppColors.darkSurface : Colors.white,
              onSurface: dark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      onRangeChanged(normalize(picked));
    }
  }

  void _showPresetsMenu(BuildContext context, Offset position) async {
    final dark = AppHelperFunctions.isDark(context);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 200,
        position.dy + 300,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        side: BorderSide(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      color: dark ? AppColors.darkSurface : Colors.white,
      items: [
        _buildItem('today', 'Today', Icons.today_rounded),
        _buildItem('yesterday', 'Yesterday', Icons.history_rounded),
        _buildItem('last7', 'Last 7 Days', Icons.date_range_rounded),
        _buildItem('last30', 'Last 30 Days', Icons.calendar_view_month_rounded),
        _buildItem('thisMonth', 'This Month', Icons.calendar_today_rounded),
        _buildItem('lastMonth', 'Last Month', Icons.event_note_rounded),
        const PopupMenuDivider(height: 8),
        _buildItem('custom', 'Custom Range...', Iconsax.calendar_1_copy, highlight: true),
        if (selectedRange != null) ...[
          const PopupMenuDivider(height: 8),
          _buildItem('clear', 'Clear Filter (All Time)', Icons.close_rounded, isDestructive: true),
        ],
      ],
    );

    if (selected == null) return;

    if (selected == 'clear') {
      onRangeChanged(null);
    } else if (selected == 'custom') {
      if (context.mounted) {
        await _pickCustom(context);
      }
    } else if (selected == 'today') {
      onRangeChanged(getPresetRange(DatePreset.today));
    } else if (selected == 'yesterday') {
      onRangeChanged(getPresetRange(DatePreset.yesterday));
    } else if (selected == 'last7') {
      onRangeChanged(getPresetRange(DatePreset.last7Days));
    } else if (selected == 'last30') {
      onRangeChanged(getPresetRange(DatePreset.last30Days));
    } else if (selected == 'thisMonth') {
      onRangeChanged(getPresetRange(DatePreset.thisMonth));
    } else if (selected == 'lastMonth') {
      onRangeChanged(getPresetRange(DatePreset.lastMonth));
    }
  }

  PopupMenuItem<String> _buildItem(
    String value,
    String text,
    IconData icon, {
    bool highlight = false,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? AppColors.error
        : (highlight ? AppColors.primary : null);

    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final isActive = selectedRange != null;
    final primary = AppColors.primary;
    final borderColor = isActive
        ? primary
        : (dark ? AppColors.darkBorder : AppColors.borderPrimary);

    return InkWell(
      onTapDown: (details) => _showPresetsMenu(context, details.globalPosition),
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? primary.withValues(alpha: dark ? 0.2 : 0.08)
              : (dark ? AppColors.darkSurface : AppColors.white),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          border: Border.all(
            color: borderColor,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.calendar_copy,
              size: 14,
              color: isActive ? primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _formatLabel(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? primary
                    : (dark ? AppColors.white : AppColors.textPrimary),
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => onRangeChanged(null),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: primary,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
