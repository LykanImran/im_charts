import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Stochastic Oscillator indicator (%K and %D lines).
/// Renders as a sub-pane oscillator with 80 (Overbought) and 20 (Oversold) threshold lines.
class StochasticIndicator extends Indicator {
  final int kPeriod;
  final int kSmooth;
  final int dPeriod;
  final Color kColor;
  final Color dColor;
  final double strokeWidth;

  StochasticIndicator({
    this.kPeriod = 14,
    this.kSmooth = 3,
    this.dPeriod = 3,
    this.kColor = const Color(0xFF2962FF),
    this.dColor = const Color(0xFFFF6D00),
    this.strokeWidth = 1.4,
  })  : assert(kPeriod > 0, 'kPeriod must be positive'),
        assert(kSmooth > 0, 'kSmooth must be positive'),
        assert(dPeriod > 0, 'dPeriod must be positive');

  @override
  String get id => 'STOCH_${kPeriod}_${kSmooth}_$dPeriod';

  @override
  String get name => 'Stochastic ($kPeriod, $kSmooth, $dPeriod)';

  @override
  bool get isOverlay => false; // Renders in sub-pane

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final rawK = List<double?>.filled(candles.length, null);
    final smoothK = List<double?>.filled(candles.length, null);
    final smoothD = List<double?>.filled(candles.length, null);

    if (candles.length < kPeriod) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: false,
        fixedMin: 0.0,
        fixedMax: 100.0,
        horizontalLevels: const [20.0, 50.0, 80.0],
        series: [
          IndicatorSeries(
            id: 'k',
            label: '%K',
            color: kColor,
            strokeWidth: strokeWidth,
            values: smoothK,
          ),
          IndicatorSeries(
            id: 'd',
            label: '%D',
            color: dColor,
            strokeWidth: strokeWidth,
            values: smoothD,
          ),
        ],
      );
    }

    // 1. Calculate raw %K = (Close - LowestLow) / (HighestHigh - LowestLow) * 100
    for (int i = kPeriod - 1; i < candles.length; i++) {
      double lowestLow = candles[i].low;
      double highestHigh = candles[i].high;

      for (int j = i - kPeriod + 1; j <= i; j++) {
        if (candles[j].low < lowestLow) lowestLow = candles[j].low;
        if (candles[j].high > highestHigh) highestHigh = candles[j].high;
      }

      final range = highestHigh - lowestLow;
      if (range > 0) {
        rawK[i] = ((candles[i].close - lowestLow) / range) * 100.0;
      } else {
        rawK[i] = 50.0;
      }
    }

    // 2. Smooth %K using SMA of rawK
    for (int i = kPeriod - 1 + kSmooth - 1; i < candles.length; i++) {
      double sum = 0.0;
      int count = 0;
      for (int j = i - kSmooth + 1; j <= i; j++) {
        if (rawK[j] != null) {
          sum += rawK[j]!;
          count++;
        }
      }
      if (count == kSmooth) {
        smoothK[i] = sum / kSmooth;
      }
    }

    // 3. Calculate %D using SMA of smoothK
    for (int i = kPeriod - 1 + kSmooth - 1 + dPeriod - 1;
        i < candles.length;
        i++) {
      double sum = 0.0;
      int count = 0;
      for (int j = i - dPeriod + 1; j <= i; j++) {
        if (smoothK[j] != null) {
          sum += smoothK[j]!;
          count++;
        }
      }
      if (count == dPeriod) {
        smoothD[i] = sum / dPeriod;
      }
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: false,
      fixedMin: 0.0,
      fixedMax: 100.0,
      horizontalLevels: const [20.0, 50.0, 80.0],
      series: [
        IndicatorSeries(
          id: 'k',
          label: '%K',
          color: kColor,
          strokeWidth: strokeWidth,
          values: smoothK,
        ),
        IndicatorSeries(
          id: 'd',
          label: '%D',
          color: dColor,
          strokeWidth: strokeWidth,
          values: smoothD,
        ),
      ],
    );
  }
}
