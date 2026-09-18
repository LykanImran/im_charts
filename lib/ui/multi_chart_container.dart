import 'package:flutter/material.dart';
import '../engine/chart_controller.dart';
import '../engine/chart_sync_group.dart';
import 'chart_widget.dart';

/// Layout arrangement mode for multi-chart displays.
enum MultiChartLayoutMode {
  /// 1 Chart full screen
  single('1x1', Icons.crop_square_rounded),

  /// 2 Charts side by side (Left / Right)
  splitHorizontal('1x2', Icons.view_column_rounded),

  /// 2 Charts stacked vertically (Top / Bottom)
  splitVertical('2x1', Icons.view_stream_rounded),

  /// 4 Charts in a 2x2 grid
  grid2x2('2x2', Icons.grid_view_rounded);

  final String label;
  final IconData icon;
  const MultiChartLayoutMode(this.label, this.icon);
}

/// Production-ready synchronized multi-chart container.
///
/// Features:
/// - Quick switching between 1x1, 1x2, 2x1, and 2x2 grid layouts.
/// - Linked crosshair cursor across all charts with timestamp precision.
/// - Synchronized horizontal pan & focal zoom across all chart viewports.
/// - Active pane focus ring highlighting.
/// - Full customization support.
class MultiChartContainer extends StatefulWidget {
  final List<TradingChartController> controllers;
  final ChartSyncGroup? syncGroup;
  final MultiChartLayoutMode initialLayout;
  final bool showToolbar;
  final Color activeBorderColor;
  final ValueChanged<int>? onActiveChartChanged;
  final Widget Function(
    BuildContext context,
    int index,
    TradingChartController controller,
  )? chartBuilder;

  const MultiChartContainer({
    super.key,
    required this.controllers,
    this.syncGroup,
    this.initialLayout = MultiChartLayoutMode.splitHorizontal,
    this.showToolbar = true,
    this.activeBorderColor = const Color(0xFF2962FF),
    this.onActiveChartChanged,
    this.chartBuilder,
  });

  @override
  State<MultiChartContainer> createState() => _MultiChartContainerState();
}

class _MultiChartContainerState extends State<MultiChartContainer> {
  late MultiChartLayoutMode _layoutMode;
  late final ChartSyncGroup _syncGroup;
  late final bool _ownsSyncGroup;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _layoutMode = widget.initialLayout;
    if (widget.syncGroup != null) {
      _syncGroup = widget.syncGroup!;
      _ownsSyncGroup = false;
    } else {
      _syncGroup = ChartSyncGroup(
        syncCrosshair: true,
        syncTimeScroll: true,
        syncTimeZoom: true,
      );
      _ownsSyncGroup = true;
    }

