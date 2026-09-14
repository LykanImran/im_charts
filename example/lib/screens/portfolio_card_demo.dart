import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

/// Embedded Component Demo:
/// Shows how im_charts can be embedded inside a wealth-tech / fintech analytics card
/// with custom portfolio summary stats and quick timeframe chips.
class PortfolioCardDemoScreen extends StatefulWidget {
  const PortfolioCardDemoScreen({super.key});

  @override
  State<PortfolioCardDemoScreen> createState() => _PortfolioCardDemoScreenState();
}

class _PortfolioCardDemoScreenState extends State<PortfolioCardDemoScreen> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;
  String _selectedPeriod = '1M';

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(initialPrice: 148250.0, volatility: 0.0012);
    _controller = TradingChartController(
      symbol: 'PORTFOLIO',
      dataSource: _dataSource,
      initialTimeframe: Timeframe.oneDay,
      initialCandleStyle: CandleStyle.area,
      theme: ChartTheme.dark().copyWith(
        backgroundColor: const Color(0xFF141722),
        currentPriceLineColor: const Color(0xFF00E676),
        currentPriceBadgeBackground: const Color(0xFF00E676),
        currentPriceBadgeTextColor: Colors.black,
        gridColor: const Color(0xFF1F2433),
      ),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF090B10),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141722),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF262C3D), width: 1),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Portfolio Header
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL PORTFOLIO VALUE',
                                style: TextStyle(
                                  color: Color(0xFF868993),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '₹1,48,250.00',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '+₹3,420.50 (+2.36%)',
                                      style: TextStyle(
                                        color: Color(0xFF00E676),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Past Month',
                                    style: TextStyle(color: Color(0xFF868993), fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),

                          // Quick Timeframe selector chips
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E222D),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: ['1D', '1W', '1M', '1Y', 'ALL'].map((period) {
                                final isSelected = _selectedPeriod == period;
                                return InkWell(
                                  onTap: () {
                                    setState(() => _selectedPeriod = period);
                                    if (period == '1D') _controller.setTimeframe(Timeframe.fiveMinutes);
                                    if (period == '1W') _controller.setTimeframe(Timeframe.fifteenMinutes);
                                    if (period == '1M') _controller.setTimeframe(Timeframe.oneHour);
                                    if (period == '1Y') _controller.setTimeframe(Timeframe.oneDay);
                                    if (period == 'ALL') _controller.setTimeframe(Timeframe.oneWeek);
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF2962FF) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      period,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF868993),
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Embedded Chart Canvas (360px height)
                    SizedBox(
                      height: 360,
                      child: TradingChart(controller: _controller),
                    ),

                    // Card Footer Telemetry
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10131C),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF00E676)),
                          const SizedBox(width: 6),
                          const Text(
                            'Institutional Real-time Feed Active',
                            style: TextStyle(color: Color(0xFF868993), fontSize: 11),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _controller.resetView(),
                            icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF2962FF)),
                            label: const Text(
                              'Reset View',
                              style: TextStyle(color: Color(0xFF2962FF), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
