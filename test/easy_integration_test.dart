import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('StaticChartDataSource Tests', () {
    test('Initializes with candles and serves historical data', () async {
      final now = DateTime.now();
      final candles = List.generate(
        10,
        (i) => Candle(
          timestamp: now.add(Duration(minutes: i * 5)),
          open: 100.0 + i,
          high: 105.0 + i,
          low: 95.0 + i,
          close: 102.0 + i,
          volume: 1000.0 * (i + 1),
        ),
      );

      final dataSource = StaticChartDataSource(candles);
      expect(dataSource.candles.length, 10);

      final historical = await dataSource.getHistoricalData(
        symbol: 'TEST',
        timeframe: Timeframe.fiveMinutes,
        count: 5,
      );
      expect(historical.length, 5);
      expect(historical.last.close, 102.0 + 9);

      // Test appendCandle
      final extraCandle = Candle(
        timestamp: now.add(const Duration(minutes: 50)),
        open: 110,
        high: 115,
        low: 108,
        close: 112,
        volume: 5000,
      );
      dataSource.appendCandle(extraCandle);
      expect(dataSource.candles.length, 11);

      // Test live ticks
      final tickFuture = dataSource.getLiveTicks('TEST').first;
      dataSource.pushPrice(114.5, volume: 25.0);
      final tick = await tickFuture;
      expect(tick.price, 114.5);
      expect(tick.volume, 25.0);

      dataSource.dispose();
    });

    test('fromMapList parses JSON map data cleanly', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final rawList = [
        {
          'timestamp': nowMs,
          'open': 24000.0,
          'high': 24100.0,
          'low': 23950.0,
          'close': 24050.0,
          'volume': 15000.0,
        },
        {
          'timestamp': nowMs + 300000,
          'open': 24050.0,
          'high': 24200.0,
          'low': 24020.0,
          'close': 24180.0,
          'volume': 22000.0,
        },
      ];

      final dataSource = StaticChartDataSource.fromMapList(rawList);
      expect(dataSource.candles.length, 2);
      expect(dataSource.candles.first.open, 24000.0);
      expect(dataSource.candles.last.close, 24180.0);
      dataSource.dispose();
    });
  });

  group('ImChart.simple & ImChart.live Widget Tests', () {
    testWidgets('ImChart.simple renders without manual controller or datasource',
        (tester) async {
      final now = DateTime.now();
      final candles = List.generate(
        20,
        (i) => Candle(
          timestamp: now.add(Duration(minutes: i * 5)),
          open: 500.0 + i,
          high: 510.0 + i,
          low: 490.0 + i,
          close: 505.0 + i,
          volume: 2000.0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ImChart.simple(
                candles: candles,
                symbol: 'BTC/USDT',
                exchange: 'BINANCE',
                indicators: [
                  EMAIndicator(period: 9, color: Colors.blue),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header should display symbol
      expect(find.text('BTC/USDT'), findsOneWidget);
      expect(find.text('BINANCE'), findsOneWidget);
    });

    testWidgets('ImChart.live streams ticks and updates chart', (tester) async {
      final now = DateTime.now();
      final candles = [
        Candle(
          timestamp: now,
          open: 100.0,
          high: 105.0,
          low: 95.0,
          close: 102.0,
          volume: 500.0,
        ),
      ];

      final tickController = StreamController<Tick>.broadcast();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ImChart.live(
                candles: candles,
                liveTickStream: tickController.stream,
                symbol: 'ETH/USDT',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('ETH/USDT'), findsOneWidget);

      // Emit tick
      tickController.add(Tick(
        timestamp: DateTime.now(),
        price: 107.0,
        volume: 100.0,
      ));
      await tester.pump(const Duration(milliseconds: 50));

      await tickController.close();
    });
  });

  group('Interactive On-Chart Order Dragging Tests', () {
    testWidgets(
        'Order vertical drag updates price and triggers onOrderModified',
        (tester) async {
      final now = DateTime.now();
      final candles = List.generate(
        20,
        (i) => Candle(
          timestamp: now.add(Duration(minutes: i * 5)),
          open: 200.0 + i,
          high: 210.0 + i,
          low: 190.0 + i,
          close: 205.0 + i,
          volume: 1000.0,
        ),
      );

      final dataSource = StaticChartDataSource(candles);
      final controller = TradingChartController(
        symbol: 'TEST',
        dataSource: dataSource,
      );
      await controller.initialize();

      final initialOrder = ChartOrder(
        id: 'ord_1',
        symbol: 'TEST',
        side: OrderSide.buy,
        price: 205.0,
        quantity: 10.0,
        takeProfitPrice: 220.0,
        stopLossPrice: 195.0,
      );
      controller.setOrders([initialOrder]);

      ChartOrder? modifiedOrder;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: TradingChart(
                controller: controller,
                enableChartTrading: true,
                onOrderModified: (order) {
                  modifiedOrder = order;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Locate draggable zone on order badge
      final orderDragFinder = find.byTooltip('Drag up/down to adjust limit price');
      expect(orderDragFinder, findsOneWidget);

      // Drag up by 60 pixels to adjust order price
      await tester.drag(orderDragFinder, const Offset(0, -60));
      await tester.pumpAndSettle();

      // onOrderModified should have been fired
      expect(modifiedOrder, isNotNull);
      expect(modifiedOrder!.id, 'ord_1');
      expect(modifiedOrder!.price, isNot(205.0));

      controller.dispose();
      dataSource.dispose();
    });

    testWidgets(
        'TradingScreen accepts initialOrders, initialPositions, and onOrderModified',
        (tester) async {
      final now = DateTime.now();
      final candles = List.generate(
        15,
        (i) => Candle(
          timestamp: now.add(Duration(minutes: i * 5)),
          open: 100.0 + i,
          high: 105.0 + i,
          low: 95.0 + i,
          close: 102.0 + i,
          volume: 1000.0,
        ),
      );

      ChartOrder? modifiedOrder;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: TradingScreen(
                initialSymbol: 'NIFTY',
                initialCandles: candles,
                initialOrders: [
                  ChartOrder(
                    id: 'ord_screen',
                    symbol: 'NIFTY',
                    side: OrderSide.buy,
                    price: 105.0,
                    quantity: 50.0,
                  ),
                ],
                initialPositions: [
                  ChartPosition(
                    id: 'pos_screen',
                    symbol: 'NIFTY',
                    side: PositionSide.long,
                    entryPrice: 102.0,
                    quantity: 25.0,
                    openedAt: now,
                  ),
                ],
                initialShowVolumeProfile: true,
                onOrderModified: (order) {
                  modifiedOrder = order;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Order badge and position badge should be present
      expect(find.byKey(const Key('cancel_order_ord_screen')), findsOneWidget);
      expect(find.byKey(const Key('close_position_pos_screen')), findsOneWidget);

      final orderDrag = find.byTooltip('Drag up/down to adjust limit price');
      await tester.drag(orderDrag, const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(modifiedOrder, isNotNull);
      expect(modifiedOrder!.id, 'ord_screen');
    });
  });
}
