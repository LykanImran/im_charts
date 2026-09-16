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
    double? latestCandleX,
    String? countdownText,
    bool showCountdownTimer = true,
  }) {
    final price = latestCandle.close;
    final y = CoordinateConverter.priceToY(price, mainBounds, priceRange);

    if (y < mainBounds.top || y > mainBounds.bottom) return;

    final priceColor = latestCandle.isBullish
        ? theme.bullishColor
        : theme.bearishColor;

    // 1. Dashed horizontal line across mainBounds
    _drawDashedHorizontalLine(
      canvas: canvas,
      y: y,
      startX: mainBounds.left,
      endX: mainBounds.right,
      color: theme.currentPriceLineColor,
    );

    // 2. Glowing Beacon Pulse Dot at latest candle location
    if (latestCandleX != null &&
        latestCandleX >= mainBounds.left &&
        latestCandleX <= mainBounds.right) {
      final glowPaint = Paint()
        ..color = priceColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(latestCandleX, y), 5.5, glowPaint);

      final dotPaint = Paint()
        ..color = priceColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(latestCandleX, y), 2.5, dotPaint);

      final dotBorder = Paint()
        ..color = Colors.white
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(latestCandleX, y), 2.5, dotBorder);
    }

    // 3. Price badge on price axis
    final priceText = price.toStringAsFixed(2);
    final textSpan = TextSpan(
      text: priceText,
      style: theme.axisTextStyle.copyWith(
        color: theme.currentPriceBadgeTextColor,
        fontWeight: FontWeight.bold,
        fontSize: 10.5,
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
      ..color = priceColor
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      badgeRect,
      const Radius.circular(3.0),
    );
    canvas.drawRRect(rrect, badgePaint);

    textPainter.paint(
      canvas,
      Offset(
        badgeRect.left + (badgeRect.width - textPainter.width) / 2.0,
        badgeRect.top + 3.0,
      ),
    );

    // 4. Candle Close Countdown Timer badge directly below the price badge
    if (showCountdownTimer &&
        countdownText != null &&
        countdownText.isNotEmpty) {
      final cdSpan = TextSpan(
        text: countdownText,
        style: TextStyle(
          color: theme.axisTextColor.withValues(alpha: 0.9),
          fontSize: 9.0,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      );
      final cdPainter = TextPainter(
        text: cdSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final cdBadgeHeight = cdPainter.height + 4.0;
      final cdBadgeWidth = axisBounds.width - 6.0;
      final cdTop = badgeRect.bottom + 2.0;

      if (cdTop + cdBadgeHeight <= axisBounds.bottom) {
        final cdRect = Rect.fromLTWH(
          axisBounds.left + 3.0,
          cdTop,
          cdBadgeWidth,
          cdBadgeHeight,
        );

        final cdBgPaint = Paint()
          ..color = const Color(0xDD161A25)
          ..style = PaintingStyle.fill;
        final cdBorderPaint = Paint()
          ..color = const Color(0xFF2A2E39)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;

        final cdRRect = RRect.fromRectAndRadius(
          cdRect,
          const Radius.circular(2.5),
        );
        canvas.drawRRect(cdRRect, cdBgPaint);
        canvas.drawRRect(cdRRect, cdBorderPaint);

        cdPainter.paint(
          canvas,
          Offset(
            cdRect.left + (cdRect.width - cdPainter.width) / 2.0,
            cdRect.top + 2.0,
          ),
        );
      }
    }
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
      final lineEnd = (currentX + dashWidth < endX)
          ? currentX + dashWidth
          : endX;
      canvas.drawLine(Offset(currentX, y), Offset(lineEnd, y), paint);
      currentX += dashWidth + dashSpace;
    }
  }
}
