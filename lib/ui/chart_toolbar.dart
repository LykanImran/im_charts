import 'package:flutter/material.dart';
import '../core/models/timeframe.dart';
import '../engine/chart_controller.dart';
import '../engine/indicators/bollinger_bands.dart';
import '../engine/indicators/ema.dart';
import '../engine/indicators/rsi.dart';

/// Top control toolbar for switching timeframes, toggling indicators, and navigating viewport.
class ChartToolbar extends StatelessWidget {
  final TradingChartController controller;

  const ChartToolbar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = controller.theme;

        return Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            border: Border(bottom: BorderSide(color: theme.gridColor, width: 1.0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Timeframe Selectors
                ...Timeframe.values.take(6).map((tf) {
                  final isSelected = controller.timeframe == tf;
                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: InkWell(
                      onTap: () => controller.setTimeframe(tf),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF2962FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tf.shortLabel,
                          style: TextStyle(
                            color: isSelected ? Colors.white : theme.axisTextColor,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(width: 8),
                Container(height: 18, width: 1, color: theme.gridColor),
                const SizedBox(width: 8),

                // Indicators Selector
                _buildIndicatorChip(
                  label: 'EMA 20',
                  color: const Color(0xFF2962FF),
                  isActive: controller.isIndicatorActive('EMA_20'),
                  onTap: () => controller.toggleIndicator(EMAIndicator(period: 20, color: const Color(0xFF2962FF))),
                  theme: theme,
                ),
                _buildIndicatorChip(
                  label: 'EMA 50',
                  color: const Color(0xFFE91E63),
                  isActive: controller.isIndicatorActive('EMA_50'),
                  onTap: () => controller.toggleIndicator(EMAIndicator(period: 50, color: const Color(0xFFE91E63))),
                  theme: theme,
                ),
                _buildIndicatorChip(
                  label: 'BB 20',
                  color: const Color(0xFFFF9800),
                  isActive: controller.isIndicatorActive('BB_20_2.0'),
                  onTap: () => controller.toggleIndicator(BollingerBandsIndicator()),
                  theme: theme,
                ),
                _buildIndicatorChip(
                  label: 'RSI 14',
                  color: const Color(0xFF7E57C2),
                  isActive: controller.isIndicatorActive('RSI_14'),
                  onTap: () => controller.toggleIndicator(RSIIndicator()),
                  theme: theme,
                ),

                const SizedBox(width: 8),
                Container(height: 18, width: 1, color: theme.gridColor),
                const SizedBox(width: 8),

                // Volume Toggle
                IconButton(
                  icon: Icon(
                    controller.showVolume ? Icons.bar_chart : Icons.bar_chart_outlined,
                    size: 18,
                    color: controller.showVolume ? const Color(0xFF2962FF) : theme.axisTextColor,
                  ),
                  tooltip: 'Toggle Volume',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: controller.toggleVolume,
                ),

                // Zoom Out
                IconButton(
                  icon: Icon(Icons.zoom_out, size: 18, color: theme.axisTextColor),
                  tooltip: 'Zoom Out',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: controller.zoomOut,
                ),

                // Zoom In
                IconButton(
                  icon: Icon(Icons.zoom_in, size: 18, color: theme.axisTextColor),
                  tooltip: 'Zoom In',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: controller.zoomIn,
                ),

                // Reset View
                IconButton(
                  icon: Icon(Icons.refresh, size: 18, color: theme.axisTextColor),
                  tooltip: 'Reset View',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: controller.resetView,
                ),

                // Jump to Latest
                IconButton(
                  icon: const Icon(Icons.last_page, size: 18, color: Color(0xFF00E676)),
                  tooltip: 'Scroll to Latest',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: controller.scrollToLatest,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndicatorChip({
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    required dynamic theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(
              color: isActive ? color : theme.gridColor,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : theme.axisTextColor,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
