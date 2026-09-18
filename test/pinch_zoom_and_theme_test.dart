import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('Theme Detection & Toggle Tests', () {
    test('ChartTheme.isDark correctly computes luminance', () {
      final darkTheme = ChartTheme.dark();
      expect(darkTheme.isDark, isTrue);

      final lightTheme = ChartTheme.light();
      expect(lightTheme.isDark, isFalse);

      // Custom black background
      final customDark =
          darkTheme.copyWith(backgroundColor: const Color(0xFF000000));
      expect(customDark.isDark, isTrue);

      // Custom near-white background
      final customLight =
          darkTheme.copyWith(backgroundColor: const Color(0xFFFAFAFA));
      expect(customLight.isDark, isFalse);
    });

    test('TradingChartController.isDarkTheme and toggleTheme work properly',
        () async {
      final controller = TradingChartController(
        symbol: 'TEST',
        exchange: 'TEST',
        dataSource: MockTradingDataSource(),
        theme: ChartTheme.dark(),
      );
      await controller.initialize();

      expect(controller.isDarkTheme, isTrue);

      controller.toggleTheme();
      expect(controller.isDarkTheme, isFalse);
      expect(controller.theme.backgroundColor, const Color(0xFFFFFFFF));

      controller.toggleTheme();
      expect(controller.isDarkTheme, isTrue);
      expect(controller.theme.backgroundColor, const Color(0xFF131722));

      controller.dispose();
    });
  });

  group('Pinch Zoom & Viewport Anchoring Tests', () {
    test(
        'Zooming out at live edge does not introduce negative future whitespace',
        () async {
      final controller = TradingChartController(
        symbol: 'TEST',
        exchange: 'TEST',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      // Ensure at live edge (scrollOffset == 0.0)
      expect(controller.viewport.scrollOffset, 0.0);

      // Apply zoom out (scaleFactor = 0.8) with focalPoint in center of chart
      controller.onZoom(0.8, const Offset(300, 200));

      // Scroll offset should not be negative (-120), it must stay at or above 0.0
      expect(controller.viewport.scrollOffset >= 0.0, isTrue);

      controller.dispose();
    });

    test('Zoom guards against NaN, infinite, and non-positive scale factors',
        () async {
      final controller = TradingChartController(
        symbol: 'TEST',
        exchange: 'TEST',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      final initialWidth = controller.viewport.candleWidth;

      controller.onZoom(double.nan, const Offset(100, 100));
      expect(controller.viewport.candleWidth, initialWidth);

      controller.onZoom(double.infinity, const Offset(100, 100));
      expect(controller.viewport.candleWidth, initialWidth);

      controller.onZoom(0.0, const Offset(100, 100));
      expect(controller.viewport.candleWidth, initialWidth);

      controller.onZoom(-1.5, const Offset(100, 100));
      expect(controller.viewport.candleWidth, initialWidth);

      controller.dispose();
    });

    test('Zoom in increases candle width smoothly clamped within bounds',
        () async {
      final controller = TradingChartController(
        symbol: 'TEST',
        exchange: 'TEST',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      final initialWidth = controller.viewport.candleWidth;
      controller.onZoom(1.25, const Offset(200, 200));

      expect(controller.viewport.candleWidth, greaterThan(initialWidth));
      expect(controller.viewport.candleWidth <= 50.0, isTrue);

      controller.dispose();
    });

    testWidgets(
        'TradingChart widget handles scale gestures without throwing',
        (tester) async {
      final controller = TradingChartController(
        symbol: 'TEST',
        exchange: 'TEST',
        dataSource: MockTradingDataSource(),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: TradingChart(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the widget renders
      expect(find.byType(TradingChart), findsOneWidget);

      // Perform a pinch gesture (scale in)
      final center = tester.getCenter(find.byType(TradingChart));
      final gesture1 =
          await tester.startGesture(center - const Offset(20, 0));
      final gesture2 =
          await tester.startGesture(center + const Offset(20, 0));

      await gesture1.moveBy(const Offset(-30, 0));
      await gesture2.moveBy(const Offset(30, 0));
      await tester.pump();

      // Release first finger, second finger remains briefly (verifies finger lift jump reset)
      await gesture1.up();
      await tester.pump();

      await gesture2.up();
      await tester.pumpAndSettle();

      expect(controller.viewport.candleWidth, isNonNegative);

      controller.dispose();
    });
  });
}
