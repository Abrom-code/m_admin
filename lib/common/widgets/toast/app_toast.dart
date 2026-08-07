import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m_admin/utils/constants/snackbar_colors.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Public API
// ═════════════════════════════════════════════════════════════════════════════

/// Variant drives the accent color and icon.
enum ToastVariant { success, error, warning, info }

/// Where toasts are anchored on screen.
enum ToastPosition { bottomCenter, bottomLeft, bottomRight, topCenter }

/// Public entry-point. Call from anywhere:
///   AppToast.success('Saved', message: 'Changes saved successfully');
///   AppToast.error('Failed');
class AppToast {
  AppToast._();

  static void success(
    String title, {
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    ToastPosition position = ToastPosition.bottomCenter,
  }) =>
      _show(
        title,
        message: message,
        variant: ToastVariant.success,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        position: position,
      );

  static void error(
    String title, {
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    // Errors linger longer and never auto-dismiss when null is passed
    Duration? duration = const Duration(seconds: 7),
    ToastPosition position = ToastPosition.bottomCenter,
  }) =>
      _show(
        title,
        message: message,
        variant: ToastVariant.error,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        position: position,
      );

  static void warning(
    String title, {
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
    ToastPosition position = ToastPosition.bottomCenter,
  }) =>
      _show(
        title,
        message: message,
        variant: ToastVariant.warning,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        position: position,
      );

  static void info(
    String title, {
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    ToastPosition position = ToastPosition.bottomCenter,
  }) =>
      _show(
        title,
        message: message,
        variant: ToastVariant.info,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        position: position,
      );

  static void _show(
    String title, {
    String? message,
    required ToastVariant variant,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
    ToastPosition position = ToastPosition.bottomCenter,
  }) {
    ToastOverlay.instance.add(
      _ToastItem(
        id: DateTime.now().microsecondsSinceEpoch,
        title: title,
        message: message,
        variant: variant,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        position: position,
      ),
    );
  }

  /// Dismisses all visible toasts immediately.
  static void dismissAll() => ToastOverlay.instance.dismissAll();
}

// ═════════════════════════════════════════════════════════════════════════════
// Overlay host widget — insert once at the app root via builder:
// ═════════════════════════════════════════════════════════════════════════════

