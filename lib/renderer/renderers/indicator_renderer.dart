import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/coordinates/viewport.dart';
import '../../core/models/price_range.dart';
import '../../engine/indicators/indicator_result.dart';
import 'base_renderer.dart';

/// Renders indicator overlay series and sub-pane series with high performance paths.
class IndicatorRenderer extends BaseRenderer {
  IndicatorRenderer(super.theme);

  /// Draws overlay indicators on the main chart pane.
  void drawOverlay({
    required Canvas canvas,
    required Rect bounds,
    required List<IndicatorResult> indicators,
    required VisibleIndices visible,
    required PriceRange priceRange,
    required CoordinateConverter converter,
  }) {
    for (final indicator in indicators) {
      if (!indicator.isOverlay) continue;

      // Special rendering for Bollinger Bands / VWAP bands (fill area between upper and lower)
      if ((indicator.indicatorId.startsWith('BB_') ||
              indicator.indicatorId == 'VWAP') &&
          indicator.series.any((s) => s.id == 'upper') &&
          indicator.series.any((s) => s.id == 'lower')) {
        _drawBandFill(
          canvas: canvas,
          bounds: bounds,
          indicator: indicator,
          visible: visible,
          priceRange: priceRange,
          converter: converter,
        );
      }

      // Special rendering for Supertrend indicator (renders bull support and bear resistance)
      if (indicator.indicatorId.startsWith('SUPERTREND_')) {
        for (final s in indicator.series) {
          if (s.id == 'supertrend_bull' || s.id == 'supertrend_bear') {
            _drawSeriesLine(
              canvas: canvas,
              bounds: bounds,
              series: s,
              visible: visible,
              priceRange: priceRange,
              converter: converter,
            );
          }
        }
        continue;
      }

      // Draw each series line
      for (final s in indicator.series) {
        _drawSeriesLine(
          canvas: canvas,
          bounds: bounds,
          series: s,
          visible: visible,
          priceRange: priceRange,
          converter: converter,
        );
      }
    }
  }

  /// Draws sub-pane indicators (e.g. RSI, MACD) inside the dedicated sub-pane bounds.
  void drawSubPane({
    required Canvas canvas,
    required Rect bounds,
    required IndicatorResult indicator,
    required VisibleIndices visible,
    required CoordinateConverter converter,
    PriceRange? priceRange,
    double candleWidth = 8.0,
  }) {
    final range = priceRange ??
        PriceRange(indicator.fixedMin ?? 0.0, indicator.fixedMax ?? 100.0);

    // Draw horizontal reference levels (e.g. 30, 50, 70 for RSI or 0.0 for MACD)
    if (indicator.horizontalLevels != null) {
      final levelPaint = Paint()
        ..color = theme.gridColor.withValues(alpha: 0.8)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      for (final level in indicator.horizontalLevels!) {
        final y = CoordinateConverter.priceToY(level, bounds, range);
        if (y >= bounds.top && y <= bounds.bottom) {
          canvas.drawLine(
            Offset(bounds.left, y),
            Offset(bounds.right, y),
            levelPaint,
          );
        }
      }
    }

    // Draw histogram series first (if any) so line series render on top
    for (final s in indicator.series) {
      if (s.id == 'histogram') {
        _drawHistogramBars(
          canvas: canvas,
          bounds: bounds,
          series: s,
          visible: visible,
          priceRange: range,
          converter: converter,
          candleWidth: candleWidth,
        );
      }
    }

    // Draw line series
    for (final s in indicator.series) {
      if (s.id == 'histogram') continue;
      _drawSeriesLine(
        canvas: canvas,
        bounds: bounds,
        series: s,
        visible: visible,
        priceRange: range,
        converter: converter,
      );
    }
  }

  void _drawHistogramBars({
    required Canvas canvas,
    required Rect bounds,
    required IndicatorSeries series,
    required VisibleIndices visible,
    required PriceRange priceRange,
    required CoordinateConverter converter,
    required double candleWidth,
  }) {
    final zeroY = CoordinateConverter.priceToY(
      0.0,
      bounds,
      priceRange,
    ).clamp(bounds.top, bounds.bottom);
    final barWidth = (candleWidth * 0.7).clamp(1.5, 24.0);

    final greenPaint = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final redPaint = Paint()
      ..color = const Color(0xFFFF3B30).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= series.values.length) continue;
      final val = series.values[i];
      if (val == null) continue;

