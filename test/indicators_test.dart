import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/core/models/candle.dart';
import 'package:im_charts/engine/indicators/bollinger_bands.dart';
import 'package:im_charts/engine/indicators/ema.dart';
import 'package:im_charts/engine/indicators/macd.dart';
import 'package:im_charts/engine/indicators/rsi.dart';
import 'package:im_charts/engine/indicators/vwap.dart';

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
        list.add(
          Candle(
            timestamp: startTime.add(Duration(minutes: i)),
            open: open,
            high: high,
            low: low,
            close: close,
            volume: 100.0 + (i * 10),
          ),
        );
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

    test(
      'VWAP calculates volume-weighted typical price and resets on session boundary',
      () {
        final startTime = DateTime(2026, 9, 14, 9, 15);
        final candles = <Candle>[
          // Day 1
          Candle(
            timestamp: startTime,
            open: 100,
            high: 105,
            low: 95,
            close: 100,
            volume: 1000,
          ),
          Candle(
            timestamp: startTime.add(const Duration(hours: 1)),
            open: 100,
            high: 110,
            low: 98,
            close: 104,
            volume: 2000,
          ),
          // Day 2 (session reset)
          Candle(
            timestamp: startTime.add(const Duration(days: 1)),
            open: 120,
            high: 125,
            low: 115,
            close: 120,
            volume: 500,
          ),
        ];

        final vwap = VWAPIndicator(bandMultiplier: 2.0);
        final result = vwap.calculate(candles);

        expect(result.isOverlay, isTrue);
        expect(result.series.length, 3); // upper, vwap, lower

        final vwapSeries = result.series.firstWhere((s) => s.id == 'vwap');
        final upperSeries = result.series.firstWhere((s) => s.id == 'upper');
        final lowerSeries = result.series.firstWhere((s) => s.id == 'lower');

        // First candle: typical price = (105+95+100)/3 = 100
        expect(vwapSeries.values[0], closeTo(100.0, 0.01));

        // Day 2 reset: typical price = (125+115+120)/3 = 120
        expect(vwapSeries.values[2], closeTo(120.0, 0.01));

        // Check standard deviation bounds
        expect(
          upperSeries.values[1]!,
          greaterThanOrEqualTo(vwapSeries.values[1]!),
        );
        expect(
          vwapSeries.values[1]!,
          greaterThanOrEqualTo(lowerSeries.values[1]!),
        );
      },
    );

    test(
      'MACD computes Fast/Slow EMA difference, Signal Line, and Histogram',
      () {
        final candles = generateMockCandles(45, 100.0);
        final macd = MACDIndicator(
          fastPeriod: 12,
          slowPeriod: 26,
          signalPeriod: 9,
        );
        final result = macd.calculate(candles);

        expect(result.isOverlay, isFalse);
        expect(result.horizontalLevels, contains(0.0));
        expect(result.series.length, 3); // histogram, macd, signal

        final hist = result.series.firstWhere((s) => s.id == 'histogram');
        final macdLine = result.series.firstWhere((s) => s.id == 'macd');
        final signal = result.series.firstWhere((s) => s.id == 'signal');

        // Slow period is 26, so first 25 values of macdLine must be null
        for (int i = 0; i < 25; i++) {
          expect(macdLine.values[i], isNull);
        }
        expect(macdLine.values[25], isNotNull);

        // Verify histogram = macd - signal where signal is computed
        for (int i = 35; i < 45; i++) {
          if (macdLine.values[i] != null && signal.values[i] != null) {
            final expectedHist = macdLine.values[i]! - signal.values[i]!;
            expect(hist.values[i]!, closeTo(expectedHist, 0.001));
          }
        }
      },
    );
  });
}
