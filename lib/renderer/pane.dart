import 'dart:ui';

/// Computes and holds the bounding rectangles for chart panes and axes.
class ChartPaneLayout {
  final Size totalSize;
  final double priceAxisWidth;
  final double timeAxisHeight;
  final bool hasSubPane;
  final double subPaneRatio; // e.g. 0.25 (25% for RSI)

  late final Rect mainPaneBounds;
  late final Rect? subPaneBounds;
  late final Rect priceAxisBounds;
  late final Rect timeAxisBounds;
  late final Rect? subPanePriceAxisBounds;

  ChartPaneLayout({
    required this.totalSize,
    this.priceAxisWidth = 65.0,
    this.timeAxisHeight = 24.0,
    this.hasSubPane = false,
    this.subPaneRatio = 0.25,
  }) {
    final chartWidth = (totalSize.width - priceAxisWidth).clamp(10.0, totalSize.width);
    final availableHeight = (totalSize.height - timeAxisHeight).clamp(10.0, totalSize.height);

    if (hasSubPane) {
      final subHeight = availableHeight * subPaneRatio;
      final mainHeight = availableHeight - subHeight;

      mainPaneBounds = Rect.fromLTWH(0, 0, chartWidth, mainHeight);
      subPaneBounds = Rect.fromLTWH(0, mainHeight, chartWidth, subHeight);

      priceAxisBounds = Rect.fromLTWH(chartWidth, 0, priceAxisWidth, mainHeight);
      subPanePriceAxisBounds = Rect.fromLTWH(chartWidth, mainHeight, priceAxisWidth, subHeight);
    } else {
      mainPaneBounds = Rect.fromLTWH(0, 0, chartWidth, availableHeight);
      subPaneBounds = null;

      priceAxisBounds = Rect.fromLTWH(chartWidth, 0, priceAxisWidth, availableHeight);
      subPanePriceAxisBounds = null;
    }

    timeAxisBounds = Rect.fromLTWH(0, availableHeight, chartWidth, timeAxisHeight);
  }
}
