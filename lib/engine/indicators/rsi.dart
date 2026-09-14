import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Relative Strength Index (RSI) Indicator with Wilder's smoothing.
class RSIIndicator extends Indicator {
  final int period;
  final Color color;
  final double strokeWidth;

  RSIIndicator({
    this.period = 14,
    this.color = const Color(0xFF7E57C2),
    this.strokeWidth = 1.5,
  }) : assert(period > 0, 'Period must be positive');

  @override
  String get id => 'RSI_$period';

  @override
  String get name => 'RSI $period';

  @override
  bool get isOverlay => false; // Renders in separate sub-pane

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final values = List<double?>.filled(candles.length, null);

    if (candles.length <= period) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: false,
        series: [
          IndicatorSeries(
            id: 'rsi',
            label: name,
            color: color,
            strokeWidth: strokeWidth,
            values: values,
          ),
        ],
        fixedMin: 0.0,
        fixedMax: 100.0,
        horizontalLevels: const [30.0, 50.0, 70.0],
      );
    }

    double gainSum = 0.0;
    double lossSum = 0.0;

    // First period calculations
    for (int i = 1; i <= period; i++) {
      final change = candles[i].close - candles[i - 1].close;
      if (change >= 0) {
        gainSum += change;
      } else {
        lossSum += change.abs();
      }
    }

    double avgGain = gainSum / period;
    double avgLoss = lossSum / period;

    values[period] = _calculateRsi(avgGain, avgLoss);

    // Smoothed subsequent periods (Wilder's smoothing)
    for (int i = period + 1; i < candles.length; i++) {
      final change = candles[i].close - candles[i - 1].close;
      final gain = change >= 0 ? change : 0.0;
      final loss = change < 0 ? change.abs() : 0.0;

      avgGain = ((avgGain * (period - 1)) + gain) / period;
      avgLoss = ((avgLoss * (period - 1)) + loss) / period;

      values[i] = _calculateRsi(avgGain, avgLoss);
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: false,
      series: [
        IndicatorSeries(
          id: 'rsi',
          label: name,
          color: color,
          strokeWidth: strokeWidth,
          values: values,
        ),
      ],
      fixedMin: 0.0,
      fixedMax: 100.0,
      horizontalLevels: const [30.0, 50.0, 70.0],
    );
  }

  double _calculateRsi(double avgGain, double avgLoss) {
    if (avgLoss == 0) return 100.0;
    if (avgGain == 0) return 0.0;
    final rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }
}
