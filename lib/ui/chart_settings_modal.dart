import 'package:flutter/material.dart';
import '../core/models/candle_style.dart';
import '../engine/chart_controller.dart';

class ChartSettingsModal extends StatelessWidget {
  final TradingChartController controller;

  const ChartSettingsModal({super.key, required this.controller});

  static Future<void> show(BuildContext context, TradingChartController controller) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => ChartSettingsModal(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = controller.theme;
    final isDark = controller.isDarkTheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.gridColor, width: 1),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings, size: 20, color: Color(0xFF2962FF)),
                        const SizedBox(width: 8),
                        Text(
                          'Chart Settings',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: theme.axisTextColor, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: theme.gridColor),
                const SizedBox(height: 16),

                // Section: Chart Display Elements
                Text(
                  'DISPLAY & SCALES',
                  style: TextStyle(
                    color: theme.axisTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),

                // Show Grid Lines Switch
                _buildSettingRow(
                  icon: Icons.grid_4x4,
                  title: 'Grid Lines',
                  subtitle: 'Display horizontal price and vertical time grid',
                  value: controller.showGrid,
                  onChanged: (_) => controller.toggleGrid(),
                  isDark: isDark,
                  textColor: theme.axisTextColor,
                ),

                // Show Volume Switch
                _buildSettingRow(
                  icon: Icons.bar_chart,
                  title: 'Volume Histogram',
                  subtitle: 'Show trading volume bars in chart base',
                  value: controller.showVolume,
                  onChanged: (_) => controller.toggleVolume(),
                  isDark: isDark,
                  textColor: theme.axisTextColor,
                ),

                // Show Crosshair Switch
                _buildSettingRow(
                  icon: Icons.adjust,
                  title: 'Crosshair Tracking',
                  subtitle: 'Show pointer coordinates and value hover pills',
                  value: controller.showCrosshair,
                  onChanged: (_) => controller.toggleCrosshair(),
                  isDark: isDark,
                  textColor: theme.axisTextColor,
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: theme.gridColor),
                const SizedBox(height: 16),

                // Section: Presentation Style
                Text(
                  'CHART PRESENTATION STYLE',
                  style: TextStyle(
                    color: theme.axisTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                // Wrap of candle style chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CandleStyle.values.map((style) {
                    final isSelected = controller.candleStyle == style;
                    return InkWell(
                      onTap: () => controller.setCandleStyle(style),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2962FF)
                              : (isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              style.icon,
                              size: 16,
                              color: isSelected ? Colors.white : theme.axisTextColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              style.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                Divider(height: 1, color: theme.gridColor),
                const SizedBox(height: 16),

                // Bottom actions: Reset view, Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        controller.resetView();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset Viewport'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2962FF),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2962FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2962FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF2962FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
