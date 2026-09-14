import 'package:flutter/material.dart';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/models/chart_order.dart';
import '../../core/models/chart_position.dart';
import '../../core/models/chart_theme.dart';
import '../../core/models/price_range.dart';

/// Renders professional TradingView-style horizontal dotted order lines,
/// interactive pill badges, and connected Stop Loss (SL) and Take Profit (TP) brackets.
class OrderRenderer {
  final ChartTheme theme;

  const OrderRenderer(this.theme);

  void drawOrders({
    required Canvas canvas,
    required Rect bounds,
    required List<ChartOrder> orders,
    required PriceRange priceRange,
  }) {
    if (orders.isEmpty) return;

    for (final order in orders) {
      final orderY = CoordinateConverter.priceToY(order.price, bounds, priceRange);
      final isBuy = order.isBuy;
      final orderColor = isBuy ? const Color(0xFF00E676) : const Color(0xFFFF3B30);

      // 1. Draw Main Order Line & Badge
      if (orderY >= bounds.top - 20 && orderY <= bounds.bottom + 20) {
        _drawDottedLine(
          canvas: canvas,
          y: orderY,
          startX: bounds.left,
          endX: bounds.right,
          color: orderColor,
          dashWidth: 5.0,
          dashSpace: 4.0,
          strokeWidth: 1.2,
        );

        _drawOrderBadge(
          canvas: canvas,
          bounds: bounds,
          y: orderY,
          order: order,
          color: orderColor,
        );
      }

      // 2. Draw Take Profit (TP) Bracket
      if (order.hasTakeProfit) {
        final tpPrice = order.takeProfitPrice!;
        final tpY = CoordinateConverter.priceToY(tpPrice, bounds, priceRange);
        final tpColor = const Color(0xFF00E5FF);

        if (tpY >= bounds.top - 20 && tpY <= bounds.bottom + 20) {
          _drawDottedLine(
            canvas: canvas,
            y: tpY,
            startX: bounds.left,
            endX: bounds.right,
            color: tpColor,
            dashWidth: 4.0,
            dashSpace: 4.0,
            strokeWidth: 1.0,
          );

          _drawBracketBadge(
            canvas: canvas,
            bounds: bounds,
            y: tpY,
            label: 'TP',
            price: tpPrice,
            percentage: order.takeProfitPercentage,
            color: tpColor,
            isProfit: true,
          );

          // Draw vertical bracket connector between parent order line and TP line
          _drawBracketConnector(
            canvas: canvas,
            x: bounds.right - 230,
            y1: orderY,
            y2: tpY,
            color: tpColor,
          );
        }
      }

      // 3. Draw Stop Loss (SL) Bracket
      if (order.hasStopLoss) {
        final slPrice = order.stopLossPrice!;
        final slY = CoordinateConverter.priceToY(slPrice, bounds, priceRange);
        final slColor = const Color(0xFFFF9100);

        if (slY >= bounds.top - 20 && slY <= bounds.bottom + 20) {
          _drawDottedLine(
            canvas: canvas,
            y: slY,
            startX: bounds.left,
            endX: bounds.right,
            color: slColor,
            dashWidth: 4.0,
            dashSpace: 4.0,
            strokeWidth: 1.0,
          );

          _drawBracketBadge(
            canvas: canvas,
            bounds: bounds,
            y: slY,
            label: 'SL',
            price: slPrice,
            percentage: order.stopLossPercentage,
            color: slColor,
            isProfit: false,
          );

          // Draw vertical bracket connector between parent order line and SL line
          _drawBracketConnector(
            canvas: canvas,
            x: bounds.right - 230,
            y1: orderY,
            y2: slY,
            color: slColor,
          );
        }
      }
    }
  }

  void drawPositions({
    required Canvas canvas,
    required Rect bounds,
    required List<ChartPosition> positions,
    required PriceRange priceRange,
    required double currentPrice,
  }) {
    if (positions.isEmpty) return;

    for (final pos in positions) {
      final posY = CoordinateConverter.priceToY(pos.entryPrice, bounds, priceRange);
      final isLong = pos.isLong;
      final posColor = isLong ? const Color(0xFF2962FF) : const Color(0xFFE91E63);

      // 1. Draw Solid Position Line & Pill Badge
      if (posY >= bounds.top - 20 && posY <= bounds.bottom + 20) {
        final linePaint = Paint()
          ..color = posColor.withValues(alpha: 0.85)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke;

        canvas.drawLine(
          Offset(bounds.left, posY),
          Offset(bounds.right, posY),
          linePaint,
        );

        _drawPositionBadge(
          canvas: canvas,
          bounds: bounds,
          y: posY,
          position: pos,
          currentPrice: currentPrice,
          color: posColor,
        );
      }

      // 2. Draw Connected Take Profit (TP) Bracket
      if (pos.hasTakeProfit) {
        final tpPrice = pos.takeProfitPrice!;
        final tpY = CoordinateConverter.priceToY(tpPrice, bounds, priceRange);
        final tpColor = const Color(0xFF00E5FF);

        if (tpY >= bounds.top - 20 && tpY <= bounds.bottom + 20) {
          _drawDottedLine(
            canvas: canvas,
            y: tpY,
            startX: bounds.left,
            endX: bounds.right,
            color: tpColor,
            dashWidth: 4.0,
            dashSpace: 3.0,
            strokeWidth: 1.0,
          );

          _drawBracketBadge(
            canvas: canvas,
            bounds: bounds,
            y: tpY,
            label: 'TP',
            price: tpPrice,
            percentage: pos.takeProfitPercentage,
            color: tpColor,
            isProfit: true,
          );

          _drawBracketConnector(
            canvas: canvas,
            x: bounds.right - 230,
            y1: posY,
            y2: tpY,
            color: tpColor,
          );
        }
      }

      // 3. Draw Connected Stop Loss (SL) Bracket
      if (pos.hasStopLoss) {
        final slPrice = pos.stopLossPrice!;
        final slY = CoordinateConverter.priceToY(slPrice, bounds, priceRange);
        final slColor = const Color(0xFFFF9100);

        if (slY >= bounds.top - 20 && slY <= bounds.bottom + 20) {
          _drawDottedLine(
            canvas: canvas,
            y: slY,
            startX: bounds.left,
            endX: bounds.right,
            color: slColor,
            dashWidth: 4.0,
            dashSpace: 3.0,
            strokeWidth: 1.0,
          );

          _drawBracketBadge(
            canvas: canvas,
            bounds: bounds,
            y: slY,
            label: 'SL',
            price: slPrice,
            percentage: pos.stopLossPercentage,
            color: slColor,
            isProfit: false,
          );

          _drawBracketConnector(
            canvas: canvas,
            x: bounds.right - 230,
            y1: posY,
            y2: slY,
            color: slColor,
          );
        }
      }
    }
  }

