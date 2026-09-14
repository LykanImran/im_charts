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

      // Special rendering for Bollinger Bands (fill area between upper and lower)
      if (indicator.indicatorId.startsWith('BB_') && indicator.series.length == 3) {
        _drawBollingerBandsFill(
          canvas: canvas,
          bounds: bounds,
          indicator: indicator,
          visible: visible,
          priceRange: priceRange,
          converter: converter,
        );
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

  /// Draws sub-pane indicators (e.g. RSI) inside the dedicated sub-pane bounds.
  void drawSubPane({
    required Canvas canvas,
    required Rect bounds,
    required IndicatorResult indicator,
    required VisibleIndices visible,
    required CoordinateConverter converter,
  }) {
    final range = PriceRange(
      indicator.fixedMin ?? 0.0,
      indicator.fixedMax ?? 100.0,
    );

    // Draw horizontal reference levels (e.g. 30, 50, 70)
    if (indicator.horizontalLevels != null) {
      final levelPaint = Paint()
        ..color = theme.gridColor
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

    // Draw series lines
    for (final s in indicator.series) {
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

  void _drawSeriesLine({
    required Canvas canvas,
    required Rect bounds,
    required IndicatorSeries series,
    required VisibleIndices visible,
    required PriceRange priceRange,
    required CoordinateConverter converter,
  }) {
    final path = Path();
    bool hasStarted = false;

    final linePaint = Paint()
      ..color = series.color
      ..strokeWidth = series.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

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

  void _drawBollingerBandsFill({
    required Canvas canvas,
    required Rect bounds,
    required IndicatorResult indicator,
    required VisibleIndices visible,
    required PriceRange priceRange,
    required CoordinateConverter converter,
  }) {
    final upper = indicator.series.firstWhere((s) => s.id == 'upper', orElse: () => indicator.series[0]);
    final lower = indicator.series.firstWhere((s) => s.id == 'lower', orElse: () => indicator.series[2]);

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
