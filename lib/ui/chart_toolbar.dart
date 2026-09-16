import 'package:flutter/material.dart';
import '../core/models/candle_style.dart';
import '../core/models/timeframe.dart';
import '../core/utils/chart_exporter.dart';
import '../engine/chart_controller.dart';
import '../engine/indicators/atr.dart';
import '../engine/indicators/bollinger_bands.dart';
import '../engine/indicators/cci.dart';
import '../engine/indicators/chandelier_exit.dart';
import '../engine/indicators/ema.dart';
import '../engine/indicators/ichimoku.dart';
import '../engine/indicators/macd.dart';
import '../engine/indicators/parabolic_sar.dart';
import '../engine/indicators/rsi.dart';
import '../engine/indicators/stochastic.dart';
import '../engine/indicators/vwap.dart';
import '../engine/indicators/williams_r.dart';
import 'chart_save_status_badge.dart';
import 'chart_settings_modal.dart';
import 'formula_editor_modal.dart';
import 'symbol_search_modal.dart';

/// Row 1: Primary Toolbar containing:
/// Search, Interval Dropdown, Candles Dropdown, Indicators Dropdown, Refresh, Dark/Light Mode, Settings, Replay, Snapshot, Shortcuts.
class ChartToolbar extends StatefulWidget {
  final TradingChartController controller;
  final GlobalKey? repaintBoundaryKey;

  const ChartToolbar({
    super.key,
    required this.controller,
    this.repaintBoundaryKey,
  });

  @override
  State<ChartToolbar> createState() => _ChartToolbarState();
}

