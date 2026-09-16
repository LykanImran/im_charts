import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Williams %R Momentum Oscillator indicator.
/// Ranges from -100 to 0 with overbought level at -20 and oversold level at -80.
class WilliamsRIndicator extends Indicator {
  final int period;
  final Color color;
  final double strokeWidth;

  WilliamsRIndicator({
    this.period = 14,
    this.color = const Color(0xFFAB47BC),
    this.strokeWidth = 1.5,
  }) : assert(period > 0, 'Period must be positive');

  @override
  String get id => 'WILLR_$period';

  @override
  String get name => '%R $period';

  @override
  bool get isOverlay => false;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final values = List<double?>.filled(candles.length, null);

    if (candles.length < period) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: false,
        series: [
          IndicatorSeries(
            id: 'williams_r',
            label: name,
            color: color,
            strokeWidth: strokeWidth,
            values: values,
          ),
        ],
        fixedMin: -100.0,
        fixedMax: 0.0,
        horizontalLevels: const [-20.0, -50.0, -80.0],
      );
    }

    for (int i = period - 1; i < candles.length; i++) {
      double highestHigh = -double.infinity;
      double lowestLow = double.infinity;

      for (int j = i - period + 1; j <= i; j++) {
        if (candles[j].high > highestHigh) highestHigh = candles[j].high;
        if (candles[j].low < lowestLow) lowestLow = candles[j].low;
      }

      final range = highestHigh - lowestLow;
      if (range > 0) {
        final r = ((highestHigh - candles[i].close) / range) * -100.0;
        values[i] = r.clamp(-100.0, 0.0);
      } else {
        values[i] = -50.0;
      }
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: false,
      series: [
        IndicatorSeries(
          id: 'williams_r',
          label: name,
          color: color,
          strokeWidth: strokeWidth,
          values: values,
        ),
      ],
      fixedMin: -100.0,
      fixedMax: 0.0,
      horizontalLevels: const [-20.0, -50.0, -80.0],
    );
  }
}
