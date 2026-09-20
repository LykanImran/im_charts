import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Weighted Moving Average (WMA) — assigns linearly increasing weights to recent closes.
class WMAIndicator extends Indicator {
  final int period;
  final Color color;
  final double strokeWidth;

  WMAIndicator({
    this.period = 20,
    this.color = const Color(0xFF7E57C2),
    this.strokeWidth = 1.5,
  }) : assert(period > 0);

  @override
  String get id => 'WMA_$period';

  @override
  String get name => 'WMA $period';

  @override
  bool get isOverlay => true;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final values = List<double?>.filled(candles.length, null);
    if (candles.length < period) {
      return IndicatorResult(
        indicatorId: id, name: name, isOverlay: true,
        series: [IndicatorSeries(id: 'wma', label: name, color: color, strokeWidth: strokeWidth, values: values)],
      );
    }

    // Precompute denominator: 1+2+...+period = period*(period+1)/2
    final denom = period * (period + 1) / 2;

    for (int i = period - 1; i < candles.length; i++) {
      double weighted = 0.0;
      for (int j = 0; j < period; j++) {
        weighted += candles[i - (period - 1) + j].close * (j + 1);
      }
      values[i] = weighted / denom;
    }

    return IndicatorResult(
      indicatorId: id, name: name, isOverlay: true,
      series: [IndicatorSeries(id: 'wma', label: name, color: color, strokeWidth: strokeWidth, values: values)],
    );
  }
}