class _ChartToolbarState extends State<ChartToolbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshAnimCtrl;

  @override
  void initState() {
    super.initState();
    _refreshAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _refreshAnimCtrl.dispose();
    super.dispose();
  }

  void _handleRefresh() {
    _refreshAnimCtrl.forward(from: 0.0);
    widget.controller.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = controller.theme;
        final isDark = controller.isDarkTheme;

        final solidToolbarBg =
            isDark ? const Color(0xFF131722) : const Color(0xFFFFFFFF);

        return Material(
          color: solidToolbarBg,
          child: Container(
            height: 44,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: solidToolbarBg,
              border: Border(
                bottom: BorderSide(color: theme.gridColor, width: 1.0),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. SEARCH BUTTON
                    InkWell(
                      onTap: () => SymbolSearchModal.show(context, controller),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E222D)
                              : const Color(0xFFF0F3FA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.gridColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search,
                              size: 16,
                              color: Color(0xFF2962FF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Search symbol...',
                              style: TextStyle(
                                color: theme.axisTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2E39)
                                    : const Color(0xFFE0E3EB),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '⌘K',
                                style: TextStyle(
                                  color: theme.axisTextColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    _buildDivider(theme),

                    // 2. INTERVAL AS A DROPDOWN
                    _buildIntervalDropdown(controller, theme, isDark),

                    _buildDivider(theme),

                    // 3. CANDLES DROPDOWN
                    _buildCandlesDropdown(controller, theme, isDark),

                    _buildDivider(theme),

                    // 4. INDICATORS DROPDOWN
                    _buildIndicatorsDropdown(controller, theme, isDark),

                    _buildDivider(theme),

                    // 5. REFRESH BUTTON
                    RotationTransition(
                      turns: _refreshAnimCtrl,
                      child: IconButton(
                        icon: Icon(
                          Icons.refresh,
                          size: 18,
                          color: theme.axisTextColor,
                        ),
                        tooltip: 'Refresh Chart Data',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: _handleRefresh,
                      ),
                    ),

                    const SizedBox(width: 4),

                    // 6. DARK / LIGHT MODES TOGGLE
                    IconButton(
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 18,
                        color: isDark
                            ? const Color(0xFFFFB300)
                            : const Color(0xFF2962FF),
                      ),
                      tooltip: isDark
                          ? 'Switch to Light Mode'
                          : 'Switch to Dark Mode',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: controller.toggleTheme,
                    ),

                    const SizedBox(width: 4),

                    // 7. SETTINGS BUTTON
                    IconButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: theme.axisTextColor,
                      ),
                      tooltip: 'Chart Settings',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () =>
                          ChartSettingsModal.show(context, controller),
                    ),

                    const SizedBox(width: 4),

                    // 8. ANIMATED SAVE STATUS BADGE (SAVING / SAVED)
                    ChartSaveStatusBadge(
                      controller: controller,
                      isDark: isDark,
                    ),

                    _buildDivider(theme),

                    // 9. BAR REPLAY BUTTON
                    IconButton(
                      icon: Icon(
                        Icons.history,
                        size: 18,
                        color: controller.isReplayMode
                            ? const Color(0xFFFF9800)
                            : theme.axisTextColor,
                      ),
                      tooltip: controller.isReplayMode
                          ? 'Exit Bar Replay'
                          : 'Bar Replay Simulator',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        if (controller.isReplayMode) {
                          controller.exitReplay();
                        } else {
                          controller.startReplay();
                        }
                      },
                    ),

                    const SizedBox(width: 4),

                    // 9. SNAPSHOT / EXPORT PNG
                    IconButton(
                      icon: Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: theme.axisTextColor,
                      ),
                      tooltip: 'Take Chart Snapshot (Export PNG)',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () async {
                        if (widget.repaintBoundaryKey != null) {
                          final bytes = await ChartExporter.capturePng(
                            widget.repaintBoundaryKey!,
                          );
                          if (bytes != null && context.mounted) {
                            ChartExporter.showSnapshotDialog(
                              context: context,
                              pngBytes: bytes,
                              symbol: controller.symbol,
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chart snapshot captured (1080p)!'),
                              backgroundColor: Color(0xFF1E222D),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),

                    const SizedBox(width: 4),

                    // 10. SHORTCUTS / HOTKEYS HELP
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_outlined,
                        size: 18,
                        color: theme.axisTextColor,
                      ),
                      tooltip: 'Keyboard Shortcuts (Hotkeys)',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => _showShortcutsDialog(context, isDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider(dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Container(height: 18, width: 1, color: theme.gridColor),
    );
  }

  Widget _buildIntervalDropdown(
    TradingChartController controller,
    dynamic theme,
    bool isDark,
  ) {
    return PopupMenuButton<Timeframe>(
      tooltip: 'Interval',
      offset: const Offset(0, 36),
      color: isDark ? const Color(0xFF1E222D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.gridColor, width: 1),
      ),
      onSelected: (tf) => controller.setTimeframe(tf),
      itemBuilder: (context) {
        return [
          _buildMenuSectionHeader('MINUTES', theme),
          _buildTimeframeItem(
            Timeframe.oneMinute,
            '1m (1 Minute)',
            controller,
            theme,
            isDark,
          ),
          _buildTimeframeItem(
            Timeframe.fiveMinutes,
            '5m (5 Minutes)',
            controller,
            theme,
            isDark,
          ),
          _buildTimeframeItem(
            Timeframe.fifteenMinutes,
            '15m (15 Minutes)',
            controller,
            theme,
            isDark,
          ),
          _buildTimeframeItem(
            Timeframe.thirtyMinutes,
            '30m (30 Minutes)',
            controller,
            theme,
            isDark,
          ),
          _buildMenuSectionHeader('HOURS', theme),
          _buildTimeframeItem(
            Timeframe.oneHour,
            '1H (1 Hour)',
            controller,
            theme,
            isDark,
          ),
          _buildTimeframeItem(
            Timeframe.fourHours,
            '4H (4 Hours)',
            controller,
            theme,
            isDark,
          ),
          _buildMenuSectionHeader('DAYS & WEEKS', theme),
          _buildTimeframeItem(
            Timeframe.oneDay,
            '1D (1 Day)',
            controller,
            theme,
            isDark,
          ),
          _buildTimeframeItem(
            Timeframe.oneWeek,
            '1W (1 Week)',
            controller,
            theme,
            isDark,
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF0F3FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.gridColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 14, color: theme.axisTextColor),
            const SizedBox(width: 5),
            Text(
              controller.timeframe.shortLabel,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.axisTextColor),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<Timeframe> _buildMenuSectionHeader(String text, dynamic theme) {
    return PopupMenuItem<Timeframe>(
      enabled: false,
      height: 24,
      child: Text(
        text,
        style: TextStyle(
          color: theme.axisTextColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  PopupMenuItem<Timeframe> _buildTimeframeItem(
    Timeframe tf,
    String label,
    TradingChartController controller,
    dynamic theme,
    bool isDark,
  ) {
    final isSelected = controller.timeframe == tf;
    return PopupMenuItem<Timeframe>(
      value: tf,
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF2962FF)
                  : (isDark ? Colors.white : Colors.black87),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, size: 16, color: Color(0xFF2962FF)),
        ],
      ),
    );
  }

  Widget _buildCandlesDropdown(
    TradingChartController controller,
    dynamic theme,
    bool isDark,
  ) {
    return PopupMenuButton<CandleStyle>(
      tooltip: 'Candle Style',
      offset: const Offset(0, 36),
      color: isDark ? const Color(0xFF1E222D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.gridColor, width: 1),
      ),
      onSelected: (style) => controller.setCandleStyle(style),
      itemBuilder: (context) {
        return CandleStyle.values.map((style) {
          final isSelected = controller.candleStyle == style;
          return PopupMenuItem<CandleStyle>(
            value: style,
            height: 36,
            child: Row(
              children: [
                Icon(
                  style.icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFF2962FF)
                      : theme.axisTextColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    style.label,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF2962FF)
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, size: 16, color: Color(0xFF2962FF)),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF0F3FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.gridColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.candleStyle.icon,
              size: 15,
              color: const Color(0xFF2962FF),
            ),
            const SizedBox(width: 6),
            Text(
              controller.candleStyle.shortLabel,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.axisTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorsDropdown(
    TradingChartController controller,
    dynamic theme,
    bool isDark,
  ) {
    final activeCount = controller.activeIndicators.length +
        (controller.showVolumeProfile ? 1 : 0) +
        (controller.showSMC ? 1 : 0);

    return PopupMenuButton<String>(
      tooltip: 'Technical Indicators',
      offset: const Offset(0, 36),
      color: isDark ? const Color(0xFF1E222D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.gridColor, width: 1),
      ),
      itemBuilder: (context) {
        return [
          // 1. STARRED & VIRAL SECTION
          _buildCategoryHeader(
            title: '⭐ VIRAL & POPULAR',
            theme: theme,
            icon: Icons.whatshot_rounded,
            iconColor: const Color(0xFFFF9100),
          ),
          _buildIndicatorMenuItem(
            label: 'Smart Money Concepts (SMC: FVG, BOS, OB)',
            color: const Color(0xFF00E676),
            isActive: controller.showSMC,
            onTap: () => controller.toggleSMC(),
            theme: theme,
            isDark: isDark,
            isStarred: true,
            badgeText: 'VIRAL',
            badgeColor: const Color(0xFF00E676),
          ),
          _buildIndicatorMenuItem(
            label: 'Supertrend (10, 3.0)',
            color: const Color(0xFF00E676),
            isActive: controller.showSupertrend,
            onTap: () => controller.toggleSupertrend(),
            theme: theme,
            isDark: isDark,
            isStarred: true,
            badgeText: 'HOT',
            badgeColor: const Color(0xFFFF9100),
          ),
          _buildIndicatorMenuItem(
            label: 'Volume Profile (VRVP)',
            color: const Color(0xFFFF1744),
            isActive: controller.showVolumeProfile,
            onTap: () => controller.toggleVolumeProfile(),
            theme: theme,
            isDark: isDark,
            isStarred: true,
            badgeText: 'PRO',
            badgeColor: const Color(0xFFFF1744),
          ),
          _buildIndicatorMenuItem(
            label: 'Stochastic Oscillator (14, 3, 3)',
            color: const Color(0xFFFF6D00),
            isActive: controller.isIndicatorActive('STOCH_14_3_3'),
            onTap: () => controller.toggleIndicator(StochasticIndicator()),
            theme: theme,
            isDark: isDark,
            isStarred: true,
            badgeText: 'POPULAR',
            badgeColor: const Color(0xFFFF6D00),
          ),
          _buildIndicatorMenuItem(
            label: 'Chandelier Exit (22, 3.0 Trailing Stop)',
            color: const Color(0xFF00E5FF),
            isActive: controller.isIndicatorActive('CHANDELIER_22_3.0'),
            onTap: () => controller.toggleIndicator(ChandelierExitIndicator()),
            theme: theme,
            isDark: isDark,
            isStarred: true,
            badgeText: 'HOT',
            badgeColor: const Color(0xFF00E5FF),
          ),
          _buildIndicatorMenuItem(
            label: 'VWAP (Intraday Benchmark)',
            color: const Color(0xFFAB47BC),
            isActive: controller.isIndicatorActive('VWAP'),
            onTap: () => controller.toggleIndicator(VWAPIndicator()),
            theme: theme,
            isDark: isDark,
            isStarred: true,
            badgeText: 'HOT',
            badgeColor: const Color(0xFFAB47BC),
          ),

          const PopupMenuDivider(height: 8),

          // 2. TREND & OVERLAYS SECTION
          _buildCategoryHeader(
            title: 'TREND & OVERLAYS',
            theme: theme,
            icon: Icons.timeline_rounded,
            iconColor: const Color(0xFF2962FF),
          ),
          _buildIndicatorMenuItem(
            label: 'Parabolic SAR (0.02, 0.2)',
            color: const Color(0xFFFFD600),
            isActive: controller.isIndicatorActive('PSAR_0.02_0.2'),
            onTap: () => controller.toggleIndicator(ParabolicSarIndicator()),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'Ichimoku Cloud (9, 26, 52)',
            color: const Color(0xFF00E676),
            isActive: controller.isIndicatorActive('ICHIMOKU_9_26_52'),
            onTap: () => controller.toggleIndicator(IchimokuIndicator()),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'EMA 20 (Trend Fast)',
            color: const Color(0xFF2962FF),
            isActive: controller.isIndicatorActive('EMA_20'),
            onTap: () => controller.toggleIndicator(
              EMAIndicator(period: 20, color: const Color(0xFF2962FF)),
            ),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'EMA 50 (Trend Slow)',
            color: const Color(0xFFE91E63),
            isActive: controller.isIndicatorActive('EMA_50'),
            onTap: () => controller.toggleIndicator(
              EMAIndicator(period: 50, color: const Color(0xFFE91E63)),
            ),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'SMA 20 (Simple Moving Average)',
            color: const Color(0xFFFFB300),
            isActive: controller.isIndicatorActive('SMA_20'),
            onTap: () => controller.toggleSma(),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'Bollinger Bands (20, 2)',
            color: const Color(0xFFFF9800),
            isActive: controller.isIndicatorActive('BB_20_2.0'),
            onTap: () => controller.toggleIndicator(BollingerBandsIndicator()),
            theme: theme,
            isDark: isDark,
          ),

          const PopupMenuDivider(height: 8),

          // 3. MOMENTUM & OSCILLATORS SECTION
          _buildCategoryHeader(
            title: 'MOMENTUM & OSCILLATORS',
            theme: theme,
            icon: Icons.speed_rounded,
            iconColor: const Color(0xFF7E57C2),
          ),
          _buildIndicatorMenuItem(
            label: 'RSI 14 (Momentum Sub-pane)',
            color: const Color(0xFF7E57C2),
            isActive: controller.isIndicatorActive('RSI_14'),
            onTap: () => controller.toggleIndicator(RSIIndicator()),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'MACD (12, 26, 9 Sub-pane)',
            color: const Color(0xFF00E5FF),
            isActive: controller.isIndicatorActive('MACD_12_26_9'),
            onTap: () => controller.toggleIndicator(MACDIndicator()),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'ATR 14 (Average True Range)',
            color: const Color(0xFF00E5FF),
            isActive: controller.isIndicatorActive('ATR_14'),
            onTap: () => controller.toggleIndicator(ATRIndicator()),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'Williams %R (14 Overbought/Oversold)',
            color: const Color(0xFFAB47BC),
            isActive: controller.isIndicatorActive('WILLR_14'),
            onTap: () => controller.toggleIndicator(WilliamsRIndicator()),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'CCI 20 (Commodity Channel Index)',
            color: const Color(0xFF00B0FF),
            isActive: controller.isIndicatorActive('CCI_20'),
            onTap: () => controller.toggleIndicator(CCIIndicator()),
            theme: theme,
            isDark: isDark,
          ),

          const PopupMenuDivider(height: 8),

          // 4. CUSTOM FORMULAS
          PopupMenuItem<String>(
            value: '__pine_formula__',
            height: 38,
            onTap: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FormulaEditorModal.show(context, controller: controller);
              });
            },
            child: Row(
              children: [
                const Icon(
                  Icons.auto_graph_rounded,
                  size: 16,
                  color: Color(0xFF00E5FF),
                ),
                const SizedBox(width: 8),
                Text(
                  '+ Custom Pine Formula...',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF0091EA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF0F3FA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: activeCount > 0
                ? const Color(0xFF2962FF).withValues(alpha: 0.6)
                : theme.gridColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, size: 15, color: Color(0xFF2962FF)),
            const SizedBox(width: 5),
            Text(
              'Indicators',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF2962FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.axisTextColor),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildCategoryHeader({
    required String title,
    required dynamic theme,
    IconData? icon,
    Color? iconColor,
  }) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 24,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? const Color(0xFFFFB300)),
            const SizedBox(width: 5),
          ],
          Text(
            title,
            style: TextStyle(
              color: iconColor ?? theme.axisTextColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildIndicatorMenuItem({
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    required dynamic theme,
    required bool isDark,
    bool isStarred = false,
    String? badgeText,
    Color? badgeColor,
  }) {
    return PopupMenuItem<String>(
      onTap: onTap,
      height: 38,
      child: Row(
        children: [
          if (isStarred)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(
                Icons.star_rounded,
                size: 15,
                color: Color(0xFFFFB300),
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive
                    ? (isDark ? Colors.white : Colors.black87)
                    : theme.axisTextColor,
                fontSize: 12,
                fontWeight: isActive || isStarred ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badgeText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: (badgeColor ?? const Color(0xFFFF9100)).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: (badgeColor ?? const Color(0xFFFF9100)).withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor ?? const Color(0xFFFF9100),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          Icon(
            isActive ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: isActive ? const Color(0xFF2962FF) : theme.axisTextColor,
          ),
        ],
      ),
    );
  }

  void _showShortcutsDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.keyboard_outlined,
                            size: 20,
                            color: Color(0xFF2962FF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TradingView Keyboard Shortcuts',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF131722),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color:
                              isDark ? const Color(0xFF787B86) : Colors.black54,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildShortcutRow(
                    'Alt + H',
                    'Place Horizontal Support/Resistance Line',
                    isDark,
                  ),
                  _buildShortcutRow(
                    'Alt + T',
                    'Activate Trendline Tool',
                    isDark,
                  ),
                  _buildShortcutRow(
                    'Alt + A',
                    'Set Price Alert at Cursor',
                    isDark,
                  ),
                  _buildShortcutRow(
                    'Alt + R',
                    'Reset View to Auto-Scale',
                    isDark,
                  ),
                  _buildShortcutRow(
                    'Delete / Backspace',
                    'Remove Selected Drawing',
                    isDark,
                  ),
                  _buildShortcutRow(
                    '← / →',
                    'Pan Historical Candlesticks',
                    isDark,
                  ),
                  _buildShortcutRow(
                    '+ / -',
                    'Zoom In / Out Horizontally',
                    isDark,
                  ),
                  _buildShortcutRow('Esc', 'Clear Tool / Selection', isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShortcutRow(
    String keyCombination,
    String description,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2E39) : const Color(0xFFECEFF1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF363A45) : const Color(0xFFCFD8DC),
              ),
            ),
            child: Text(
              keyCombination,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              textAlign: TextAlign.right,
              style: TextStyle(
                color:
                    isDark ? const Color(0xFFB2B5BE) : const Color(0xFF434651),
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
