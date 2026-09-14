import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/coordinates/viewport.dart';
import '../../core/models/candle.dart';
import '../../core/models/price_range.dart';
import '../../core/models/timeframe.dart';
import 'base_renderer.dart';

/// Renders the right price scale (Y-axis) and bottom timestamp scale (X-axis).
class AxisRenderer extends BaseRenderer {
  AxisRenderer(super.theme);

  /// Draws the price scale on the right.
  void drawPriceAxis({
    required Canvas canvas,
    required Rect axisBounds,
    required Rect paneBounds,
    required PriceRange priceRange,
    int verticalDivisions = 6,
  }) {
    // Draw vertical divider line
    canvas.drawLine(
      Offset(axisBounds.left, axisBounds.top),
      Offset(axisBounds.left, axisBounds.bottom),
      Paint()..color = theme.axisLineColor..strokeWidth = 1.0,
    );

    if (priceRange.span <= 0 || paneBounds.height <= 0) return;

    final step = _calculateNicePriceStep(priceRange.span, verticalDivisions);
    final firstLinePrice = (priceRange.min / step).ceil() * step;

    for (double p = firstLinePrice; p <= priceRange.max; p += step) {
      final y = CoordinateConverter.priceToY(p, paneBounds, priceRange);
      if (y >= paneBounds.top + 10 && y <= paneBounds.bottom - 10) {
        final textSpan = TextSpan(
          text: p.toStringAsFixed(2),
          style: theme.axisTextStyle,
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, Offset(axisBounds.left + 6.0, y - (tp.height / 2.0)));
      }
    }
  }

  /// Draws the time scale along the bottom.
  void drawTimeAxis({
    required Canvas canvas,
    required Rect timeBounds,
    required List<Candle> candles,
    required VisibleIndices visible,
    required CoordinateConverter converter,
    required ChartViewport viewport,
    required Timeframe timeframe,
    double minLabelSpacing = 85.0,
  }) {
    // Draw horizontal divider line
    canvas.drawLine(
      Offset(timeBounds.left, timeBounds.top),
      Offset(timeBounds.right + 65.0, timeBounds.top), // extend into price axis area
      Paint()..color = theme.axisLineColor..strokeWidth = 1.0,
    );

    if (candles.isEmpty || visible.count <= 0) return;

    final candleTotalWidth = viewport.candleTotalWidth;
    if (candleTotalWidth <= 0) return;

    final candlesPerLabel = math.max(1, (minLabelSpacing / candleTotalWidth).round());
    final firstIndex = (visible.start ~/ candlesPerLabel) * candlesPerLabel;

    for (int i = firstIndex; i <= visible.end; i += candlesPerLabel) {
      if (i < 0 || i >= candles.length) continue;
      final c = candles[i];
      final x = converter.indexToX(i);

      if (x >= timeBounds.left && x <= timeBounds.right - 30.0) {
        final label = _formatTimestamp(c.timestamp, timeframe);
        final textSpan = TextSpan(
          text: label,
          style: theme.axisTextStyle,
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, Offset(x - (tp.width / 2.0), timeBounds.top + 6.0));
      }
    }
  }

  String _formatTimestamp(DateTime dt, Timeframe tf) {
    if (tf == Timeframe.oneDay || tf == Timeframe.oneWeek) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } else {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
  }

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
