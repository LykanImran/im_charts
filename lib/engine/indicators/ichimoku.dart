import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Ichimoku Kinko Hyo (Ichimoku Cloud) indicator.
/// Overlay indicator comprising Tenkan-sen (Conversion Line), Kijun-sen (Base Line),
/// Senkou Span A (Leading Span A), and Senkou Span B (Leading Span B).
class IchimokuIndicator extends Indicator {
  final int conversionPeriod;
  final int basePeriod;
  final int leadingSpanBPeriod;
  final int displacement;

  final Color conversionColor;
  final Color baseColor;
  final Color spanAColor;
  final Color spanBColor;

  IchimokuIndicator({
    this.conversionPeriod = 9,
    this.basePeriod = 26,
    this.leadingSpanBPeriod = 52,
    this.displacement = 26,
    this.conversionColor = const Color(0xFF2962FF),
    this.baseColor = const Color(0xFFFF1744),
    this.spanAColor = const Color(0xFF00E676),
    this.spanBColor = const Color(0xFFFF5252),
  })  : assert(conversionPeriod > 0),
        assert(basePeriod > 0),
        assert(leadingSpanBPeriod > 0);

  @override
  String get id => 'ICHIMOKU_${conversionPeriod}_${basePeriod}_$leadingSpanBPeriod';

  @override
  String get name => 'Ichimoku ($conversionPeriod, $basePeriod, $leadingSpanBPeriod)';

  @override
  bool get isOverlay => true;

  double _midpoint(List<Candle> candles, int endIndex, int period) {
    if (endIndex < period - 1) return candles[endIndex].close;
    double high = -double.infinity;
    double low = double.infinity;
    for (int i = endIndex - period + 1; i <= endIndex; i++) {
      if (candles[i].high > high) high = candles[i].high;
      if (candles[i].low < low) low = candles[i].low;
    }
    return (high + low) / 2.0;
  }

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final tenkan = List<double?>.filled(candles.length, null);
    final kijun = List<double?>.filled(candles.length, null);
    final spanA = List<double?>.filled(candles.length, null);
    final spanB = List<double?>.filled(candles.length, null);

    if (candles.isEmpty) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: true,
        series: [],
      );
    }

    for (int i = 0; i < candles.length; i++) {
      if (i >= conversionPeriod - 1) {
        tenkan[i] = _midpoint(candles, i, conversionPeriod);
      }
      if (i >= basePeriod - 1) {
        kijun[i] = _midpoint(candles, i, basePeriod);
      }
      if (tenkan[i] != null && kijun[i] != null) {
        spanA[i] = (tenkan[i]! + kijun[i]!) / 2.0;
      }
      if (i >= leadingSpanBPeriod - 1) {
        spanB[i] = _midpoint(candles, i, leadingSpanBPeriod);
      }
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: [
        IndicatorSeries(
          id: 'tenkan',
          label: 'Tenkan-sen ($conversionPeriod)',
          color: conversionColor,
          strokeWidth: 1.5,
          values: tenkan,
        ),
        IndicatorSeries(
          id: 'kijun',
          label: 'Kijun-sen ($basePeriod)',
          color: baseColor,
          strokeWidth: 1.5,
          values: kijun,
        ),
        IndicatorSeries(
          id: 'span_a',
          label: 'Span A',
          color: spanAColor,
          strokeWidth: 1.2,
          values: spanA,
        ),
        IndicatorSeries(
          id: 'span_b',
          label: 'Span B',
          color: spanBColor,
          strokeWidth: 1.2,
          values: spanB,
        ),
      ],
    );
  }
}
