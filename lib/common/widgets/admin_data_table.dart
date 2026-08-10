import 'package:flutter/material.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Column definition for [AdminDataTable].
class AdminColumn<T> {
  const AdminColumn({
    required this.label,
    required this.cell,
    this.sortKey,
    this.width,
    this.flex = 1,
    this.numeric = false,
  });

  final String label;

  /// Builds the cell for a row. Kept as a builder rather than a string so a
  /// cell can be a chip, a pill or a button without a second mechanism.
  final Widget Function(BuildContext context, T row) cell;

  /// Non-null makes the column sortable; the value is handed back to
  /// [AdminDataTable.onSort] so the caller can sort server-side.
  final String? sortKey;

  final double? width;
  final int flex;
  final bool numeric;
}

/// The single table used by every list screen in the console.
///
/// Handles loading, empty and error states, sortable headers, horizontal
/// scrolling on narrow widths, and pagination. Feature screens supply columns
/// and rows; they must not hand-roll a second table.
class AdminDataTable<T> extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.emptyTitle = 'No data yet',
    this.emptyMessage,
    this.onRowTap,
    this.rowActions,
    this.sortKey,
    this.sortAscending = true,
    this.onSort,
    this.page = 0,
    this.pageSize = 25,
    this.totalCount,
    this.onPageChanged,
    this.minWidth = 900,
  });

  final List<AdminColumn<T>> columns;
  final List<T> rows;

  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  /// Pull-to-refresh callback. When supplied, the table's scrollable rows
  /// area gets a [RefreshIndicator].
  final Future<void> Function()? onRefresh;

  final String emptyTitle;
  final String? emptyMessage;

  final void Function(T row)? onRowTap;

  /// Trailing per-row action slot, pinned to the right of every row.
  final Widget Function(BuildContext context, T row)? rowActions;

  final String? sortKey;
  final bool sortAscending;
  final void Function(String key, bool ascending)? onSort;

  final int page;
  final int pageSize;

  /// Total matching rows across all pages. Null disables the count readout
  /// and the forward-limit check.
  final int? totalCount;

  final void Function(int page)? onPageChanged;

  /// Below this width the table scrolls horizontally rather than crushing
  /// columns into illegibility.
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _buildBody(context)),
          if (onPageChanged != null && error == null)
            _Pagination(
              page: page,
              pageSize: pageSize,
              rowCount: rows.length,
              totalCount: totalCount,
              onPageChanged: onPageChanged!,
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (error != null) return _ErrorState(message: error!, onRetry: onRetry);

    if (isLoading && rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
        child: AppCircularLoading(),
      );
    }

    if (rows.isEmpty) {
      // Wrap in a scrollable so pull-to-refresh still fires on empty state.
      if (onRefresh != null) {
        return RefreshIndicator(
          onRefresh: onRefresh!,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [_EmptyState(title: emptyTitle, message: emptyMessage)],
          ),
        );
      }
      return _EmptyState(title: emptyTitle, message: emptyMessage);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final needsScroll = constraints.maxWidth < minWidth;
        final tableWidth = needsScroll ? minWidth : constraints.maxWidth;

        final table = SizedBox(
          width: tableWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderRow<T>(
                columns: columns,
                hasActions: rowActions != null,
                sortKey: sortKey,
                sortAscending: sortAscending,
                onSort: onSort,
              ),
              Flexible(child: _buildRowsList(context)),
            ],
          ),
        );

        return needsScroll
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: table,
              )
            : table;
      },
    );
  }

  /// Builds the scrollable rows list, wrapped in a [RefreshIndicator] when
  /// [onRefresh] is provided so dragging down reloads the table.
  Widget _buildRowsList(BuildContext context) {
    final list = ListView.separated(
      physics: onRefresh != null
          ? const AlwaysScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (context, _) => Divider(
        height: 1,
        color: AppHelperFunctions.isDark(context)
            ? AppColors.darkBorder
            : AppColors.borderPrimary,
      ),
      itemBuilder: (context, index) => _BodyRow<T>(
        row: rows[index],
        columns: columns,
        onTap: onRowTap,
        rowActions: rowActions,
      ),
    );

    if (onRefresh != null) {
      return RefreshIndicator(onRefresh: onRefresh!, child: list);
    }
    return list;
  }
}

