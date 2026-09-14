import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/models/candle.dart';
import '../../core/models/price_range.dart';
import 'base_renderer.dart';

/// Renders the real-time Last Traded Price (LTP) horizontal guide line and glowing price badge.
class CurrentPriceRenderer extends BaseRenderer {
  CurrentPriceRenderer(super.theme);

  void drawCurrentPrice({
    required Canvas canvas,
    required Rect mainBounds,
    required Rect axisBounds,
    required Candle latestCandle,
    required PriceRange priceRange,
  }) {
    final price = latestCandle.close;
    final y = CoordinateConverter.priceToY(price, mainBounds, priceRange);

    if (y < mainBounds.top || y > mainBounds.bottom) return;

    // 1. Dashed horizontal line across mainBounds
    _drawDashedHorizontalLine(
      canvas: canvas,
      y: y,
      startX: mainBounds.left,
      endX: mainBounds.right,
      color: theme.currentPriceLineColor,
    );

    // 2. Price badge on price axis
    final priceText = price.toStringAsFixed(2);
    final textSpan = TextSpan(
      text: priceText,
      style: theme.axisTextStyle.copyWith(
        color: theme.currentPriceBadgeTextColor,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeHeight = textPainter.height + 6.0;
    final badgeWidth = axisBounds.width - 4.0;
    final badgeRect = Rect.fromLTWH(
      axisBounds.left + 2.0,
      y - (badgeHeight / 2.0),
      badgeWidth,
      badgeHeight,
    );

    final badgePaint = Paint()
      ..color = latestCandle.isBullish ? theme.bullishColor : theme.bearishColor
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(3.0));
    canvas.drawRRect(rrect, badgePaint);

    textPainter.paint(
      canvas,
      Offset(
        badgeRect.left + (badgeRect.width - textPainter.width) / 2.0,
        badgeRect.top + 3.0,
      ),
    );
  }

  void _drawDashedHorizontalLine({
    required Canvas canvas,
    required double y,
    required double startX,
    required double endX,
    required Color color,
    double dashWidth = 4.0,
    double dashSpace = 4.0,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double currentX = startX;
    while (currentX < endX) {
      final lineEnd = (currentX + dashWidth < endX) ? currentX + dashWidth : endX;
      canvas.drawLine(Offset(currentX, y), Offset(lineEnd, y), paint);
      currentX += dashWidth + dashSpace;
    }
  }
}
