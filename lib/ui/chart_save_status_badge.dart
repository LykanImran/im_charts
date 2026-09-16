import 'package:flutter/material.dart';
import '../core/models/chart_save_state.dart';
import '../engine/chart_controller.dart';

/// Animated toolbar badge showing real-time chart synchronization and save status.
///
/// States:
/// - **saving**: Displays spinning sync icon with "Saving..." label.
/// - **saved**: Displays glowing green checkmark with "Saved" label.
/// - **unsaved**: Displays cloud upload icon with "Save" label for manual trigger.
class ChartSaveStatusBadge extends StatefulWidget {
  final TradingChartController controller;
  final bool isDark;

  const ChartSaveStatusBadge({
    super.key,
    required this.controller,
    required this.isDark,
  });

  @override
  State<ChartSaveStatusBadge> createState() => _ChartSaveStatusBadgeState();
}

class _ChartSaveStatusBadgeState extends State<ChartSaveStatusBadge>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _popCtrl;
  late final Animation<double> _popAnim;
  ChartSaveState? _prevState;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _popAnim = CurvedAnimation(
      parent: _popCtrl,
      curve: Curves.easeOutBack,
    );

    _prevState = widget.controller.saveState;
    if (_prevState == ChartSaveState.saving) {
      _spinCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ChartSaveStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleStateTransition();
  }

  void _handleStateTransition() {
    final currState = widget.controller.saveState;
    if (currState != _prevState) {
      if (currState == ChartSaveState.saving) {
        _spinCtrl.repeat();
      } else {
        _spinCtrl.stop();
        _spinCtrl.reset();
      }

      if (currState == ChartSaveState.saved &&
          _prevState == ChartSaveState.saving) {
        _popCtrl.forward(from: 0.0);
      }
      _prevState = currState;
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        _handleStateTransition();
        final state = widget.controller.saveState;

        String tooltip;
        Color bg;
        Color border;
        Color textCol;
        Widget iconWidget;
        String label;

        switch (state) {
          case ChartSaveState.saving:
            tooltip = 'Saving chart settings & drawings...';
            bg = const Color(0xFF2962FF).withValues(alpha: 0.15);
            border = const Color(0xFF2962FF).withValues(alpha: 0.4);
            textCol = const Color(0xFF2962FF);
            label = 'Saving...';
            iconWidget = RotationTransition(
              turns: _spinCtrl,
              child: const Icon(
                Icons.sync_rounded,
                size: 13,
                color: Color(0xFF2962FF),
              ),
            );
            break;

          case ChartSaveState.saved:
            tooltip = 'All chart settings, indicators & drawings are saved';
            bg = const Color(0xFF00E676).withValues(alpha: 0.12);
            border = const Color(0xFF00E676).withValues(alpha: 0.35);
            textCol = const Color(0xFF00E676);
            label = 'Saved';
            iconWidget = ScaleTransition(
              scale: _popCtrl.isAnimating
                  ? _popAnim
                  : const AlwaysStoppedAnimation(1.0),
              child: const Icon(
                Icons.cloud_done_rounded,
                size: 13,
                color: Color(0xFF00E676),
              ),
            );
            break;

          case ChartSaveState.unsaved:
            tooltip = 'Unsaved changes. Click to save now';
            bg = const Color(0xFFFFB300).withValues(alpha: 0.12);
            border = const Color(0xFFFFB300).withValues(alpha: 0.35);
            textCol = const Color(0xFFFFB300);
            label = 'Save';
            iconWidget = const Icon(
              Icons.cloud_upload_outlined,
              size: 13,
              color: Color(0xFFFFB300),
            );
            break;
        }

        return Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: () => widget.controller.saveChart(),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  const SizedBox(width: 5),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: textCol,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
