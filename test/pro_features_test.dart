import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('JSON Serialization & Persistence Tests', () {
    test('DrawingPoint and ChartDrawing toJson and fromJson round-trip', () {
      final point1 = DrawingPoint(
        candleIndex: 12,
        price: 24500.50,
        timestamp: DateTime(2026, 9, 16, 10, 30),
      );
      final point2 = DrawingPoint(
        candleIndex: 25,
        price: 24800.75,
        timestamp: DateTime(2026, 9, 16, 11, 45),
      );

      final drawing = ChartDrawing(
        id: 'ray_101',
        tool: DrawingTool.horizontalRay,
        points: [point1, point2],
        color: const Color(0xFF00E676),
        strokeWidth: 2.5,
        isLocked: true,
        isSelected: false,
        properties: {'note': 'Breakout retest level', 'zone': 1},
      );

      final json = drawing.toJson();
      expect(json['id'], 'ray_101');
      expect(json['tool'], 'horizontalRay');
      expect(json['color'], const Color(0xFF00E676).toARGB32());
      expect(json['strokeWidth'], 2.5);
      expect(json['isLocked'], isTrue);
      expect(json['properties']['zone'], 1);

      final restored = ChartDrawing.fromJson(json);
      expect(restored.id, drawing.id);
      expect(restored.tool, DrawingTool.horizontalRay);
      expect(restored.points.length, 2);
      expect(restored.points[0].candleIndex, 12);
      expect(restored.points[0].price, 24500.50);
      expect(restored.points[0].timestamp, DateTime(2026, 9, 16, 10, 30));
      expect(restored.color, drawing.color);
      expect(restored.strokeWidth, 2.5);
      expect(restored.isLocked, isTrue);
      expect(restored.properties['note'], 'Breakout retest level');
    });

    test('ChartAlert toJson and fromJson round-trip', () {
      final alert = ChartAlert(
        id: 'alt_99',
        symbol: 'BANKNIFTY',
        price: 52400.0,
        note: 'All-time High Crossing',
        condition: AlertTriggerCondition.crossingUp,
        createdAt: DateTime(2026, 9, 16, 9, 15),
        isTriggered: true,
        isActive: false,
        triggeredAt: DateTime(2026, 9, 16, 9, 45),
      );

      final json = alert.toJson();
      expect(json['id'], 'alt_99');
      expect(json['condition'], 'crossingUp');
      expect(json['isTriggered'], isTrue);

      final restored = ChartAlert.fromJson(json);
      expect(restored.id, alert.id);
      expect(restored.symbol, 'BANKNIFTY');
      expect(restored.price, 52400.0);
      expect(restored.condition, AlertTriggerCondition.crossingUp);
      expect(restored.isTriggered, isTrue);
      expect(restored.isActive, isFalse);
    });

    test('ChartOrder toJson and fromJson round-trip', () {
      final order = ChartOrder(
        id: 'ord_55',
        symbol: 'RELIANCE',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: 2950.0,
        quantity: 50.0,
        takeProfitPrice: 3050.0,
        stopLossPrice: 2900.0,
        customLabel: 'Swing Long',
      );

      final json = order.toJson();
      expect(json['id'], 'ord_55');
      expect(json['side'], 'buy');
      expect(json['type'], 'limit');
      expect(json['takeProfitPrice'], 3050.0);

      final restored = ChartOrder.fromJson(json);
      expect(restored.id, 'ord_55');
      expect(restored.side, OrderSide.buy);
      expect(restored.type, OrderType.limit);
      expect(restored.price, 2950.0);
      expect(restored.takeProfitPrice, 3050.0);
      expect(restored.stopLossPrice, 2900.0);
      expect(restored.customLabel, 'Swing Long');
    });
  });

  group('Undo / Redo History Stack Tests', () {
    late TradingChartController controller;
    late MockTradingDataSource dataSource;

    setUp(() {
      dataSource = MockTradingDataSource(initialPrice: 24000.0);
      controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );
    });

    tearDown(() {
      controller.dispose();
      dataSource.dispose();
    });

    test('Undo and redo stack tracks additions, removals, and modifications',
        () {
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);

      final d1 = ChartDrawing(
        id: 'd1',
        tool: DrawingTool.horizontalLine,
        points: [DrawingPoint(candleIndex: 5, price: 24100.0)],
      );
      controller.addDrawing(d1);

      expect(controller.drawings.length, 1);
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);

      final d2 = ChartDrawing(
        id: 'd2',
        tool: DrawingTool.horizontalRay,
        points: [DrawingPoint(candleIndex: 10, price: 24200.0)],
      );
      controller.addDrawing(d2);
      expect(controller.drawings.length, 2);

      // Undo d2
      controller.undo();
      expect(controller.drawings.length, 1);
      expect(controller.drawings.first.id, 'd1');
      expect(controller.canRedo, isTrue);

      // Undo d1
      controller.undo();
      expect(controller.drawings, isEmpty);
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isTrue);

      // Redo d1
      controller.redo();
      expect(controller.drawings.length, 1);
      expect(controller.drawings.first.id, 'd1');

      // Redo d2
      controller.redo();
      expect(controller.drawings.length, 2);
      expect(controller.drawings[1].id, 'd2');
      expect(controller.canRedo, isFalse);
    });

    test(
        'Controller exportDrawingsJson and importDrawingsJson works seamlessly',
        () {
      final d1 = ChartDrawing(
        id: 'exp_1',
        tool: DrawingTool.horizontalRay,
        points: [DrawingPoint(candleIndex: 8, price: 24150.0)],
      );
      controller.addDrawing(d1);

      final exported = controller.exportDrawingsJson();
      expect(exported, contains('exp_1'));
      expect(exported, contains('horizontalRay'));

      controller.clearDrawings();
      expect(controller.drawings, isEmpty);

      controller.importDrawingsJson(exported);
      expect(controller.drawings.length, 1);
      expect(controller.drawings.first.id, 'exp_1');
      expect(controller.drawings.first.tool, DrawingTool.horizontalRay);
    });
  });

  group('Magnet Mode (Snap to OHLC) Tests', () {
    late TradingChartController controller;
    late MockTradingDataSource dataSource;

    setUp(() async {
      dataSource = MockTradingDataSource(initialPrice: 24000.0);
      controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );
      await controller.initialize();
    });

    tearDown(() {
      controller.dispose();
      dataSource.dispose();
    });

    test('Magnet mode toggles properly and defaults to false', () {
      expect(controller.magnetMode, isFalse);
      controller.toggleMagnetMode();
      expect(controller.magnetMode, isTrue);
      controller.setMagnetMode(false);
      expect(controller.magnetMode, isFalse);
    });

    test('snapPointToCandle leaves price unchanged when magnet is OFF', () {
      final raw = DrawingPoint(candleIndex: 5, price: 24002.37);
      final snapped = controller.snapPointToCandle(raw);
      expect(snapped.price, 24002.37);
    });

    test(
        'snapPointToCandle snaps price to closest of Open, High, Low, Close when magnet is ON',
        () {
      controller.setMagnetMode(true);
      final candle = controller.candles[5];

      // Test point very close to candle high
      final nearHigh = DrawingPoint(candleIndex: 5, price: candle.high - 0.15);
      final snappedHigh = controller.snapPointToCandle(nearHigh);
      expect(snappedHigh.price, candle.high);

      // Test point very close to candle low
      final nearLow = DrawingPoint(candleIndex: 5, price: candle.low + 0.10);
      final snappedLow = controller.snapPointToCandle(nearLow);
      expect(snappedLow.price, candle.low);
    });
  });

  group('New Technical Indicators (SMA & Supertrend) Tests', () {
    late List<Candle> sampleCandles;

    setUp(() {
      sampleCandles = List.generate(30, (i) {
        final base = 100.0 + (i * 2.0);
        return Candle(
          timestamp: DateTime(2026, 9, 16, 9, i),
          open: base,
          high: base + 3.0,
          low: base - 2.0,
          close: base + 1.5,
          volume: 1000.0 + (i * 100.0),
        );
      });
    });

    test('SMAIndicator calculates rolling mean accurately', () {
      final sma = SMAIndicator(period: 5);
      final result = sma.calculate(sampleCandles);

      expect(result.series.first.values.length, sampleCandles.length);
      // First 4 candles should be null
      for (int i = 0; i < 4; i++) {
        expect(result.series.first.values[i], isNull);
      }
      // 5th candle (index 4) should be exact mean of first 5 closes
      double sum = 0.0;
      for (int i = 0; i < 5; i++) {
        sum += sampleCandles[i].close;
      }
      expect(result.series.first.values[4], closeTo(sum / 5, 0.001));
    });

    test(
        'SupertrendIndicator calculates ATR bands and trend direction accurately',
        () {
      final supertrend = SupertrendIndicator(period: 10, multiplier: 3.0);
      final result = supertrend.calculate(sampleCandles);

      expect(result.series.length, 4); // supertrend, bull, bear, direction
      final dirSeries =
          result.series.firstWhere((s) => s.id == 'supertrend_dir');

      // Upward trend candles should yield +1.0 bullish direction
      final lastDir = dirSeries.values.last;
      expect(lastDir, 1.0);
    });
  });

  group('CSV Historical Data Exporter Tests', () {
    test('exportCandlesToCsv generates valid RFC 4180 CSV with headers', () {
      final candles = [
        Candle(
          timestamp: DateTime.utc(2026, 9, 16, 9, 15),
          open: 24000.0,
          high: 24050.0,
          low: 23980.0,
          close: 24030.0,
          volume: 15400.0,
        ),
        Candle(
          timestamp: DateTime.utc(2026, 9, 16, 9, 20),
          open: 24030.0,
          high: 24080.0,
          low: 24020.0,
          close: 24065.0,
          volume: 18200.0,
        ),
      ];

      final csv = ChartExporter.exportCandlesToCsv(candles);
      expect(csv, contains('timestamp,open,high,low,close,volume'));
      expect(
          csv,
          contains(
              '2026-09-16T09:15:00.000Z,24000.0000,24050.0000,23980.0000,24030.0000,15400.00'));
      expect(
          csv,
          contains(
              '2026-09-16T09:20:00.000Z,24030.0000,24080.0000,24020.0000,24065.0000,18200.00'));
    });
  });
}
