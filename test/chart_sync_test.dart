import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/core/models/chart_theme.dart';
import 'package:im_charts/core/models/timeframe.dart';
import 'package:im_charts/datasource/mock_data_source.dart';
import 'package:im_charts/engine/chart_controller.dart';
import 'package:im_charts/engine/chart_sync_group.dart';

void main() {
  group('ChartSyncGroup Tests', () {
    test('findClosestCandleIndex works correctly for various timestamps', () {
      final t0 = DateTime(2026, 9, 14, 9, 15);
      final timestamps = List.generate(
        10,
        (i) => t0.add(Duration(minutes: i * 5)),
      );

      // Exact matches
      expect(ChartSyncGroup.findClosestCandleIndex(timestamps, t0), equals(0));
      expect(
        ChartSyncGroup.findClosestCandleIndex(
          timestamps,
          t0.add(const Duration(minutes: 20)),
        ),
        equals(4),
      );

      // Left clamp
      expect(
        ChartSyncGroup.findClosestCandleIndex(
          timestamps,
          t0.subtract(const Duration(minutes: 10)),
        ),
        equals(0),
      );

      // Right clamp
      expect(
        ChartSyncGroup.findClosestCandleIndex(
          timestamps,
          t0.add(const Duration(minutes: 100)),
        ),
        equals(9),
      );

      // In-between rounding (e.g. 9:16 is closer to 9:15 than 9:20)
      expect(
        ChartSyncGroup.findClosestCandleIndex(
          timestamps,
          t0.add(const Duration(minutes: 1)),
        ),
        equals(0),
      );
      expect(
        ChartSyncGroup.findClosestCandleIndex(
          timestamps,
          t0.add(const Duration(minutes: 4)),
        ),
        equals(1),
      );
    });

    test('SyncGroup synchronizes crosshairs across controllers', () async {
      final ds1 = MockTradingDataSource(initialPrice: 100);
      final ds2 = MockTradingDataSource(initialPrice: 200);

      final c1 = TradingChartController(
        symbol: 'BTC',
        dataSource: ds1,
        initialTimeframe: Timeframe.fiveMinutes,
        theme: ChartTheme.dark(),
      );
      final c2 = TradingChartController(
        symbol: 'ETH',
        dataSource: ds2,
        initialTimeframe: Timeframe.fiveMinutes,
        theme: ChartTheme.dark(),
      );

      await c1.initialize();
      await c2.initialize();

      c1.updateDimensions(800, 600);
      c2.updateDimensions(800, 600);

      final syncGroup = ChartSyncGroup(syncCrosshair: true);
      syncGroup.register(c1);
      syncGroup.register(c2);

      expect(c1.syncGroup, equals(syncGroup));
      expect(c2.syncGroup, equals(syncGroup));

      // Move pointer in c1
      c1.setCrosshairPosition(const Offset(400, 300));

      // c1 should have crosshair
      expect(c1.crosshairPosition, isNotNull);

      // c2 should also receive synced crosshair matching the timestamp
      expect(c2.crosshairPosition, isNotNull);
      expect(c2.hoveredCandle, isNotNull);

      // Clear crosshair in c1
      c1.setCrosshairPosition(null);
      expect(c1.crosshairPosition, isNull);
      expect(c2.crosshairPosition, isNull);

      c1.dispose();
      c2.dispose();
      ds1.dispose();
      ds2.dispose();
    });

    test('SyncGroup synchronizes horizontal pan and zoom', () async {
      final ds1 = MockTradingDataSource(initialPrice: 100);
      final ds2 = MockTradingDataSource(initialPrice: 200);

      final c1 = TradingChartController(
        symbol: 'BTC',
        dataSource: ds1,
        initialTimeframe: Timeframe.fiveMinutes,
        theme: ChartTheme.dark(),
      );
      final c2 = TradingChartController(
        symbol: 'ETH',
        dataSource: ds2,
        initialTimeframe: Timeframe.fiveMinutes,
        theme: ChartTheme.dark(),
      );

      await c1.initialize();
      await c2.initialize();

      c1.updateDimensions(800, 600);
      c2.updateDimensions(800, 600);

      final syncGroup =
          ChartSyncGroup(syncTimeScroll: true, syncTimeZoom: true);
      syncGroup.register(c1);
      syncGroup.register(c2);

      final initialScroll = c2.viewport.scrollOffset;
      // Pan c1
      c1.onPan(50.0);
      expect(c2.viewport.scrollOffset, equals(initialScroll + 50.0));

      final initialWidth = c2.viewport.candleWidth;
      // Zoom c1
      c1.onZoom(1.5, const Offset(400, 300));
      expect(c2.viewport.candleWidth, greaterThan(initialWidth));

      // Unregister c2
      syncGroup.unregister(c2);
      expect(c2.syncGroup, isNull);

      // Pan again - c2 should not change
      final scrollBefore = c2.viewport.scrollOffset;
      c1.onPan(30.0);
      expect(c2.viewport.scrollOffset, equals(scrollBefore));

      c1.dispose();
      c2.dispose();
      ds1.dispose();
      ds2.dispose();
    });
  });
}
