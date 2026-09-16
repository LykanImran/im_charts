import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/models/candle.dart';
import '../../core/models/price_range.dart';
import '../../core/models/timeframe.dart';
import '../pane.dart';
import 'base_renderer.dart';

/// Renders the interactive crosshair guidelines, snapped indicators, and axis badges.
class CrosshairRenderer extends BaseRenderer {
  CrosshairRenderer(super.theme);

  void drawCrosshair({
    required Canvas canvas,
    required ChartPaneLayout layout,
    required Offset? pointerPosition,
    required List<Candle> candles,
    required CoordinateConverter converter,
    required PriceRange priceRange,
    required Timeframe timeframe,
  }) {
    if (pointerPosition == null || candles.isEmpty) return;

    final x = pointerPosition.dx;
    final y = pointerPosition.dy;

    // Check bounds
    if (x < 0 || x > layout.mainPaneBounds.right) return;
    if (y < 0 || y > layout.timeAxisBounds.top) return;

    final candleIndex = converter.xToIndex(x);
    if (candleIndex < 0 || candleIndex >= candles.length) return;
    final candle = candles[candleIndex];
    final snappedX = converter.indexToX(candleIndex);

    // 1. Vertical guideline through all panes
    _drawDashedLine(
      canvas: canvas,
      p1: Offset(snappedX, 0),
      p2: Offset(snappedX, layout.timeAxisBounds.top),
      color: theme.crosshairColor,
    );

    // 2. Horizontal guideline across pane
    final isInsideMain = y <= layout.mainPaneBounds.bottom;
    _drawDashedLine(
      canvas: canvas,
      p1: Offset(layout.mainPaneBounds.left, y),
      p2: Offset(layout.mainPaneBounds.right, y),
      color: theme.crosshairColor,
    );

    // 3. Price badge on price axis
    if (isInsideMain) {
      final pointerPrice = CoordinateConverter.yToPrice(
        y,
        layout.mainPaneBounds,
        priceRange,
      );
      _drawBadge(
        canvas: canvas,
        center: Offset(layout.priceAxisBounds.center.dx, y),
        text: pointerPrice.toStringAsFixed(2),
        bgColor: theme.crosshairBadgeBackground,
        textColor: theme.crosshairBadgeTextColor,
      );
    }

    // 4. Timestamp badge on time axis
    final timeStr = _formatTimestamp(candle.timestamp, timeframe);
    _drawBadge(
      canvas: canvas,
      center: Offset(snappedX, layout.timeAxisBounds.center.dy),
      text: timeStr,
      bgColor: theme.crosshairBadgeBackground,
      textColor: theme.crosshairBadgeTextColor,
    );

    // 5. Highlight dot on candle close
    if (isInsideMain) {
      final candleY = CoordinateConverter.priceToY(
        candle.close,
        layout.mainPaneBounds,
        priceRange,
      );
      canvas.drawCircle(
        Offset(snappedX, candleY),
        3.5,
        Paint()
          ..color = theme.crosshairColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(snappedX, candleY),
        1.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawBadge({
    required Canvas canvas,
    required Offset center,
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: theme.axisTextStyle.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
      ..layout();

    final badgeWidth = tp.width + 10.0;
    final badgeHeight = tp.height + 6.0;
    final rect = Rect.fromCenter(
      center: center,
      width: badgeWidth,
      height: badgeHeight,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3.0));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.fill,
    );

    tp.paint(canvas, Offset(rect.left + 5.0, rect.top + 3.0));
  }

  void _drawDashedLine({
    required Canvas canvas,
    required Offset p1,
    required Offset p2,
    required Color color,
    double dashWidth = 3.0,
    double dashSpace = 3.0,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = (p2 - p1).distance;
    if (distance == 0) return;

    final unit = Offset(dx / distance, dy / distance);
    double currentDist = 0.0;

    while (currentDist < distance) {
      final start = p1 + (unit * currentDist);
      final segmentLength = (currentDist + dashWidth < distance)
          ? dashWidth
          : (distance - currentDist);
      final end = start + (unit * segmentLength);
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  String _formatTimestamp(DateTime dt, Timeframe tf) {
    if (tf == Timeframe.oneDay || tf == Timeframe.oneWeek) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } else {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} $h:$m';
    }
  }
}
