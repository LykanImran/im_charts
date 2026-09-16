import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Represents the virtual viewport and visible index window of the chart.
@immutable
class ChartViewport {
  final double candleWidth;
  final double candleSpacing;
  final double scrollOffset;
  final double viewportWidth;
  final double viewportHeight;
  final double rightMargin;

  const ChartViewport({
    this.candleWidth = 8.0,
    this.candleSpacing = 3.0,
    this.scrollOffset = 0.0,
    this.viewportWidth = 0.0,
    this.viewportHeight = 0.0,
    this.rightMargin = 50.0,
  });

  double get candleTotalWidth => candleWidth + candleSpacing;

  /// Visible candle count fitting within the horizontal viewport.
  int get visibleCount =>
      candleTotalWidth > 0 ? (viewportWidth / candleTotalWidth).ceil() + 3 : 0;

  /// Returns the starting (leftmost) and ending (rightmost) candle indices in [0, totalCandles - 1].
  VisibleIndices calculateVisibleIndices(int totalCandles) {
    if (totalCandles <= 0 || candleTotalWidth <= 0 || viewportWidth <= 0) {
      return const VisibleIndices(0, 0);
    }

    final lastIndex = totalCandles - 1;

    // A candle index i has screen x = viewportWidth - rightMargin - (lastIndex - i) * candleTotalWidth + scrollOffset
    // Right boundary of screen is x <= viewportWidth:
    // (lastIndex - i) * candleTotalWidth >= scrollOffset - rightMargin
    // i <= lastIndex - (scrollOffset - rightMargin) / candleTotalWidth
    // Left boundary of screen is x >= 0:
    // (lastIndex - i) * candleTotalWidth <= viewportWidth - rightMargin + scrollOffset
    // i >= lastIndex - (viewportWidth - rightMargin + scrollOffset) / candleTotalWidth

    final rawEnd =
        lastIndex -
        ((scrollOffset - rightMargin) / candleTotalWidth).floor() +
        1;
    final end = math.max(0, math.min(lastIndex, rawEnd));

    final rawStart =
        lastIndex -
        ((viewportWidth - rightMargin + scrollOffset) / candleTotalWidth)
            .ceil() -
        1;
    final start = math.max(0, math.min(lastIndex, rawStart));

    return VisibleIndices(start, end);
  }

  ChartViewport copyWith({
    double? candleWidth,
    double? candleSpacing,
    double? scrollOffset,
    double? viewportWidth,
    double? viewportHeight,
    double? rightMargin,
  }) {
    return ChartViewport(
      candleWidth: candleWidth ?? this.candleWidth,
      candleSpacing: candleSpacing ?? this.candleSpacing,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      viewportWidth: viewportWidth ?? this.viewportWidth,
      viewportHeight: viewportHeight ?? this.viewportHeight,
      rightMargin: rightMargin ?? this.rightMargin,
    );
  }
}

/// Pair of visible start and end indices.
@immutable
class VisibleIndices {
  final int start;
  final int end;

  const VisibleIndices(this.start, this.end);

  int get count => (end >= start) ? (end - start + 1) : 0;

  @override
  String toString() =>
      'VisibleIndices(start: $start, end: $end, count: $count)';
}
