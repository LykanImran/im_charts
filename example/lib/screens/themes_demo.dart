import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

/// Custom Themes & Styles Lab:
/// Demonstrates custom brand theming using ChartTheme.copyWith and real-time
/// switching between all 6 candlestick presentation styles.
class ThemesDemoScreen extends StatefulWidget {
  const ThemesDemoScreen({super.key});

  @override
  State<ThemesDemoScreen> createState() => _ThemesDemoScreenState();
}

class _ThemesDemoScreenState extends State<ThemesDemoScreen> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;
  String _selectedThemeName = 'Dark';

  // Custom curated palettes
  static final ChartTheme _cyberpunkTheme = ChartTheme.dark().copyWith(
    backgroundColor: const Color(0xFF090D16),
    bullishColor: const Color(0xFF00FF88),
    bearishColor: const Color(0xFFFF0055),
    gridColor: const Color(0xFF131B2A),
    currentPriceLineColor: const Color(0xFF00E5FF),
    currentPriceBadgeBackground: const Color(0xFF00E5FF),
    axisTextColor: const Color(0xFF00E5FF),
  );

  static final ChartTheme _bloombergTheme = ChartTheme.dark().copyWith(
    backgroundColor: const Color(0xFF000000),
    bullishColor: const Color(0xFFFFB300),
    bearishColor: const Color(0xFFE53935),
    gridColor: const Color(0xFF1A1A1A),
    currentPriceLineColor: const Color(0xFFFFB300),
    currentPriceBadgeBackground: const Color(0xFFFFB300),
    currentPriceBadgeTextColor: Colors.black,
    axisTextColor: const Color(0xFFFFB300),
  );

  static final ChartTheme _emeraldLightTheme = ChartTheme.light().copyWith(
    backgroundColor: Colors.white,
    bullishColor: const Color(0xFF00C805),
    bearishColor: const Color(0xFFFF5000),
    gridColor: const Color(0xFFF7F7F8),
  );

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(initialPrice: 24520.0, volatility: 0.0018);
    _controller = TradingChartController(
      symbol: 'TCS',
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

  void _applyTheme(String name, ChartTheme theme) {
    setState(() => _selectedThemeName = name);
    _controller.setTheme(theme);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final currentTheme = _controller.theme;

        return Scaffold(
          backgroundColor: currentTheme.backgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Top Customization Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: currentTheme.backgroundColor,
                    border: Border(bottom: BorderSide(color: currentTheme.gridColor, width: 1)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'Theme: ',
                          style: TextStyle(color: Color(0xFF868993), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        _buildThemeChip('Dark', ChartTheme.dark()),
                        _buildThemeChip('Cyberpunk', _cyberpunkTheme),
                        _buildThemeChip('Bloomberg', _bloombergTheme),
                        _buildThemeChip('Emerald Light', _emeraldLightTheme),

                        const SizedBox(width: 16),
                        Container(width: 1, height: 20, color: currentTheme.gridColor),
                        const SizedBox(width: 16),

                        const Text(
                          'Style: ',
                          style: TextStyle(color: Color(0xFF868993), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        ...CandleStyle.values.map((style) {
                          final isSelected = _controller.candleStyle == style;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: FilterChip(
                              label: Text(style.shortLabel),
                              selected: isSelected,
                              onSelected: (_) => _controller.setCandleStyle(style),
                              backgroundColor: Colors.transparent,
                              selectedColor: const Color(0xFF2962FF),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : currentTheme.axisTextColor,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFF2962FF) : currentTheme.gridColor,
                                ),
                              ),
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Canvas Area with Floating Telemetry
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: TradingChart(controller: _controller),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 65,
                        child: ChartHeader(controller: _controller),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeChip(String label, ChartTheme theme) {
    final isSelected = _selectedThemeName == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        onTap: () => _applyTheme(label, theme),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2962FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? const Color(0xFF2962FF) : const Color(0xFF2A2E39),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF868993),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
