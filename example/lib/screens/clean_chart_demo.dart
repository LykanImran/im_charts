import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

/// Clean / Minimalist Chart Mode (Headless):
/// A version of the chart where the top toolbar and heavy header are completely removed,
/// maximizing canvas space for embedding or minimalist broker applications.
class CleanChartDemoScreen extends StatefulWidget {
  const CleanChartDemoScreen({super.key});

  @override
  State<CleanChartDemoScreen> createState() => _CleanChartDemoScreenState();
}

class _CleanChartDemoScreenState extends State<CleanChartDemoScreen> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(initialPrice: 24520.0, volatility: 0.0018);
    _controller = TradingChartController(
      symbol: 'NIFTY 50',
      exchange: 'NSE',
      dataSource: _dataSource,
      initialTimeframe: Timeframe.fiveMinutes,
      initialCandleStyle: CandleStyle.candles,
      theme: ChartTheme.dark(),
    );

    _controller.initialize().then((_) {
      if (mounted) {
        _controller.toggleIndicator(
          EMAIndicator(period: 20, color: const Color(0xFF2962FF)),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. PURE STANDALONE CANVAS (100% full screen, no top toolbar or header)
            Positioned.fill(
              child: TradingChart(controller: _controller),
            ),

            // 2. Minimalist Floating Ticker & Timeframe Pill (Top-Left overlay)
            Positioned(
              top: 12,
              left: 12,
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final latest = _controller.currentCandle;
                  final isBullish = latest?.isBullish ?? true;
                  final color = isBullish ? const Color(0xFF089981) : const Color(0xFFF23645);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xDD1E222D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2A2E39), width: 1),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Live pulse
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E676),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'NIFTY 50',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CLEAN CANVAS MODE',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (latest != null) ...[
                          Text(
                            latest.close.toStringAsFixed(2),
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${latest.priceChange >= 0 ? '+' : ''}${latest.priceChange.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // 3. Minimalist Timeframe Selector Chips (Top-Right overlay)
            Positioned(
              top: 12,
              right: 75, // Keeps right price scale clear
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xDD1E222D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2E39), width: 1),
                ),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final timeframes = [
                      Timeframe.oneMinute,
                      Timeframe.fiveMinutes,
                      Timeframe.fifteenMinutes,
                      Timeframe.oneHour,
                      Timeframe.oneDay,
                    ];

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: timeframes.map((tf) {
                        final isSelected = _controller.timeframe == tf;
                        return InkWell(
                          onTap: () => _controller.setTimeframe(tf),
                          borderRadius: BorderRadius.circular(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2962FF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              tf.shortLabel,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFF868993),
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