  void _drawPositionBadge({
    required Canvas canvas,
    required Rect bounds,
    required double y,
    required ChartPosition position,
    required double currentPrice,
    required Color color,
  }) {
    final sideText = position.side.label;
    final qtyText = position.quantity.toStringAsFixed(position.quantity % 1 == 0 ? 0 : 2);
    final entryText = position.entryPrice.toStringAsFixed(2);
    final pnl = position.unrealizedPnL(currentPrice);
    final pnlPct = position.unrealizedPnLPercentage(currentPrice);
    final isProfit = pnl >= 0;
    final pnlColor = isProfit ? const Color(0xFF00E676) : const Color(0xFFFF3B30);
    final pnlSign = isProfit ? '+' : '';

    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '$sideText ',
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: '$qtyText @ $entryText  ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
        TextSpan(
          text: '$pnlSign₹${pnl.abs().toStringAsFixed(2)} ($pnlSign${pnlPct.toStringAsFixed(2)}%)  ',
          style: TextStyle(
            color: pnlColor,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const TextSpan(
          text: '✖ Close',
          style: TextStyle(
            color: Color(0xFFFF5252),
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const hPadding = 8.0;
    const vPadding = 4.0;
    final badgeWidth = textPainter.width + (hPadding * 2);
    final badgeHeight = textPainter.height + (vPadding * 2);

    final rightX = bounds.right - 18.0;
    final leftX = rightX - badgeWidth;
    final topY = y - (badgeHeight / 2);

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftX, topY, badgeWidth, badgeHeight),
      const Radius.circular(5.0),
    );

    // Background fill & dynamic glow border
    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xFF131722),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = pnlColor.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    textPainter.paint(canvas, Offset(leftX + hPadding, topY + vPadding));
  }

  void _drawDottedLine({
    required Canvas canvas,
    required double y,
    required double startX,
    required double endX,
    required Color color,
    double dashWidth = 5.0,
    double dashSpace = 4.0,
    double strokeWidth = 1.0,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double currentX = startX;
    while (currentX < endX) {
      final lineEnd = (currentX + dashWidth).clamp(startX, endX);
      canvas.drawLine(Offset(currentX, y), Offset(lineEnd, y), paint);
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawOrderBadge({
    required Canvas canvas,
    required Rect bounds,
    required double y,
    required ChartOrder order,
    required Color color,
  }) {
    final sideText = order.isBuy ? 'BUY' : 'SELL';
    final qtyText = order.quantity.toStringAsFixed(order.quantity % 1 == 0 ? 0 : 2);
    final priceText = order.price.toStringAsFixed(2);

    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '$sideText ',
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: '$qtyText @ $priceText  ✖',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const hPadding = 8.0;
    const vPadding = 4.0;
    final badgeWidth = textPainter.width + (hPadding * 2);
    final badgeHeight = textPainter.height + (vPadding * 2);

    final rightX = bounds.right - 18.0;
    final leftX = rightX - badgeWidth;
    final topY = y - (badgeHeight / 2);

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftX, topY, badgeWidth, badgeHeight),
      const Radius.circular(5.0),
    );

    // Background fill & glow
    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xFF161A25),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    textPainter.paint(canvas, Offset(leftX + hPadding, topY + vPadding));
  }

  void _drawBracketBadge({
    required Canvas canvas,
    required Rect bounds,
    required double y,
    required String label,
    required double price,
    required double? percentage,
    required Color color,
    required bool isProfit,
  }) {
    final pctString = percentage != null
        ? ' (${percentage >= 0 ? '+' : ''}${percentage.toStringAsFixed(1)}%)'
        : '';
    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: '${price.toStringAsFixed(2)}$pctString  ✖',
          style: TextStyle(
            color: color.withValues(alpha: 0.95),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const hPadding = 7.0;
    const vPadding = 3.0;
    final badgeWidth = textPainter.width + (hPadding * 2);
    final badgeHeight = textPainter.height + (vPadding * 2);

    final rightX = bounds.right - 18.0;
    final leftX = rightX - badgeWidth;
    final topY = y - (badgeHeight / 2);

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftX, topY, badgeWidth, badgeHeight),
      const Radius.circular(4.0),
    );

    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xFF131722),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    textPainter.paint(canvas, Offset(leftX + hPadding, topY + vPadding));
  }

  void _drawBracketConnector({
    required Canvas canvas,
    required double x,
    required double y1,
    required double y2,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw vertical connector line with tick marks
    canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    canvas.drawLine(Offset(x, y2), Offset(x + 10, y2), paint);
  }
}
