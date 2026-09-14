import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/coordinates/viewport.dart';
import '../core/models/candle.dart';
import '../core/models/candle_style.dart';
import '../core/models/chart_drawing.dart';
import '../core/models/chart_theme.dart';
import '../core/models/price_range.dart';
import '../core/models/timeframe.dart';
import '../engine/indicators/indicator_result.dart';
import '../core/models/chart_order.dart';
import '../core/models/chart_position.dart';
import 'pane.dart';
import 'renderers/axis_renderer.dart';
import 'renderers/candle_renderer.dart';
import 'renderers/crosshair_renderer.dart';
import 'renderers/current_price_renderer.dart';
import 'renderers/drawing_renderer.dart';
import 'renderers/grid_renderer.dart';
import 'renderers/indicator_renderer.dart';
import 'renderers/order_renderer.dart';
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
  final List<ChartOrder> orders;
  final List<ChartPosition> positions;
  final List<ChartDrawing> drawings;
  final ChartDrawing? previewDrawing;
  final Offset? crosshairPosition;
  final bool showVolume;
  final bool showGrid;
  final bool showWatermark;
  final bool showCountdownTimer;
  final String? countdownText;
  final String symbol;
  final String exchange;
  final double verticalScale;
  final double verticalPan;

  final GridRenderer _gridRenderer;
  final CandleRenderer _candleRenderer;
  final VolumeRenderer _volumeRenderer;
  final IndicatorRenderer _indicatorRenderer;
  final CurrentPriceRenderer _currentPriceRenderer;
  final AxisRenderer _axisRenderer;
  final CrosshairRenderer _crosshairRenderer;
  final OrderRenderer _orderRenderer;
  final DrawingRenderer _drawingRenderer;

  ChartPainter({
    required this.candles,
    required this.viewport,
    required this.theme,
    required this.timeframe,
    this.candleStyle = CandleStyle.candles,
    this.overlayIndicators = const [],
    this.subPaneIndicator,
    this.orders = const [],
    this.positions = const [],
    this.drawings = const [],
    this.previewDrawing,
    this.crosshairPosition,
    this.showVolume = true,
    this.showGrid = true,
    this.showWatermark = true,
    this.showCountdownTimer = true,
    this.countdownText,
    this.symbol = 'NIFTY 50',
    this.exchange = 'NSE',
    this.verticalScale = 1.0,
    this.verticalPan = 0.0,
  })  : _gridRenderer = GridRenderer(theme),
        _candleRenderer = CandleRenderer(theme),
        _volumeRenderer = VolumeRenderer(theme),
        _indicatorRenderer = IndicatorRenderer(theme),
        _currentPriceRenderer = CurrentPriceRenderer(theme),
        _axisRenderer = AxisRenderer(theme),
        _crosshairRenderer = CrosshairRenderer(theme),
        _orderRenderer = OrderRenderer(theme),
        _drawingRenderer = DrawingRenderer(theme);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Save canvas state and strictly clip to widget size
    canvas.save();
    canvas.clipRect(Offset.zero & size);

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

    if (candles.isEmpty) {
      canvas.restore();
      return;
    }

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
        final subRange = _calculateSubPaneRange(subPaneIndicator!, visible);
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

    // 5.5 Draw Background Watermark (behind candles)
    if (showWatermark && candles.isNotEmpty) {
      _drawWatermark(canvas, layout.mainPaneBounds);
    }

    // Clip to main pane bounds for candles, volume, overlay indicators, and drawings
    // Prevents drawing above the top boundary or over axes
    canvas.save();
    canvas.clipRect(layout.mainPaneBounds);

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

    // 8b. Draw Interactive Chart Drawings (Trendlines, Fib, Position Boxes, Ruler)
    final allDrawings = [
      ...drawings,
      ?previewDrawing,
    ];
    if (allDrawings.isNotEmpty) {
      _drawingRenderer.drawDrawings(
        canvas: canvas,
        bounds: layout.mainPaneBounds,
        drawings: allDrawings,
        priceRange: priceRange,
        converter: converter,
      );
    }

    canvas.restore();

    // 8c. Draw Active Orders, Stop Loss & Take Profit brackets
    if (orders.isNotEmpty) {
      _orderRenderer.drawOrders(
        canvas: canvas,
        bounds: layout.mainPaneBounds,
        orders: orders,
        priceRange: priceRange,
      );
    }

    // 8d. Draw Executed Open Positions & Live Unrealized P&L
    if (positions.isNotEmpty) {
      final currentPrice = candles.isNotEmpty ? candles.last.close : 0.0;
      _orderRenderer.drawPositions(
        canvas: canvas,
        bounds: layout.mainPaneBounds,
        positions: positions,
        priceRange: priceRange,
        currentPrice: currentPrice,
      );
    }

    // 9. Draw Current Price Line, Pulse Beacon & Countdown Badge
    if (candles.isNotEmpty) {
      final lastCandleX = converter.indexToX(candles.length - 1);
      _currentPriceRenderer.drawCurrentPrice(
        canvas: canvas,
        mainBounds: layout.mainPaneBounds,
        axisBounds: layout.priceAxisBounds,
        latestCandle: candles.last,
        priceRange: priceRange,
        latestCandleX: lastCandleX,
        countdownText: countdownText,
        showCountdownTimer: showCountdownTimer,
      );
    }

    // 10. Draw Sub-pane Indicator (e.g. RSI, MACD)
    if (layout.subPaneBounds != null && subPaneIndicator != null) {
      final subRange = _calculateSubPaneRange(subPaneIndicator!, visible);
      _indicatorRenderer.drawSubPane(
        canvas: canvas,
        bounds: layout.subPaneBounds!,
        indicator: subPaneIndicator!,
        visible: visible,
        converter: converter,
        priceRange: subRange,
        candleWidth: viewport.candleWidth,
      );

      // Sub-pane price scale
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

    // Restore root canvas clip
    canvas.restore();
  }

  void _drawWatermark(Canvas canvas, Rect bounds) {
    final watermarkColor = theme.axisTextColor.withValues(alpha: 0.045);
    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '$symbol\n',
          style: TextStyle(
            color: watermarkColor,
            fontSize: math.min(bounds.width * 0.08, 48.0),
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),
        TextSpan(
          text: '${timeframe.shortLabel} • $exchange',
          style: TextStyle(
            color: watermarkColor,
            fontSize: math.min(bounds.width * 0.035, 20.0),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final center = bounds.center;
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)),
    );
  }

  PriceRange _calculateSubPaneRange(IndicatorResult indicator, VisibleIndices visible) {
    if (indicator.fixedMin != null && indicator.fixedMax != null) {
      return PriceRange(indicator.fixedMin!, indicator.fixedMax!);
    }

    double minVal = double.infinity;
    double maxVal = -double.infinity;

    for (final s in indicator.series) {
      for (int i = visible.start; i <= visible.end; i++) {
        if (i >= 0 && i < s.values.length) {
          final val = s.values[i];
          if (val != null && !val.isNaN && !val.isInfinite) {
            if (val < minVal) minVal = val;
            if (val > maxVal) maxVal = val;
          }
        }
      }
    }

    // Always include zero baseline if horizontalLevels contains 0.0
    if (indicator.horizontalLevels?.contains(0.0) == true || (minVal < double.infinity && minVal > 0) || (maxVal > -double.infinity && maxVal < 0)) {
      if (minVal > 0) minVal = 0.0;
      if (maxVal < 0) maxVal = 0.0;
    }

    if (minVal.isInfinite || maxVal.isInfinite || minVal == maxVal) {
      minVal = -1.0;
      maxVal = 1.0;
    }

    final span = maxVal - minVal;
    final padding = span * 0.15;
    return PriceRange(minVal - padding, maxVal + padding);
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.viewport != viewport ||
        oldDelegate.crosshairPosition != crosshairPosition ||
        oldDelegate.orders != orders ||
        oldDelegate.positions != positions ||
        oldDelegate.drawings != drawings ||
        oldDelegate.previewDrawing != previewDrawing ||
        oldDelegate.showWatermark != showWatermark ||
        oldDelegate.showCountdownTimer != showCountdownTimer ||
        oldDelegate.countdownText != countdownText ||
        oldDelegate.symbol != symbol ||
        oldDelegate.exchange != exchange ||
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
