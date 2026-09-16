import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Parabolic SAR (Stop and Reverse) technical indicator.
/// Plots dots trailing price to identify directional trends and trailing stop reversals.
class ParabolicSarIndicator extends Indicator {
  final double step;
  final double maxStep;
  final Color bullColor;
  final Color bearColor;
  final double strokeWidth;

  ParabolicSarIndicator({
    this.step = 0.02,
    this.maxStep = 0.2,
    this.bullColor = const Color(0xFF00E676),
    this.bearColor = const Color(0xFFFF5252),
    this.strokeWidth = 2.0,
  })  : assert(step > 0, 'step must be positive'),
        assert(maxStep >= step, 'maxStep must be >= step');

  @override
  String get id => 'PSAR_${step}_$maxStep';

  @override
  String get name => 'Parabolic SAR ($step, $maxStep)';

  @override
  bool get isOverlay => true;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final sarValues = List<double?>.filled(candles.length, null);

    if (candles.length < 3) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: true,
        series: [
          IndicatorSeries(
            id: 'psar',
            label: name,
            color: bullColor,
            strokeWidth: strokeWidth,
            values: sarValues,
          ),
        ],
      );
    }

    bool isLong = candles[1].close > candles[0].close;
    double sar = isLong ? candles[0].low : candles[0].high;
    double ep = isLong ? candles[0].high : candles[0].low; // Extreme Price
    double af = step; // Acceleration Factor

    sarValues[0] = sar;

    for (int i = 1; i < candles.length; i++) {
      final prevSar = sar;
      final prevCandle = candles[i - 1];
      final currCandle = candles[i];

      if (isLong) {
        sar = prevSar + af * (ep - prevSar);
        if (i >= 2) {
          sar = math.min(sar, math.min(prevCandle.low, candles[i - 2].low));
        } else {
          sar = math.min(sar, prevCandle.low);
        }

        // Check reversal to short
        if (currCandle.low < sar) {
          isLong = false;
          sar = ep;
          ep = currCandle.low;
          af = step;
        } else {
          if (currCandle.high > ep) {
            ep = currCandle.high;
            af = math.min(af + step, maxStep);
          }
        }
      } else {
        // Short trend
        sar = prevSar + af * (ep - prevSar);
        if (i >= 2) {
          sar = math.max(sar, math.max(prevCandle.high, candles[i - 2].high));
        } else {
          sar = math.max(sar, prevCandle.high);
        }

        // Check reversal to long
        if (currCandle.high > sar) {
          isLong = true;
          sar = ep;
          ep = currCandle.high;
          af = step;
        } else {
          if (currCandle.low < ep) {
            ep = currCandle.low;
            af = math.min(af + step, maxStep);
          }
        }
      }

      sarValues[i] = sar;
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: [
        IndicatorSeries(
          id: 'psar',
          label: name,
          color: const Color(0xFFFFB300),
          strokeWidth: strokeWidth,
          values: sarValues,
        ),
      ],
    );
  }
}
