import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Bollinger Bands Indicator (Upper, Middle, Lower).
class BollingerBandsIndicator extends Indicator {
  final int period;
  final double multiplier;
  final Color middleColor;
  final Color upperColor;
  final Color lowerColor;

  BollingerBandsIndicator({
    this.period = 20,
    this.multiplier = 2.0,
    this.middleColor = const Color(0xFFFF9800),
    this.upperColor = const Color(0xFF2196F3),
    this.lowerColor = const Color(0xFF2196F3),
  }) : assert(period > 0, 'Period must be positive');

  @override
  String get id => 'BB_${period}_$multiplier';

  @override
  String get name => 'BB $period ($multiplier)';

  @override
  bool get isOverlay => true;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final middleValues = List<double?>.filled(candles.length, null);
    final upperValues = List<double?>.filled(candles.length, null);
    final lowerValues = List<double?>.filled(candles.length, null);

    if (candles.length < period) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: true,
        series: [
          IndicatorSeries(
            id: 'upper',
            label: 'Upper',
            color: upperColor,
            values: upperValues,
          ),
          IndicatorSeries(
            id: 'middle',
            label: 'Basis',
            color: middleColor,
            values: middleValues,
          ),
          IndicatorSeries(
            id: 'lower',
            label: 'Lower',
            color: lowerColor,
            values: lowerValues,
          ),
        ],
      );
    }

    for (int i = period - 1; i < candles.length; i++) {
      double sum = 0.0;
      for (int j = i - period + 1; j <= i; j++) {
        sum += candles[j].close;
      }
      final sma = sum / period;
      middleValues[i] = sma;

      double varianceSum = 0.0;
      for (int j = i - period + 1; j <= i; j++) {
        final diff = candles[j].close - sma;
        varianceSum += diff * diff;
      }
      final stdDev = math.sqrt(varianceSum / period);

      upperValues[i] = sma + (multiplier * stdDev);
      lowerValues[i] = sma - (multiplier * stdDev);
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: [
        IndicatorSeries(
          id: 'upper',
          label: 'Upper',
          color: upperColor,
          values: upperValues,
        ),
        IndicatorSeries(
          id: 'middle',
          label: 'Basis',
          color: middleColor,
          strokeWidth: 1.2,
          values: middleValues,
        ),
        IndicatorSeries(
          id: 'lower',
          label: 'Lower',
          color: lowerColor,
          values: lowerValues,
        ),
      ],
    );
  }
}
