import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

/// Interactive Drawing Tools & Real-Time Telemetry Showcase:
/// Demonstrates institutional TradingView-style analysis & chart visuals:
/// - Left-docked drawing toolbar (Trendline, Horizontal Ray, Fibonacci Retracement, Long/Short Position R:R Box, Ruler)
/// - Live ticking candle close countdown timer badge on the vertical price scale
/// - Background canvas watermark with large bold symbol & timeframe typography
/// - Current price radiant pulse beacon dot.
class DrawingToolsDemoScreen extends StatefulWidget {
  const DrawingToolsDemoScreen({super.key});

  @override
  State<DrawingToolsDemoScreen> createState() => _DrawingToolsDemoScreenState();
}

class _DrawingToolsDemoScreenState extends State<DrawingToolsDemoScreen> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(
      initialPrice: 24520.0,
      volatility: 0.0015,
    );
    _controller = TradingChartController(
      symbol: 'NIFTY 50',
      exchange: 'NSE',
      dataSource: _dataSource,
      initialTimeframe: Timeframe.fiveMinutes,
      initialCandleStyle: CandleStyle.candles,
      theme: ChartTheme.dark(),
    );

    _controller.initialize().then((_) {
      if (!mounted) return;
      _seedSampleDrawings();
    });
  }

  void _seedSampleDrawings() {
    final candles = _controller.candles;
    if (candles.length < 50) return;

    final lastIndex = candles.length - 1;
    final currentPrice = candles.last.close;

    // 1. Ascending Trendline
    final trendline = ChartDrawing(
      id: 'draw_sample_trendline',
      tool: DrawingTool.trendline,
      points: [
        DrawingPoint(candleIndex: lastIndex - 35, price: currentPrice * 0.994),
        DrawingPoint(candleIndex: lastIndex - 5, price: currentPrice * 0.999),
      ],
      color: const Color(0xFF2962FF),
      strokeWidth: 2.0,
    );

    // 2. Horizontal Resistance Level
    final horizontalLine = ChartDrawing(
      id: 'draw_sample_horizontal',
      tool: DrawingTool.horizontalLine,
      points: [
        DrawingPoint(
          candleIndex: lastIndex - 10,
          price: double.parse((currentPrice * 1.004).toStringAsFixed(2)),
        ),
      ],
      color: const Color(0xFF00E5FF),
      strokeWidth: 1.5,
    );

    // 3. Long Position (Risk:Reward Box)
    final longPosition = ChartDrawing(
      id: 'draw_sample_long_pos',
      tool: DrawingTool.longPosition,
      points: [
        DrawingPoint(
          candleIndex: lastIndex - 25,
          price: double.parse((currentPrice * 0.998).toStringAsFixed(2)),
        ),
      ],
      properties: {
        'targetPrice': double.parse((currentPrice * 1.012).toStringAsFixed(2)),
        'stopPrice': double.parse((currentPrice * 0.992).toStringAsFixed(2)),
      },
    );

    _controller.addDrawing(trendline);
    _controller.addDrawing(horizontalLine);
    _controller.addDrawing(longPosition);
  }

  @override
  void dispose() {
    _controller.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  void _addSampleFibonacci() {
    final candles = _controller.candles;
    if (candles.length < 40) return;

    final lastIndex = candles.length - 1;
    final currentPrice = candles.last.close;

    final fib = ChartDrawing(
      id: 'draw_fib_${DateTime.now().millisecondsSinceEpoch}',
      tool: DrawingTool.fibonacci,
      points: [
        DrawingPoint(candleIndex: lastIndex - 40, price: currentPrice * 0.988),
        DrawingPoint(candleIndex: lastIndex - 12, price: currentPrice * 1.008),
      ],
    );

    _controller.addDrawing(fib);
    _showFeedback('Fibonacci Retracement Added', const Color(0xFF00E676));
  }

  void _showFeedback(String message, Color color) {
    if (!mounted) return;
    ChartToast.show(context, message: message, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      body: SafeArea(
        child: Column(
          children: [
            // Top Quick Controls Header
            _buildInteractiveHeader(),

            // Main Terminal with Left Drawing Toolbar & Watermark
            Expanded(
              child: TradingScreen(
                controller: _controller,
                showToolbar: true,
                showHeader: true,
                showDrawingToolbar: true,
                showWatermark: true,
                showCountdownTimer: true,
                enableChartTrading: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveHeader() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF131722),
            border: Border(
              bottom: BorderSide(color: Color(0xFF2A2E39), width: 1),
            ),
          ),
          child: Row(
            children: [
              // Mode Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2962FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2962FF), width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.brush_outlined,
                      size: 13,
                      color: Color(0xFF2962FF),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'DRAWING TOOLS & TELEMETRY LAB',
                      style: TextStyle(
                        color: Color(0xFF2962FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Active Tool Feedback Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222D),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2A2E39), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _controller.activeDrawingTool.icon,
                      size: 12,
                      color: const Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tool: ${_controller.activeDrawingTool.label}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Quick Action Buttons
              _buildHeaderButton(
                label: '+ Add Fib',
                color: const Color(0xFF00E676),
                onTap: _addSampleFibonacci,
              ),
              const SizedBox(width: 6),
              _buildHeaderButton(
                label: 'Reset Drawings',
                color: const Color(0xFF868993),
                onTap: () {
                  _controller.clearDrawings();
                  _seedSampleDrawings();
                },
              ),
              const SizedBox(width: 6),

              // Watermark Toggle
              IconButton(
                tooltip: _controller.showWatermark
                    ? 'Hide Watermark'
                    : 'Show Watermark',
                icon: Icon(
                  Icons.branding_watermark_outlined,
                  size: 16,
                  color: _controller.showWatermark
                      ? const Color(0xFF2962FF)
                      : const Color(0xFF868993),
                ),
                onPressed: () =>
                    _controller.showWatermark = !_controller.showWatermark,
              ),

              // Countdown Timer Toggle
              IconButton(
                tooltip: _controller.showCountdownTimer
                    ? 'Hide Countdown Timer'
                    : 'Show Countdown Timer',
                icon: Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: _controller.showCountdownTimer
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFF868993),
                ),
                onPressed: () => _controller.showCountdownTimer =
                    !_controller.showCountdownTimer,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
