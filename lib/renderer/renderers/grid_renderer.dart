import 'dart:math' as math;
import 'dart:ui';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/coordinates/viewport.dart';
import '../../core/models/price_range.dart';
import 'base_renderer.dart';

/// Renders adaptive background grid lines for prices and timestamps.
class GridRenderer extends BaseRenderer {
  GridRenderer(super.theme);

  /// Draws the background grid for the specified pane.
  void drawGrid({
    required Canvas canvas,
    required Rect bounds,
    required PriceRange priceRange,
    required CoordinateConverter converter,
    required ChartViewport viewport,
    required int totalCandles,
    int verticalDivisions = 6,
    double minHorizontalSpacing = 80.0,
  }) {
    // 1. Horizontal Price Grid Lines
    if (priceRange.span > 0 && bounds.height > 0) {
      final step = _calculateNicePriceStep(priceRange.span, verticalDivisions);
      final firstLinePrice = (priceRange.min / step).ceil() * step;

      for (double p = firstLinePrice; p <= priceRange.max; p += step) {
        final y = CoordinateConverter.priceToY(p, bounds, priceRange);
        if (y >= bounds.top && y <= bounds.bottom) {
          canvas.drawLine(
            Offset(bounds.left, y),
            Offset(bounds.right, y),
            gridPaint,
          );
        }
      }
    }

    // 2. Vertical Time Grid Lines
    if (totalCandles > 0 && bounds.width > 0) {
      final candleTotalWidth = viewport.candleTotalWidth;
      if (candleTotalWidth > 0) {
        final candlesPerGrid = math.max(1, (minHorizontalSpacing / candleTotalWidth).round());
        final visible = viewport.calculateVisibleIndices(totalCandles);

        final firstIndex = (visible.start ~/ candlesPerGrid) * candlesPerGrid;
        for (int i = firstIndex; i <= visible.end; i += candlesPerGrid) {
          if (i < 0 || i >= totalCandles) continue;
          final x = converter.indexToX(i);
          if (x >= bounds.left && x <= bounds.right) {
            canvas.drawLine(
              Offset(x, bounds.top),
              Offset(x, bounds.bottom),
              gridPaint,
            );
          }
        }
      }
    }
  }

  /// Calculates human-readable "nice" grid step intervals (1, 2, 5, 10, etc.)
  double _calculateNicePriceStep(double span, int targetCount) {
    if (span <= 0) return 1.0;
    final roughStep = span / targetCount;
    final exponent = math.pow(10, (math.log(roughStep) / math.ln10).floor()).toDouble();
    final fraction = roughStep / exponent;

    double niceFraction;
    if (fraction < 1.5) {
      niceFraction = 1.0;
    } else if (fraction < 3.0) {
      niceFraction = 2.0;
    } else if (fraction < 7.0) {
      niceFraction = 5.0;
    } else {
      niceFraction = 10.0;
    }

    return niceFraction * exponent;
  }
}
