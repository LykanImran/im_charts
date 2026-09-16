import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/core/models/chart_save_state.dart';
import 'package:im_charts/core/models/chart_theme.dart';
import 'package:im_charts/core/models/timeframe.dart';
import 'package:im_charts/datasource/mock_data_source.dart';
import 'package:im_charts/engine/chart_controller.dart';
import 'package:im_charts/ui/chart_save_status_badge.dart';

void main() {
  group('Chart Save State & Animation Tests', () {
    test(
        'saveChart updates saveState from saving to saved and invokes callback',
        () async {
      final ds = MockTradingDataSource(initialPrice: 100);
      final controller = TradingChartController(
        symbol: 'TEST',
        dataSource: ds,
        initialTimeframe: Timeframe.fiveMinutes,
        theme: ChartTheme.dark(),
      );

      await controller.initialize();

      expect(controller.saveState, equals(ChartSaveState.saved));

      String? savedPayload;
      controller.onSaveCallback = (payload) async {
        savedPayload = payload;
      };

      final saveFuture = controller.saveChart();
      expect(controller.saveState, equals(ChartSaveState.saving));

      await saveFuture;
      expect(controller.saveState, equals(ChartSaveState.saved));
      expect(savedPayload, isNotNull);

      final map = jsonDecode(savedPayload!) as Map<String, dynamic>;
      expect(map['symbol'], equals('TEST'));
      expect(map['timeframe'], equals('fiveMinutes'));

      controller.dispose();
      ds.dispose();
    });

    test('triggerAutoSave debounces and completes save automatically',
        () async {
      final ds = MockTradingDataSource(initialPrice: 100);
      final controller = TradingChartController(
        symbol: 'TEST',
        dataSource: ds,
        initialTimeframe: Timeframe.fiveMinutes,
        theme: ChartTheme.dark(),
      );

      await controller.initialize();

      int saveCount = 0;
      controller.onSaveCallback = (_) async {
        saveCount++;
      };

      // Trigger multiple rapid auto-saves
      controller.triggerAutoSave();
      controller.triggerAutoSave();
      controller.triggerAutoSave();

      expect(controller.saveState, equals(ChartSaveState.unsaved));

      // Wait for debounce timer (750ms) + completion
      await Future.delayed(const Duration(milliseconds: 900));

      expect(saveCount, equals(1));
      expect(controller.saveState, equals(ChartSaveState.saved));

      controller.dispose();
      ds.dispose();
    });

    testWidgets('ChartSaveStatusBadge renders and handles tap interaction',
        (tester) async {
      final ds = MockTradingDataSource(initialPrice: 100);
      final controller = TradingChartController(
        symbol: 'TEST',
        dataSource: ds,
        initialTimeframe: Timeframe.fiveMinutes,
        theme: ChartTheme.dark(),
      );

      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChartSaveStatusBadge(
                controller: controller,
                isDark: true,
              ),
            ),
          ),
        ),
      );

      // Initially saved
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

      // Tap badge to trigger save
      await tester.tap(find.text('Saved'));
      await tester.pump();

      // State transitions to saving
      expect(controller.saveState, equals(ChartSaveState.saving));
      expect(find.text('Saving...'), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

      // Pump through the simulated save delay
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(controller.saveState, equals(ChartSaveState.saved));
      expect(find.text('Saved'), findsOneWidget);

      controller.dispose();
      ds.dispose();
    });
  });
}
