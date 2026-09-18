import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('ChartPosition Model Tests', () {
    test(
      'Calculates unrealized P&L and percentage accurately for Long positions',
      () {
        final pos = ChartPosition(
          id: 'pos_1',
          symbol: 'NIFTY 50',
          side: PositionSide.long,
          entryPrice: 24000.0,
          quantity: 100,
          takeProfitPrice: 24240.0, // +1.0%
          stopLossPrice: 23880.0, // -0.5%
          openedAt: DateTime(2026, 9, 14, 10, 0),
        );

        expect(pos.isLong, isTrue);
        expect(pos.isShort, isFalse);
        expect(pos.hasTakeProfit, isTrue);
        expect(pos.hasStopLoss, isTrue);

        // Current price = 24100 (+100 profit per unit -> +10,000 total)
        expect(pos.unrealizedPnL(24100.0), closeTo(10000.0, 0.001));
        expect(pos.unrealizedPnLPercentage(24100.0), closeTo(0.4166, 0.01));

        // Current price = 23900 (-100 loss per unit -> -10,000 total)
        expect(pos.unrealizedPnL(23900.0), closeTo(-10000.0, 0.001));

        // Brackets
        expect(pos.takeProfitPercentage, closeTo(1.0, 0.001));
        expect(pos.stopLossPercentage, closeTo(-0.5, 0.001));
      },
    );

    test(
      'Calculates unrealized P&L and percentage accurately for Short positions',
      () {
        final pos = ChartPosition(
          id: 'pos_2',
          symbol: 'BANKNIFTY',
          side: PositionSide.short,
          entryPrice: 50000.0,
          quantity: 20,
          takeProfitPrice: 49000.0, // +2.0% profit for short
          stopLossPrice: 50500.0, // -1.0% loss for short
          openedAt: DateTime(2026, 9, 14, 11, 0),
        );

        expect(pos.isLong, isFalse);
        expect(pos.isShort, isTrue);

        // Price drops to 49500 (+500 profit per unit -> +10,000 total)
        expect(pos.unrealizedPnL(49500.0), closeTo(10000.0, 0.001));
        expect(pos.unrealizedPnLPercentage(49500.0), closeTo(1.0, 0.001));

        // Price rises to 50200 (-200 loss per unit -> -4,000 total)
        expect(pos.unrealizedPnL(50200.0), closeTo(-4000.0, 0.001));

        // Brackets for short
        expect(pos.takeProfitPercentage, closeTo(2.0, 0.001));
        expect(pos.stopLossPercentage, closeTo(-1.0, 0.001));
      },
    );

    test('copyWith updates properties and allows clearing brackets', () {
      final pos = ChartPosition(
        id: 'pos_3',
        symbol: 'TCS',
        side: PositionSide.long,
        entryPrice: 3500.0,
        takeProfitPrice: 3600.0,
        openedAt: DateTime.now(),
      );

      final updated = pos.copyWith(quantity: 50, takeProfitPrice: () => null);

      expect(updated.quantity, 50);
      expect(updated.takeProfitPrice, isNull);
      expect(updated.entryPrice, 3500.0);
    });
  });

  group('TradingChartController Position Lifecycle Tests', () {
    late MockTradingDataSource dataSource;
    late TradingChartController controller;

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

    test('Initial positions list is empty', () {
      expect(controller.positions, isEmpty);
    });

    test(
      'openPosition adds position and triggers notification and callback',
      () {
        ChartPosition? opened;
        controller.onPositionOpened = (p) => opened = p;

        final pos = ChartPosition(
          id: 'pos_test',
          symbol: 'NIFTY 50',
          side: PositionSide.long,
          entryPrice: 24000.0,
          quantity: 50,
          openedAt: DateTime.now(),
        );

        controller.openPosition(pos);
        expect(controller.positions.length, 1);
        expect(controller.positions.first.id, 'pos_test');
        expect(opened?.id, 'pos_test');
      },
    );

    test('updatePosition modifies existing position', () {
      final pos = ChartPosition(
        id: 'pos_update',
        symbol: 'NIFTY 50',
        side: PositionSide.long,
        entryPrice: 24000.0,
        quantity: 10,
        openedAt: DateTime.now(),
      );
      controller.openPosition(pos);

      controller.updatePosition(pos.copyWith(quantity: 25));
      expect(controller.positions.first.quantity, 25);
    });

    test('closePosition removes position and triggers callback', () {
      ChartPosition? closed;
      controller.onPositionClosed = (p) => closed = p;

      final pos = ChartPosition(
        id: 'pos_close',
        symbol: 'NIFTY 50',
        side: PositionSide.short,
        entryPrice: 24100.0,
        openedAt: DateTime.now(),
      );
      controller.openPosition(pos);
      expect(controller.positions.length, 1);

      controller.closePosition('pos_close');
      expect(controller.positions, isEmpty);
      expect(closed?.id, 'pos_close');
    });

    test('clearPositions removes all open positions', () {
      controller.openPosition(
        ChartPosition(
          id: 'p1',
          symbol: 'NIFTY 50',
          side: PositionSide.long,
          entryPrice: 24000.0,
          openedAt: DateTime.now(),
        ),
      );
      controller.openPosition(
        ChartPosition(
          id: 'p2',
          symbol: 'NIFTY 50',
          side: PositionSide.short,
          entryPrice: 24100.0,
          openedAt: DateTime.now(),
        ),
      );
      expect(controller.positions.length, 2);

      controller.clearPositions();
      expect(controller.positions, isEmpty);
    });
  });

  group('TradingChart Position Overlay Widget Tests', () {
    testWidgets('Renders position close button and tapping closes position', (
      WidgetTester tester,
    ) async {
      final dataSource = MockTradingDataSource(initialPrice: 24000.0);
      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );
      await controller.initialize();

      ChartPosition? closedCallbackPosition;
      final currentPrice = controller.currentCandle?.close ?? 24520.0;

      final position = ChartPosition(
        id: 'pos_widget_test',
        symbol: 'NIFTY 50',
        side: PositionSide.long,
        entryPrice: currentPrice,
        quantity: 100,
        openedAt: DateTime.now(),
      );
      controller.openPosition(position);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TradingChart(
                controller: controller,
                enableChartTrading: true,
                onPositionClosed: (pos) => closedCallbackPosition = pos,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Verify Close Position button appears
      final closeKey = find.byKey(const Key('close_position_pos_widget_test'));
      expect(closeKey, findsOneWidget);

      // Tap Close button
      await tester.tap(closeKey);
      await tester.pump(const Duration(seconds: 3));

      // Verify position was closed in controller and callback invoked
      expect(controller.positions, isEmpty);
      expect(closedCallbackPosition?.id, 'pos_widget_test');

      controller.dispose();
      dataSource.dispose();
    });
  });
}
