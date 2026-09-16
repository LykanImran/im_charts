import 'package:flutter/material.dart';

/// Interactive Dashboard Hub displaying cards for each common mode/possibility
/// of im_charts so developers can explore what they require.
class ShowcaseHubScreen extends StatelessWidget {
  final Function(int modeIndex) onSelectMode;

  const ShowcaseHubScreen({super.key, required this.onSelectMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1117),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Badge & Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2962FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2962FF),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.candlestick_chart,
                          size: 14,
                          color: Color(0xFF2962FF),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Im Charts Studio v0.1.0',
                          style: TextStyle(
                            color: Color(0xFF2962FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Impeller & Skia • 120 FPS',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text(
                'Im Charts Possibilities & Modes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Explore the institutional capabilities and integration modes of Im Charts. Tap any mode below to test live interactions.',
                style: TextStyle(
                  color: Color(0xFF868993),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // Hero Brand Banner
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2E39), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final h = (constraints.maxWidth * 0.28).clamp(
                        120.0,
                        240.0,
                      );
                      return SizedBox(
                        width: double.infinity,
                        height: h,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/im_charts_banner.jpg',
                              fit: BoxFit.cover,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Grid of Showcase Modes
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildModeCard(
                        width: isWide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        title: '1. Full Institutional Terminal',
                        tag: 'PLUG & PLAY',
                        tagColor: const Color(0xFF2962FF),
                        description:
                            'The complete TradingView-grade trading setup with 2-row toolbars: Symbol search (⌘K), Interval selector, Candle styles, Technical indicators dropdown, Real-time telemetry, and Settings modal.',
                        icon: Icons.dashboard_customize,
                        bullets: [
                          'Row 1 Primary Tools & Search',
                          'Row 2 Floating Telemetry Strip',
                          'Volume & Multi-pane Indicators',
                          'Trackpad Pinch-to-Zoom & Pan',
                        ],
                        onTap: () => onSelectMode(1),
                      ),
                      _buildModeCard(
                        width: isWide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        title: '2. Clean / Headless Chart (No Top Header)',
                        tag: 'MINIMALIST',
                        tagColor: const Color(0xFF00E676),
                        description:
                            'A version of the chart where you do not need the top toolbar or header. Pure high-performance canvas with minimal floating chips, maximizing chart viewport space.',
                        icon: Icons.fullscreen,
                        bullets: [
                          'No top toolbar or heavy header',
                          'Unobstructed canvas for embeddability',
                          'Minimalist floating interval pill',
                          'Ideal for custom broker UIs & mobile',
                        ],
                        onTap: () => onSelectMode(2),
                      ),
                      _buildModeCard(
                        width: isWide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        title: '3. Multi-Chart Grid (Dual Split View)',
                        tag: 'ADVANCED TRADING',
                        tagColor: const Color(0xFFFF9800),
                        description:
                            'Two independent live chart engines running side-by-side (NIFTY 50 vs BANKNIFTY) with concurrent tick feeds, independent timeframes, and zero lag.',
                        icon: Icons.grid_view_rounded,
                        bullets: [
                          'Synchronized multi-symbol monitoring',
                          'Independent timeframes (5m vs 15m)',
                          'Multi-controller state management',
                          '60/120 FPS concurrent rendering',
                        ],
                        onTap: () => onSelectMode(3),
                      ),
                      _buildModeCard(
                        width: isWide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        title: '4. Custom Themes & Styles Lab',
                        tag: 'DEEPLY CUSTOMIZABLE',
                        tagColor: const Color(0xFFE91E63),
                        description:
                            'Demonstrates custom brand theming via ChartTheme.copyWith. Live toggle between Institutional Dark, Cyberpunk Neon, Bloomberg Amber, and Clean Paper Light palettes.',
                        icon: Icons.palette_outlined,
                        bullets: [
                          'Instant live theme swapping',
                          '6 Candle Styles (Hollow, Heikin Ashi, Area...)',
                          'Custom brand color tokens',
                          'Dark & Light mode support',
                        ],
                        onTap: () => onSelectMode(4),
                      ),
                      _buildModeCard(
                        width: isWide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        title: '5. Embedded Analytics Card',
                        tag: 'COMPONENT USAGE',
                        tagColor: const Color(0xFFAB47BC),
                        description:
                            'Embed Im Charts as a compact 320px widget inside an analytics dashboard or portfolio overview card with summary KPIs, Net Worth, and timeframe filters.',
                        icon: Icons.account_balance_wallet_outlined,
                        bullets: [
                          'Embedded in Card with summary stats',
                          'Gradient mountain Area chart',
                          'Custom timeframe chips (1D, 1W, 1M, 1Y)',
                          'Perfect for banking & wealth tech apps',
                        ],
                        onTap: () => onSelectMode(5),
                      ),
                      _buildModeCard(
                        width: isWide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        title: '6. Direct Chart Trading & Brackets',
                        tag: 'NEW • INTERACTIVE',
                        tagColor: const Color(0xFF00E5FF),
                        description:
                            'Institutional trading execution straight from the chart: Hover "+" button before the price axis, 1-click Limit order & Bracket menu, Take-Profit & Stop-Loss connected lines, drag-to-modify prices, and real-time ledger.',
                        icon: Icons.add_chart,
                        bullets: [
                          'Hover "+" button tracks cursor Y',
                          '1-click popup for Limit & Bracket orders',
                          'Horizontal dotted order lines on canvas',
                          'Take Profit (TP) & Stop Loss (SL) connector arms',
                          'Drag badges on canvas to adjust prices live',
                          'Instant cancellation (✖) & working ledger',
                        ],
                        onTap: () => onSelectMode(6),
                      ),
                      _buildModeCard(
                        width: isWide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        title: '7. Drawing Tools & Real-Time Telemetry',
                        tag: 'NEW • TECHNICAL ANALYSIS',
                        tagColor: const Color(0xFFFFD600),
                        description:
                            'Institutional TradingView-style analysis: Left-docked drawing tools (Trendlines, Horizontal Rays, Fibonacci retracement, Long & Short Risk:Reward boxes, Measure ruler), live ticking candle countdown timer, and background watermark.',
                        icon: Icons.brush_outlined,
                        bullets: [
                          'Left drawing toolbar with 7 tools',
                          'Trendlines & Horizontal support/resistance',
                          'Fibonacci retracement with golden ratio bands',
                          'Long/Short Risk:Reward box with target/stop zones',
                          'Measure ruler (ΔPrice, Δ%, bar count)',
                          'Live ticking candle countdown timer badge',
                          'Background typography watermark (NIFTY 50 • 5m)',
                        ],
                        onTap: () => onSelectMode(7),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required double width,
    required String title,
    required String tag,
    required Color tagColor,
    required String description,
    required IconData icon,
    required List<String> bullets,
    required VoidCallback onTap,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF161A25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262C3D), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: tagColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: tagColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tagColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: tagColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF9EA3B0),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: bullets.map((bullet) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2332),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF2E354A),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 12, color: tagColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              bullet,
                              style: const TextStyle(
                                color: Color(0xFFD0D4E0),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Launch Interactive Mode',
                      style: TextStyle(
                        color: tagColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 14, color: tagColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
