import 'dart:ui';

/// Computes and holds the bounding rectangles for chart panes and axes,
/// supporting both single and multiple stacked sub-panes (e.g. RSI and MACD concurrently).
class ChartPaneLayout {
  final Size totalSize;
  final double priceAxisWidth;
  final double timeAxisHeight;
  final int subPaneCount;
  final double subPaneRatio;

  late final Rect mainPaneBounds;
  late final List<Rect> subPanesBounds;
  late final Rect priceAxisBounds;
  late final List<Rect> subPanesPriceAxisBounds;
  late final Rect timeAxisBounds;

  ChartPaneLayout({
    required this.totalSize,
    this.priceAxisWidth = 65.0,
    this.timeAxisHeight = 24.0,
    bool hasSubPane = false,
    int? subPanes,
    this.subPaneRatio = 0.25,
  }) : subPaneCount = subPanes ?? (hasSubPane ? 1 : 0) {
    final chartWidth = (totalSize.width - priceAxisWidth).clamp(
      10.0,
      totalSize.width,
    );
    final availableHeight = (totalSize.height - timeAxisHeight).clamp(
      10.0,
      totalSize.height,
    );

    subPanesBounds = [];
    subPanesPriceAxisBounds = [];

    if (subPaneCount <= 0) {
      mainPaneBounds = Rect.fromLTWH(0, 0, chartWidth, availableHeight);
      priceAxisBounds = Rect.fromLTWH(
        chartWidth,
        0,
        priceAxisWidth,
        availableHeight,
      );
    } else if (subPaneCount == 1) {
      final subHeight = availableHeight * subPaneRatio;
      final mainHeight = availableHeight - subHeight;

      mainPaneBounds = Rect.fromLTWH(0, 0, chartWidth, mainHeight);
      priceAxisBounds = Rect.fromLTWH(
        chartWidth,
        0,
        priceAxisWidth,
        mainHeight,
      );

      final sBounds = Rect.fromLTWH(0, mainHeight, chartWidth, subHeight);
      final sAxisBounds = Rect.fromLTWH(
        chartWidth,
        mainHeight,
        priceAxisWidth,
        subHeight,
      );

      subPanesBounds.add(sBounds);
      subPanesPriceAxisBounds.add(sAxisBounds);
    } else {
      // Multiple stacked sub-panes (e.g. RSI + MACD)
      // Cap total sub-pane height to max 45% of chart height so main candle pane stays prominent
      final totalSubHeightRatio = (0.20 * subPaneCount).clamp(0.20, 0.45);
      final totalSubHeight = availableHeight * totalSubHeightRatio;
      final perSubHeight = totalSubHeight / subPaneCount;
      final mainHeight = availableHeight - totalSubHeight;

      mainPaneBounds = Rect.fromLTWH(0, 0, chartWidth, mainHeight);
      priceAxisBounds = Rect.fromLTWH(
        chartWidth,
        0,
        priceAxisWidth,
        mainHeight,
      );

      for (int i = 0; i < subPaneCount; i++) {
        final top = mainHeight + (i * perSubHeight);
        subPanesBounds.add(Rect.fromLTWH(0, top, chartWidth, perSubHeight));
        subPanesPriceAxisBounds.add(
          Rect.fromLTWH(chartWidth, top, priceAxisWidth, perSubHeight),
        );
      }
    }

    timeAxisBounds = Rect.fromLTWH(
      0,
      availableHeight,
      chartWidth,
      timeAxisHeight,
    );
  }

  /// Backward-compatible getters for single sub-pane consumers
  bool get hasSubPane => subPaneCount > 0;
  Rect? get subPaneBounds =>
      subPanesBounds.isNotEmpty ? subPanesBounds.first : null;
  Rect? get subPanePriceAxisBounds =>
      subPanesPriceAxisBounds.isNotEmpty ? subPanesPriceAxisBounds.first : null;
}
