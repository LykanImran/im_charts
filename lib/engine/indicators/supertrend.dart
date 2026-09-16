import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Supertrend technical indicator using Average True Range (ATR).
/// Computes upper band (resistance in downtrend) and lower band (support in uptrend).
class SupertrendIndicator extends Indicator {
  final int period;
  final double multiplier;
  final Color bullColor;
  final Color bearColor;
  final double strokeWidth;

  SupertrendIndicator({
    this.period = 10,
    this.multiplier = 3.0,
    this.bullColor = const Color(0xFF00E676),
    this.bearColor = const Color(0xFFFF5252),
    this.strokeWidth = 2.0,
  })  : assert(period > 0, 'Period must be positive'),
        assert(multiplier > 0, 'Multiplier must be positive');

  @override
  String get id => 'SUPERTREND_${period}_$multiplier';

  @override
  String get name => 'Supertrend ($period, $multiplier)';

  @override
  bool get isOverlay => true;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final upperBand = List<double?>.filled(candles.length, null);
    final lowerBand = List<double?>.filled(candles.length, null);
    final supertrendLine = List<double?>.filled(candles.length, null);
    final trendDirections =
        List<double?>.filled(candles.length, null); // 1 = Bull, -1 = Bear

    if (candles.length <= period) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: true,
        series: [
          IndicatorSeries(
            id: 'supertrend',
            label: name,
            color: bullColor,
            strokeWidth: strokeWidth,
            values: supertrendLine,
          ),
        ],
      );
    }

    // 1. Calculate True Range (TR)
    final tr = List<double>.filled(candles.length, 0.0);
    tr[0] = candles[0].high - candles[0].low;
    for (int i = 1; i < candles.length; i++) {
      final hl = candles[i].high - candles[i].low;
      final hc = (candles[i].high - candles[i - 1].close).abs();
      final lc = (candles[i].low - candles[i - 1].close).abs();
      tr[i] = math.max(hl, math.max(hc, lc));
    }

    // 2. Wilder's Smoothed Average True Range (ATR)
    final atr = List<double>.filled(candles.length, 0.0);
    double initialTrSum = 0.0;
    for (int i = 0; i < period; i++) {
      initialTrSum += tr[i];
    }
    atr[period - 1] = initialTrSum / period;
    for (int i = period; i < candles.length; i++) {
      atr[i] = (atr[i - 1] * (period - 1) + tr[i]) / period;
    }

    // 3. Bands calculation
    final finalUpper = List<double>.filled(candles.length, 0.0);
    final finalLower = List<double>.filled(candles.length, 0.0);
    final trend =
        List<int>.filled(candles.length, 1); // 1: Bullish, -1: Bearish

    for (int i = period - 1; i < candles.length; i++) {
      final hl2 = (candles[i].high + candles[i].low) / 2.0;
      final basicUpper = hl2 + (multiplier * atr[i]);
      final basicLower = hl2 - (multiplier * atr[i]);

      if (i == period - 1) {
        finalUpper[i] = basicUpper;
        finalLower[i] = basicLower;
        trend[i] = candles[i].close >= basicLower ? 1 : -1;
      } else {
        // Final Upper Band
        if (basicUpper < finalUpper[i - 1] ||
            candles[i - 1].close > finalUpper[i - 1]) {
          finalUpper[i] = basicUpper;
        } else {
          finalUpper[i] = finalUpper[i - 1];
        }

        // Final Lower Band
        if (basicLower > finalLower[i - 1] ||
            candles[i - 1].close < finalLower[i - 1]) {
          finalLower[i] = basicLower;
        } else {
          finalLower[i] = finalLower[i - 1];
        }

        // Trend logic
        if (trend[i - 1] == 1) {
          if (candles[i].close < finalLower[i]) {
            trend[i] = -1;
          } else {
            trend[i] = 1;
          }
        } else {
          if (candles[i].close > finalUpper[i]) {
            trend[i] = 1;
          } else {
            trend[i] = -1;
          }
        }
      }

      if (trend[i] == 1) {
        supertrendLine[i] = finalLower[i];
        lowerBand[i] = finalLower[i];
        trendDirections[i] = 1.0;
      } else {
        supertrendLine[i] = finalUpper[i];
        upperBand[i] = finalUpper[i];
        trendDirections[i] = -1.0;
      }
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: [
        IndicatorSeries(
          id: 'supertrend',
          label: name,
          color: bullColor,
          strokeWidth: strokeWidth,
          values: supertrendLine,
        ),
        IndicatorSeries(
          id: 'supertrend_bull',
          label: 'Bull Support',
          color: bullColor,
          strokeWidth: strokeWidth,
          values: lowerBand,
        ),
        IndicatorSeries(
          id: 'supertrend_bear',
          label: 'Bear Resistance',
          color: bearColor,
          strokeWidth: strokeWidth,
          values: upperBand,
        ),
        IndicatorSeries(
          id: 'supertrend_dir',
          label: 'Trend Direction',
          color: bullColor,
          strokeWidth: 1.0,
          values: trendDirections,
        ),
      ],
    );
  }
}
