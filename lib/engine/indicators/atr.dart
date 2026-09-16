import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Average True Range (ATR) indicator with Wilder's smoothing.
/// Measures market volatility as a sub-pane line oscillator.
class ATRIndicator extends Indicator {
  final int period;
  final Color color;
  final double strokeWidth;

  ATRIndicator({
    this.period = 14,
    this.color = const Color(0xFF00E5FF),
    this.strokeWidth = 1.5,
  }) : assert(period > 0, 'Period must be positive');

  @override
  String get id => 'ATR_$period';

  @override
  String get name => 'ATR $period';

  @override
  bool get isOverlay => false;

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
            id: 'atr',
            label: name,
            color: color,
            strokeWidth: strokeWidth,
            values: values,
          ),
        ],
      );
    }

    // 1. Calculate True Range (TR) for each candle
    final tr = List<double>.filled(candles.length, 0.0);
    tr[0] = candles[0].high - candles[0].low;

    for (int i = 1; i < candles.length; i++) {
      final high = candles[i].high;
      final low = candles[i].low;
      final prevClose = candles[i - 1].close;

      final hl = high - low;
      final hc = (high - prevClose).abs();
      final lc = (low - prevClose).abs();

      tr[i] = math.max(hl, math.max(hc, lc));
    }

    // 2. Initial ATR is simple average of first `period` true ranges
    double currentAtr = 0.0;
    for (int i = 0; i < period; i++) {
      currentAtr += tr[i];
    }
    currentAtr /= period;
    values[period - 1] = currentAtr;

    // 3. Wilder's exponential smoothing for subsequent bars
    for (int i = period; i < candles.length; i++) {
      currentAtr = (currentAtr * (period - 1) + tr[i]) / period;
      values[i] = currentAtr;
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: false,
      series: [
        IndicatorSeries(
          id: 'atr',
          label: name,
          color: color,
          strokeWidth: strokeWidth,
          values: values,
        ),
      ],
    );
  }
}
