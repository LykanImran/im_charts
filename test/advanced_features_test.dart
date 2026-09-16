import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('ChartPaneLayout Multi-SubPane Tests', () {
    test('Calculates layout bounds accurately for 0, 1, and 2 sub-panes', () {
      const size = Size(1000, 600);

      // 0 sub-panes
      final layout0 = ChartPaneLayout(totalSize: size, subPanes: 0);
      expect(layout0.hasSubPane, isFalse);
      expect(layout0.subPanesBounds, isEmpty);
      expect(layout0.mainPaneBounds.height, 600 - 24.0); // total - time axis

      // 1 sub-pane (e.g. RSI)
      final layout1 = ChartPaneLayout(totalSize: size, subPanes: 1);
      expect(layout1.hasSubPane, isTrue);
      expect(layout1.subPanesBounds.length, 1);
      expect(layout1.subPaneBounds, isNotNull);
      expect(
        layout1.mainPaneBounds.height + layout1.subPanesBounds[0].height,
        600 - 24.0,
      );

      // 2 stacked sub-panes (e.g. RSI + MACD)
      final layout2 = ChartPaneLayout(totalSize: size, subPanes: 2);
      expect(layout2.hasSubPane, isTrue);
      expect(layout2.subPanesBounds.length, 2);
      expect(layout2.subPanesPriceAxisBounds.length, 2);

      final totalAvailable = 600 - 24.0;
      final expectedSubTotal = totalAvailable * 0.40;
      final perSubHeight = expectedSubTotal / 2;

      expect(layout2.subPanesBounds[0].height, closeTo(perSubHeight, 0.1));
      expect(layout2.subPanesBounds[1].height, closeTo(perSubHeight, 0.1));
      expect(
        layout2.mainPaneBounds.height,
        closeTo(totalAvailable - expectedSubTotal, 0.1),
      );
    });
  });

  group('Bar Replay Simulator Lifecycle Tests', () {
    test('startReplay, stepForward, stepBackward, and exitReplay', () async {
      final dataSource = MockTradingDataSource();
      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );
      await controller.initialize();

      final totalCandles = controller.candles.length;
      expect(totalCandles, greaterThan(40));

      // Start replay at index 20
      controller.startReplay(20);
      expect(controller.isReplayMode, isTrue);
      expect(controller.replayIndex, 20);
      expect(controller.candles.length, 21); // indices 0 to 20

      // Step Forward
      controller.stepReplayForward();
      expect(controller.replayIndex, 21);
      expect(controller.candles.length, 22);

      // Step Backward
      controller.stepReplayBackward();
      expect(controller.replayIndex, 20);
      expect(controller.candles.length, 21);

      // Toggle Play / Pause
      controller.toggleReplayPlay();
      expect(controller.isReplaying, isTrue);
      controller.pauseReplay();
      expect(controller.isReplaying, isFalse);

      // Speed change
      controller.setReplaySpeed(3.0);
      expect(controller.replaySpeed, 3.0);

      // Exit Replay
      controller.exitReplay();
      expect(controller.isReplayMode, isFalse);
      expect(controller.replayIndex, isNull);
      expect(controller.candles.length, totalCandles);

      controller.dispose();
      dataSource.dispose();
    });
  });

  group('ReplayControlBar Widget Tests', () {
    testWidgets('Renders buttons and handles step and play interactions', (
      WidgetTester tester,
    ) async {
      final dataSource = MockTradingDataSource();
      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );
      await controller.initialize();
      controller.startReplay(15);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReplayControlBar(controller: controller)),
        ),
      );
      await tester.pump();

      expect(find.text('REPLAY'), findsOneWidget);

      // Tap Step Forward button
      final forwardBtn = find.byKey(const Key('replay_step_forward'));
      expect(forwardBtn, findsOneWidget);
      await tester.tap(forwardBtn);
      await tester.pump();
      expect(controller.replayIndex, 16);

      // Tap Speed button
      final speedBtn = find.byKey(const Key('replay_speed_button'));
      expect(speedBtn, findsOneWidget);
      await tester.tap(speedBtn);
      await tester.pump();
      expect(controller.replaySpeed, 2.0);

      // Tap Exit button
      final exitBtn = find.byKey(const Key('replay_exit_button'));
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      await tester.pump();
      expect(controller.isReplayMode, isFalse);

      controller.dispose();
      dataSource.dispose();
    });
  });
}