/// Wrap around your app's child in `GetMaterialApp(builder:)`.
/// This inserts the overlay layer and wires up the manager.
///
/// Usage in app.dart:
///   builder: (context, child) => ToastHost(child: child ?? const SizedBox()),
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child});
  final Widget child;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  @override
  void initState() {
    super.initState();
    // Register this State so the overlay can call setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ToastOverlay.instance._attach(this);
    });
  }

  @override
  void dispose() {
    ToastOverlay.instance._detach(this);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = ToastOverlay.instance._visibleItems;

    return Stack(
      children: [
        widget.child,
        if (items.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              // Let taps through everywhere except on the toasts themselves.
              ignoring: false,
              child: _ToastStack(items: items),
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Overlay manager (singleton)
// ═════════════════════════════════════════════════════════════════════════════

class ToastOverlay {
  ToastOverlay._();
  static final ToastOverlay instance = ToastOverlay._();

  static const int _maxVisible = 3;

  final List<_ToastItem> _visibleItems = [];
  final List<_ToastItem> _queue = [];
  _ToastHostState? _host;

  void _attach(_ToastHostState host) => _host = host;
  void _detach(_ToastHostState host) {
    if (_host == host) _host = null;
  }

  // ignore: library_private_types_in_public_api
  void add(_ToastItem item) {
    if (_visibleItems.length >= _maxVisible) {
      _queue.add(item);
      return;
    }
    _visibleItems.add(item);
    _host?._rebuild();
  }

  void _dismiss(int id) {
    _visibleItems.removeWhere((i) => i.id == id);
    // Dequeue next if any
    if (_queue.isNotEmpty && _visibleItems.length < _maxVisible) {
      final next = _queue.removeAt(0);
      _visibleItems.add(next);
    }
    _host?._rebuild();
  }

  void dismissAll() {
    for (final item in _visibleItems) {
      item._cancelTimer();
    }
    _visibleItems.clear();
    _queue.clear();
    _host?._rebuild();
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Internal data model
// ═════════════════════════════════════════════════════════════════════════════

class _ToastItem {
  _ToastItem({
    required this.id,
    required this.title,
    this.message,
    required this.variant,
    this.actionLabel,
    this.onAction,
    this.duration,
    required this.position,
  });

  final int id;
  final String title;
  final String? message;
  final ToastVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? duration; // null = persist until manually dismissed
  final ToastPosition position;

  Timer? _autoDismissTimer;

  void startTimer(VoidCallback onDone) {
    if (duration == null) return;
    _autoDismissTimer = Timer(duration!, onDone);
  }

  void pauseTimer() => _autoDismissTimer?.cancel();

  void resumeTimer(VoidCallback onDone) {
    // Simplified resume: restart with remaining ~half — full remaining-time
    // tracking adds complexity; for mobile this is fine.
    if (duration == null) return;
    _autoDismissTimer = Timer(
      Duration(milliseconds: (duration!.inMilliseconds * 0.5).round()),
      onDone,
    );
  }

  void _cancelTimer() => _autoDismissTimer?.cancel();
}

// ═════════════════════════════════════════════════════════════════════════════
// Stack layout widget
// ═════════════════════════════════════════════════════════════════════════════

class _ToastStack extends StatelessWidget {
  const _ToastStack({required this.items});
  final List<_ToastItem> items;

  @override
  Widget build(BuildContext context) {
    // Group by position — each group renders independently.
    final groups = <ToastPosition, List<_ToastItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.position, () => []).add(item);
    }

    return Stack(
      children: [
        for (final entry in groups.entries)
          _ToastGroup(position: entry.key, items: entry.value),
      ],
    );
  }
}

class _ToastGroup extends StatelessWidget {
  const _ToastGroup({required this.position, required this.items});
  final ToastPosition position;
  final List<_ToastItem> items;

  @override
  Widget build(BuildContext context) {
    final safeArea = MediaQuery.of(context).padding;
    const bottomBase = 24.0;
    const sideInset = 16.0;

    AlignmentGeometry alignment;
    EdgeInsets padding;

    switch (position) {
      case ToastPosition.bottomCenter:
        alignment = Alignment.bottomCenter;
        padding = EdgeInsets.only(
          bottom: bottomBase + safeArea.bottom,
          left: sideInset,
          right: sideInset,
        );
      case ToastPosition.bottomLeft:
        alignment = Alignment.bottomLeft;
        padding = EdgeInsets.only(
          bottom: bottomBase + safeArea.bottom,
          left: sideInset,
          right: sideInset,
        );
      case ToastPosition.bottomRight:
        alignment = Alignment.bottomRight;
        padding = EdgeInsets.only(
          bottom: bottomBase + safeArea.bottom,
          left: sideInset,
          right: sideInset,
        );
      case ToastPosition.topCenter:
        alignment = Alignment.topCenter;
        padding = EdgeInsets.only(
          top: bottomBase + safeArea.top,
          left: sideInset,
          right: sideInset,
        );
    }

    final isTop = position == ToastPosition.topCenter;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            verticalDirection:
                isTop ? VerticalDirection.down : VerticalDirection.up,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _ToastWidget(
                  key: ValueKey(items[i].id),
                  item: items[i],
                  slideFromTop: isTop,
                  onDismiss: () =>
                      ToastOverlay.instance._dismiss(items[i].id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Individual toast widget
// ═════════════════════════════════════════════════════════════════════════════

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    super.key,
    required this.item,
    required this.onDismiss,
    required this.slideFromTop,
  });

  final _ToastItem item;
  final VoidCallback onDismiss;
  final bool slideFromTop;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _progressCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _dismissed = false;

  @override
  void initState() {
    super.initState();

    // ── Enter/exit animation ──────────────────────────────────────────
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    final slideBegin =
        widget.slideFromTop ? const Offset(0, -0.25) : const Offset(0, 0.25);
    _slideAnim =
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic)
            .drive(Tween(begin: slideBegin, end: Offset.zero));

    // ── Progress bar animation ────────────────────────────────────────
    final duration = widget.item.duration;
    _progressCtrl = AnimationController(
      vsync: this,
      duration: duration ?? Duration.zero,
      value: 1.0, // starts full
    );

    _enterCtrl.forward().then((_) {
      if (!mounted) return;
      // Start countdown after enter completes
      if (duration != null) {
        _progressCtrl.animateTo(0.0, curve: Curves.linear);
      }
      widget.item.startTimer(_autoDismiss);
    });
  }

  void _autoDismiss() {
    if (!_dismissed && mounted) _dismiss();
  }

  void _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    widget.item._cancelTimer();
    _progressCtrl.stop();
    _enterCtrl.duration = const Duration(milliseconds: 180);
    await _enterCtrl.reverse();
    if (mounted) widget.onDismiss();
  }

  void _onHoverEnter(_) {
    widget.item.pauseTimer();
    _progressCtrl.stop();
  }

  void _onHoverExit(_) {
    if (_dismissed) return;
    final remaining = _progressCtrl.value;
    if (remaining <= 0) return;
    final remainingMs =
        (widget.item.duration!.inMilliseconds * remaining).round();
    _progressCtrl.animateTo(
      0.0,
      duration: Duration(milliseconds: remainingMs),
      curve: Curves.linear,
    );
    widget.item.resumeTimer(_autoDismiss);
  }

  @override
  void dispose() {
    widget.item._cancelTimer();
    _enterCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: MouseRegion(
          onEnter: widget.item.duration != null ? _onHoverEnter : null,
          onExit: widget.item.duration != null ? _onHoverExit : null,
          child: Dismissible(
            key: ValueKey('d_${widget.item.id}'),
            direction: widget.slideFromTop
                ? DismissDirection.up
                : DismissDirection.down,
            onDismissed: (_) => widget.onDismiss(),
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _dismiss();
                }
              },
              child: _ToastCard(
                item: widget.item,
                progressAnim: _progressCtrl,
                onDismiss: _dismiss,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Toast card (visual)
// ═════════════════════════════════════════════════════════════════════════════

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.item,
    required this.progressAnim,
    required this.onDismiss,
  });

  final _ToastItem item;
  final Animation<double> progressAnim;
  final VoidCallback onDismiss;

  static _ToastTheme _themeFor(ToastVariant variant) {
    switch (variant) {
      case ToastVariant.success:
        return const _ToastTheme(
          accent: SnackbarColors.success,
          icon: Icons.check_circle_rounded,
          semanticLabel: 'Success',
        );
      case ToastVariant.error:
        return const _ToastTheme(
          accent: SnackbarColors.error,
          icon: Icons.cancel_rounded,
          semanticLabel: 'Error',
        );
      case ToastVariant.warning:
        return const _ToastTheme(
          accent: SnackbarColors.warning,
          icon: Icons.warning_rounded,
          semanticLabel: 'Warning',
        );
      case ToastVariant.info:
        return const _ToastTheme(
          accent: SnackbarColors.info,
          icon: Icons.info_rounded,
          semanticLabel: 'Information',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _themeFor(item.variant);
    final brightness = Theme.of(context).brightness;
    final isError = item.variant == ToastVariant.error;

    final bg = SnackbarColors.surface(brightness);
    final titleColor = SnackbarColors.text(brightness);
    final subtitleColor = SnackbarColors.subtext(brightness);
    final dismissColor = SnackbarColors.dismiss(brightness);
    final actionColor = SnackbarColors.action(brightness);

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${t.semanticLabel}: ${item.title}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Main row ───────────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left accent bar
                    Container(width: 4, color: t.accent),

                    const SizedBox(width: 14),

                    // Icon
                    Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.icon, color: t.accent, size: 18),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Text block
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.message != null &&
                                item.message!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                item.message!,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            // Optional action button
                            if (item.actionLabel != null) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () {
                                  item.onAction?.call();
                                  onDismiss();
                                },
                                child: Text(
                                  item.actionLabel!,
                                  style: TextStyle(
                                    color: actionColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Dismiss ×
                    Semantics(
                      button: true,
                      label: 'Dismiss',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDismiss,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: dismissColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Progress bar ───────────────────────────────────────
              if (item.duration != null && !isError)
                AnimatedBuilder(
                  animation: progressAnim,
                  builder: (_, _) => LinearProgressIndicator(
                    value: progressAnim.value,
                    minHeight: 2,
                    backgroundColor: t.accent.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(
                      t.accent.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tiny theme record ─────────────────────────────────────────────────────────

class _ToastTheme {
  const _ToastTheme({
    required this.accent,
    required this.icon,
    required this.semanticLabel,
  });
  final Color accent;
  final IconData icon;
  final String semanticLabel;
}
