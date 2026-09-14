import 'dart:math' as math;
import 'dart:ui';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/coordinates/viewport.dart';
import '../../core/models/candle.dart';
import '../../core/models/price_range.dart';
import 'base_renderer.dart';

/// Ultra-high performance Candlestick painter drawing directly to Skia/Impeller canvas.
/// Avoids any widget allocation and operates strictly on visible slice [start, end].
class CandleRenderer extends BaseRenderer {
  CandleRenderer(super.theme);

  void drawCandles({
    required Canvas canvas,
    required Rect bounds,
    required List<Candle> candles,
    required VisibleIndices visible,
    required PriceRange priceRange,
    required CoordinateConverter converter,
    required double candleWidth,
  }) {
    if (candles.isEmpty || visible.count <= 0) return;

    final halfWidth = math.max(0.5, candleWidth / 2.0);

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= candles.length) continue;
      final c = candles[i];
      final x = converter.indexToX(i);

      // Early viewport culling
      if (x + halfWidth < bounds.left || x - halfWidth > bounds.right) {
        continue;
      }

      final isBull = c.isBullish;
      final wickPaint = isBull ? bullWickPaint : bearWickPaint;
      final bodyPaint = isBull ? bullBodyPaint : bearBodyPaint;

      // 1. Draw Wick (high to low)
      final yHigh = CoordinateConverter.priceToY(c.high, bounds, priceRange);
      final yLow = CoordinateConverter.priceToY(c.low, bounds, priceRange);

      canvas.drawLine(
        Offset(x, yHigh),
        Offset(x, yLow),
        wickPaint,
      );

      // 2. Draw Body (open to close)
      final yOpen = CoordinateConverter.priceToY(c.open, bounds, priceRange);
      final yClose = CoordinateConverter.priceToY(c.close, bounds, priceRange);

      final top = math.min(yOpen, yClose);
      var height = (yOpen - yClose).abs();

      // Ensure flat/doji candles remain crisp and visible
      if (height < 1.0) {
        height = 1.0;
      }

      canvas.drawRect(
        Rect.fromLTWH(x - halfWidth, top, candleWidth, height),
        bodyPaint,
      );
    }
  }
}
