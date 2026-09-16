import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Moving Average Convergence Divergence (MACD) Sub-Pane Indicator.
///
/// Computes:
/// - MACD Line: Fast EMA (12) - Slow EMA (26)
/// - Signal Line: Signal EMA (9) of MACD Line
/// - Histogram: MACD Line - Signal Line
class MACDIndicator extends Indicator {
  final int fastPeriod;
  final int slowPeriod;
  final int signalPeriod;
  final Color macdColor;
  final Color signalColor;

  MACDIndicator({
    this.fastPeriod = 12,
    this.slowPeriod = 26,
    this.signalPeriod = 9,
    this.macdColor = const Color(0xFF00E5FF),
    this.signalColor = const Color(0xFFFF9100),
  })  : assert(fastPeriod > 0, 'Fast period must be positive'),
        assert(
          slowPeriod > fastPeriod,
          'Slow period must be greater than fast period',
        ),
        assert(signalPeriod > 0, 'Signal period must be positive');

  @override
  String get id => 'MACD_${fastPeriod}_${slowPeriod}_$signalPeriod';

  @override
  String get name => 'MACD ($fastPeriod, $slowPeriod, $signalPeriod)';

  @override
  bool get isOverlay => false;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final macdValues = List<double?>.filled(candles.length, null);
    final signalValues = List<double?>.filled(candles.length, null);
    final histValues = List<double?>.filled(candles.length, null);

    if (candles.length < slowPeriod) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: false,
        series: [
          IndicatorSeries(
            id: 'histogram',
            label: 'Hist',
            color: const Color(0xFF00E676),
            values: histValues,
          ),
          IndicatorSeries(
            id: 'macd',
            label: 'MACD',
            color: macdColor,
            strokeWidth: 1.5,
            values: macdValues,
          ),
          IndicatorSeries(
            id: 'signal',
            label: 'Signal',
            color: signalColor,
            strokeWidth: 1.5,
            values: signalValues,
          ),
        ],
        horizontalLevels: const [0.0],
      );
    }

    // 1. Calculate Fast EMA (12) and Slow EMA (26)
    final fastEma = _calculateEmaSeries(candles, fastPeriod);
    final slowEma = _calculateEmaSeries(candles, slowPeriod);

    // 2. Calculate MACD Line = Fast EMA - Slow EMA
    for (int i = 0; i < candles.length; i++) {
      if (fastEma[i] != null && slowEma[i] != null) {
        macdValues[i] = fastEma[i]! - slowEma[i]!;
      }
    }

    // 3. Calculate Signal Line = EMA (9) of MACD Line
    // First find start index of non-null MACD values
    int macdStartIndex = -1;
    for (int i = 0; i < candles.length; i++) {
      if (macdValues[i] != null) {
        macdStartIndex = i;
        break;
      }
    }

    if (macdStartIndex != -1 &&
        (candles.length - macdStartIndex) >= signalPeriod) {
      // SMA of first signalPeriod valid MACD values
      double sum = 0.0;
      for (int i = macdStartIndex; i < macdStartIndex + signalPeriod; i++) {
        sum += macdValues[i]!;
      }
      double currentSignal = sum / signalPeriod;
      signalValues[macdStartIndex + signalPeriod - 1] = currentSignal;

      final k = 2.0 / (signalPeriod + 1);
      for (int i = macdStartIndex + signalPeriod; i < candles.length; i++) {
        if (macdValues[i] != null) {
          currentSignal = (macdValues[i]! * k) + (currentSignal * (1 - k));
          signalValues[i] = currentSignal;
        }
      }
    }

    // 4. Calculate Histogram = MACD - Signal
    for (int i = 0; i < candles.length; i++) {
      if (macdValues[i] != null && signalValues[i] != null) {
        histValues[i] = macdValues[i]! - signalValues[i]!;
      }
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: false,
      series: [
        IndicatorSeries(
          id: 'histogram',
          label: 'Histogram',
          color: const Color(0xFF00E676),
          values: histValues,
        ),
        IndicatorSeries(
          id: 'macd',
          label: 'MACD',
          color: macdColor,
          strokeWidth: 1.5,
          values: macdValues,
        ),
        IndicatorSeries(
          id: 'signal',
          label: 'Signal',
          color: signalColor,
          strokeWidth: 1.5,
          values: signalValues,
        ),
      ],
      horizontalLevels: const [0.0],
    );
  }

  List<double?> _calculateEmaSeries(List<Candle> candles, int period) {
    final values = List<double?>.filled(candles.length, null);
    if (candles.length < period) return values;

    double sum = 0.0;
    for (int i = 0; i < period; i++) {
      sum += candles[i].close;
    }
    double currentEma = sum / period;
    values[period - 1] = currentEma;

    final multiplier = 2.0 / (period + 1);
    for (int i = period; i < candles.length; i++) {
      currentEma = (candles[i].close - currentEma) * multiplier + currentEma;
      values[i] = currentEma;
    }

    return values;
  }
}
