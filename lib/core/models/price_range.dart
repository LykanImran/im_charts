import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'candle.dart';

/// Defines the minimum and maximum price range in a given viewport or series.
@immutable
class PriceRange {
  final double min;
  final double max;

  const PriceRange(this.min, this.max)
      : assert(max >= min, 'Max price ($max) must be >= Min price ($min)');

  /// Empty or default zero price range.
  static const zero = PriceRange(0.0, 1.0);

  double get span => max - min;

  /// Returns a new [PriceRange] with proportional top and bottom padding.
  PriceRange withPadding({double topPaddingPercent = 0.08, double bottomPaddingPercent = 0.08}) {
    final s = span == 0 ? 1.0 : span;
    final topPad = s * topPaddingPercent;
    final bottomPad = s * bottomPaddingPercent;
    return PriceRange(min - bottomPad, max + topPad);
  }

  /// Calculates the price range spanning a list of [candles] within optional [start] and [end] indices.
  factory PriceRange.fromCandles(List<Candle> candles, {int? start, int? end}) {
    if (candles.isEmpty) return PriceRange.zero;

    final s = math.max(0, start ?? 0);
    final e = math.min(candles.length - 1, end ?? (candles.length - 1));

    if (s > e) return PriceRange.zero;

    double minVal = candles[s].low;
    double maxVal = candles[s].high;

    for (int i = s + 1; i <= e; i++) {
      final c = candles[i];
      if (c.low < minVal) minVal = c.low;
      if (c.high > maxVal) maxVal = c.high;
    }

    if (minVal == maxVal) {
      minVal -= 1.0;
      maxVal += 1.0;
    }

    return PriceRange(minVal, maxVal);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceRange &&
          runtimeType == other.runtimeType &&
          min == other.min &&
          max == other.max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'PriceRange(min: $min, max: $max, span: $span)';
}
