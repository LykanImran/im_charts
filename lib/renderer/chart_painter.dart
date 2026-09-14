import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/coordinates/viewport.dart';
import '../core/models/candle.dart';
import '../core/models/candle_style.dart';
import '../core/models/chart_theme.dart';
import '../core/models/price_range.dart';
import '../core/models/timeframe.dart';
import '../engine/indicators/indicator_result.dart';
import 'pane.dart';
import 'renderers/axis_renderer.dart';
import 'renderers/candle_renderer.dart';
import 'renderers/crosshair_renderer.dart';
import 'renderers/current_price_renderer.dart';
import 'renderers/grid_renderer.dart';
import 'renderers/indicator_renderer.dart';
import 'renderers/volume_renderer.dart';

/// Primary CustomPainter coordinating the high-performance Skia/Impeller rendering pipeline.
class ChartPainter extends CustomPainter {
  final List<Candle> candles;
  final ChartViewport viewport;
  final ChartTheme theme;
  final Timeframe timeframe;
  final CandleStyle candleStyle;
  final List<IndicatorResult> overlayIndicators;
  final IndicatorResult? subPaneIndicator;
  final Offset? crosshairPosition;
  final bool showVolume;
  final bool showGrid;
  final double verticalScale;
  final double verticalPan;

  final GridRenderer _gridRenderer;
  final CandleRenderer _candleRenderer;
  final VolumeRenderer _volumeRenderer;
  final IndicatorRenderer _indicatorRenderer;
  final CurrentPriceRenderer _currentPriceRenderer;
  final AxisRenderer _axisRenderer;
  final CrosshairRenderer _crosshairRenderer;

