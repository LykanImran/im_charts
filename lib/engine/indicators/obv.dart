import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// On-Balance Volume (OBV) — cumulative volume with direction from close change.
/// Rising OBV = buying pressure; falling OBV = selling pressure.
/// Displayed in a sub-pane.
class OBVIndicator extends Indicator {
  final Color color;
  final double strokeWidth;

  OBVIndicator({
    this.color = const Color(0xFF42A5F5),
    this.strokeWidth = 1.5,
  });

  @override
  String get id => 'OBV';

  @override
  String get name => 'OBV';

  @override
  bool get isOverlay => false;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final values = List<double?>.filled(candles.length, null);

    if (candles.isEmpty) {
      return IndicatorResult(
        indicatorId: id, name: name, isOverlay: false,
        series: [IndicatorSeries(id: 'obv', label: 'OBV', color: color, strokeWidth: strokeWidth, values: values)],
      );
    }

    double obv = 0.0;
    values[0] = 0.0;

    for (int i = 1; i < candles.length; i++) {
      final curr = candles[i];
      final prev = candles[i - 1];
      if (curr.close > prev.close) {
        obv += curr.volume;
      } else if (curr.close < prev.close) {
        obv -= curr.volume;
      }
      values[i] = obv;
    }

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: false,
      series: [
        IndicatorSeries(id: 'obv', label: 'OBV', color: color, strokeWidth: strokeWidth, values: values),
      ],
    );
  }
}
