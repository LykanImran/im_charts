import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/models/chart_drawing.dart';
import '../../core/models/chart_theme.dart';
import '../../core/models/price_range.dart';

/// High-performance Skia/Impeller renderer for interactive chart drawings:
/// Trendlines, Horizontal Lines, Rectangles, Fibonacci Retracements,
/// Long/Short Risk:Reward boxes, and Rulers.
class DrawingRenderer {
  final ChartTheme theme;

  const DrawingRenderer(this.theme);

  void drawDrawings({
    required Canvas canvas,
    required Rect bounds,
    required List<ChartDrawing> drawings,
    required PriceRange priceRange,
    required CoordinateConverter converter,
  }) {
    if (drawings.isEmpty) return;

    for (final drawing in drawings) {
      if (drawing.points.isEmpty) continue;

      switch (drawing.tool) {
        case DrawingTool.pointer:
          break;
        case DrawingTool.trendline:
          _drawTrendline(canvas, bounds, drawing, priceRange, converter);
          break;
        case DrawingTool.horizontalLine:
          _drawHorizontalLine(canvas, bounds, drawing, priceRange);
          break;
        case DrawingTool.rectangle:
          _drawRectangle(canvas, bounds, drawing, priceRange, converter);
          break;
        case DrawingTool.fibonacci:
          _drawFibonacci(canvas, bounds, drawing, priceRange, converter);
          break;
        case DrawingTool.longPosition:
          _drawPositionBox(canvas, bounds, drawing, priceRange, converter, isLong: true);
          break;
        case DrawingTool.shortPosition:
          _drawPositionBox(canvas, bounds, drawing, priceRange, converter, isLong: false);
          break;
        case DrawingTool.ruler:
          _drawRuler(canvas, bounds, drawing, priceRange, converter);
          break;
      }
    }
  }

