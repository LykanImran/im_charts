import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('Context Menu & Controller Removal Tests', () {
    tearDown(() {
      ChartToast.dismiss();
    });

    test('clearIndicators removes all active indicators and updates state',
        () async {
      final controller = TradingChartController(
        symbol: 'TEST',
        exchange: 'TEST',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      // Add 2 indicators
      controller.toggleSma(20);
      controller.toggleIndicator(RSIIndicator(period: 14));

      expect(controller.activeIndicators.length, 2);
      expect(controller.overlayResults.isNotEmpty, isTrue);
      expect(controller.subPaneResults.isNotEmpty, isTrue);

      bool notified = false;
      controller.addListener(() => notified = true);

      // Call clearIndicators
      controller.clearIndicators();

      expect(controller.activeIndicators.isEmpty, isTrue);
      expect(controller.overlayResults.isEmpty, isTrue);
      expect(controller.subPaneResults.isEmpty, isTrue);
      expect(controller.subPaneResult, isNull);
      expect(notified, isTrue);

      controller.dispose();
    });

    test('resetView resets candleWidth, scrollOffset, verticalScale and pan',
        () async {
      final controller = TradingChartController(
        symbol: 'TEST',
        exchange: 'TEST',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      // Modify view state
      controller.onZoom(1.5, const Offset(200, 200));
      controller.onPan(100.0);
      controller.onVerticalScale(50.0);

      expect(
        controller.viewport.candleWidth != 8.0 ||
            controller.viewport.scrollOffset != 0.0 ||
            controller.verticalScale != 1.0,
        isTrue,
      );

      // Call resetView
      controller.resetView();

      expect(controller.viewport.candleWidth, 8.0);
      expect(controller.viewport.scrollOffset, 0.0);
      expect(controller.verticalScale, 1.0);
      expect(controller.verticalPan, 0.0);
      expect(controller.crosshairPosition, isNull);

      controller.dispose();
    });

    testWidgets('Secondary tap on TradingChart displays custom context menu',
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

      // Add indicator and drawing
      controller.toggleSma(20);
      final drawing = ChartDrawing(
        id: 'draw_test_1',
        tool: DrawingTool.horizontalLine,
        points: [const DrawingPoint(candleIndex: 5, price: 100.0)],
      );
      controller.addDrawing(drawing);

      expect(controller.activeIndicators.length, 1);
      expect(controller.drawings.length, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: TradingChart(
                controller: controller,
                enableContextMenu: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Right-click / secondary tap on the chart canvas
      final center = tester.getCenter(find.byType(TradingChart));
      await tester.tapAt(center, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Verify context menu items are present
      expect(find.text('Reset Chart View'), findsOneWidget);
      expect(find.text('Remove Indicators (1)'), findsOneWidget);
      expect(find.text('Remove Drawings (1)'), findsOneWidget);
      expect(find.textContaining('Add Alert at ₹'), findsOneWidget);
      expect(find.textContaining('Buy 100 Limit @ ₹'), findsOneWidget);
      expect(find.textContaining('Sell 100 Limit @ ₹'), findsOneWidget);

      // Tap "Reset Chart View"
      await tester.tap(find.text('Reset Chart View'));
      await tester.pumpAndSettle();

      expect(controller.viewport.candleWidth, 8.0);
      expect(controller.viewport.scrollOffset, 0.0);

      await tester.pump(const Duration(seconds: 3));
      controller.dispose();
    });

    testWidgets(
        'Tapping Remove Indicators in context menu clears all indicators',
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

      controller.toggleSma(20);
      expect(controller.activeIndicators.isNotEmpty, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: TradingChart(
                controller: controller,
                enableContextMenu: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Secondary click
      final center = tester.getCenter(find.byType(TradingChart));
      await tester.tapAt(center, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Tap Remove Indicators
      await tester.tap(find.text('Remove Indicators (1)'));
      await tester.pumpAndSettle();

      expect(controller.activeIndicators.isEmpty, isTrue);

      await tester.pump(const Duration(seconds: 3));
      controller.dispose();
    });

    testWidgets('Tapping Remove Drawings in context menu clears all drawings',
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

      controller.addDrawing(
        ChartDrawing(
          id: 'test_drawing',
          tool: DrawingTool.horizontalLine,
          points: [const DrawingPoint(candleIndex: 2, price: 150.0)],
        ),
      );
      expect(controller.drawings.isNotEmpty, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: TradingChart(
                controller: controller,
                enableContextMenu: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Secondary click
      final center = tester.getCenter(find.byType(TradingChart));
      await tester.tapAt(center, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Tap Remove Drawings
      await tester.tap(find.text('Remove Drawings (1)'));
      await tester.pumpAndSettle();

      expect(controller.drawings.isEmpty, isTrue);

      await tester.pump(const Duration(seconds: 3));
      controller.dispose();
    });

    testWidgets(
        'enableContextMenu: false disables context menu on secondary tap',
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
              width: 1000,
              height: 600,
              child: TradingChart(
                controller: controller,
                enableContextMenu: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Secondary click
      final center = tester.getCenter(find.byType(TradingChart));
      await tester.tapAt(center, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Verify no context menu item appeared
      expect(find.text('Reset Chart View'), findsNothing);

      controller.dispose();
    });
  });
}
