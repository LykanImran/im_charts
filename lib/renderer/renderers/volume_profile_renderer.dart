import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/models/chart_theme.dart';
import '../../core/models/price_range.dart';
import '../../engine/indicators/volume_profile.dart';

/// Institutional Skia/Impeller renderer for Visible Range Volume Profile (VRVP),
/// Point of Control (POC), and Value Area (VAH / VAL).
class VolumeProfileRenderer {
  final ChartTheme theme;

  const VolumeProfileRenderer(this.theme);

  void drawVolumeProfile({
    required Canvas canvas,
    required Rect bounds,
    required VolumeProfile profile,
    required PriceRange priceRange,
    bool isRightAligned = true,
    double maxProfileWidthRatio = 0.22,
  }) {
    if (profile.bins.isEmpty || profile.maxBinVolume <= 0) return;

    final maxProfileWidth = bounds.width * maxProfileWidthRatio;

    final buyPaint = Paint()
      ..color = const Color(0xFF2962FF).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final sellPaint = Paint()
      ..color = const Color(0xFFFF7043).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    // 1. Draw horizontal volume bars for each price bin
    for (final bin in profile.bins) {
      if (bin.totalVolume <= 0) continue;

      final yTop = CoordinateConverter.priceToY(bin.upperPrice, bounds, priceRange);
      final yBottom = CoordinateConverter.priceToY(bin.lowerPrice, bounds, priceRange);

      final barY = yTop < yBottom ? yTop : yBottom;
      final barHeight = (yBottom - yTop).abs().clamp(1.0, bounds.height);

      if (barY + barHeight < bounds.top || barY > bounds.bottom) continue;

      final buyRatio = bin.buyVolume / profile.maxBinVolume;
      final sellRatio = bin.sellVolume / profile.maxBinVolume;

      final buyWidth = buyRatio * maxProfileWidth;
      final sellWidth = sellRatio * maxProfileWidth;

      if (isRightAligned) {
        final right = bounds.right;
        // Sell volume bar
        if (sellWidth > 0) {
          final sellRect = Rect.fromLTWH(
            right - buyWidth - sellWidth,
            barY,
            sellWidth,
            barHeight - 0.5,
          );
          canvas.drawRect(sellRect, sellPaint);
        }

        // Buy volume bar
        if (buyWidth > 0) {
          final buyRect = Rect.fromLTWH(
            right - buyWidth,
            barY,
            buyWidth,
            barHeight - 0.5,
          );
          canvas.drawRect(buyRect, buyPaint);
        }
      } else {
        // Left aligned
        final left = bounds.left;
        if (buyWidth > 0) {
          final buyRect = Rect.fromLTWH(left, barY, buyWidth, barHeight - 0.5);
          canvas.drawRect(buyRect, buyPaint);
        }
        if (sellWidth > 0) {
          final sellRect = Rect.fromLTWH(left + buyWidth, barY, sellWidth, barHeight - 0.5);
          canvas.drawRect(sellRect, sellPaint);
        }
      }
    }

    // 2. Draw Value Area High (VAH) & Value Area Low (VAL) reference levels
    _drawReferenceLevel(
      canvas: canvas,
      bounds: bounds,
      price: profile.vahPrice,
      priceRange: priceRange,
      label: 'VAH',
      color: const Color(0xFF00B0FF),
    );

    _drawReferenceLevel(
      canvas: canvas,
      bounds: bounds,
      price: profile.valPrice,
      priceRange: priceRange,
      label: 'VAL',
      color: const Color(0xFF00B0FF),
    );

    // 3. Draw Point of Control (POC) with prominent red line and badge
    if (profile.pocPrice != null) {
      final pocY = CoordinateConverter.priceToY(profile.pocPrice!, bounds, priceRange);
      if (pocY >= bounds.top && pocY <= bounds.bottom) {
        final pocPaint = Paint()
          ..color = const Color(0xFFFF1744)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        // Draw solid POC horizontal line across the entire chart
        canvas.drawLine(
          Offset(bounds.left, pocY),
          Offset(bounds.right, pocY),
          pocPaint,
        );

        // Draw POC pill badge on right
        final pocText = 'POC ₹${profile.pocPrice!.toStringAsFixed(1)}';
        final textPainter = TextPainter(
          text: TextSpan(
            text: pocText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final badgeWidth = textPainter.width + 10;
        const badgeHeight = 16.0;
        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            bounds.right - badgeWidth - 4,
            pocY - (badgeHeight / 2),
            badgeWidth,
            badgeHeight,
          ),
          const Radius.circular(3),
        );

        canvas.drawRRect(
          badgeRect,
          Paint()..color = const Color(0xFFFF1744),
        );

        textPainter.paint(
          canvas,
          Offset(
            badgeRect.left + 5,
            badgeRect.top + (badgeHeight - textPainter.height) / 2,
          ),
        );
      }
    }
  }

  void _drawReferenceLevel({
    required Canvas canvas,
    required Rect bounds,
    required double price,
    required PriceRange priceRange,
    required String label,
    required Color color,
  }) {
    final y = CoordinateConverter.priceToY(price, bounds, priceRange);
    if (y < bounds.top || y > bounds.bottom) return;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw dashed level line
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double currentX = bounds.left;
    while (currentX < bounds.right) {
      canvas.drawLine(
        Offset(currentX, y),
        Offset((currentX + dashWidth).clamp(bounds.left, bounds.right), y),
        linePaint,
      );
      currentX += dashWidth + dashSpace;
    }

    // Draw small text label
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$label ₹${price.toStringAsFixed(1)}',
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(bounds.right - textPainter.width - 6, y - textPainter.height - 2),
    );
  }
}
