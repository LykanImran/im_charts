import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';
import 'wma.dart';

/// Hull Moving Average — WMA(2*WMA(n/2) − WMA(n), sqrt(n)).
/// Extremely low lag while remaining smooth — ideal for trend-following.
class HMAIndicator extends Indicator {
  final int period;
  final Color color;
  final double strokeWidth;

  HMAIndicator({
    this.period = 20,
    this.color = const Color(0xFF26C6DA),
    this.strokeWidth = 1.8,
  }) : assert(period >= 4);

  @override
  String get id => 'HMA_$period';

  @override
  String get name => 'HMA $period';

  @override
  bool get isOverlay => true;

  /// Computes a WMA series inline for the given period.
  List<double?> _wma(List<Candle> candles, int p) {
    return WMAIndicator(period: p).calculate(candles).series.first.values;
  }

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final values = List<double?>.filled(candles.length, null);

    if (candles.length < period) {
      return IndicatorResult(
        indicatorId: id, name: name, isOverlay: true,
        series: [IndicatorSeries(id: 'hma', label: name, color: color, strokeWidth: strokeWidth, values: values)],
      );
    }

    final halfPeriod = (period / 2).round();
    final sqrtPeriod = math.sqrt(period).round().clamp(2, period);

    final wmaFull = _wma(candles, period);
    final wmaHalf = _wma(candles, halfPeriod);

    // Build intermediate series: 2*WMA(n/2) - WMA(n)
    final intermediate = List<Candle>.from(candles);
    for (int i = 0; i < candles.length; i++) {
      final half = wmaHalf[i];
      final full = wmaFull[i];
      if (half != null && full != null) {
        intermediate[i] = candles[i].copyWith(close: 2.0 * half - full);
      }
    }

    final hmaRaw = _wma(intermediate, sqrtPeriod);
    for (int i = 0; i < candles.length; i++) {
      values[i] = hmaRaw[i];
    }

    return IndicatorResult(
      indicatorId: id, name: name, isOverlay: true,
      series: [IndicatorSeries(id: 'hma', label: name, color: color, strokeWidth: strokeWidth, values: values)],
    );
  }
}
