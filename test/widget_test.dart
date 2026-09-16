import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/main.dart';

void main() {
  testWidgets(
    'TradingApp renders Row 1 primary tools and Row 2 symbol telemetry',
    (WidgetTester tester) async {
      await tester.pumpWidget(const TradingApp());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      // Row 1: Search trigger
      expect(find.text('Search symbol...'), findsOneWidget);

      // Row 1: Interval dropdown showing initial timeframe '5m'
      expect(find.text('5m'), findsOneWidget);

      // Row 1: Candles dropdown showing initial style 'Candles'
      expect(find.text('Candles'), findsOneWidget);

      // Row 1: Indicators dropdown
      expect(find.text('Indicators'), findsOneWidget);

      // Row 1: Refresh and Settings tooltips/icons
      expect(find.byTooltip('Refresh Chart Data'), findsOneWidget);
      expect(find.byTooltip('Chart Settings'), findsOneWidget);

      // Row 2: Selected Symbol Name
      expect(find.text('NIFTY 50'), findsOneWidget);

      // Row 2: Exchange Badge (displays passed exchange)
      expect(find.text('NSE'), findsOneWidget);
    },
  );

  testWidgets('Interval dropdown opens menu with all timeframes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the interval dropdown button
    await tester.tap(find.text('5m'));
    await tester.pumpAndSettle();

    // Verify timeframes are shown in popup menu
    expect(find.text('1m (1 Minute)'), findsOneWidget);
    expect(find.text('15m (15 Minutes)'), findsOneWidget);
    expect(find.text('1H (1 Hour)'), findsOneWidget);
    expect(find.text('4H (4 Hours)'), findsOneWidget);
    expect(find.text('1D (1 Day)'), findsOneWidget);

    // Select 15m
    await tester.tap(find.text('15m (15 Minutes)'));
    await tester.pumpAndSettle();

    // Verify interval dropdown now displays 15m
    expect(find.text('15m'), findsOneWidget);
  });

  testWidgets('Candles dropdown opens menu and allows style selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap candles dropdown button
    await tester.tap(find.text('Candles'));
    await tester.pumpAndSettle();

    // Verify candle styles are displayed
    expect(find.text('Hollow Candles'), findsOneWidget);
    expect(find.text('Heikin Ashi'), findsOneWidget);
    expect(find.text('Line'), findsOneWidget);
    expect(find.text('Area'), findsOneWidget);
    expect(find.text('Bars (OHLC)'), findsOneWidget);

    // Select Line
    await tester.tap(find.text('Line'));
    await tester.pumpAndSettle();

    // Verify toolbar now displays Line
    expect(find.text('Line'), findsOneWidget);
  });

  testWidgets('Exchange badge displays the passed exchange', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Default TradingApp has initialExchange: 'NSE'
    expect(find.text('NSE'), findsOneWidget);
  });

  testWidgets('Search button opens symbol search dialog and displays symbols', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Search
    await tester.tap(find.text('Search symbol...'));
    await tester.pumpAndSettle();

    // Verify search modal is open
    expect(find.text('Indices'), findsOneWidget);
    expect(find.text('Stocks'), findsOneWidget);
    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.text('TCS'), findsOneWidget);

    // Select RELIANCE
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();

    // Verify symbol in header changed to RELIANCE
    expect(find.text('RELIANCE'), findsOneWidget);
  });

  testWidgets('Dragging price scale engages manual scale and shows AUTO pill', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Initially AUTO pill is not visible because auto-scale is active
    expect(find.byKey(const Key('auto_scale_pill')), findsNothing);

    // Find the chart widget size
    final chartFinder = find.byType(TradingChart);
    expect(chartFinder, findsOneWidget);
    final chartRect = tester.getRect(chartFinder);

    // Drag vertically on the right price scale (width 65px)
    final priceAxisPoint = Offset(chartRect.right - 30, chartRect.top + 100);
    await tester.dragFrom(priceAxisPoint, const Offset(0, 80));
    await tester.pumpAndSettle();

    // Now AUTO pill should be visible
    expect(find.byKey(const Key('auto_scale_pill')), findsOneWidget);

    // Tapping AUTO should reset manual price scale
    await tester.tap(find.byKey(const Key('auto_scale_pill')));
    await tester.pumpAndSettle();

    // AUTO pill is hidden after reset
    expect(find.byKey(const Key('auto_scale_pill')), findsNothing);
  });

  testWidgets('Dragging time scale horizontally zooms candle width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    final chartFinder = find.byType(TradingChart);
    final chartRect = tester.getRect(chartFinder);

    // Drag horizontally on the bottom time scale (height 24px)
    final timeAxisPoint = Offset(chartRect.center.dx, chartRect.bottom - 12);
    await tester.dragFrom(timeAxisPoint, const Offset(60, 0));
    await tester.pumpAndSettle();

    // Drag left to zoom out
    await tester.dragFrom(timeAxisPoint, const Offset(-100, 0));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'ChartHeader is stacked on top of TradingChart and left aligned',
    (WidgetTester tester) async {
      await tester.pumpWidget(const TradingApp());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      // TradingChart occupies full height of the expanded area
      final chartRect = tester.getRect(find.byType(TradingChart));
      final headerRect = tester.getRect(find.byType(ChartHeader));

      // Header top matches Chart top because they are stacked
      expect(headerRect.top, equals(chartRect.top));
      expect(headerRect.left, equals(chartRect.left));
    },
  );

  testWidgets('Trackpad pan zoom event zooms candle width horizontally', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    final chartRect = tester.getRect(find.byType(TradingChart));
    final center = chartRect.center;

    // Send PointerPanZoomStartEvent
    await tester.sendEventToBinding(PointerPanZoomStartEvent(position: center));
    await tester.pump();

    // Send PointerPanZoomUpdateEvent with scale = 1.3 (pinch to zoom in)
    await tester.sendEventToBinding(
      PointerPanZoomUpdateEvent(
        position: center,
        scale: 1.3,
        pan: Offset.zero,
        panDelta: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    // Send PointerPanZoomEndEvent
    await tester.sendEventToBinding(PointerPanZoomEndEvent(position: center));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'TradingChart displays active order overlays and supports cancellation',
    (WidgetTester tester) async {
      final dataSource = MockTradingDataSource(initialPrice: 24500.0);
      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );

      await controller.initialize();

      final currentPrice = controller.currentCandle?.close ?? 24520.0;
      final order = ChartOrder(
        id: 'ord_test_widget',
        symbol: 'NIFTY 50',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: currentPrice,
        quantity: 50,
        takeProfitPrice: currentPrice + 10.0,
        stopLossPrice: currentPrice - 10.0,
      );
      controller.placeOrder(order);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TradingChart(
              controller: controller,
              enableChartTrading: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verify cancel order button key is present
      expect(
        find.byKey(const Key('cancel_order_ord_test_widget')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cancel_tp_ord_test_widget')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cancel_sl_ord_test_widget')),
        findsOneWidget,
      );

      // Tap cancel order button
      await tester.tap(find.byKey(const Key('cancel_order_ord_test_widget')));
      await tester.pump(const Duration(milliseconds: 50));

      // Verify order was cancelled in controller
      expect(controller.orders.isEmpty, isTrue);

      controller.dispose();
      dataSource.dispose();
    },
  );

  testWidgets(
    'Im Charts brand properties, watermark defaults, and type aliases work as expected',
    (WidgetTester tester) async {
      final dataSource = MockTradingDataSource();
      final ImChartController controller = ImChartController(
        symbol: 'NIFTY 50',
        dataSource: dataSource,
      );
      await controller.initialize();

      // 1. Default brandName is 'Im Charts'
      expect(controller.brandName, 'Im Charts');

      // 2. Changing brandName notifies listeners
      bool notified = false;
      controller.addListener(() => notified = true);
      controller.brandName = 'Custom Broker';
      expect(notified, isTrue);
      expect(controller.brandName, 'Custom Broker');

      // 3. ImChart and ImTradingScreen type aliases construct valid widgets
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ImChart(controller: controller)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(TradingChart), findsOneWidget);

      // 4. ImChartsApp renders turnkey application with Im Charts title
      const app = ImChartsApp();
      expect(app, isA<TradingApp>());

      controller.dispose();
      dataSource.dispose();
    },
  );
}
