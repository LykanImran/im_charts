import 'dart:ui' show PictureRecorder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('Smart Money Concepts (SMC) Engine', () {
    test('Detects Bullish and Bearish Fair Value Gaps (FVG)', () {
      final baseTime = DateTime(2025, 1, 1);
      final candles = <Candle>[
        // Candle 0: Low 100, High 105
        Candle(
          timestamp: baseTime,
          open: 101,
          high: 105,
          low: 100,
          close: 104,
          volume: 1000,
        ),
        // Candle 1: Big expansion candle: Low 105, High 125
        Candle(
          timestamp: baseTime.add(const Duration(minutes: 5)),
          open: 105,
          high: 125,
          low: 105,
          close: 124,
          volume: 5000,
        ),
        // Candle 2: Pullback bar: Low 115, High 126
        // Bullish gap exists between Candle 0 High (105) and Candle 2 Low (115)!
        Candle(
          timestamp: baseTime.add(const Duration(minutes: 10)),
          open: 124,
          high: 126,
          low: 115,
          close: 120,
          volume: 2000,
        ),
      ];

      final smc = SmartMoneyConcepts.calculate(candles);
      expect(smc.fvgZones.isNotEmpty, isTrue);

      final bullishFvg = smc.fvgZones.firstWhere((f) => f.isBullish);
      expect(bullishFvg.bottomPrice, equals(105.0));
      expect(bullishFvg.topPrice, equals(115.0));
      expect(bullishFvg.midPrice, equals(110.0));
      expect(bullishFvg.isMitigated, isFalse);
    });

    test('FVG mitigation is triggered when future candle price penetrates gap', () {
      final baseTime = DateTime(2025, 1, 1);
      final candles = <Candle>[
        Candle(
          timestamp: baseTime,
          open: 100,
          high: 105,
          low: 99,
          close: 104,
          volume: 1000,
        ),
        Candle(
          timestamp: baseTime.add(const Duration(minutes: 5)),
          open: 105,
          high: 130,
          low: 105,
          close: 129,
          volume: 5000,
        ),
        Candle(
          timestamp: baseTime.add(const Duration(minutes: 10)),
          open: 129,
          high: 131,
          low: 115,
          close: 125,
          volume: 2000,
        ),
        // Mitigating candle: Low dips to 104 (penetrates through FVG bottom of 105)
        Candle(
          timestamp: baseTime.add(const Duration(minutes: 15)),
          open: 125,
          high: 126,
          low: 104,
          close: 110,
          volume: 3000,
        ),
      ];

      final smc = SmartMoneyConcepts.calculate(candles);
      final bullishFvg = smc.fvgZones.firstWhere((f) => f.isBullish);
      expect(bullishFvg.isMitigated, isTrue);
    });

    test('Detects Break of Structure (BOS) and Order Blocks (OB)', () {
      final baseTime = DateTime(2025, 1, 1);
      final candles = <Candle>[];

      // Build a realistic swing high and breakout
      double price = 100.0;
      for (int i = 0; i < 30; i++) {
        if (i < 10) {
          price += 2.0; // Trend up to swing high around 120
        } else if (i < 18) {
          price -= 1.5; // Pullback to 108
        } else {
          price += 3.0; // Aggressive expansion breaking swing high
        }
        candles.add(
          Candle(
            timestamp: baseTime.add(Duration(minutes: 5 * i)),
            open: price - 1,
            high: price + 1.5,
            low: price - 1.5,
            close: price,
            volume: 1500,
          ),
        );
      }

      final smc = SmartMoneyConcepts.calculate(candles);
      expect(smc.structureBreaks, isNotNull);
      expect(smc.orderBlocks, isNotNull);
    });
  });

  group('Viral Technical Indicators', () {
    List<Candle> generateCandles(int count) {
      final baseTime = DateTime(2025, 1, 1);
      final candles = <Candle>[];
      double p = 100.0;
      for (int i = 0; i < count; i++) {
        p += (i % 2 == 0 ? 1.5 : -1.0);
        candles.add(
          Candle(
            timestamp: baseTime.add(Duration(minutes: 5 * i)),
            open: p - 0.5,
            high: p + 2.0,
            low: p - 2.0,
            close: p,
            volume: 1000 + (i * 10).toDouble(),
          ),
        );
      }
      return candles;
    }

    test('Stochastic Oscillator calculates %K and %D correctly', () {
      final candles = generateCandles(40);
      final stoch = StochasticIndicator(kPeriod: 14, kSmooth: 3, dPeriod: 3);

      expect(stoch.id, equals('STOCH_14_3_3'));
      expect(stoch.isOverlay, isFalse);

      final result = stoch.calculate(candles);
      expect(result.series.length, equals(2));
      expect(result.fixedMin, equals(0.0));
      expect(result.fixedMax, equals(100.0));
      expect(result.horizontalLevels, contains(80.0));
      expect(result.horizontalLevels, contains(20.0));

      final kValues = result.series.firstWhere((s) => s.id == 'k').values;
      final dValues = result.series.firstWhere((s) => s.id == 'd').values;

      expect(kValues.last, isNotNull);
      expect(dValues.last, isNotNull);
      expect(kValues.last! >= 0.0 && kValues.last! <= 100.0, isTrue);
    });

    test('Parabolic SAR calculates trailing dots and trend reversals', () {
      final candles = generateCandles(40);
      final psar = ParabolicSarIndicator();

      expect(psar.id, equals('PSAR_0.02_0.2'));
      expect(psar.isOverlay, isTrue);

      final result = psar.calculate(candles);
      expect(result.series.isNotEmpty, isTrue);

      final sarValues = result.series.first.values;
      expect(sarValues.last, isNotNull);
    });

    test('Chandelier Exit calculates ATR trailing stop lines', () {
      final candles = generateCandles(40);
      final chandelier = ChandelierExitIndicator(period: 22, multiplier: 3.0);

      expect(chandelier.id, equals('CHANDELIER_22_3.0'));
      expect(chandelier.isOverlay, isTrue);

      final result = chandelier.calculate(candles);
      expect(result.series.length, equals(2)); // Long & Short stops

      final longStop = result.series.firstWhere((s) => s.id == 'longExit').values;
      expect(longStop.last, isNotNull);
    });

    test('ATR calculates Wilder smoothed True Range', () {
      final candles = generateCandles(35);
      final atr = ATRIndicator(period: 14);

      expect(atr.id, equals('ATR_14'));
      expect(atr.isOverlay, isFalse);

      final result = atr.calculate(candles);
      expect(result.series.isNotEmpty, isTrue);

      final atrValues = result.series.first.values;
      expect(atrValues.last, isNotNull);
      expect(atrValues.last! > 0, isTrue);
    });

    test('Williams %R calculates bounded momentum values', () {
      final candles = generateCandles(35);
      final willr = WilliamsRIndicator(period: 14);

      expect(willr.id, equals('WILLR_14'));
      expect(willr.isOverlay, isFalse);

      final result = willr.calculate(candles);
      expect(result.fixedMin, equals(-100.0));
      expect(result.fixedMax, equals(0.0));

      final values = result.series.first.values;
      expect(values.last, isNotNull);
      expect(values.last! >= -100.0 && values.last! <= 0.0, isTrue);
    });

    test('CCI calculates Commodity Channel Index', () {
      final candles = generateCandles(35);
      final cci = CCIIndicator(period: 20);

      expect(cci.id, equals('CCI_20'));
      expect(cci.isOverlay, isFalse);

      final result = cci.calculate(candles);
      expect(result.series.isNotEmpty, isTrue);

      final values = result.series.first.values;
      expect(values.last, isNotNull);
    });

    test('Ichimoku Cloud calculates multi-line trend system', () {
      final candles = generateCandles(60);
      final ichimoku = IchimokuIndicator();

      expect(ichimoku.isOverlay, isTrue);

      final result = ichimoku.calculate(candles);
      expect(result.series.length, equals(4)); // Tenkan, Kijun, Span A, Span B

      final tenkan = result.series.firstWhere((s) => s.id == 'tenkan').values;
      final kijun = result.series.firstWhere((s) => s.id == 'kijun').values;

      expect(tenkan.last, isNotNull);
      expect(kijun.last, isNotNull);
    });
  });

  group('TradingChartController SMC Integration', () {
    test('Toggling SMC calculates concepts on candle update', () async {
      final candles = List.generate(
        30,
        (i) => Candle(
          timestamp: DateTime(2025, 1, 1).add(Duration(minutes: i * 5)),
          open: 100.0 + i,
          high: 105.0 + i,
          low: 98.0 + i,
          close: 102.0 + i,
          volume: 1000.0,
        ),
      );
      final ds = StaticChartDataSource(candles);
      final controller = TradingChartController(
        symbol: 'BTCUSDT',
        dataSource: ds,
      );

      expect(controller.showSMC, isFalse);
      expect(controller.smc, isNull);

      controller.toggleSMC();
      expect(controller.showSMC, isTrue);

      await controller.initialize();
      expect(controller.smc, isNotNull);

      controller.toggleSMC();
      expect(controller.showSMC, isFalse);
      expect(controller.smc, isNull);

      controller.dispose();
      ds.dispose();
    });
  });

  group('SMCRenderer Canvas Painting', () {
    testWidgets('SMCRenderer paints without crashing', (tester) async {
      final theme = ChartTheme.dark();
      final renderer = SMCRenderer(theme);

      final baseTime = DateTime(2025, 1, 1);
      final candles = <Candle>[
        Candle(
          timestamp: baseTime,
          open: 100,
          high: 105,
          low: 99,
          close: 104,
          volume: 1000,
        ),
        Candle(
          timestamp: baseTime.add(const Duration(minutes: 5)),
          open: 105,
          high: 130,
          low: 105,
          close: 128,
          volume: 5000,
        ),
        Candle(
          timestamp: baseTime.add(const Duration(minutes: 10)),
          open: 128,
          high: 132,
          low: 114,
          close: 125,
          volume: 2000,
        ),
      ];

      final smc = SmartMoneyConcepts.calculate(candles);
      const viewport = ChartViewport(
        viewportWidth: 800,
        viewportHeight: 500,
        candleWidth: 10,
        candleSpacing: 2,
      );
      final converter = CoordinateConverter(
        viewport: viewport,
        totalCandles: candles.length,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const bounds = Rect.fromLTWH(0, 0, 800, 500);
      final priceRange = PriceRange(90, 140);

      expect(
        () => renderer.drawSMC(
          canvas: canvas,
          bounds: bounds,
          smc: smc,
          priceRange: priceRange,
          converter: converter,
        ),
        returnsNormally,
      );

      final picture = recorder.endRecording();
      picture.dispose();
    });
  });
}
