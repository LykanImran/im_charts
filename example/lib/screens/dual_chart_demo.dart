import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

/// Multi-Chart Grid & PineScript Formula Demo:
/// Demonstrates synchronized 1x1, 1x2, 2x1, and 2x2 grid charting engines
/// (e.g. NIFTY 50, BANKNIFTY, RELIANCE, TCS) with linked crosshairs,
/// synchronized time scrolling & zoom, and dynamic PineScript indicators.
class DualChartDemoScreen extends StatefulWidget {
  const DualChartDemoScreen({super.key});

  @override
  State<DualChartDemoScreen> createState() => _DualChartDemoScreenState();
}

class _DualChartDemoScreenState extends State<DualChartDemoScreen> {
  final List<MockTradingDataSource> _dataSources = [];
  final List<TradingChartController> _controllers = [];
  late final ChartSyncGroup _syncGroup;

  @override
  void initState() {
    super.initState();
    _syncGroup = ChartSyncGroup(
      syncCrosshair: true,
      syncTimeScroll: true,
      syncTimeZoom: true,
    );

    // Chart 1: NIFTY 50 (5m)
    final ds1 = MockTradingDataSource(
      initialPrice: 24520.0,
      volatility: 0.0018,
    );
    final c1 = TradingChartController(
      symbol: 'NIFTY 50',
      exchange: 'NSE',
      dataSource: ds1,
      initialTimeframe: Timeframe.fiveMinutes,
      theme: ChartTheme.dark(),
    );

    // Chart 2: BANKNIFTY (15m) with RSI
    final ds2 = MockTradingDataSource(
      initialPrice: 51240.0,
      volatility: 0.0022,
    );
    final c2 = TradingChartController(
      symbol: 'BANKNIFTY',
      exchange: 'NSE',
      dataSource: ds2,
      initialTimeframe: Timeframe.fifteenMinutes,
      theme: ChartTheme.dark(),
    );

    // Chart 3: RELIANCE (1h) with Custom Pine Formula
    final ds3 = MockTradingDataSource(initialPrice: 2980.0, volatility: 0.0025);
    final c3 = TradingChartController(
      symbol: 'RELIANCE',
      exchange: 'NSE',
      dataSource: ds3,
      initialTimeframe: Timeframe.oneHour,
      theme: ChartTheme.dark(),
    );

    // Chart 4: TCS (1d) with Supertrend
    final ds4 = MockTradingDataSource(initialPrice: 4230.0, volatility: 0.0020);
    final c4 = TradingChartController(
      symbol: 'TCS',
      exchange: 'NSE',
      dataSource: ds4,
      initialTimeframe: Timeframe.oneDay,
      theme: ChartTheme.dark(),
    );

    _dataSources.addAll([ds1, ds2, ds3, ds4]);
    _controllers.addAll([c1, c2, c3, c4]);

    // Initialize all controllers
    c1.initialize().then((_) {
      if (mounted) {
        c1.toggleIndicator(
          EMAIndicator(period: 20, color: const Color(0xFF2962FF)),
        );
      }
    });

    c2.initialize().then((_) {
      if (mounted) {
        c2.toggleIndicator(RSIIndicator(period: 14));
      }
    });

    c3.initialize().then((_) {
      if (mounted) {
        // Add a PineScript-like formula indicator dynamically!
        c3.toggleIndicator(
          FormulaIndicator(
            name: 'Pine Volatility Band',
            formula: 'sma(close, 20) + 2.0 * stdev(close, 20)',
            defaultColor: const Color(0xFF00E5FF),
          ),
        );
      }
    });

    c4.initialize().then((_) {
      if (mounted) {
        c4.toggleSupertrend(period: 10, multiplier: 3.0);
      }
    });
  }

  @override
  void dispose() {
    _syncGroup.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final ds in _dataSources) {
      ds.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      body: SafeArea(
        child: MultiChartContainer(
          controllers: _controllers,
          syncGroup: _syncGroup,
          initialLayout: MultiChartLayoutMode.splitHorizontal,
          chartBuilder: (context, index, controller) {
            return Column(
              children: [
                // Mini Pane Header
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  color: const Color(0xFF161A25),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${controller.symbol} • ${controller.timeframe.shortLabel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.auto_graph_rounded,
                          size: 14,
                          color: Color(0xFF00E5FF),
                        ),
                        tooltip: 'Add Pine Formula',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        onPressed: () => FormulaEditorModal.show(
                          context,
                          controller: controller,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          size: 14,
                          color: Color(0xFF868993),
                        ),
                        tooltip: 'Reset Viewport',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        onPressed: controller.resetView,
                      ),
                    ],
                  ),
                ),

                // Embedded Chart
                Expanded(child: TradingChart(controller: controller)),
              ],
            );
          },
        ),
      ),
    );
  }
}
