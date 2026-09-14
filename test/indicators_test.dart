import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/core/models/candle.dart';
import 'package:im_charts/engine/indicators/bollinger_bands.dart';
import 'package:im_charts/engine/indicators/ema.dart';
import 'package:im_charts/engine/indicators/rsi.dart';

void main() {
  group('Technical Indicators Tests', () {
    List<Candle> generateMockCandles(int count, double basePrice) {
      final list = <Candle>[];
      final startTime = DateTime(2026, 9, 14, 9, 15);
      double current = basePrice;
      for (int i = 0; i < count; i++) {
        final change = (i % 2 == 0) ? 2.0 : -1.0;
        final open = current;
        final close = current + change;
        final high = (open > close ? open : close) + 1.0;
        final low = (open < close ? open : close) - 1.0;
        list.add(Candle(
          timestamp: startTime.add(Duration(minutes: i)),
          open: open,
          high: high,
          low: low,
          close: close,
          volume: 100.0 + (i * 10),
        ));
        current = close;
      }
      return list;
    }

    test('EMA calculates correctly and overlay flag is true', () {
      final candles = generateMockCandles(30, 100.0);
      final ema = EMAIndicator(period: 10);
      final result = ema.calculate(candles);

      expect(result.isOverlay, isTrue);
      expect(result.series.first.values.length, equals(30));
      // First 9 items should be null
      for (int i = 0; i < 9; i++) {
        expect(result.series.first.values[i], isNull);
      }
      // Index 9 should be the initial SMA
      expect(result.series.first.values[9], isNotNull);
      // Last value should be calculated
      expect(result.series.first.values.last, isNotNull);
    });

    test('Bollinger Bands returns upper, middle, and lower bands', () {
      final candles = generateMockCandles(30, 100.0);
      final bb = BollingerBandsIndicator(period: 10, multiplier: 2.0);
      final result = bb.calculate(candles);

      expect(result.isOverlay, isTrue);
      expect(result.series.length, equals(3));
      final upper = result.series.firstWhere((s) => s.id == 'upper');
      final middle = result.series.firstWhere((s) => s.id == 'middle');
      final lower = result.series.firstWhere((s) => s.id == 'lower');

      for (int i = 10; i < 30; i++) {
        expect(upper.values[i]!, greaterThanOrEqualTo(middle.values[i]!));
        expect(middle.values[i]!, greaterThanOrEqualTo(lower.values[i]!));
      }
    });

    test('RSI calculates bounded values between 0 and 100', () {
      final candles = generateMockCandles(50, 100.0);
      final rsi = RSIIndicator(period: 14);
      final result = rsi.calculate(candles);

      expect(result.isOverlay, isFalse);
      expect(result.fixedMin, equals(0.0));
      expect(result.fixedMax, equals(100.0));

      for (int i = 14; i < 50; i++) {
        final val = result.series.first.values[i];
        expect(val, isNotNull);
        expect(val!, greaterThanOrEqualTo(0.0));
        expect(val, lessThanOrEqualTo(100.0));
      }
    });
  });
}
