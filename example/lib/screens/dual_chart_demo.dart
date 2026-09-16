import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

/// Dual Multi-Chart Grid Demo:
/// Demonstrates running two independent live charting engines simultaneously
/// (e.g. NIFTY 50 5m on Left vs BANKNIFTY 15m on Right) with zero frame drops.
class DualChartDemoScreen extends StatefulWidget {
  const DualChartDemoScreen({super.key});

  @override
  State<DualChartDemoScreen> createState() => _DualChartDemoScreenState();
}

class _DualChartDemoScreenState extends State<DualChartDemoScreen> {
  late final MockTradingDataSource _dataSource1;
  late final MockTradingDataSource _dataSource2;
  late final TradingChartController _controller1;
  late final TradingChartController _controller2;

  @override
  void initState() {
    super.initState();
    // Chart 1: NIFTY 50 (5m)
    _dataSource1 = MockTradingDataSource(
      initialPrice: 24520.0,
      volatility: 0.0018,
    );
    _controller1 = TradingChartController(
      symbol: 'NIFTY 50',
      exchange: 'NSE',
      dataSource: _dataSource1,
      initialTimeframe: Timeframe.fiveMinutes,
      theme: ChartTheme.dark(),
    );
    _controller1.initialize().then((_) {
      if (mounted) {
        _controller1.toggleIndicator(
          EMAIndicator(period: 20, color: const Color(0xFF2962FF)),
        );
      }
    });

    // Chart 2: BANKNIFTY (15m) with RSI sub-pane
    _dataSource2 = MockTradingDataSource(
      initialPrice: 51240.0,
      volatility: 0.0022,
    );
    _controller2 = TradingChartController(
      symbol: 'BANKNIFTY',
      exchange: 'NSE',
      dataSource: _dataSource2,
      initialTimeframe: Timeframe.fifteenMinutes,
      theme: ChartTheme.dark(),
    );
    _controller2.initialize().then((_) {
      if (mounted) {
        _controller2.toggleIndicator(RSIIndicator(period: 14));
      }
    });
  }

  @override
  void dispose() {
    _controller1.dispose();
    _dataSource1.dispose();
    _controller2.dispose();
    _dataSource2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1117),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            final chart1Widget = _buildChartPane(
              title: 'NIFTY 50 • 5m (Intraday Trend)',
              controller: _controller1,
            );

            final chart2Widget = _buildChartPane(
              title: 'BANKNIFTY • 15m (RSI Momentum)',
              controller: _controller2,
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: chart1Widget),
                  Container(width: 2, color: const Color(0xFF2A2E39)),
                  Expanded(child: chart2Widget),
                ],
              );
            } else {
              return Column(
                children: [
                  Expanded(child: chart1Widget),
                  Container(height: 2, color: const Color(0xFF2A2E39)),
                  Expanded(child: chart2Widget),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildChartPane({
    required String title,
    required TradingChartController controller,
  }) {
    return Column(
      children: [
        // Mini Pane Header
        Container(
          height: 34,
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
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 14,
                  color: Color(0xFF868993),
                ),
                tooltip: 'Reset Viewport',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: controller.resetView,
              ),
            ],
          ),
        ),

        // Embedded Canvas Chart
        Expanded(child: TradingChart(controller: controller)),
      ],
    );
  }
}
