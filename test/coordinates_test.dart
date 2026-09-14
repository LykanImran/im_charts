import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/core/coordinates/coordinate_converter.dart';
import 'package:im_charts/core/coordinates/viewport.dart';
import 'package:im_charts/core/models/price_range.dart';

void main() {
  group('CoordinateConverter & Viewport Tests', () {
    test('Price to Y and Y to Price are inverse functions', () {
      const bounds = Rect.fromLTWH(0, 0, 400, 300);
      const range = PriceRange(100.0, 200.0);

      const testPrices = [100.0, 125.0, 150.0, 175.5, 200.0];
      for (final price in testPrices) {
        final y = CoordinateConverter.priceToY(price, bounds, range);
        final reconstructedPrice = CoordinateConverter.yToPrice(y, bounds, range);
        expect(reconstructedPrice, closeTo(price, 1e-4));
      }

      // Max price should map to bounds.top
      expect(CoordinateConverter.priceToY(200.0, bounds, range), closeTo(bounds.top, 1e-4));
      // Min price should map to bounds.bottom
      expect(CoordinateConverter.priceToY(100.0, bounds, range), closeTo(bounds.bottom, 1e-4));
    });

    test('Index to X and X to Index mapping', () {
      const viewport = ChartViewport(
        candleWidth: 8.0,
        candleSpacing: 2.0,
        scrollOffset: 0.0,
        viewportWidth: 800.0,
        viewportHeight: 500.0,
        rightMargin: 50.0,
      );
      const totalCandles = 100;
      final converter = CoordinateConverter(viewport: viewport, totalCandles: totalCandles);

      // Latest candle is index 99
      final lastX = converter.indexToX(99);
      expect(lastX, equals(800.0 - 50.0));

      // Test conversion round-trip for various indices
      for (int i = 50; i < 100; i++) {
        final x = converter.indexToX(i);
        final reconstructedIndex = converter.xToIndex(x);
        expect(reconstructedIndex, equals(i));
      }
    });

    test('VisibleIndices calculation within viewport', () {
      const viewport = ChartViewport(
        candleWidth: 8.0,
        candleSpacing: 2.0, // total 10px per candle
        scrollOffset: 0.0,
        viewportWidth: 300.0, // fits ~30 candles
        viewportHeight: 400.0,
        rightMargin: 50.0,
      );
      const totalCandles = 200;
      final visible = viewport.calculateVisibleIndices(totalCandles);

      expect(visible.end, equals(199));
      expect(visible.start, lessThan(visible.end));
      expect(visible.count, greaterThan(0));
    });
  });
}