// ── Header ────────────────────────────────────────────────────────────

class _HeaderRow<T> extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.hasActions,
    required this.sortKey,
    required this.sortAscending,
    required this.onSort,
  });

  final List<AdminColumn<T>> columns;
  final bool hasActions;
  final String? sortKey;
  final bool sortAscending;
  final void Function(String key, bool ascending)? onSort;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.softGrey,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSizes.borderRadiusLg),
          topRight: Radius.circular(AppSizes.borderRadiusLg),
        ),
      ),
      child: Row(
        children: [
          for (final column in columns)
            _cellWrapper(
              column: column,
              child: _HeaderCell(
                column: column,
                isSorted: sortKey != null && sortKey == column.sortKey,
                ascending: sortAscending,
                onSort: onSort,
              ),
            ),
          if (hasActions) const SizedBox(width: 120),
        ],
      ),
    );
  }

  Widget _cellWrapper({required AdminColumn<T> column, required Widget child}) {
    if (column.width != null) {
      return SizedBox(width: column.width, child: child);
    }
    return Expanded(flex: column.flex, child: child);
  }
}

class _HeaderCell<T> extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.isSorted,
    required this.ascending,
    required this.onSort,
  });

  final AdminColumn<T> column;
  final bool isSorted;
  final bool ascending;
  final void Function(String key, bool ascending)? onSort;

  @override
  Widget build(BuildContext context) {
    final sortable = column.sortKey != null && onSort != null;

    final label = Row(
      mainAxisAlignment: column.numeric
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            column.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: isSorted ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
        if (isSorted)
          Icon(
            ascending ? Icons.arrow_upward : Icons.arrow_downward,
            size: AppSizes.iconXs,
            color: AppColors.primary,
          ),
      ],
    );

    if (!sortable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
        child: label,
      );
    }

    return InkWell(
      onTap: () => onSort!(column.sortKey!, isSorted ? !ascending : true),
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.xs,
          vertical: AppSizes.xs,
        ),
        child: label,
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────

class _BodyRow<T> extends StatelessWidget {
  const _BodyRow({
    required this.row,
    required this.columns,
    required this.onTap,
    required this.rowActions,
  });

  final T row;
  final List<AdminColumn<T>> columns;
  final void Function(T row)? onTap;
  final Widget Function(BuildContext context, T row)? rowActions;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(row),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm + 2,
        ),
        child: Row(
          children: [
            for (final column in columns)
              _cellWrapper(
                column: column,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.xs,
                  ),
                  child: Align(
                    alignment: column.numeric
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: column.cell(context, row),
                  ),
                ),
              ),
            if (rowActions != null)
              SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: rowActions!(context, row),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cellWrapper({required AdminColumn<T> column, required Widget child}) {
    if (column.width != null) {
      return SizedBox(width: column.width, child: child);
    }
    return Expanded(flex: column.flex, child: child);
  }
}

// ── States ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xl),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: AppSizes.iconLg,
            color: AppColors.darkGrey,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            title,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSizes.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.xl,
        horizontal: AppSizes.lg,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: AppSizes.iconLg,
            color: AppColors.error,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSizes.spaceBtwItems),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: AppSizes.iconSm),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pagination ────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageSize,
    required this.rowCount,
    required this.totalCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int rowCount;
  final int? totalCount;
  final void Function(int page) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final first = rowCount == 0 ? 0 : page * pageSize + 1;
    final last = page * pageSize + rowCount;

    // Without a total, fall back to "a full page means there is probably
    // more" — never claim a count we cannot substantiate.
    final canGoForward = totalCount == null
        ? rowCount == pageSize
        : last < totalCount!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            totalCount == null
                ? 'Showing $first–$last'
                : 'Showing $first–$last of $totalCount',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '${page + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: canGoForward ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
