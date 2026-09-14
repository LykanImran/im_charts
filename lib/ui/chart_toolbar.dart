import 'package:flutter/material.dart';
import '../core/models/candle_style.dart';
import '../core/models/timeframe.dart';
import '../engine/chart_controller.dart';
import '../engine/indicators/bollinger_bands.dart';
import '../engine/indicators/ema.dart';
import '../engine/indicators/rsi.dart';
import 'chart_settings_modal.dart';
import 'symbol_search_modal.dart';

/// Row 1: Primary Toolbar containing:
/// Search, Interval Dropdown, Candles Dropdown, Indicators Dropdown, Refresh, Dark/Light Mode, Settings.
class ChartToolbar extends StatefulWidget {
  final TradingChartController controller;

  const ChartToolbar({super.key, required this.controller});

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

        final solidToolbarBg = isDark
            ? const Color(0xFF131722)
            : const Color(0xFFFFFFFF);

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
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
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
    final activeCount = controller.activeIndicators.length;

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
          PopupMenuItem<String>(
            enabled: false,
            height: 24,
            child: Text(
              'OVERLAYS & OSCILLATORS',
              style: TextStyle(
                color: theme.axisTextColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
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
            label: 'Bollinger Bands (20, 2)',
            color: const Color(0xFFFF9800),
            isActive: controller.isIndicatorActive('BB_20_2.0'),
            onTap: () => controller.toggleIndicator(BollingerBandsIndicator()),
            theme: theme,
            isDark: isDark,
          ),
          _buildIndicatorMenuItem(
            label: 'RSI 14 (Momentum Sub-pane)',
            color: const Color(0xFF7E57C2),
            isActive: controller.isIndicatorActive('RSI_14'),
            onTap: () => controller.toggleIndicator(RSIIndicator()),
            theme: theme,
            isDark: isDark,
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

  PopupMenuItem<String> _buildIndicatorMenuItem({
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    required dynamic theme,
    required bool isDark,
  }) {
    return PopupMenuItem<String>(
      onTap: onTap,
      height: 38,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive
                    ? (isDark ? Colors.white : Colors.black87)
                    : theme.axisTextColor,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Icon(
            isActive ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: isActive ? const Color(0xFF2962FF) : theme.axisTextColor,
          ),
        ],
      ),
    );
  }
}
