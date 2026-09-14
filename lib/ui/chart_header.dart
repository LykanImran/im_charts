import 'package:flutter/material.dart';
import '../core/models/chart_theme.dart';
import '../engine/chart_controller.dart';

/// Row 2: Symbol & Telemetry Bar showing:
/// Selected symbol name, NSE/BSE exchange toggle, LTP (Last Traded Price), net change, and live OHLCV stats.
class ChartHeader extends StatelessWidget {
  final TradingChartController controller;

  const ChartHeader({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final candle = controller.hoveredCandle;
        final latest = controller.currentCandle;
        final theme = controller.theme;
        final isDark = controller.isDarkTheme;

        final isBullish = (candle?.isBullish ?? true);
        final changeColor = isBullish ? theme.bullishColor : theme.bearishColor;

        // Determine symbol category badge
        String categoryTag = 'EQ';
        if (controller.symbol.contains('NIFTY') ||
            controller.symbol.contains('SENSEX') ||
            controller.symbol.contains('BANK')) {
          categoryTag = 'INDEX';
        } else if (controller.symbol.contains('BTC') || controller.symbol.contains('ETH')) {
          categoryTag = 'CRYPTO';
        }

        return Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            border: Border(bottom: BorderSide(color: theme.gridColor, width: 1.0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. Live Pulse Dot & Symbol Name
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6600E676),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      controller.symbol,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        categoryTag,
                        style: TextStyle(
                          color: theme.axisTextColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // 2. NSE / BSE Exchange Toggle
                _buildExchangeSelector(controller, theme, isDark),

                _buildDivider(theme),

                // 3. LTP (Last Traded Price) & Dynamic Change
                if (latest != null) ...[
                  Text(
                    latest.close.toStringAsFixed(2),
                    style: TextStyle(
                      color: changeColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${latest.priceChange >= 0 ? '+' : ''}${latest.priceChange.toStringAsFixed(2)} (${latest.percentageChange.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],

                _buildDivider(theme),

                // 4. Live / Hovered OHLCV Data Strip
                if (candle != null) ...[
                  _buildMetricBadge('O', candle.open.toStringAsFixed(2), theme, isDark),
                  _buildMetricBadge('H', candle.high.toStringAsFixed(2), theme, isDark),
                  _buildMetricBadge('L', candle.low.toStringAsFixed(2), theme, isDark),
                  _buildMetricBadge('C', candle.close.toStringAsFixed(2), theme, isDark, valueColor: changeColor),
                  _buildMetricBadge('Vol', _formatVolume(candle.volume), theme, isDark),
                ],

                _buildDivider(theme),

                // 5. Quick Viewport Navigation
                IconButton(
                  icon: Icon(Icons.zoom_out, size: 16, color: theme.axisTextColor),
                  tooltip: 'Zoom Out',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: controller.zoomOut,
                ),
                IconButton(
                  icon: Icon(Icons.zoom_in, size: 16, color: theme.axisTextColor),
                  tooltip: 'Zoom In',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: controller.zoomIn,
                ),
                IconButton(
                  icon: Icon(Icons.center_focus_strong, size: 16, color: theme.axisTextColor),
                  tooltip: 'Reset Viewport',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: controller.resetView,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page, size: 16, color: Color(0xFF00E676)),
                  tooltip: 'Scroll to Latest Candle',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: controller.scrollToLatest,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider(ChartTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Container(
        height: 18,
        width: 1,
        color: theme.gridColor,
      ),
    );
  }

  Widget _buildExchangeSelector(TradingChartController controller, ChartTheme theme, bool isDark) {
    final exchanges = ['NSE', 'BSE'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF0F3FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.gridColor, width: 1),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: exchanges.map((ex) {
          final isSelected = controller.exchange == ex;
          return InkWell(
            onTap: () => controller.setExchange(ex),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2962FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ex,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricBadge(
    String label,
    String value,
    ChartTheme theme,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: theme.axisTextColor,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor ?? (isDark ? Colors.white.withValues(alpha: 0.95) : Colors.black87),
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 10000000) {
      return '${(volume / 10000000).toStringAsFixed(2)}Cr';
    } else if (volume >= 100000) {
      return '${(volume / 100000).toStringAsFixed(2)}L';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }
    return volume.toStringAsFixed(0);
  }
}
