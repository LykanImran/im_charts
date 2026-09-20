import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/chart_drawing.dart';
import '../engine/chart_controller.dart';

/// Professional vertical drawing toolbar docked on the left side of the chart.
/// Provides 1-click access to Trendline, Horizontal Line, Fibonacci Retracements,
/// Long/Short Risk:Reward Position Boxes, and Measurement Ruler.
class ChartDrawingToolbar extends StatefulWidget {
  final TradingChartController controller;
  final bool isCollapsible;
  final bool? initialCollapsed;

  const ChartDrawingToolbar({
    super.key,
    required this.controller,
    this.isCollapsible = true,
    this.initialCollapsed,
  });

  @override
  State<ChartDrawingToolbar> createState() => _ChartDrawingToolbarState();
}

class _ChartDrawingToolbarState extends State<ChartDrawingToolbar> {
  bool? _isCollapsed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isCollapsed == null) {
      if (widget.initialCollapsed != null) {
        _isCollapsed = widget.initialCollapsed!;
      } else {
        final screenWidth = MediaQuery.maybeOf(context)?.size.width ?? 1000.0;
        _isCollapsed = screenWidth < 600.0;
      }
    }
  }

  final List<DrawingTool> _tools = const [
    DrawingTool.pointer,
    DrawingTool.trendline,
    DrawingTool.horizontalLine,
    DrawingTool.horizontalRay,
    DrawingTool.verticalLine,
    DrawingTool.rectangle,
    DrawingTool.fibonacci,
    DrawingTool.longPosition,
    DrawingTool.shortPosition,
    DrawingTool.ruler,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final activeTool = widget.controller.activeDrawingTool;
        final hasDrawings = widget.controller.drawings.isNotEmpty;
        final isDark = widget.controller.isDarkTheme;

        final bgColor = isDark ? const Color(0xFF131722) : Colors.white;
        final borderColor =
            isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB);
        final inactiveIconColor =
            isDark ? const Color(0xFF868993) : const Color(0xFF787B86);
        final activeActionColor =
            isDark ? const Color(0xFFD1D4DC) : const Color(0xFF2A2E39);
        final disabledActionColor =
            isDark ? const Color(0xFF4A4E59) : const Color(0xFFB2B5BE);

        if (_isCollapsed ?? false) {
          return SizedBox(
            width: 24,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Thin blue vertical line showing collapsed toolbar
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 1.5,
                    color: const Color(0xFF2962FF),
                  ),
                ),

                // Thumb Button: circular widget on the blue line
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: Center(
                    child: Tooltip(
                      message: 'Open Drawing Toolbar',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('expand_drawing_toolbar_button'),
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isCollapsed = false);
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF2962FF),
                                  Color(0xFF1546D2),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2962FF)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 4.0,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.chevron_right,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: 44,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              right: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Drawing Tool Buttons
                      for (final tool in _tools) ...[
                        _buildToolButton(
                          tool: tool,
                          isActive: activeTool == tool,
                          isDark: isDark,
                          onTap: () {
                            if (activeTool == tool) {
                              widget.controller.activeDrawingTool =
                                  DrawingTool.pointer;
                            } else {
                              widget.controller.activeDrawingTool = tool;
                            }
                          },
                        ),
                        const SizedBox(height: 4),
                      ],

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Divider(color: borderColor, height: 1),
                      ),

                      // Magnet Mode Toggle
                      Tooltip(
                        message: widget.controller.magnetMode
                            ? 'Magnet Mode: ON (Snap to OHLC)'
                            : 'Magnet Mode: OFF (Snap to OHLC)',
                        waitDuration: const Duration(milliseconds: 400),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            key: const Key('magnet_mode_button'),
                            onTap: widget.controller.toggleMagnetMode,
                            borderRadius: BorderRadius.circular(6),
                            hoverColor: const Color(
                              0xFF2962FF,
                            ).withValues(alpha: 0.15),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: widget.controller.magnetMode
                                    ? const Color(
                                        0xFFFFB300,
                                      ).withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: widget.controller.magnetMode
                                    ? Border.all(
                                        color: const Color(0xFFFFB300),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.gps_fixed,
                                size: 18,
                                color: widget.controller.magnetMode
                                    ? const Color(0xFFFFB300)
                                    : inactiveIconColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Undo Button
                      Tooltip(
                        message: 'Undo (Ctrl+Z)',
                        waitDuration: const Duration(milliseconds: 400),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            key: const Key('undo_drawing_button'),
                            onTap: widget.controller.canUndo
                                ? widget.controller.undo
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            hoverColor: const Color(
                              0xFF2962FF,
                            ).withValues(alpha: 0.15),
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.undo,
                                size: 18,
                                color: widget.controller.canUndo
                                    ? activeActionColor
                                    : disabledActionColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Redo Button
                      Tooltip(
                        message: 'Redo (Ctrl+Y)',
                        waitDuration: const Duration(milliseconds: 400),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          child: InkWell(
                            key: const Key('redo_drawing_button'),
                            onTap: widget.controller.canRedo
                                ? widget.controller.redo
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            hoverColor: const Color(
                              0xFF2962FF,
                            ).withValues(alpha: 0.15),
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.redo,
                                size: 18,
                                color: widget.controller.canRedo
                                    ? activeActionColor
                                    : disabledActionColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Clear All Drawings Button
                      if (hasDrawings)
                        Tooltip(
                          message:
                              'Clear Drawings (${widget.controller.drawings.length})',
                          waitDuration: const Duration(milliseconds: 400),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              key: const Key('clear_drawings_button'),
                              onTap: widget.controller.clearDrawings,
                              borderRadius: BorderRadius.circular(6),
                              hoverColor: const Color(
                                0xFFFF3B30,
                              ).withValues(alpha: 0.15),
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Color(0xFFFF3B30),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),

              // Collapse Button with comfortable thumb hit target
              if (widget.isCollapsible)
                Tooltip(
                  message: 'Hide Drawing Toolbar',
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isCollapsed = true);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.chevron_left,
                        size: 16,
                        color: inactiveIconColor,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolButton({
    required DrawingTool tool,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final hoverColor =
        isActive ? const Color(0xFF2962FF) : (isDark ? const Color(0xFF2A2E39) : const Color(0xFFF0F3FA));
    final defaultIconColor =
        isDark ? const Color(0xFFB2B5BE) : const Color(0xFF50535E);

    return Tooltip(
      message: tool.label,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: isActive ? const Color(0xFF2962FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: Key('drawing_tool_${tool.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: hoverColor,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: isActive
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2962FF).withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  )
                : null,
            child: Icon(
              tool.icon,
              size: 18,
              color: isActive ? Colors.white : defaultIconColor,
            ),
          ),
        ),
      ),
    );
  }
}


