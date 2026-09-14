import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_charts/im_charts.dart';

import 'screens/chart_trading_demo.dart';
import 'screens/clean_chart_demo.dart';
import 'screens/dual_chart_demo.dart';
import 'screens/portfolio_card_demo.dart';
import 'screens/showcase_hub.dart';
import 'screens/themes_demo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ExampleApp());
}

/// Main entry point for the im_charts Example application.
/// Demonstrates the multiple usage modes and possibilities of im_charts:
/// 0: Showcase Hub (Possibilities Dashboard)
/// 1: Full Institutional Terminal (Toolbar + Header + Indicators + Drawings)
/// 2: Clean / Headless Chart (No Top Toolbar, No Header, 100% Canvas)
/// 3: Dual Multi-Chart Grid (Side-by-side independent engines)
/// 4: Custom Themes & Styles Lab (Theme live-swapping & candle styles)
/// 5: Embedded Analytics Card (Wealth-tech component integration)
class ExampleApp extends StatefulWidget {
  final int initialModeIndex;

  const ExampleApp({
    super.key,
    this.initialModeIndex = 0,
  });

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late int _currentModeIndex;
  bool _showTopNavBar = true;

  final List<({String title, IconData icon, Color color})> _modes = const [
    (title: 'Dashboard Hub', icon: Icons.dashboard_outlined, color: Color(0xFF2962FF)),
    (title: 'Full Terminal', icon: Icons.candlestick_chart, color: Color(0xFF2962FF)),
    (title: 'Clean Chart', icon: Icons.fullscreen, color: Color(0xFF00E676)),
    (title: 'Dual Grid', icon: Icons.grid_view_rounded, color: Color(0xFFFF9800)),
    (title: 'Themes Lab', icon: Icons.palette_outlined, color: Color(0xFFE91E63)),
    (title: 'Portfolio Card', icon: Icons.account_balance_wallet_outlined, color: Color(0xFFAB47BC)),
    (title: 'Chart Trading', icon: Icons.add_chart, color: Color(0xFF00E5FF)),
  ];

  @override
  void initState() {
    super.initState();
    _currentModeIndex = widget.initialModeIndex;
  }

  void _selectMode(int index) {
    if (index >= 0 && index < _modes.length) {
      setState(() {
        _currentModeIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'im_charts Showcase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E1117),
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0E1117),
        body: SafeArea(
          child: Column(
            children: [
              // Top Mode Navigation Bar
              if (_showTopNavBar) _buildTopNavigation(),

              // Active Mode Viewport
              Expanded(
                child: Stack(
                  children: [
                    _buildActiveScreen(),

                    // Floating toggle to show top nav bar when collapsed
                    if (!_showTopNavBar)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: const Color(0xDD1E222D),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => setState(() => _showTopNavBar = true),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF2A2E39), width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_open_rounded, size: 14, color: Colors.white70),
                                  SizedBox(width: 4),
                                  Text(
                                    'Show Modes',
                                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavigation() {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF131722),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2E39), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo & Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2962FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'im',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'im_charts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF2A2E39), indent: 10, endIndent: 10),

          // Scrollable Mode Switcher Tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: List.generate(_modes.length, (index) {
                  final mode = _modes[index];
                  final isSelected = _currentModeIndex == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectMode(index),
                        borderRadius: BorderRadius.circular(6),
                        hoverColor: Colors.white.withValues(alpha: 0.05),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? mode.color.withValues(alpha: 0.18) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? mode.color : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                mode.icon,
                                size: 14,
                                color: isSelected ? mode.color : const Color(0xFF868993),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                mode.title,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : const Color(0xFF868993),
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Collapse Bar Button (to experience edge-to-edge)
          IconButton(
            tooltip: 'Hide Mode Bar (Edge-to-Edge)',
            icon: const Icon(Icons.fullscreen_outlined, size: 18, color: Color(0xFF868993)),
            onPressed: () => setState(() => _showTopNavBar = false),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveScreen() {
    switch (_currentModeIndex) {
      case 0:
        return ShowcaseHubScreen(onSelectMode: _selectMode);
      case 1:
        return const TradingScreen(
          key: ValueKey('full_terminal'),
          initialSymbol: 'NIFTY 50',
          initialExchange: 'NSE',
          initialTimeframe: Timeframe.fiveMinutes,
          initialCandleStyle: CandleStyle.candles,
          showToolbar: true,
          showHeader: true,
        );
      case 2:
        return const CleanChartDemoScreen(key: ValueKey('clean_chart'));
      case 3:
        return const DualChartDemoScreen(key: ValueKey('dual_chart'));
      case 4:
        return const ThemesDemoScreen(key: ValueKey('themes_lab'));
      case 5:
        return const PortfolioCardDemoScreen(key: ValueKey('portfolio_card'));
      case 6:
        return const ChartTradingDemoScreen(key: ValueKey('chart_trading'));
      default:
        return ShowcaseHubScreen(onSelectMode: _selectMode);
    }
  }
}
