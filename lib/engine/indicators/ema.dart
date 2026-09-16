import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Exponential Moving Average (EMA) Indicator.
class EMAIndicator extends Indicator {
  final int period;
  final Color color;
  final double strokeWidth;

  EMAIndicator({
    this.period = 20,
    this.color = const Color(0xFF2962FF),
    this.strokeWidth = 1.5,
  }) : assert(period > 0, 'Period must be positive');

  @override
  String get id => 'EMA_$period';

  @override
  String get name => 'EMA $period';

  @override
  bool get isOverlay => true;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final values = List<double?>.filled(candles.length, null);

    if (candles.length < period) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: true,
        series: [
          IndicatorSeries(
            id: 'ema',
            label: name,
            color: color,
            strokeWidth: strokeWidth,
            values: values,
          ),
        ],
      );
    }

    // Step 1: Initial Simple Moving Average
    double sum = 0.0;
    for (int i = 0; i < period; i++) {
      sum += candles[i].close;
    }
    double currentEma = sum / period;
    values[period - 1] = currentEma;

    // Step 2: Exponential smoothing
    final multiplier = 2.0 / (period + 1);
    for (int i = period; i < candles.length; i++) {
      currentEma =
          (candles[i].close * multiplier) + (currentEma * (1.0 - multiplier));
      values[i] = currentEma;
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: [
        IndicatorSeries(
          id: 'ema',
          label: name,
          color: color,
          strokeWidth: strokeWidth,
          values: values,
        ),
      ],
    );
  }
}
