import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Simple Moving Average (SMA) Indicator.
class SMAIndicator extends Indicator {
  final int period;
  final Color color;
  final double strokeWidth;

  SMAIndicator({
    this.period = 20,
    this.color = const Color(0xFFFFB300),
    this.strokeWidth = 1.5,
  }) : assert(period > 0, 'Period must be positive');

  @override
  String get id => 'SMA_$period';

  @override
  String get name => 'SMA $period';

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
            id: 'sma',
            label: name,
            color: color,
            strokeWidth: strokeWidth,
            values: values,
          ),
        ],
      );
    }

    double runningSum = 0.0;
    for (int i = 0; i < period; i++) {
      runningSum += candles[i].close;
    }
    values[period - 1] = runningSum / period;

    for (int i = period; i < candles.length; i++) {
      runningSum += candles[i].close - candles[i - period].close;
      values[i] = runningSum / period;
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: [
        IndicatorSeries(
          id: 'sma',
          label: name,
          color: color,
          strokeWidth: strokeWidth,
          values: values,
        ),
      ],
    );
  }
}
