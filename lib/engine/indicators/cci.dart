import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Commodity Channel Index (CCI) indicator.
/// Momentum oscillator measuring price deviation from its statistical mean.
/// Horizontal reference levels at +100 (Overbought) and -100 (Oversold).
class CCIIndicator extends Indicator {
  final int period;
  final Color color;
  final double strokeWidth;

  CCIIndicator({
    this.period = 20,
    this.color = const Color(0xFF00B0FF),
    this.strokeWidth = 1.5,
  }) : assert(period > 0, 'Period must be positive');

  @override
  String get id => 'CCI_$period';

  @override
  String get name => 'CCI $period';

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
            id: 'cci',
            label: name,
            color: color,
            strokeWidth: strokeWidth,
            values: values,
          ),
        ],
        horizontalLevels: const [-100.0, 0.0, 100.0],
      );
    }

    // 1. Calculate Typical Price (TP) for all candles
    final tp = List<double>.generate(
      candles.length,
      (i) => (candles[i].high + candles[i].low + candles[i].close) / 3.0,
    );

    // 2. Compute CCI for each window
    for (int i = period - 1; i < candles.length; i++) {
      double sumTp = 0.0;
      for (int j = i - period + 1; j <= i; j++) {
        sumTp += tp[j];
      }
      final smaTp = sumTp / period;

      double sumDev = 0.0;
      for (int j = i - period + 1; j <= i; j++) {
        sumDev += (tp[j] - smaTp).abs();
      }
      final meanDev = sumDev / period;

      if (meanDev == 0.0) {
        values[i] = 0.0;
      } else {
        values[i] = (tp[i] - smaTp) / (0.015 * meanDev);
      }
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: false,
      series: [
        IndicatorSeries(
          id: 'cci',
          label: name,
          color: color,
          strokeWidth: strokeWidth,
          values: values,
        ),
      ],
      horizontalLevels: const [-100.0, 0.0, 100.0],
    );
  }
}