    _registerAllControllers();
  }

  void _registerAllControllers() {
    for (final controller in widget.controllers) {
      _syncGroup.register(controller);
    }
  }

  @override
  void didUpdateWidget(covariant MultiChartContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controllers != widget.controllers) {
      _registerAllControllers();
    }
  }

  @override
  void dispose() {
    if (_ownsSyncGroup) {
      _syncGroup.dispose();
    }
    super.dispose();
  }

  void _setActiveIndex(int index) {
    if (_activeIndex != index) {
      setState(() => _activeIndex = index);
      widget.onActiveChartChanged?.call(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controllers.isEmpty) {
      return const Center(child: Text('No charts configured'));
    }

    final activeController = (_activeIndex < widget.controllers.length)
        ? widget.controllers[_activeIndex]
        : widget.controllers.first;

    return ListenableBuilder(
      listenable: activeController,
      builder: (context, _) {
        final isDark = activeController.isDarkTheme;
        final bgColor = isDark ? const Color(0xFF131722) : Colors.white;
        final toolbarBg =
            isDark ? const Color(0xFF1E222D) : const Color(0xFFF8F9FD);
        final borderColor =
            isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB);
        final headerTextColor =
            isDark ? Colors.white : const Color(0xFF131722);
        final subTextColor =
            isDark ? const Color(0xFF787B86) : const Color(0xFF6A6D78);

        return Container(
          color: bgColor,
          child: Column(
            children: [
              if (widget.showToolbar)
                _buildTopToolbar(
                  isDark: isDark,
                  toolbarBg: toolbarBg,
                  borderColor: borderColor,
                  headerTextColor: headerTextColor,
                  subTextColor: subTextColor,
                ),
              Expanded(
                child: _buildLayoutGrid(isDark: isDark, borderColor: borderColor, subTextColor: subTextColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopToolbar({
    required bool isDark,
    required Color toolbarBg,
    required Color borderColor,
    required Color headerTextColor,
    required Color subTextColor,
  }) {
    final inactiveBorder =
        isDark ? const Color(0xFF363A45) : const Color(0xFFD0D3DC);

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: toolbarBg,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.dashboard_customize_rounded,
            size: 16,
            color: Color(0xFF90CAF9),
          ),
          const SizedBox(width: 8),
          Text(
            'Multi-Chart Sync',
            style: TextStyle(
              color: headerTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 18, color: borderColor),
          const SizedBox(width: 10),

          // Layout Mode Selector Buttons
          ...MultiChartLayoutMode.values.map((mode) {
            final isSelected = _layoutMode == mode;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: '${mode.label} Grid Layout',
                child: InkWell(
                  onTap: () => setState(() => _layoutMode = mode),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2962FF).withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2962FF)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mode.icon,
                          size: 14,
                          color: isSelected
                              ? const Color(0xFF2962FF)
                              : subTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mode.label,
                          style: TextStyle(
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF2962FF))
                                : subTextColor,
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Link Crosshairs Toggle
          ListenableBuilder(
            listenable: _syncGroup,
            builder: (context, _) {
              final active = _syncGroup.syncCrosshair;
              return Tooltip(
                message: active
                    ? 'Crosshairs Linked (Click to Unlink)'
                    : 'Link Crosshairs across all charts',
                child: InkWell(
                  onTap: () => _syncGroup.syncCrosshair = !active,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF00E676).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: active
                            ? const Color(0xFF00E676)
                            : inactiveBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          size: 13,
                          color: active
                              ? const Color(0xFF00E676)
                              : subTextColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Crosshairs',
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF00E676)
                                : subTextColor,
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),

          // Link Scroll / Zoom Toggle
          ListenableBuilder(
            listenable: _syncGroup,
            builder: (context, _) {
              final active =
                  _syncGroup.syncTimeScroll && _syncGroup.syncTimeZoom;
              return Tooltip(
                message: active
                    ? 'Time Scroll & Zoom Linked (Click to Unlink)'
                    : 'Link Time Scroll & Zoom across all charts',
                child: InkWell(
                  onTap: () {
                    final newState = !active;
                    _syncGroup.syncTimeScroll = newState;
                    _syncGroup.syncTimeZoom = newState;
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF2962FF).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: active
                            ? const Color(0xFF2962FF)
                            : inactiveBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 13,
                          color: active
                              ? const Color(0xFF2962FF)
                              : subTextColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Time & Zoom',
                          style: TextStyle(
                            color: active
                                ? const Color(0xFF2962FF)
                                : subTextColor,
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutGrid({
    required bool isDark,
    required Color borderColor,
    required Color subTextColor,
  }) {
    switch (_layoutMode) {
      case MultiChartLayoutMode.single:
        return _buildSinglePane(0, isDark, subTextColor);

      case MultiChartLayoutMode.splitHorizontal:
        return Row(
          children: [
            Expanded(child: _buildSinglePane(0, isDark, subTextColor)),
            Container(width: 2, color: borderColor),
            Expanded(child: _buildSinglePane(1, isDark, subTextColor)),
          ],
        );

      case MultiChartLayoutMode.splitVertical:
        return Column(
          children: [
            Expanded(child: _buildSinglePane(0, isDark, subTextColor)),
            Container(height: 2, color: borderColor),
            Expanded(child: _buildSinglePane(1, isDark, subTextColor)),
          ],
        );

      case MultiChartLayoutMode.grid2x2:
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildSinglePane(0, isDark, subTextColor)),
                  Container(width: 2, color: borderColor),
                  Expanded(child: _buildSinglePane(1, isDark, subTextColor)),
                ],
              ),
            ),
            Container(height: 2, color: borderColor),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildSinglePane(2, isDark, subTextColor)),
                  Container(width: 2, color: borderColor),
                  Expanded(child: _buildSinglePane(3, isDark, subTextColor)),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildSinglePane(int index, bool isDark, Color subTextColor) {
    if (index >= widget.controllers.length) {
      return Container(
        color: isDark ? const Color(0xFF131722) : Colors.white,
        child: Center(
          child: Text(
            'Chart ${index + 1} Unassigned',
            style: TextStyle(color: subTextColor, fontSize: 13),
          ),
        ),
      );
    }

    final controller = widget.controllers[index];
    final isActive = _activeIndex == index;

    final child = widget.chartBuilder != null
        ? widget.chartBuilder!(context, index, controller)
        : TradingChart(controller: controller);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _setActiveIndex(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? widget.activeBorderColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: child,
      ),
    );
  }
}
