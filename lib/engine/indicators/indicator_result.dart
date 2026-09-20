import 'package:flutter/material.dart';

/// Represents a single named line/series inside an indicator calculation.
class IndicatorSeries {
  final String id;
  final String label;
  final Color color;
  final double strokeWidth;

  /// Values aligned 1:1 with candles. Null when insufficient data.
  final List<double?> values;

  /// If true, the renderer draws this line as a dashed pattern.
  final bool isDashed;

  const IndicatorSeries({
    required this.id,
    required this.label,
    required this.color,
    this.strokeWidth = 1.5,
    required this.values,
    this.isDashed = false,
  });
}

/// Represents the output of an indicator calculation.
class IndicatorResult {
  final String indicatorId;
  final String name;
  final bool isOverlay;
  final List<IndicatorSeries> series;

  /// Optional fixed range or thresholds (e.g. 0-100 for RSI, 30/70 levels).
  final double? fixedMin;
  final double? fixedMax;
  final List<double>? horizontalLevels;

  const IndicatorResult({
    required this.indicatorId,
    required this.name,
    required this.isOverlay,
    required this.series,
    this.fixedMin,
    this.fixedMax,
    this.horizontalLevels,
  });

  /// Extracts the active values at a given candle index.
  Map<String, double?> getValuesAt(int index) {
    final res = <String, double?>{};
    for (final s in series) {
      if (index >= 0 && index < s.values.length) {
        res[s.id] = s.values[index];
      }
    }
    return res;
  }
}
