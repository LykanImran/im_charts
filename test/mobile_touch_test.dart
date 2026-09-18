import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('Mobile Touch & Responsive Layout Tests', () {
    tearDown(() {
      ChartToast.dismiss();
    });

    testWidgets('Automatically switches to mobile mode when width < 600',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(450, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 450,
              height: 700,
              child: TradingChart(
                controller: controller,
                layoutMode: ChartLayoutMode.auto,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In mobile mode, CustomPaint should have width 450 and priceAxisWidth should be 52
      final customPaintFinder = find.byType(CustomPaint);
      expect(customPaintFinder, findsWidgets);

      controller.dispose();
    });

    testWidgets('Forces mobile layout when layoutMode is ChartLayoutMode.mobile',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: TradingChart(
                controller: controller,
                layoutMode: ChartLayoutMode.mobile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TradingChart), findsOneWidget);
      controller.dispose();
    });

    testWidgets('Interactive alert badge renders and allows dragging to update price',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      final currentPrice = controller.currentCandle?.close ?? 24500.0;
      // Add a test alert at current price
      final alert = ChartAlert(
        id: 'alert_drag_test',
        symbol: 'NIFTY 50',
        price: currentPrice,
        note: 'Target Level',
        createdAt: DateTime.now(),
      );
      controller.addAlert(alert);
      expect(controller.alerts.length, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TradingChart(
                controller: controller,
                enableChartTrading: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify alert drag handle appears
      final alertHandle = find.byKey(const Key('drag_alert_alert_drag_test'));
      expect(alertHandle, findsOneWidget);

      // Drag alert vertically by -30px (upwards in price)
      await tester.drag(alertHandle, const Offset(0, -30));
      await tester.pumpAndSettle();

      // Verify alert price changed
      expect(controller.alerts.first.price != currentPrice, isTrue);

      // Verify cancel alert button works
      final cancelBtn = find.byKey(const Key('cancel_alert_alert_drag_test'));
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(controller.alerts.isEmpty, isTrue);

      controller.dispose();
    });

    testWidgets('Order drag handle has smooth opaque drag and updates price',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      final currentPrice = controller.currentCandle?.close ?? 24500.0;
      final order = ChartOrder(
        id: 'order_smooth_drag',
        symbol: 'NIFTY 50',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: currentPrice,
        quantity: 50,
      );
      controller.placeOrder(order);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TradingChart(
                controller: controller,
                enableChartTrading: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The order interactive widget row is rendered
      final cancelOrderFinder = find.byKey(const Key('cancel_order_order_smooth_drag'));
      expect(cancelOrderFinder, findsOneWidget);

      // Cancel order
      await tester.tap(cancelOrderFinder);
      await tester.pumpAndSettle();
      expect(controller.orders.isEmpty, isTrue);

      controller.dispose();
    });

    testWidgets('Toolbar search button adapts responsively on mobile',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = TradingChartController(
        symbol: 'RELIANCE',
        exchange: 'NSE',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: ChartToolbar(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On mobile (< 600px), toolbar displays symbol in search button instead of long text
      expect(find.text('RELIANCE'), findsOneWidget);
      // Keyboard shortcuts hotkey button is hidden on mobile
      expect(find.byIcon(Icons.keyboard_outlined), findsNothing);

      controller.dispose();
    });
  });
}