      final x = converter.indexToX(i);
      final y = CoordinateConverter.priceToY(val, bounds, priceRange);

      final topY = (val >= 0 ? y : zeroY).clamp(bounds.top, bounds.bottom);
      final bottomY = (val >= 0 ? zeroY : y).clamp(bounds.top, bounds.bottom);

      final barRect = Rect.fromLTRB(
        x - (barWidth / 2),
        topY,
        x + (barWidth / 2),
        bottomY,
      );
      canvas.drawRect(barRect, val >= 0 ? greenPaint : redPaint);
    }
  }

  void _drawSeriesLine({
    required Canvas canvas,
    required Rect bounds,
    required IndicatorSeries series,
    required VisibleIndices visible,
    required PriceRange priceRange,
    required CoordinateConverter converter,
  }) {
    final linePaint = Paint()
      ..color = series.color
      ..strokeWidth = series.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (series.isDashed) {
      // Dashed line: collect all (x,y) points, then draw dash segments
      final points = <Offset>[];
      for (int i = visible.start; i <= visible.end; i++) {
        if (i < 0 || i >= series.values.length) continue;
        final val = series.values[i];
        if (val == null) continue;
        final x = converter.indexToX(i);
        final y = CoordinateConverter.priceToY(val, bounds, priceRange);
        points.add(Offset(x, y));
      }
      const dashLen = 6.0;
      const gapLen = 4.0;
      bool drawing = true;
      double carry = 0.0;
      for (int i = 0; i < points.length - 1; i++) {
        final p1 = points[i];
        final p2 = points[i + 1];
        final dx = p2.dx - p1.dx;
        final dy = p2.dy - p1.dy;
        // Simple dash over segment using lerp
        double traveled = -carry;
        while (traveled < (p2.dx - p1.dx).abs().clamp(1.0, double.infinity)) {
          final segDist = (p2.dx - p1.dx).abs().clamp(1.0, double.infinity);
          final t1 = (traveled / segDist).clamp(0.0, 1.0);
          final t2 = ((traveled + (drawing ? dashLen : gapLen)) / segDist).clamp(0.0, 1.0);
          if (drawing) {
            canvas.drawLine(
              Offset(p1.dx + dx * t1, p1.dy + dy * t1),
              Offset(p1.dx + dx * t2, p1.dy + dy * t2),
              linePaint,
            );
          }
          traveled += drawing ? dashLen : gapLen;
          drawing = !drawing;
        }
        carry = traveled - (p2.dx - p1.dx).abs().clamp(1.0, double.infinity);
      }
      return;
    }

    final path = Path();
    bool hasStarted = false;

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= series.values.length) continue;
      final val = series.values[i];
      if (val == null) continue;

      final x = converter.indexToX(i);
      final y = CoordinateConverter.priceToY(val, bounds, priceRange);

      if (!hasStarted) {
        path.moveTo(x, y);
        hasStarted = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (hasStarted) {
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawBandFill({
    required Canvas canvas,
    required Rect bounds,
    required IndicatorResult indicator,
    required VisibleIndices visible,
    required PriceRange priceRange,
    required CoordinateConverter converter,
  }) {
    final upper = indicator.series.firstWhere(
      (s) => s.id == 'upper',
      orElse: () => indicator.series[0],
    );
    final lower = indicator.series.firstWhere(
      (s) => s.id == 'lower',
      orElse: () => indicator.series[2],
    );

    final fillPath = Path();
    bool started = false;

    // Trace forward along upper band
    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= upper.values.length) continue;
      final val = upper.values[i];
      if (val == null) continue;

      final x = converter.indexToX(i);
      final y = CoordinateConverter.priceToY(val, bounds, priceRange);

      if (!started) {
        fillPath.moveTo(x, y);
        started = true;
      } else {
        fillPath.lineTo(x, y);
      }
    }

    // Trace backward along lower band
    if (started) {
      for (int i = visible.end; i >= visible.start; i--) {
        if (i < 0 || i >= lower.values.length) continue;
        final val = lower.values[i];
        if (val == null) continue;

        final x = converter.indexToX(i);
        final y = CoordinateConverter.priceToY(val, bounds, priceRange);
        fillPath.lineTo(x, y);
      }

      fillPath.close();

      final fillPaint = Paint()
        ..color = upper.color.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }
  }
}
