import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/models/chart_alert.dart';
import '../../core/models/chart_theme.dart';
import '../../core/models/price_range.dart';

/// Institutional Skia/Impeller renderer for visual price alerts.
class AlertRenderer {
  final ChartTheme theme;

  const AlertRenderer(this.theme);

  void drawAlerts({
    required Canvas canvas,
    required Rect bounds,
    required Rect priceAxisBounds,
    required List<ChartAlert> alerts,
    required PriceRange priceRange,
  }) {
    if (alerts.isEmpty) return;

    for (final alert in alerts) {
      if (!alert.isActive && !alert.isTriggered) continue;

      final y = CoordinateConverter.priceToY(alert.price, bounds, priceRange);
      if (y < bounds.top || y > bounds.bottom) continue;

      final isTriggered = alert.isTriggered;
      final alertColor = isTriggered
          ? const Color(0xFF787B86)
          : const Color(0xFFFFB300);

      final linePaint = Paint()
        ..color = alertColor.withValues(alpha: isTriggered ? 0.4 : 0.85)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // 1. Draw dashed horizontal alert line across chart pane
      const dashWidth = 5.0;
      const dashSpace = 4.0;
      double currentX = bounds.left;
      while (currentX < bounds.right) {
        canvas.drawLine(
          Offset(currentX, y),
          Offset((currentX + dashWidth).clamp(bounds.left, bounds.right), y),
          linePaint,
        );
        currentX += dashWidth + dashSpace;
      }

      // 2. Draw note pill badge on the canvas (near right edge)
      if (alert.note.isNotEmpty) {
        final notePainter = TextPainter(
          text: TextSpan(
            text: '🔔 ${alert.note}',
            style: TextStyle(
              color: alertColor,
              fontSize: 9.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final noteBadgeWidth = notePainter.width + 10;
        const noteBadgeHeight = 16.0;
        final noteRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            bounds.right - noteBadgeWidth - 8,
            y - (noteBadgeHeight / 2),
            noteBadgeWidth,
            noteBadgeHeight,
          ),
          const Radius.circular(3),
        );

        canvas.drawRRect(
          noteRect,
          Paint()
            ..color = theme.crosshairBadgeBackground.withValues(alpha: 0.9),
        );
        canvas.drawRRect(
          noteRect,
          Paint()
            ..color = alertColor.withValues(alpha: 0.6)
            ..strokeWidth = 0.8
            ..style = PaintingStyle.stroke,
        );

        notePainter.paint(
          canvas,
          Offset(
            noteRect.left + 5,
            noteRect.top + (noteBadgeHeight - notePainter.height) / 2,
          ),
        );
      }

      // 3. Draw solid bell pill badge on the vertical price axis
      final priceText = alert.price.toStringAsFixed(1);
      final pricePainter = TextPainter(
        text: TextSpan(
          text: priceText,
          style: const TextStyle(
            color: Color(0xFF131722),
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const axisBadgeHeight = 18.0;
      final axisBadgeWidth = priceAxisBounds.width - 6;
      final axisBadgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          priceAxisBounds.left + 3,
          y - (axisBadgeHeight / 2),
          axisBadgeWidth,
          axisBadgeHeight,
        ),
        const Radius.circular(3),
      );

      // Badge background
      canvas.drawRRect(axisBadgeRect, Paint()..color = alertColor);

      // Price text centered in axis badge
      pricePainter.paint(
        canvas,
        Offset(
          axisBadgeRect.left + (axisBadgeWidth - pricePainter.width) / 2,
          axisBadgeRect.top + (axisBadgeHeight - pricePainter.height) / 2,
        ),
      );
    }
  }
}
