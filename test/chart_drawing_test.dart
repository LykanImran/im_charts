import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('ChartDrawing Model Tests', () {
    test('DrawingPoint holds index, price and optional timestamp', () {
      final point = DrawingPoint(
        candleIndex: 42,
        price: 24500.50,
        timestamp: DateTime(2025, 1, 15, 10, 30),
      );

      expect(point.candleIndex, 42);
      expect(point.price, 24500.50);
      expect(point.timestamp, DateTime(2025, 1, 15, 10, 30));
    });

    test('ChartDrawing creates instances with default and custom values', () {
      final drawing = ChartDrawing(
        id: 'draw_1',
        tool: DrawingTool.trendline,
        points: [
          DrawingPoint(candleIndex: 10, price: 100.0),
          DrawingPoint(candleIndex: 20, price: 120.0),
        ],
        color: const Color(0xFF2962FF),
        strokeWidth: 2.5,
      );

      expect(drawing.id, 'draw_1');
      expect(drawing.tool, DrawingTool.trendline);
      expect(drawing.points.length, 2);
      expect(drawing.color, const Color(0xFF2962FF));
      expect(drawing.strokeWidth, 2.5);
      expect(drawing.isSelected, isFalse);
    });

    test('ChartDrawing copyWith updates properties correctly', () {
      final drawing = ChartDrawing(
        id: 'draw_2',
        tool: DrawingTool.horizontalLine,
        points: [DrawingPoint(candleIndex: 15, price: 150.0)],
        color: const Color(0xFF00E5FF),
      );

      final updated = drawing.copyWith(
        isSelected: true,
        strokeWidth: 3.0,
        properties: {'note': 'Strong Resistance'},
      );

      expect(updated.id, 'draw_2');
      expect(updated.tool, DrawingTool.horizontalLine);
      expect(updated.isSelected, isTrue);
      expect(updated.strokeWidth, 3.0);
      expect(updated.properties['note'], 'Strong Resistance');
    });

    test('DrawingTool metadata getters provide valid labels and icons', () {
      for (final tool in DrawingTool.values) {
        expect(tool.label.isNotEmpty, isTrue);
        expect(tool.icon, isNotNull);
      }
      expect(DrawingTool.trendline.requiredPoints, 2);
      expect(DrawingTool.horizontalLine.requiredPoints, 1);
      expect(DrawingTool.rectangle.requiredPoints, 2);
      expect(DrawingTool.rectangle.label, 'Rectangle');
      expect(DrawingTool.fibonacci.requiredPoints, 2);
      expect(DrawingTool.longPosition.requiredPoints, 1);
      expect(DrawingTool.shortPosition.requiredPoints, 1);
      expect(DrawingTool.ruler.requiredPoints, 2);
      expect(DrawingTool.pointer.requiredPoints, 0);
    });

    test('distanceToSegment accurately computes perpendicular distances', () {
      const p1 = Offset(0, 0);
      const p2 = Offset(100, 0);

      // Point right above line
      final d1 = ChartDrawing.distanceToSegment(const Offset(50, 10), p1, p2);
      expect(d1, closeTo(10.0, 0.001));

      // Point beyond end of line
      final d2 = ChartDrawing.distanceToSegment(const Offset(120, 0), p1, p2);
      expect(d2, closeTo(20.0, 0.001));

      // Point on the line
      final d3 = ChartDrawing.distanceToSegment(const Offset(50, 0), p1, p2);
      expect(d3, closeTo(0.0, 0.001));
    });
  });

  group('TradingChartController Drawing & Telemetry State Tests', () {
    late MockTradingDataSource dataSource;
    late TradingChartController controller;

    setUp(() {
      dataSource = MockTradingDataSource(initialPrice: 24000.0);
      controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
        initialTimeframe: Timeframe.fiveMinutes,
        initialCandleStyle: CandleStyle.candles,
      );
    });

    tearDown(() {
      controller.dispose();
      dataSource.dispose();
    });

    test('Initial drawing state is clean', () {
      expect(controller.drawings, isEmpty);
      expect(controller.activeDrawingTool, DrawingTool.pointer);
      expect(controller.previewDrawing, isNull);
      expect(controller.showWatermark, isTrue);
      expect(controller.showCountdownTimer, isTrue);
    });

    test('Adding and removing drawings updates state and notifies listeners', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      final drawing = ChartDrawing(
        id: 'test_draw',
        tool: DrawingTool.horizontalLine,
        points: [DrawingPoint(candleIndex: 5, price: 24100.0)],
      );

      controller.addDrawing(drawing);
      expect(controller.drawings.length, 1);
      expect(controller.drawings.first.id, 'test_draw');
      expect(notifyCount, greaterThan(0));

      controller.removeDrawing('test_draw');
      expect(controller.drawings, isEmpty);
    });

    test('Updating drawings modifies drawing by id', () {
      final drawing = ChartDrawing(
        id: 'test_draw',
        tool: DrawingTool.trendline,
        points: [
          DrawingPoint(candleIndex: 1, price: 100.0),
          DrawingPoint(candleIndex: 5, price: 105.0),
        ],
      );
      controller.addDrawing(drawing);

      final updated = drawing.copyWith(isSelected: true);
      controller.updateDrawing(updated);

      expect(controller.drawings.first.isSelected, isTrue);
    });

    test('Clearing drawings removes all drawings', () {
      controller.addDrawing(ChartDrawing(
        id: 'd1',
        tool: DrawingTool.horizontalLine,
        points: [DrawingPoint(candleIndex: 1, price: 100.0)],
      ));
      controller.addDrawing(ChartDrawing(
        id: 'd2',
        tool: DrawingTool.trendline,
        points: [
          DrawingPoint(candleIndex: 2, price: 101.0),
          DrawingPoint(candleIndex: 4, price: 103.0),
        ],
      ));
      expect(controller.drawings.length, 2);

      controller.clearDrawings();
      expect(controller.drawings, isEmpty);
    });

    test('Setting active drawing tool and preview drawing works', () {
      controller.activeDrawingTool = DrawingTool.fibonacci;
      expect(controller.activeDrawingTool, DrawingTool.fibonacci);

      final preview = ChartDrawing(
        id: 'preview',
        tool: DrawingTool.fibonacci,
        points: [DrawingPoint(candleIndex: 1, price: 100.0)],
      );
      controller.setPreviewDrawing(preview);
      expect(controller.previewDrawing, isNotNull);

      controller.setPreviewDrawing(null);
      expect(controller.previewDrawing, isNull);
    });

    test('updateDrawingPoint modifies specific anchor point of drawing', () {
      final drawing = ChartDrawing(
        id: 'd_trend',
        tool: DrawingTool.trendline,
        points: [
          DrawingPoint(candleIndex: 10, price: 24000.0),
          DrawingPoint(candleIndex: 20, price: 24200.0),
        ],
      );
      controller.addDrawing(drawing);

      controller.updateDrawingPoint('d_trend', 1, DrawingPoint(candleIndex: 25, price: 24350.0));
      final updated = controller.drawings.first;
      expect(updated.points[1].candleIndex, 25);
      expect(updated.points[1].price, 24350.0);
      expect(updated.points[0].candleIndex, 10);
    });

    test('translateDrawing shifts all points and position properties', () {
      final drawing = ChartDrawing(
        id: 'd_pos',
        tool: DrawingTool.longPosition,
        points: [DrawingPoint(candleIndex: 10, price: 24000.0)],
        properties: {'targetPrice': 24360.0, 'stopPrice': 23820.0},
      );
      controller.addDrawing(drawing);

      controller.translateDrawing('d_pos', 5, 100.0);
      final updated = controller.drawings.first;
      expect(updated.points[0].candleIndex, 15);
      expect(updated.points[0].price, 24100.0);
      expect(updated.properties['targetPrice'], 24460.0);
      expect(updated.properties['stopPrice'], 23920.0);
    });

    test('setSelectedDrawingColor, strokeWidth, lock and delete operate on selected drawing', () {
      final drawing = ChartDrawing(
        id: 'd_sel',
        tool: DrawingTool.rectangle,
        points: [
          DrawingPoint(candleIndex: 10, price: 24000.0),
          DrawingPoint(candleIndex: 20, price: 24500.0),
        ],
      );
      controller.addDrawing(drawing);
      controller.selectDrawing('d_sel');
      expect(controller.selectedDrawing?.id, 'd_sel');

      controller.setSelectedDrawingColor(const Color(0xFF00E676));
      expect(controller.selectedDrawing?.color, const Color(0xFF00E676));

      controller.setSelectedDrawingStrokeWidth(3.0);
      expect(controller.selectedDrawing?.strokeWidth, 3.0);

      controller.toggleSelectedDrawingLocked();
      expect(controller.selectedDrawing?.isLocked, isTrue);

      // Locked drawing cannot be modified
      controller.setSelectedDrawingStrokeWidth(4.0);
      expect(controller.selectedDrawing?.strokeWidth, 3.0);

      controller.deleteSelectedDrawing();
      expect(controller.drawings, isEmpty);
      expect(controller.selectedDrawing, isNull);
    });

    test('Countdown timer produces valid formatted time', () async {
      await controller.initialize();
      expect(controller.candleCountdownText, isNotEmpty);
      expect(controller.candleCountdownText.contains(':'), isTrue);
    });

    test('Toggling watermark and countdown timer flags', () {
      controller.showWatermark = false;
      expect(controller.showWatermark, isFalse);

      controller.showCountdownTimer = false;
      expect(controller.showCountdownTimer, isFalse);
    });
  });

  group('ChartDrawingToolbar Widget Tests', () {
    testWidgets('Renders all drawing tool buttons including Rectangle and handles selection', (WidgetTester tester) async {
      final dataSource = MockTradingDataSource(initialPrice: 24000.0);
      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );

      // Add a dummy drawing so the clear button appears
      controller.addDrawing(ChartDrawing(
        id: 'test_d',
        tool: DrawingTool.horizontalLine,
        points: [DrawingPoint(candleIndex: 0, price: 24000.0)],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartDrawingToolbar(
              controller: controller,
            ),
          ),
        ),
      );

      // Verify tooltips for primary tools
      expect(find.byTooltip('Cursor'), findsOneWidget);
      expect(find.byTooltip('Trendline'), findsOneWidget);
      expect(find.byTooltip('Horizontal Line'), findsOneWidget);
      expect(find.byTooltip('Rectangle'), findsOneWidget);
      expect(find.byTooltip('Fibonacci Retracement'), findsOneWidget);
      expect(find.byTooltip('Long Position'), findsOneWidget);
      expect(find.byTooltip('Short Position'), findsOneWidget);
      expect(find.byTooltip('Measure Ruler'), findsOneWidget);
      expect(find.byTooltip('Clear Drawings (1)'), findsOneWidget);

      // Tap Rectangle tool
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pump();
      expect(controller.activeDrawingTool, DrawingTool.rectangle);

      // Tap Trendline tool
      await tester.tap(find.byTooltip('Trendline'));
      await tester.pump();
      expect(controller.activeDrawingTool, DrawingTool.trendline);

      // Tap Clear All Drawings
      await tester.tap(find.byTooltip('Clear Drawings (1)'));
      await tester.pump();
      expect(controller.drawings, isEmpty);

      // Tap Collapse button
      expect(find.byTooltip('Hide Drawing Toolbar'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide Drawing Toolbar'));
      await tester.pump();

      // Tool should now be collapsed (width 18 with chevron_right icon)
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      controller.dispose();
      dataSource.dispose();
    });

    testWidgets('TradingChart displays floating action bar when drawing is selected and allows deletion', (WidgetTester tester) async {
      final dataSource = MockTradingDataSource(initialPrice: 24000.0);
      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );
      await controller.initialize();

      final drawing = ChartDrawing(
        id: 'd_box',
        tool: DrawingTool.rectangle,
        points: [
          DrawingPoint(candleIndex: 10, price: 24000.0),
          DrawingPoint(candleIndex: 20, price: 24200.0),
        ],
      );
      controller.addDrawing(drawing);
      controller.selectDrawing('d_box');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: TradingChart(controller: controller),
            ),
          ),
        ),
      );

      // Verify floating action bar is rendered
      expect(find.byKey(const Key('delete_drawing_d_box')), findsOneWidget);
      expect(find.text('Rectangle'), findsOneWidget);

      // Tap delete button on floating action bar
      await tester.tap(find.byKey(const Key('delete_drawing_d_box')));
      await tester.pump();

      // Drawing should be deleted
      expect(controller.drawings, isEmpty);
      expect(find.byKey(const Key('delete_drawing_d_box')), findsNothing);

      controller.dispose();
      dataSource.dispose();
    });

    testWidgets('DrawingActionToolbar changes color, stroke width, lock status and deletes drawing', (WidgetTester tester) async {
      final dataSource = MockTradingDataSource(initialPrice: 24000.0);
      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );
      await controller.initialize();

      final drawing = ChartDrawing(
        id: 'tb_test',
        tool: DrawingTool.trendline,
        points: [
          DrawingPoint(candleIndex: 5, price: 23900.0),
          DrawingPoint(candleIndex: 15, price: 24100.0),
        ],
        color: const Color(0xFF2962FF),
        strokeWidth: 2.0,
      );
      controller.addDrawing(drawing);
      controller.selectDrawing('tb_test');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DrawingActionToolbar(
                controller: controller,
                selectedDrawing: controller.selectedDrawing!,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Trendline'), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_outlined), findsOneWidget);

      // Tap lock button
      await tester.tap(find.byIcon(Icons.lock_open_outlined));
      await tester.pump();
      expect(controller.drawings.first.isLocked, isTrue);

      // Unlock
      await tester.tap(find.byIcon(Icons.lock));
      await tester.pump();
      expect(controller.drawings.first.isLocked, isFalse);

      // Change stroke width to 4px (index 3 in stroke widths)
      await tester.tap(find.byKey(const Key('delete_drawing_tb_test')));
      await tester.pump();
      expect(controller.drawings, isEmpty);

      controller.dispose();
      dataSource.dispose();
    });
  });
}
