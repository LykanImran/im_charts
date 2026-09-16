import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart' show Colors;
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/coordinates/viewport.dart';
import '../../core/models/candle.dart';
import '../../core/models/candle_style.dart';
import '../../core/models/price_range.dart';
import 'base_renderer.dart';

/// Ultra-high performance Candlestick painter drawing directly to Skia/Impeller canvas.
/// Supports standard Candles, Hollow Candles, Heikin Ashi, Line, Area, and Bars.
class CandleRenderer extends BaseRenderer {
  late final Paint bullHollowPaint;
  late final Paint lineChartPaint;

  CandleRenderer(super.theme) {
    bullHollowPaint = Paint()
      ..color = theme.bullishColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    lineChartPaint = Paint()
      ..color = theme.currentPriceLineColor
      ..strokeWidth = 2.0
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;
  }

  void drawCandles({
    required Canvas canvas,
    required Rect bounds,
    required List<Candle> candles,
    required VisibleIndices visible,
    required PriceRange priceRange,
    required CoordinateConverter converter,
    required double candleWidth,
    CandleStyle candleStyle = CandleStyle.candles,
  }) {
    if (candles.isEmpty || visible.count <= 0) return;

    switch (candleStyle) {
      case CandleStyle.candles:
        _drawStandardCandles(
          canvas,
          bounds,
          candles,
          visible,
          priceRange,
          converter,
          candleWidth,
        );
        break;
      case CandleStyle.hollowCandles:
        _drawHollowCandles(
          canvas,
          bounds,
          candles,
          visible,
          priceRange,
          converter,
          candleWidth,
        );
        break;
      case CandleStyle.heikinAshi:
        _drawHeikinAshiCandles(
          canvas,
          bounds,
          candles,
          visible,
          priceRange,
          converter,
          candleWidth,
        );
        break;
      case CandleStyle.line:
        _drawLineChart(canvas, bounds, candles, visible, priceRange, converter);
        break;
      case CandleStyle.area:
        _drawAreaChart(canvas, bounds, candles, visible, priceRange, converter);
        break;
      case CandleStyle.bars:
        _drawBarChart(
          canvas,
          bounds,
          candles,
          visible,
          priceRange,
          converter,
          candleWidth,
        );
        break;
    }
  }

  void _drawStandardCandles(
    Canvas canvas,
    Rect bounds,
    List<Candle> candles,
    VisibleIndices visible,
    PriceRange priceRange,
    CoordinateConverter converter,
    double candleWidth,
  ) {
    final halfWidth = math.max(0.5, candleWidth / 2.0);

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= candles.length) continue;
      final c = candles[i];
      final x = converter.indexToX(i);

      if (x + halfWidth < bounds.left || x - halfWidth > bounds.right) {
        continue;
      }

      final isBull = c.isBullish;
      final wickPaint = isBull ? bullWickPaint : bearWickPaint;
      final bodyPaint = isBull ? bullBodyPaint : bearBodyPaint;

      final yHigh = CoordinateConverter.priceToY(c.high, bounds, priceRange);
      final yLow = CoordinateConverter.priceToY(c.low, bounds, priceRange);

      canvas.drawLine(Offset(x, yHigh), Offset(x, yLow), wickPaint);

      final yOpen = CoordinateConverter.priceToY(c.open, bounds, priceRange);
      final yClose = CoordinateConverter.priceToY(c.close, bounds, priceRange);

      final top = math.min(yOpen, yClose);
      var height = (yOpen - yClose).abs();
      if (height < 1.0) height = 1.0;

