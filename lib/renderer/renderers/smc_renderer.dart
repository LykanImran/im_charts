import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/models/chart_theme.dart';
import '../../core/models/price_range.dart';
import '../../engine/indicators/smart_money_concepts.dart';

/// Institutional Skia/Impeller hardware-accelerated renderer for Smart Money Concepts (SMC):
/// Fair Value Gaps (FVG), Break of Structure (BOS), Change of Character (CHoCH), and Order Blocks (OB).
class SMCRenderer {
  final ChartTheme theme;

  const SMCRenderer(this.theme);

  void drawSMC({
    required Canvas canvas,
    required Rect bounds,
    required SmartMoneyConcepts smc,
    required PriceRange priceRange,
    required CoordinateConverter converter,
  }) {
    if (converter.totalCandles <= 0) return;

    // 1. Draw Fair Value Gaps (FVG)
    for (final fvg in smc.fvgZones) {
      final startX = converter.indexToX(fvg.startIndex);
      final endX = converter.indexToX(fvg.endIndex).clamp(startX + 8.0, bounds.right);

      final topY = CoordinateConverter.priceToY(
        fvg.topPrice,
        bounds,
        priceRange,
      );
      final bottomY = CoordinateConverter.priceToY(
        fvg.bottomPrice,
        bounds,
        priceRange,
      );

      final rectY = topY < bottomY ? topY : bottomY;
      final rectH = (bottomY - topY).abs().clamp(2.0, bounds.height);

      // Cull if completely off screen
      if (endX < bounds.left || startX > bounds.right) continue;
      if (rectY + rectH < bounds.top || rectY > bounds.bottom) continue;

      final fvgColor = fvg.isBullish
          ? const Color(0xFF00E676)
          : const Color(0xFFFF5252);
      final opacity = fvg.isMitigated ? 0.08 : 0.16;

      final fvgRect = Rect.fromLTWH(
        startX.clamp(bounds.left, bounds.right),
        rectY.clamp(bounds.top, bounds.bottom),
        (endX - startX).clamp(4.0, bounds.width),
        rectH,
      );

      // Translucent FVG box fill
      canvas.drawRect(
        fvgRect,
        Paint()
          ..color = fvgColor.withValues(alpha: opacity)
          ..style = PaintingStyle.fill,
      );

      // FVG border
      canvas.drawRect(
        fvgRect,
        Paint()
          ..color = fvgColor.withValues(alpha: fvg.isMitigated ? 0.25 : 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // 50% Consequent Encroachment (CE) dashed midline
      final midY = CoordinateConverter.priceToY(
        fvg.midPrice,
        bounds,
        priceRange,
      );
      if (midY >= bounds.top && midY <= bounds.bottom) {
        _drawDashedHorizontal(
          canvas: canvas,
          y: midY,
          startX: fvgRect.left,
          endX: fvgRect.right,
          color: fvgColor.withValues(alpha: 0.5),
        );
      }

      // Small FVG Label
      if (fvgRect.width > 28) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: fvg.isBullish ? 'B-FVG' : 'S-FVG',
            style: TextStyle(
              color: fvgColor.withValues(alpha: 0.85),
              fontSize: 8.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            fvgRect.left + 4,
            fvgRect.top + (rectH - textPainter.height) / 2,
          ),
        );
      }
    }

    // 2. Draw Order Blocks (OB)
    for (final ob in smc.orderBlocks) {
      final startX = converter.indexToX(ob.candleIndex);
      final endX = converter.indexToX(ob.endIndex).clamp(startX + 12.0, bounds.right);

      final topY = CoordinateConverter.priceToY(
        ob.topPrice,
        bounds,
        priceRange,
      );
      final bottomY = CoordinateConverter.priceToY(
        ob.bottomPrice,
        bounds,
        priceRange,
      );

      final rectY = topY < bottomY ? topY : bottomY;
      final rectH = (bottomY - topY).abs().clamp(2.0, bounds.height);

      if (endX < bounds.left || startX > bounds.right) continue;
      if (rectY + rectH < bounds.top || rectY > bounds.bottom) continue;

      final obColor = ob.isBullish
          ? const Color(0xFF00E5FF)
          : const Color(0xFFE91E63);

      final obRect = Rect.fromLTWH(
        startX.clamp(bounds.left, bounds.right),
        rectY.clamp(bounds.top, bounds.bottom),
        (endX - startX).clamp(4.0, bounds.width),
        rectH,
      );

      // Translucent OB fill
      canvas.drawRect(
        obRect,
        Paint()
          ..color = obColor.withValues(alpha: ob.isMitigated ? 0.06 : 0.14)
          ..style = PaintingStyle.fill,
      );

      // OB outline
      canvas.drawRect(
        obRect,
        Paint()
          ..color = obColor.withValues(alpha: ob.isMitigated ? 0.2 : 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );

      // OB label
      if (obRect.width > 30) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: ob.isBullish ? 'OB (Demand)' : 'OB (Supply)',
            style: TextStyle(
              color: obColor.withValues(alpha: 0.9),
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(obRect.left + 4, obRect.top + 2),
        );
      }
    }

    // 3. Draw Break of Structure (BOS) & Change of Character (CHoCH)
    for (final sb in smc.structureBreaks) {
      final startX = converter.indexToX(sb.swingIndex);
      final endX = converter.indexToX(sb.breakIndex);

      final y = CoordinateConverter.priceToY(sb.price, bounds, priceRange);

      if (endX < bounds.left || startX > bounds.right) continue;
      if (y < bounds.top || y > bounds.bottom) continue;

      final sbColor = sb.isBullish
          ? const Color(0xFF00E676)
          : const Color(0xFFFF5252);

      // Draw dotted horizontal structure line
      _drawDashedHorizontal(
        canvas: canvas,
        y: y,
        startX: startX,
        endX: endX,
        color: sbColor.withValues(alpha: 0.75),
        dashWidth: 4.0,
        dashSpace: 3.0,
      );

      // Draw BOS / CHoCH pill badge midway between swing and break
      final midX = (startX + endX) / 2.0;
      final textSpan = TextSpan(
        text: sb.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeW = textPainter.width + 8;
      const badgeH = 14.0;
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(midX - (badgeW / 2), y - (badgeH / 2), badgeW, badgeH),
        const Radius.circular(3),
      );

      canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFF131722));
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = sbColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      textPainter.paint(
        canvas,
        Offset(
          badgeRect.left + 4,
          badgeRect.top + (badgeH - textPainter.height) / 2,
        ),
      );
    }
  }

  void _drawDashedHorizontal({
    required Canvas canvas,
    required double y,
    required double startX,
    required double endX,
    required Color color,
    double dashWidth = 3.0,
    double dashSpace = 3.0,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double currentX = startX;
    while (currentX < endX) {
      final lineEnd = (currentX + dashWidth).clamp(startX, endX);
      canvas.drawLine(Offset(currentX, y), Offset(lineEnd, y), paint);
      currentX += dashWidth + dashSpace;
    }
  }
}
