import 'dart:async';
import 'package:flutter/material.dart';

/// Trading terminal toast notification system.
///
/// Automatically adapts placement and layout to the active platform:
/// - **Desktop / Web (width >= 600)**: Positioned at **top-right** with a **fixed width** (350px),
///   preventing unwanted full-screen stretching.
/// - **Mobile (width < 600)**: Positioned at **center-top** with **full width** across the device screen.
class ChartToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Displays a responsive toast notification.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    Color color = const Color(0xFF2962FF),
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // Dismiss any existing toast before displaying the new one
    dismiss();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastAnimationWrapper(
        message: message,
        title: title,
        color: color,
        icon: icon,
        isMobile: isMobile,
        topPadding: isMobile ? mediaQuery.padding.top + 10 : 18.0,
        onDismiss: () => dismiss(),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  /// Immediately dismisses the currently active toast notification if any.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null) {
      _currentEntry?.remove();
      _currentEntry = null;
    }
  }

  // Convenience helper methods
  static void success(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      color: const Color(0xFF00E676),
      icon: Icons.check_circle_outline,
    );
  }

  static void info(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      color: const Color(0xFF2962FF),
      icon: Icons.info_outline,
    );
  }

  static void alert(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      color: const Color(0xFFFFB74D),
      icon: Icons.notifications_active_outlined,
    );
  }

  static void error(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      color: const Color(0xFFFF3B30),
      icon: Icons.error_outline,
    );
  }
}

class _ToastAnimationWrapper extends StatefulWidget {
  final String message;
  final String? title;
  final Color color;
  final IconData? icon;
  final bool isMobile;
  final double topPadding;
  final VoidCallback onDismiss;

  const _ToastAnimationWrapper({
    required this.message,
    this.title,
    required this.color,
    this.icon,
    required this.isMobile,
    required this.topPadding,
    required this.onDismiss,
  });

  @override
  State<_ToastAnimationWrapper> createState() => _ToastAnimationWrapperState();
}

class _ToastAnimationWrapperState extends State<_ToastAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClose() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB);
    final textColor = isDark ? Colors.white : const Color(0xFF131722);
    final subColor = isDark ? const Color(0xFF868993) : const Color(0xFF6A6D78);

    final toastCard = Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Color status badge / icon
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    widget.icon ?? Icons.info_outline,
                    size: 16,
                    color: widget.color,
                  ),
                ),
                const SizedBox(width: 12),

                // Message & optional Title
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.title != null) ...[
                        Text(
                          widget.title!,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.title != null ? subColor : textColor,
                          fontSize: 12,
                          fontWeight: widget.title != null
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Quick dismiss button
                InkWell(
                  onTap: _handleClose,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: subColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isMobile) {
      // Mobile: Centered at top, full width with standard edge margins
      return Positioned(
        top: widget.topPadding,
        left: 14,
        right: 14,
        child: toastCard,
      );
    } else {
      // Web / Desktop: Top-right corner with fixed width (350px)
      return Positioned(
        top: widget.topPadding,
        right: 18,
        width: 350,
        child: toastCard,
      );
    }
  }
}