      canvas.drawRect(
        Rect.fromLTWH(x - halfWidth, top, candleWidth, height),
        bodyPaint,
      );
    }
  }

  void _drawHollowCandles(
    Canvas canvas,
    Rect bounds,
    List<Candle> candles,
    VisibleIndices visible,
    PriceRange priceRange,
    CoordinateConverter converter,
    double candleWidth,
  ) {
    final halfWidth = math.max(0.5, candleWidth / 2.0);

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= candles.length) continue;
      final c = candles[i];
      final x = converter.indexToX(i);

      if (x + halfWidth < bounds.left || x - halfWidth > bounds.right) {
        continue;
      }

      final isBull = c.isBullish;
      final wickPaint = isBull ? bullWickPaint : bearWickPaint;

      final yHigh = CoordinateConverter.priceToY(c.high, bounds, priceRange);
      final yLow = CoordinateConverter.priceToY(c.low, bounds, priceRange);

      canvas.drawLine(Offset(x, yHigh), Offset(x, yLow), wickPaint);

      final yOpen = CoordinateConverter.priceToY(c.open, bounds, priceRange);
      final yClose = CoordinateConverter.priceToY(c.close, bounds, priceRange);

      final top = math.min(yOpen, yClose);
      var height = (yOpen - yClose).abs();
      if (height < 1.0) height = 1.0;

      final bodyRect = Rect.fromLTWH(x - halfWidth, top, candleWidth, height);
      if (isBull) {
        canvas.drawRect(bodyRect, bullHollowPaint);
      } else {
        canvas.drawRect(bodyRect, bearBodyPaint);
      }
    }
  }

  void _drawHeikinAshiCandles(
    Canvas canvas,
    Rect bounds,
    List<Candle> candles,
    VisibleIndices visible,
    PriceRange priceRange,
    CoordinateConverter converter,
    double candleWidth,
  ) {
    final halfWidth = math.max(0.5, candleWidth / 2.0);

    // Track previous HA values
    double prevHaOpen = candles.first.open;
    double prevHaClose = candles.first.close;

    for (int i = 0; i <= visible.end && i < candles.length; i++) {
      final c = candles[i];
      final haClose = (c.open + c.high + c.low + c.close) / 4.0;
      final haOpen = (prevHaOpen + prevHaClose) / 2.0;
      final haHigh = math.max(c.high, math.max(haOpen, haClose));
      final haLow = math.min(c.low, math.min(haOpen, haClose));

      prevHaOpen = haOpen;
      prevHaClose = haClose;

      if (i < visible.start) continue;

      final x = converter.indexToX(i);
      if (x + halfWidth < bounds.left || x - halfWidth > bounds.right) {
        continue;
      }

      final isBull = haClose >= haOpen;
      final wickPaint = isBull ? bullWickPaint : bearWickPaint;
      final bodyPaint = isBull ? bullBodyPaint : bearBodyPaint;

      final yHigh = CoordinateConverter.priceToY(haHigh, bounds, priceRange);
      final yLow = CoordinateConverter.priceToY(haLow, bounds, priceRange);

      canvas.drawLine(Offset(x, yHigh), Offset(x, yLow), wickPaint);

      final yOpen = CoordinateConverter.priceToY(haOpen, bounds, priceRange);
      final yClose = CoordinateConverter.priceToY(haClose, bounds, priceRange);

      final top = math.min(yOpen, yClose);
      var height = (yOpen - yClose).abs();
      if (height < 1.0) height = 1.0;

      canvas.drawRect(
        Rect.fromLTWH(x - halfWidth, top, candleWidth, height),
        bodyPaint,
      );
    }
  }

  void _drawLineChart(
    Canvas canvas,
    Rect bounds,
    List<Candle> candles,
    VisibleIndices visible,
    PriceRange priceRange,
    CoordinateConverter converter,
  ) {
    final path = Path();
    bool isFirst = true;

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= candles.length) continue;
      final x = converter.indexToX(i);
      final y = CoordinateConverter.priceToY(
        candles[i].close,
        bounds,
        priceRange,
      );

      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, lineChartPaint);
  }

  void _drawAreaChart(
    Canvas canvas,
    Rect bounds,
    List<Candle> candles,
    VisibleIndices visible,
    PriceRange priceRange,
    CoordinateConverter converter,
  ) {
    if (visible.count < 2) return;

    final linePath = Path();
    final fillPath = Path();
    bool isFirst = true;
    double firstX = bounds.left;
    double lastX = bounds.right;

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= candles.length) continue;
      final x = converter.indexToX(i);
      final y = CoordinateConverter.priceToY(
        candles[i].close,
        bounds,
        priceRange,
      );

      if (isFirst) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, bounds.bottom);
        fillPath.lineTo(x, y);
        firstX = x;
        isFirst = false;
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      lastX = x;
    }

    fillPath.lineTo(lastX, bounds.bottom);
    fillPath.lineTo(firstX, bounds.bottom);
    fillPath.close();

    final areaGradient = Gradient.linear(
      Offset(0, bounds.top),
      Offset(0, bounds.bottom),
      [
        theme.currentPriceLineColor.withValues(alpha: 0.35),
        theme.currentPriceLineColor.withValues(alpha: 0.02),
        Colors.transparent,
      ],
      [0.0, 0.7, 1.0],
    );

    final areaPaint = Paint()
      ..shader = areaGradient
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, areaPaint);
    canvas.drawPath(linePath, lineChartPaint);
  }

  void _drawBarChart(
    Canvas canvas,
    Rect bounds,
    List<Candle> candles,
    VisibleIndices visible,
    PriceRange priceRange,
    CoordinateConverter converter,
    double candleWidth,
  ) {
    final halfWidth = math.max(1.0, candleWidth / 2.0);

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= candles.length) continue;
      final c = candles[i];
      final x = converter.indexToX(i);

      if (x + halfWidth < bounds.left || x - halfWidth > bounds.right) {
        continue;
      }

      final isBull = c.isBullish;
      final barPaint = isBull ? bullWickPaint : bearWickPaint;

      final yHigh = CoordinateConverter.priceToY(c.high, bounds, priceRange);
      final yLow = CoordinateConverter.priceToY(c.low, bounds, priceRange);
      final yOpen = CoordinateConverter.priceToY(c.open, bounds, priceRange);
      final yClose = CoordinateConverter.priceToY(c.close, bounds, priceRange);

      // Vertical line from high to low
      canvas.drawLine(Offset(x, yHigh), Offset(x, yLow), barPaint);

      // Left tick (Open)
      canvas.drawLine(Offset(x - halfWidth, yOpen), Offset(x, yOpen), barPaint);

      // Right tick (Close)
      canvas.drawLine(
        Offset(x, yClose),
        Offset(x + halfWidth, yClose),
        barPaint,
      );
    }
  }
}