  ChartPainter({
    required this.candles,
    required this.viewport,
    required this.theme,
    required this.timeframe,
    this.candleStyle = CandleStyle.candles,
    this.overlayIndicators = const [],
    this.subPaneIndicator,
    this.crosshairPosition,
    this.showVolume = true,
    this.showGrid = true,
    this.verticalScale = 1.0,
    this.verticalPan = 0.0,
  })  : _gridRenderer = GridRenderer(theme),
        _candleRenderer = CandleRenderer(theme),
        _volumeRenderer = VolumeRenderer(theme),
        _indicatorRenderer = IndicatorRenderer(theme),
        _currentPriceRenderer = CurrentPriceRenderer(theme),
        _axisRenderer = AxisRenderer(theme),
        _crosshairRenderer = CrosshairRenderer(theme);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Clear background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = theme.backgroundColor,
    );

    // 2. Setup multi-pane layout
    final layout = ChartPaneLayout(
      totalSize: size,
      hasSubPane: subPaneIndicator != null,
    );

    if (candles.isEmpty) return;

    // 3. Compute visible slice and coordinate converter
    final visible = viewport.calculateVisibleIndices(candles.length);
    final converter = CoordinateConverter(
      viewport: viewport,
      totalCandles: candles.length,
    );

    // 4. Calculate auto-scaled price range with manual vertical scale & pan
    final basePriceRange = PriceRange.fromCandles(
      candles,
      start: visible.start,
      end: visible.end,
    ).withPadding(topPaddingPercent: 0.08, bottomPaddingPercent: 0.08);

    final priceRange = basePriceRange.applyVerticalScaleAndPan(
      scale: verticalScale,
      pan: verticalPan,
    );

    // 5. Draw Background Grid (if enabled)
    if (showGrid) {
      _gridRenderer.drawGrid(
        canvas: canvas,
        bounds: layout.mainPaneBounds,
        priceRange: priceRange,
        converter: converter,
        viewport: viewport,
        totalCandles: candles.length,
      );

      if (layout.subPaneBounds != null && subPaneIndicator != null) {
        final subRange = PriceRange(
          subPaneIndicator!.fixedMin ?? 0.0,
          subPaneIndicator!.fixedMax ?? 100.0,
        );
        _gridRenderer.drawGrid(
          canvas: canvas,
          bounds: layout.subPaneBounds!,
          priceRange: subRange,
          converter: converter,
          viewport: viewport,
          totalCandles: candles.length,
          verticalDivisions: 3,
        );
      }
    }

    // 6. Draw Volume Histogram (in lower section of main pane)
    if (showVolume) {
      _volumeRenderer.drawVolume(
        canvas: canvas,
        bounds: layout.mainPaneBounds,
        candles: candles,
        visible: visible,
        converter: converter,
        candleWidth: viewport.candleWidth,
      );
    }

    // 7. Draw Overlay Indicators (EMA, Bollinger Bands)
    if (overlayIndicators.isNotEmpty) {
      _indicatorRenderer.drawOverlay(
        canvas: canvas,
        bounds: layout.mainPaneBounds,
        indicators: overlayIndicators,
        visible: visible,
        priceRange: priceRange,
        converter: converter,
      );
    }

    // 8. Draw Candlesticks with selected CandleStyle
    _candleRenderer.drawCandles(
      canvas: canvas,
      bounds: layout.mainPaneBounds,
      candles: candles,
      visible: visible,
      priceRange: priceRange,
      converter: converter,
      candleWidth: viewport.candleWidth,
      candleStyle: candleStyle,
    );

    // 9. Draw Current Price Line & Badge
    if (candles.isNotEmpty) {
      _currentPriceRenderer.drawCurrentPrice(
        canvas: canvas,
        mainBounds: layout.mainPaneBounds,
        axisBounds: layout.priceAxisBounds,
        latestCandle: candles.last,
        priceRange: priceRange,
      );
    }

    // 10. Draw Sub-pane Indicator (e.g. RSI)
    if (layout.subPaneBounds != null && subPaneIndicator != null) {
      _indicatorRenderer.drawSubPane(
        canvas: canvas,
        bounds: layout.subPaneBounds!,
        indicator: subPaneIndicator!,
        visible: visible,
        converter: converter,
      );

      // Sub-pane price scale
      final subRange = PriceRange(
        subPaneIndicator!.fixedMin ?? 0.0,
        subPaneIndicator!.fixedMax ?? 100.0,
      );
      _axisRenderer.drawPriceAxis(
        canvas: canvas,
        axisBounds: layout.subPanePriceAxisBounds!,
        paneBounds: layout.subPaneBounds!,
        priceRange: subRange,
        verticalDivisions: 3,
      );
    }

    // 11. Draw Price Axis (Y) & Time Axis (X)
    _axisRenderer.drawPriceAxis(
      canvas: canvas,
      axisBounds: layout.priceAxisBounds,
      paneBounds: layout.mainPaneBounds,
      priceRange: priceRange,
    );

    _axisRenderer.drawTimeAxis(
      canvas: canvas,
      timeBounds: layout.timeAxisBounds,
      candles: candles,
      visible: visible,
      converter: converter,
      viewport: viewport,
      timeframe: timeframe,
    );

    // 12. Draw Interactive Crosshair & Tooltips
    if (crosshairPosition != null) {
      _crosshairRenderer.drawCrosshair(
        canvas: canvas,
        layout: layout,
        pointerPosition: crosshairPosition,
        candles: candles,
        converter: converter,
        priceRange: priceRange,
        timeframe: timeframe,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.viewport != viewport ||
        oldDelegate.crosshairPosition != crosshairPosition ||
        oldDelegate.timeframe != timeframe ||
        oldDelegate.candleStyle != candleStyle ||
        oldDelegate.overlayIndicators != overlayIndicators ||
        oldDelegate.subPaneIndicator != subPaneIndicator ||
        oldDelegate.showVolume != showVolume ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.verticalScale != verticalScale ||
        oldDelegate.verticalPan != verticalPan ||
        oldDelegate.theme != theme;
  }
}
