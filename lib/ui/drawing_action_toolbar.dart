import 'package:flutter/material.dart';
import '../core/models/chart_drawing.dart';
import '../engine/chart_controller.dart';

/// Sleek TradingView-style floating quick-action toolbar that appears when
/// any drawing is selected on the chart. Provides instant access to:
/// - Color swatches
/// - Stroke thickness (1px - 4px)
/// - Lock / Unlock toggle
/// - Delete drawing
/// - Deselect / Dismiss
class DrawingActionToolbar extends StatelessWidget {
  final TradingChartController controller;
  final ChartDrawing selectedDrawing;

  const DrawingActionToolbar({
    super.key,
    required this.controller,
    required this.selectedDrawing,
  });

  static const List<Color> _swatches = [
    Color(0xFF2962FF), // TradingView Blue
    Color(0xFF00E676), // Bullish Green
    Color(0xFFFF3B30), // Bearish Red
    Color(0xFFFF9800), // Amber
    Color(0xFF00BCD4), // Cyan
    Color(0xFFAB47BC), // Purple
    Color(0xFFFFFFFF), // White
  ];

  static const List<double> _strokeWidths = [1.0, 2.0, 3.0, 4.0];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentDrawing = controller.selectedDrawing ?? selectedDrawing;
        return Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xF01E222D),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF363A45), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tool indicator label & icon
                Icon(
                  currentDrawing.tool.icon,
                  size: 16,
                  color: currentDrawing.color,
                ),
                const SizedBox(width: 6),
                Text(
                  currentDrawing.tool.label,
                  style: const TextStyle(
                    color: Color(0xFFD1D4DC),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 18, color: const Color(0xFF363A45)),
                const SizedBox(width: 8),

                // Color Swatches
                for (final color in _swatches) ...[
                  _buildColorSwatch(color, currentDrawing),
                  const SizedBox(width: 4),
                ],

                const SizedBox(width: 4),
                Container(width: 1, height: 18, color: const Color(0xFF363A45)),
                const SizedBox(width: 8),

                // Stroke Width Selector
                for (final width in _strokeWidths) ...[
                  _buildStrokeWidthButton(width, currentDrawing),
                  const SizedBox(width: 4),
                ],

                const SizedBox(width: 4),
                Container(width: 1, height: 18, color: const Color(0xFF363A45)),
                const SizedBox(width: 8),

                // Lock / Unlock Toggle
                Tooltip(
                  message: currentDrawing.isLocked
                      ? 'Unlock Drawing'
                      : 'Lock Drawing',
                  child: _buildIconButton(
                    icon: currentDrawing.isLocked
                        ? Icons.lock
                        : Icons.lock_open_outlined,
                    color: currentDrawing.isLocked
                        ? const Color(0xFFFF9800)
                        : const Color(0xFF868993),
                    onTap: controller.toggleSelectedDrawingLocked,
                  ),
                ),
                const SizedBox(width: 4),

                // Delete Button
                Tooltip(
                  message: 'Delete Drawing (Del)',
                  child: _buildIconButton(
                    key: Key('delete_drawing_${currentDrawing.id}'),
                    icon: Icons.delete_outline,
                    color: const Color(0xFFFF3B30),
                    onTap: controller.deleteSelectedDrawing,
                  ),
                ),
                const SizedBox(width: 4),

                // Deselect / Close Button
                Tooltip(
                  message: 'Deselect',
                  child: _buildIconButton(
                    key: Key('close_drawing_${currentDrawing.id}'),
                    icon: Icons.close,
                    color: const Color(0xFF868993),
                    onTap: () => controller.selectDrawing(null),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorSwatch(Color color, ChartDrawing drawing) {
    final isSelected = drawing.color.toARGB32() == color.toARGB32();
    return InkWell(
      onTap: () => controller.setSelectedDrawingColor(color),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)]
              : null,
        ),
      ),
    );
  }

  Widget _buildStrokeWidthButton(double width, ChartDrawing drawing) {
    final isSelected = drawing.strokeWidth == width;
    return InkWell(
      onTap: () => controller.setSelectedDrawingStrokeWidth(width),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2962FF).withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected
              ? Border.all(color: const Color(0xFF2962FF), width: 1.0)
              : null,
        ),
        child: Container(
          width: 14,
          height: width,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFF868993),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    Key? key,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      hoverColor: color.withValues(alpha: 0.15),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
