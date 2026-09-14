import 'package:flutter/material.dart';
import '../core/models/chart_theme.dart';
import '../engine/chart_controller.dart';

/// Top terminal header showing ticker symbol, live LTP, percentage change, and OHLCV tooltip.
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

        final isBullish = (candle?.isBullish ?? true);
        final changeColor = isBullish ? theme.bullishColor : theme.bearishColor;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            border: Border(bottom: BorderSide(color: theme.gridColor, width: 1.0)),
          ),
          child: Row(
            children: [
              // Symbol badge & Live Pulse
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.gridColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      controller.symbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Last Traded Price (LTP)
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
                const SizedBox(width: 8),
                Text(
                  '${latest.priceChange >= 0 ? '+' : ''}${latest.priceChange.toStringAsFixed(2)} (${latest.percentageChange.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],

              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: candle != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMetricBadge('O', candle.open.toStringAsFixed(2), theme),
                              _buildMetricBadge('H', candle.high.toStringAsFixed(2), theme),
                              _buildMetricBadge('L', candle.low.toStringAsFixed(2), theme),
                              _buildMetricBadge('C', candle.close.toStringAsFixed(2), theme, valueColor: changeColor),
                              _buildMetricBadge('Vol', candle.volume.toStringAsFixed(0), theme),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBadge(String label, String value, ChartTheme theme, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: theme.axisTextColor,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: valueColor ?? Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
