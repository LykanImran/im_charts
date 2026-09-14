import 'dart:ui';
import '../models/price_range.dart';
import 'viewport.dart';

/// Provides bidirectional conversions between Chart Coordinates (Index, Price)
/// and Screen Canvas Pixels (X, Y).
class CoordinateConverter {
  final ChartViewport viewport;
  final int totalCandles;

  const CoordinateConverter({
    required this.viewport,
    required this.totalCandles,
  });

  /// Converts a candle index to screen X pixel coordinate (center of candle).
  double indexToX(int index) {
    if (totalCandles <= 0) return 0.0;
    final lastIndex = totalCandles - 1;
    final distanceFromLast = (lastIndex - index) * viewport.candleTotalWidth;
    return viewport.viewportWidth - viewport.rightMargin - distanceFromLast + viewport.scrollOffset;
  }

  /// Converts a screen X pixel coordinate to the nearest candle index.
  int xToIndex(double x) {
    if (totalCandles <= 0 || viewport.candleTotalWidth <= 0) return 0;
    final lastIndex = totalCandles - 1;
    final distanceFromRight = (viewport.viewportWidth - viewport.rightMargin + viewport.scrollOffset) - x;
    final deltaIndex = (distanceFromRight / viewport.candleTotalWidth).round();
    final index = lastIndex - deltaIndex;
    return index.clamp(0, lastIndex);
  }

  /// Converts a continuous floating index to exact screen X.
  double continuousIndexToX(double continuousIndex) {
    if (totalCandles <= 0) return 0.0;
    final lastIndex = totalCandles - 1;
    final distanceFromLast = (lastIndex - continuousIndex) * viewport.candleTotalWidth;
    return viewport.viewportWidth - viewport.rightMargin - distanceFromLast + viewport.scrollOffset;
  }

  /// Converts a price value to screen Y coordinate within [paneBounds].
  /// In screen coordinates, Y=0 is at the top, so max price corresponds to paneBounds.top.
  static double priceToY(double price, Rect paneBounds, PriceRange priceRange) {
    if (priceRange.span <= 0 || paneBounds.height <= 0) {
      return paneBounds.center.dy;
    }
    final normalized = (price - priceRange.min) / priceRange.span;
    return paneBounds.bottom - (normalized * paneBounds.height);
  }

  /// Converts a screen Y coordinate within [paneBounds] back to price.
  static double yToPrice(double y, Rect paneBounds, PriceRange priceRange) {
    if (paneBounds.height <= 0) return priceRange.min;
    final normalized = (paneBounds.bottom - y) / paneBounds.height;
    return priceRange.min + (normalized * priceRange.span);
  }
}
