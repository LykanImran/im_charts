import 'package:flutter/material.dart';
import '../core/models/chart_drawing.dart';
import '../engine/chart_controller.dart';

/// Professional vertical drawing toolbar docked on the left side of the chart.
/// Provides 1-click access to Trendline, Horizontal Line, Fibonacci Retracements,
/// Long/Short Risk:Reward Position Boxes, and Measurement Ruler.
class ChartDrawingToolbar extends StatefulWidget {
  final TradingChartController controller;
  final bool isCollapsible;

  const ChartDrawingToolbar({
    super.key,
    required this.controller,
    this.isCollapsible = true,
  });

  @override
  State<ChartDrawingToolbar> createState() => _ChartDrawingToolbarState();
}

class _ChartDrawingToolbarState extends State<ChartDrawingToolbar> {
  bool _isCollapsed = false;

  final List<DrawingTool> _tools = const [
    DrawingTool.pointer,
    DrawingTool.trendline,
    DrawingTool.horizontalLine,
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

        if (_isCollapsed) {
          return Container(
            width: 18,
            decoration: const BoxDecoration(
              color: Color(0xFF131722),
              border: Border(right: BorderSide(color: Color(0xFF2A2E39), width: 1)),
            ),
            child: InkWell(
              onTap: () => setState(() => _isCollapsed = false),
              child: const Center(
                child: Icon(Icons.chevron_right, size: 14, color: Color(0xFF868993)),
              ),
            ),
          );
        }

        return Container(
          width: 44,
          decoration: const BoxDecoration(
            color: Color(0xFF131722),
            border: Border(right: BorderSide(color: Color(0xFF2A2E39), width: 1)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Drawing Tool Buttons
              for (final tool in _tools) ...[
                _buildToolButton(
                  tool: tool,
                  isActive: activeTool == tool,
                  onTap: () {
                    if (activeTool == tool) {
                      widget.controller.activeDrawingTool = DrawingTool.pointer;
                    } else {
                      widget.controller.activeDrawingTool = tool;
                    }
                  },
                ),
                const SizedBox(height: 4),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Divider(color: Color(0xFF2A2E39), height: 1),
              ),

              // Clear All Drawings Button
              if (hasDrawings)
                Tooltip(
                  message: 'Clear Drawings (${widget.controller.drawings.length})',
                  waitDuration: const Duration(milliseconds: 400),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      key: const Key('clear_drawings_button'),
                      onTap: widget.controller.clearDrawings,
                      borderRadius: BorderRadius.circular(6),
                      hoverColor: const Color(0xFFFF3B30).withValues(alpha: 0.15),
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

              const Spacer(),

              // Collapse Button
              if (widget.isCollapsible)
                Tooltip(
                  message: 'Hide Drawing Toolbar',
                  child: InkWell(
                    onTap: () => setState(() => _isCollapsed = true),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      child: const Icon(Icons.chevron_left, size: 16, color: Color(0xFF868993)),
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
    required VoidCallback onTap,
  }) {
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
          hoverColor: isActive ? const Color(0xFF2962FF) : const Color(0xFF2A2E39),
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
              color: isActive ? Colors.white : const Color(0xFFB2B5BE),
            ),
          ),
        ),
      ),
    );
  }
}
