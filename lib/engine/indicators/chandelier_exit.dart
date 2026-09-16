import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Chandelier Exit indicator by Chuck LeBeau / Alexander Elder.
/// A volatility-based trailing stop indicator using Average True Range (ATR).
/// Plots Long Exit (support) and Short Exit (resistance) lines.
class ChandelierExitIndicator extends Indicator {
  final int period;
  final double multiplier;
  final Color longColor;
  final Color shortColor;
  final double strokeWidth;

  ChandelierExitIndicator({
    this.period = 22,
    this.multiplier = 3.0,
    this.longColor = const Color(0xFF00E676),
    this.shortColor = const Color(0xFFFF5252),
    this.strokeWidth = 1.6,
  })  : assert(period > 0, 'period must be positive'),
        assert(multiplier > 0, 'multiplier must be positive');

  @override
  String get id => 'CHANDELIER_${period}_$multiplier';

  @override
  String get name => 'Chandelier Exit ($period, $multiplier)';

  @override
  bool get isOverlay => true;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final longExit = List<double?>.filled(candles.length, null);
    final shortExit = List<double?>.filled(candles.length, null);

    if (candles.length <= period) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: true,
        series: [
          IndicatorSeries(
            id: 'longExit',
            label: 'Long Stop',
            color: longColor,
            strokeWidth: strokeWidth,
            values: longExit,
          ),
          IndicatorSeries(
            id: 'shortExit',
            label: 'Short Stop',
            color: shortColor,
            strokeWidth: strokeWidth,
            values: shortExit,
          ),
        ],
      );
    }

    // 1. Calculate True Range (TR)
    final tr = List<double>.filled(candles.length, 0.0);
    tr[0] = candles[0].high - candles[0].low;

    for (int i = 1; i < candles.length; i++) {
      final h = candles[i].high;
      final l = candles[i].low;
      final prevClose = candles[i - 1].close;
      final hl = h - l;
      final hpc = (h - prevClose).abs();
      final lpc = (l - prevClose).abs();
      tr[i] = math.max(hl, math.max(hpc, lpc));
    }

    // 2. Wilder's Smoothed ATR
    final atr = List<double>.filled(candles.length, 0.0);
    double initialTrSum = 0.0;
    for (int i = 0; i < period; i++) {
      initialTrSum += tr[i];
    }
    atr[period - 1] = initialTrSum / period;

    for (int i = period; i < candles.length; i++) {
      atr[i] = (atr[i - 1] * (period - 1) + tr[i]) / period;
    }

    // 3. Compute Highest High and Lowest Low over `period`
    for (int i = period - 1; i < candles.length; i++) {
      double highestHigh = candles[i].high;
      double lowestLow = candles[i].low;

      for (int j = i - period + 1; j <= i; j++) {
        if (candles[j].high > highestHigh) highestHigh = candles[j].high;
        if (candles[j].low < lowestLow) lowestLow = candles[j].low;
      }

      final stopDistance = atr[i] * multiplier;
      longExit[i] = highestHigh - stopDistance;
      shortExit[i] = lowestLow + stopDistance;
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: [
        IndicatorSeries(
          id: 'longExit',
          label: 'Long Stop',
          color: longColor,
          strokeWidth: strokeWidth,
          values: longExit,
        ),
        IndicatorSeries(
          id: 'shortExit',
          label: 'Short Stop',
          color: shortColor,
          strokeWidth: strokeWidth,
          values: shortExit,
        ),
      ],
    );
  }
}