  void _drawHandle(Canvas canvas, Offset offset, Color color, {double radius = 4.5}) {
    // Subtle shadow
    canvas.drawCircle(
      offset.translate(0, 1),
      radius + 0.5,
      Paint()..color = Colors.black45,
    );
    // White center fill
    canvas.drawCircle(
      offset,
      radius,
      Paint()..color = Colors.white,
    );
    // Colored border
    canvas.drawCircle(
      offset,
      radius,
      Paint()
        ..color = color
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawTrendline(
    Canvas canvas,
    Rect bounds,
    ChartDrawing drawing,
    PriceRange priceRange,
    CoordinateConverter converter,
  ) {
    if (drawing.points.length < 2) return;
    final p1 = drawing.points[0];
    final p2 = drawing.points[1];

    final x1 = converter.indexToX(p1.candleIndex);
    final y1 = CoordinateConverter.priceToY(p1.price, bounds, priceRange);
    final x2 = converter.indexToX(p2.candleIndex);
    final y2 = CoordinateConverter.priceToY(p2.price, bounds, priceRange);

    final linePaint = Paint()
      ..color = drawing.color
      ..strokeWidth = drawing.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);

    // Draw circular anchor handles ONLY if selected or preview
    if (drawing.isSelected || drawing.id == 'preview') {
      _drawHandle(canvas, Offset(x1, y1), drawing.color);
      _drawHandle(canvas, Offset(x2, y2), drawing.color);

      // Angle & Price delta telemetry badge
      final deltaY = y2 - y1;
      final deltaX = x2 - x1;
      final angle = (math.atan2(-deltaY, deltaX) * 180 / math.pi).round();
      final deltaPrice = p2.price - p1.price;
      final sign = deltaPrice >= 0 ? '+' : '';
      final label = '$angle° • $sign${deltaPrice.toStringAsFixed(2)}';

      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final mid = Offset((x1 + x2) / 2, (y1 + y2) / 2);
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: mid.translate(0, -12), width: tp.width + 10, height: tp.height + 4),
        const Radius.circular(3),
      );
      canvas.drawRRect(pillRect, Paint()..color = const Color(0xE61E222D));
      canvas.drawRRect(pillRect, Paint()..color = drawing.color..strokeWidth = 1.0..style = PaintingStyle.stroke);
      tp.paint(canvas, Offset(pillRect.left + 5, pillRect.top + 2));
    }
  }

  void _drawHorizontalLine(
    Canvas canvas,
    Rect bounds,
    ChartDrawing drawing,
    PriceRange priceRange,
  ) {
    final p = drawing.points.first;
    final y = CoordinateConverter.priceToY(p.price, bounds, priceRange);

    if (y < bounds.top - 10 || y > bounds.bottom + 10) return;

    final linePaint = Paint()
      ..color = drawing.color
      ..strokeWidth = drawing.strokeWidth
      ..style = PaintingStyle.stroke;

    // Solid line across entire viewport
    canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), linePaint);

    // If selected, draw grab handle at center and highlight glow
    if (drawing.isSelected || drawing.id == 'preview') {
      _drawHandle(canvas, Offset(bounds.center.dx, y), drawing.color, radius: 5.5);
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y),
        Paint()
          ..color = drawing.color.withValues(alpha: 0.25)
          ..strokeWidth = drawing.strokeWidth + 4.0
          ..style = PaintingStyle.stroke,
      );
    }

    // Pill badge on the right
    final textSpan = TextSpan(
      text: p.price.toStringAsFixed(2),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
      ),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        bounds.right - textPainter.width - 16,
        y - (textPainter.height / 2) - 3,
        textPainter.width + 12,
        textPainter.height + 6,
      ),
      const Radius.circular(3),
    );

    canvas.drawRRect(badgeRect, Paint()..color = drawing.color);
    textPainter.paint(canvas, Offset(badgeRect.left + 6, badgeRect.top + 3));
  }

  void _drawRectangle(
    Canvas canvas,
    Rect bounds,
    ChartDrawing drawing,
    PriceRange priceRange,
    CoordinateConverter converter,
  ) {
    if (drawing.points.length < 2) return;
    final p1 = drawing.points[0];
    final p2 = drawing.points[1];

    final x1 = converter.indexToX(p1.candleIndex);
    final y1 = CoordinateConverter.priceToY(p1.price, bounds, priceRange);
    final x2 = converter.indexToX(p2.candleIndex);
    final y2 = CoordinateConverter.priceToY(p2.price, bounds, priceRange);

    final left = math.min(x1, x2);
    final right = math.max(x1, x2);
    final top = math.min(y1, y2);
    final bottom = math.max(y1, y2);
    final rect = Rect.fromLTRB(left, top, right, bottom);

    // Shaded box fill
    canvas.drawRect(
      rect,
      Paint()..color = drawing.color.withValues(alpha: 0.15),
    );

    // Border
    canvas.drawRect(
      rect,
      Paint()
        ..color = drawing.color
        ..strokeWidth = drawing.strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // If selected or previewing, draw 4 corner handles
    if (drawing.isSelected || drawing.id == 'preview') {
      _drawHandle(canvas, Offset(x1, y1), drawing.color);
      _drawHandle(canvas, Offset(x2, y1), drawing.color);
      _drawHandle(canvas, Offset(x2, y2), drawing.color);
      _drawHandle(canvas, Offset(x1, y2), drawing.color);

      // Telemetry pill
      final deltaPrice = (p2.price - p1.price).abs();
      final textSpan = TextSpan(
        text: 'Zone: ₹${deltaPrice.toStringAsFixed(2)}',
        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 6, top - tp.height - 6, tp.width + 10, tp.height + 4),
        const Radius.circular(3),
      );
      canvas.drawRRect(pillRect, Paint()..color = drawing.color);
      tp.paint(canvas, Offset(pillRect.left + 5, pillRect.top + 2));
    }
  }

  void _drawFibonacci(
    Canvas canvas,
    Rect bounds,
    ChartDrawing drawing,
    PriceRange priceRange,
    CoordinateConverter converter,
  ) {
    if (drawing.points.length < 2) return;
    final p1 = drawing.points[0];
    final p2 = drawing.points[1];

    final x1 = converter.indexToX(p1.candleIndex);
    final x2 = converter.indexToX(p2.candleIndex);
    final minX = math.min(x1, x2);
    final maxX = math.max(bounds.right, math.max(x1, x2));

    final priceStart = p1.price;
    final priceDiff = p2.price - p1.price;

    final fibLevels = const [
      (ratio: 0.0, label: '0.0% (0.0)', color: Color(0xFF787B86)),
      (ratio: 0.236, label: '23.6% (0.236)', color: Color(0xFFF23645)),
      (ratio: 0.382, label: '38.2% (0.382)', color: Color(0xFFFF9800)),
      (ratio: 0.500, label: '50.0% (0.5)', color: Color(0xFF4CAF50)),
      (ratio: 0.618, label: '61.8% (0.618) Golden', color: Color(0xFF00E676)),
      (ratio: 0.786, label: '78.6% (0.786)', color: Color(0xFF00BCD4)),
      (ratio: 1.000, label: '100.0% (1.0)', color: Color(0xFF2962FF)),
    ];

    double? prevY;
    Color? prevColor;

    for (final fib in fibLevels) {
      final levelPrice = priceStart + (priceDiff * fib.ratio);
      final y = CoordinateConverter.priceToY(levelPrice, bounds, priceRange);

      // Shaded band between levels
      if (prevY != null && prevColor != null) {
        final bandRect = Rect.fromLTRB(minX, math.min(prevY, y), maxX, math.max(prevY, y));
        canvas.drawRect(
          bandRect,
          Paint()..color = prevColor.withValues(alpha: 0.06),
        );
      }
      prevY = y;
      prevColor = fib.color;

      if (y >= bounds.top && y <= bounds.bottom) {
        // Horizontal level line
        canvas.drawLine(
          Offset(minX, y),
          Offset(maxX, y),
          Paint()
            ..color = fib.color.withValues(alpha: 0.7)
            ..strokeWidth = 1.0,
        );

        // Level label
        final labelText = '${fib.label}  ${levelPrice.toStringAsFixed(2)}';
        final textSpan = TextSpan(
          text: labelText,
          style: TextStyle(
            color: fib.color,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        );
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(minX + 8, y - tp.height - 2));
      }
    }

    if (drawing.isSelected || drawing.id == 'preview') {
      final y1 = CoordinateConverter.priceToY(p1.price, bounds, priceRange);
      final y2 = CoordinateConverter.priceToY(p2.price, bounds, priceRange);
      _drawHandle(canvas, Offset(x1, y1), drawing.color);
      _drawHandle(canvas, Offset(x2, y2), drawing.color);
    }
  }

  void _drawPositionBox(
    Canvas canvas,
    Rect bounds,
    ChartDrawing drawing,
    PriceRange priceRange,
    CoordinateConverter converter, {
    required bool isLong,
  }) {
    final entry = drawing.points.first;
    final entryY = CoordinateConverter.priceToY(entry.price, bounds, priceRange);
    final entryX = converter.indexToX(entry.candleIndex);

    // Box width spans 40 candles (or to end of chart)
    final widthSpan = (drawing.properties['widthSpan'] as double?) ?? (40 * 11.0);
    final rightX = (entryX + widthSpan).clamp(entryX + 50.0, bounds.right);

    // Target and Stop prices
    final targetPrice = drawing.properties['targetPrice'] as double? ??
        (isLong ? entry.price * 1.015 : entry.price * 0.985);
    final stopPrice = drawing.properties['stopPrice'] as double? ??
        (isLong ? entry.price * 0.9925 : entry.price * 1.0075);

    final targetY = CoordinateConverter.priceToY(targetPrice, bounds, priceRange);
    final stopY = CoordinateConverter.priceToY(stopPrice, bounds, priceRange);

    final targetDiff = (targetPrice - entry.price).abs();
    final stopDiff = (entry.price - stopPrice).abs();
    final rrRatio = stopDiff > 0 ? (targetDiff / stopDiff) : 0.0;

    // 1. Target Zone (Green Profit Box)
    final targetTop = math.min(entryY, targetY);
    final targetBottom = math.max(entryY, targetY);
    final targetRect = Rect.fromLTRB(entryX, targetTop, rightX, targetBottom);

    canvas.drawRect(targetRect, Paint()..color = const Color(0x2800E676));
    canvas.drawRect(
      targetRect,
      Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // 2. Stop Zone (Red Loss Box)
    final stopTop = math.min(entryY, stopY);
    final stopBottom = math.max(entryY, stopY);
    final stopRect = Rect.fromLTRB(entryX, stopTop, rightX, stopBottom);

    canvas.drawRect(stopRect, Paint()..color = const Color(0x28FF3B30));
    canvas.drawRect(
      stopRect,
      Paint()
        ..color = const Color(0xFFFF3B30)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // 3. Central Entry Line
    canvas.drawLine(
      Offset(entryX, entryY),
      Offset(rightX, entryY),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.2,
    );

    // 4. Center Telemetry Pill
    final targetPct = ((targetDiff / entry.price) * 100.0).toStringAsFixed(2);
    final stopPct = ((stopDiff / entry.price) * 100.0).toStringAsFixed(2);
    final badgeText =
        '${isLong ? 'LONG' : 'SHORT'} • R:R 1:${rrRatio.toStringAsFixed(2)}  |  Target: +$targetPct%  |  Stop: -$stopPct%';

    final textSpan = TextSpan(
      text: badgeText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset((entryX + rightX) / 2, entryY),
        width: textPainter.width + 16,
        height: textPainter.height + 8,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(badgeRect, Paint()..color = const Color(0xE61E222D));
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = const Color(0xFF2962FF)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
    textPainter.paint(canvas, Offset(badgeRect.left + 8, badgeRect.top + 4));

    // If selected, draw grab handles
    if (drawing.isSelected || drawing.id == 'preview') {
      _drawHandle(canvas, Offset((entryX + rightX) / 2, targetY), const Color(0xFF00E676), radius: 5.0);
      _drawHandle(canvas, Offset((entryX + rightX) / 2, stopY), const Color(0xFFFF3B30), radius: 5.0);
      _drawHandle(canvas, Offset(entryX, entryY), Colors.white, radius: 4.5);
      _drawHandle(canvas, Offset(rightX, entryY), const Color(0xFF2962FF), radius: 4.5);
    }
  }

  void _drawRuler(
    Canvas canvas,
    Rect bounds,
    ChartDrawing drawing,
    PriceRange priceRange,
    CoordinateConverter converter,
  ) {
    if (drawing.points.length < 2) return;
    final p1 = drawing.points[0];
    final p2 = drawing.points[1];

    final x1 = converter.indexToX(p1.candleIndex);
    final y1 = CoordinateConverter.priceToY(p1.price, bounds, priceRange);
    final x2 = converter.indexToX(p2.candleIndex);
    final y2 = CoordinateConverter.priceToY(p2.price, bounds, priceRange);

    final left = math.min(x1, x2);
    final right = math.max(x1, x2);
    final top = math.min(y1, y2);
    final bottom = math.max(y1, y2);
    final boxRect = Rect.fromLTRB(left, top, right, bottom);

    final isPositive = p2.price >= p1.price;
    final boxColor = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF3B30);

    // Shaded bounding area
    canvas.drawRect(boxRect, Paint()..color = boxColor.withValues(alpha: 0.12));
    canvas.drawRect(
      boxRect,
      Paint()
        ..color = boxColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // Diagonal measurement line
    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()
        ..color = boxColor
        ..strokeWidth = 1.5,
    );

    // Measurement badge
    final deltaPrice = (p2.price - p1.price).abs();
    final deltaPct = ((deltaPrice / p1.price) * 100.0).toStringAsFixed(2);
    final barCount = (p2.candleIndex - p1.candleIndex).abs();
    final sign = isPositive ? '+' : '-';
    final label = '$sign${deltaPrice.toStringAsFixed(2)} ($sign$deltaPct%) • $barCount Bars';

    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(boxRect.center.dx, boxRect.center.dy),
        width: tp.width + 14,
        height: tp.height + 6,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(badgeRect, Paint()..color = const Color(0xE61E222D));
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = boxColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
    tp.paint(canvas, Offset(badgeRect.left + 7, badgeRect.top + 3));

    if (drawing.isSelected || drawing.id == 'preview') {
      _drawHandle(canvas, Offset(x1, y1), boxColor);
      _drawHandle(canvas, Offset(x2, y2), boxColor);
    }
  }
}
