import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../coordinates/coordinate_converter.dart';
import 'price_range.dart';

/// Available interactive drawing tools on the chart.
enum DrawingTool {
  pointer,
  trendline,
  horizontalLine,
  horizontalRay,
  verticalLine,
  rectangle,
  fibonacci,
  longPosition,
  shortPosition,
  ruler,
}

extension DrawingToolExtension on DrawingTool {
  String get label {
    switch (this) {
      case DrawingTool.pointer:
        return 'Cursor';
      case DrawingTool.trendline:
        return 'Trendline';
      case DrawingTool.horizontalLine:
        return 'Horizontal Line';
      case DrawingTool.horizontalRay:
        return 'Horizontal Ray';
      case DrawingTool.verticalLine:
        return 'Vertical Line';
      case DrawingTool.rectangle:
        return 'Rectangle';
      case DrawingTool.fibonacci:
        return 'Fibonacci Retracement';
      case DrawingTool.longPosition:
        return 'Long Position';
      case DrawingTool.shortPosition:
        return 'Short Position';
      case DrawingTool.ruler:
        return 'Measure Ruler';
    }
  }

  IconData get icon {
    switch (this) {
      case DrawingTool.pointer:
        return Icons.near_me_outlined;
      case DrawingTool.trendline:
        return Icons.trending_up;
      case DrawingTool.horizontalLine:
        return Icons.horizontal_rule;
      case DrawingTool.horizontalRay:
        return Icons.arrow_right_alt;
      case DrawingTool.verticalLine:
        return Icons.vertical_align_center;
      case DrawingTool.rectangle:
        return Icons.crop_square_outlined;
      case DrawingTool.fibonacci:
        return Icons.stacked_bar_chart;
      case DrawingTool.longPosition:
        return Icons.arrow_outward;
      case DrawingTool.shortPosition:
        return Icons.south_east;
      case DrawingTool.ruler:
        return Icons.straighten_outlined;
    }
  }

  /// Number of clicks/points required to complete this drawing on the chart.
  int get requiredPoints {
    switch (this) {
      case DrawingTool.pointer:
        return 0;
      case DrawingTool.horizontalLine:
      case DrawingTool.horizontalRay:
      case DrawingTool.verticalLine:
      case DrawingTool.longPosition:
      case DrawingTool.shortPosition:
        return 1;
      case DrawingTool.trendline:
      case DrawingTool.rectangle:
      case DrawingTool.fibonacci:
      case DrawingTool.ruler:
        return 2;
    }
  }
}

/// A geometric anchor point in chart coordinates (index and price).
/// Using candle index and price ensures drawings remain pinned to the exact
/// financial levels across zooming, panning, and new tick arrivals.
class DrawingPoint {
  final int candleIndex;
  final double price;
  final DateTime? timestamp;

  const DrawingPoint({
    required this.candleIndex,
    required this.price,
    this.timestamp,
  });

  DrawingPoint copyWith({
    int? candleIndex,
    double? price,
    DateTime? timestamp,
  }) {
    return DrawingPoint(
      candleIndex: candleIndex ?? this.candleIndex,
      price: price ?? this.price,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'candleIndex': candleIndex,
        'price': price,
        if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      };

  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    return DrawingPoint(
      candleIndex: json['candleIndex'] as int,
      price: (json['price'] as num).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

/// Represents a persistent interactive user drawing on the chart canvas.
class ChartDrawing {
  final String id;
  final DrawingTool tool;
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;
  final bool isLocked;
  final bool isSelected;
  final Map<String, dynamic> properties;

  const ChartDrawing({
    required this.id,
    required this.tool,
    required this.points,
    this.color = const Color(0xFF2962FF),
    this.strokeWidth = 1.8,
    this.isLocked = false,
    this.isSelected = false,
    this.properties = const {},
  });

  ChartDrawing copyWith({
    String? id,
    DrawingTool? tool,
    List<DrawingPoint>? points,
    Color? color,
    double? strokeWidth,
    bool? isLocked,
    bool? isSelected,
    Map<String, dynamic>? properties,
  }) {
    return ChartDrawing(
      id: id ?? this.id,
      tool: tool ?? this.tool,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isLocked: isLocked ?? this.isLocked,
      isSelected: isSelected ?? this.isSelected,
      properties: properties ?? this.properties,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tool': tool.name,
        'points': points.map((p) => p.toJson()).toList(),
        'color': color.toARGB32(),
        'strokeWidth': strokeWidth,
        'isLocked': isLocked,
        'isSelected': isSelected,
        'properties': properties,
      };

  factory ChartDrawing.fromJson(Map<String, dynamic> json) {
    return ChartDrawing(
      id: json['id'] as String,
      tool: DrawingTool.values.firstWhere(
        (t) => t.name == json['tool'],
        orElse: () => DrawingTool.pointer,
      ),
      points: (json['points'] as List<dynamic>?)
              ?.map((p) => DrawingPoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      color: json['color'] != null
          ? Color(json['color'] as int)
          : const Color(0xFF2962FF),
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.8,
      isLocked: json['isLocked'] as bool? ?? false,
      isSelected: json['isSelected'] as bool? ?? false,
      properties: json['properties'] != null
          ? Map<String, dynamic>.from(json['properties'] as Map)
          : const {},
    );
  }

  /// Calculates perpendicular distance from point [p] to segment between [a] and [b].
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final l2 = (b - a).distanceSquared;
    if (l2 == 0) return (p - a).distance;
    final t = math.max(
      0.0,
      math.min(
        1.0,
        ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2,
      ),
    );
    final projection = Offset(
      a.dx + t * (b.dx - a.dx),
      a.dy + t * (b.dy - a.dy),
    );
    return (p - projection).distance;
  }

  /// Returns pixel positions of all interactive handles for this drawing.
  List<Offset> getHandleOffsets(
    Rect bounds,
    PriceRange priceRange,
    CoordinateConverter converter,
  ) {
    if (points.isEmpty) return const [];

    switch (tool) {
      case DrawingTool.pointer:
        return const [];

      case DrawingTool.trendline:
      case DrawingTool.ruler:
        if (points.length < 2) {
          final x = converter.indexToX(points[0].candleIndex);
          final y = CoordinateConverter.priceToY(
            points[0].price,
            bounds,
            priceRange,
          );
          return [Offset(x, y)];
        }
        final x1 = converter.indexToX(points[0].candleIndex);
        final y1 = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        final x2 = converter.indexToX(points[1].candleIndex);
        final y2 = CoordinateConverter.priceToY(
          points[1].price,
          bounds,
          priceRange,
        );
        return [Offset(x1, y1), Offset(x2, y2)];

      case DrawingTool.horizontalLine:
        final y = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        return [
          Offset(bounds.left + 50.0, y),
          Offset(bounds.center.dx, y),
          Offset(bounds.right - 50.0, y),
        ];

      case DrawingTool.horizontalRay:
        final x = converter.indexToX(points[0].candleIndex);
        final y = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        return [
          Offset(x, y),
          Offset(((x + bounds.right) / 2).clamp(x + 20.0, bounds.right), y),
        ];

      case DrawingTool.verticalLine:
        final x = converter.indexToX(points[0].candleIndex);
        return [
          Offset(x, bounds.top + 40.0),
          Offset(x, bounds.center.dy),
          Offset(x, bounds.bottom - 40.0),
        ];

      case DrawingTool.rectangle:
        if (points.length < 2) {
          final x = converter.indexToX(points[0].candleIndex);
          final y = CoordinateConverter.priceToY(
            points[0].price,
            bounds,
            priceRange,
          );
          return [Offset(x, y)];
        }
        final x1 = converter.indexToX(points[0].candleIndex);
        final y1 = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        final x2 = converter.indexToX(points[1].candleIndex);
        final y2 = CoordinateConverter.priceToY(
          points[1].price,
          bounds,
          priceRange,
        );

        final left = math.min(x1, x2);
        final right = math.max(x1, x2);
        final top = math.min(y1, y2);
        final bottom = math.max(y1, y2);
        final midX = (left + right) / 2;
        final midY = (top + bottom) / 2;

        return [
          Offset(left, top), // 0: Top-Left corner
          Offset(right, top), // 1: Top-Right corner
          Offset(right, bottom), // 2: Bottom-Right corner
          Offset(left, bottom), // 3: Bottom-Left corner
          Offset(midX, top), // 4: Top Edge
          Offset(right, midY), // 5: Right Edge
          Offset(midX, bottom), // 6: Bottom Edge
          Offset(left, midY), // 7: Left Edge
        ];

      case DrawingTool.fibonacci:
        if (points.length < 2) return const [];
        final x1 = converter.indexToX(points[0].candleIndex);
        final y1 = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        final x2 = converter.indexToX(points[1].candleIndex);
        final y2 = CoordinateConverter.priceToY(
          points[1].price,
          bounds,
          priceRange,
        );
        return [Offset(x1, y1), Offset(x2, y2)];

      case DrawingTool.longPosition:
      case DrawingTool.shortPosition:
        final isLong = tool == DrawingTool.longPosition;
        final entry = points.first;
        final entryX = converter.indexToX(entry.candleIndex);
        final entryY = CoordinateConverter.priceToY(
          entry.price,
          bounds,
          priceRange,
        );
        final widthSpan = (properties['widthSpan'] as double?) ?? (40 * 11.0);
        final rightX = (entryX + widthSpan).clamp(entryX + 50.0, bounds.right);

        final targetPrice = properties['targetPrice'] as double? ??
            (isLong ? entry.price * 1.015 : entry.price * 0.985);
        final stopPrice = properties['stopPrice'] as double? ??
            (isLong ? entry.price * 0.9925 : entry.price * 1.0075);

        final targetY = CoordinateConverter.priceToY(
          targetPrice,
          bounds,
          priceRange,
        );
        final stopY = CoordinateConverter.priceToY(
          stopPrice,
          bounds,
          priceRange,
        );

        return [
          Offset((entryX + rightX) / 2, targetY),
          Offset((entryX + rightX) / 2, stopY),
          Offset(entryX, entryY),
          Offset(rightX, entryY),
        ];
    }
  }

  /// Returns the appropriate MouseCursor when hovering over a handle.
  MouseCursor getHandleCursor(int handleIndex) {
    switch (tool) {
      case DrawingTool.horizontalLine:
      case DrawingTool.horizontalRay:
        return SystemMouseCursors.resizeUpDown;

      case DrawingTool.verticalLine:
        return SystemMouseCursors.resizeLeftRight;

      case DrawingTool.rectangle:
        switch (handleIndex) {
          case 0:
          case 2:
            return SystemMouseCursors.resizeUpLeftDownRight;
          case 1:
          case 3:
            return SystemMouseCursors.resizeUpRightDownLeft;
          case 4:
          case 6:
            return SystemMouseCursors.resizeUpDown;
          case 5:
          case 7:
            return SystemMouseCursors.resizeLeftRight;
          default:
            return SystemMouseCursors.grab;
        }

      case DrawingTool.longPosition:
      case DrawingTool.shortPosition:
        switch (handleIndex) {
          case 0:
          case 1:
          case 2:
            return SystemMouseCursors.resizeUpDown;
          case 3:
            return SystemMouseCursors.resizeLeftRight;
          default:
            return SystemMouseCursors.grab;
        }

      case DrawingTool.trendline:
      case DrawingTool.ruler:
      case DrawingTool.fibonacci:
        return SystemMouseCursors.grab;

      case DrawingTool.pointer:
        return SystemMouseCursors.basic;
    }
  }

  /// Checks if [pos] falls within [threshold] pixels of any handle on this drawing.
  int? hitTestHandle(
    Offset pos,
    Rect bounds,
    PriceRange priceRange,
    CoordinateConverter converter, {
    double threshold = 12.0,
  }) {
    final handles = getHandleOffsets(bounds, priceRange, converter);
    for (int i = 0; i < handles.length; i++) {
      if ((pos - handles[i]).distance <= threshold) {
        return i;
      }
    }
    return null;
  }

  /// Checks if [pos] hits this drawing (near line, inside box, or near handles).
  bool hitTest(
    Offset pos,
    Rect bounds,
    PriceRange priceRange,
    CoordinateConverter converter, {
    double threshold = 8.0,
  }) {
    if (points.isEmpty) return false;

    if (hitTestHandle(
          pos,
          bounds,
          priceRange,
          converter,
          threshold: threshold + 4,
        ) !=
        null) {
      return true;
    }

    switch (tool) {
      case DrawingTool.pointer:
        return false;

      case DrawingTool.trendline:
      case DrawingTool.ruler:
        if (points.length < 2) return false;
        final x1 = converter.indexToX(points[0].candleIndex);
        final y1 = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        final x2 = converter.indexToX(points[1].candleIndex);
        final y2 = CoordinateConverter.priceToY(
          points[1].price,
          bounds,
          priceRange,
        );
        return distanceToSegment(pos, Offset(x1, y1), Offset(x2, y2)) <=
            threshold;

      case DrawingTool.horizontalLine:
        final y = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        return (pos.dy - y).abs() <= math.max(threshold, 10.0) &&
            pos.dx >= bounds.left - 10 &&
            pos.dx <= bounds.right + 10;

      case DrawingTool.horizontalRay:
        final x = converter.indexToX(points[0].candleIndex);
        final y = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        return (pos.dy - y).abs() <= math.max(threshold, 10.0) &&
            pos.dx >= x - 10 &&
            pos.dx <= bounds.right + 10;

      case DrawingTool.verticalLine:
        final x = converter.indexToX(points[0].candleIndex);
        return (pos.dx - x).abs() <= math.max(threshold, 10.0) &&
            pos.dy >= bounds.top - 10 &&
            pos.dy <= bounds.bottom + 10;

      case DrawingTool.rectangle:
        if (points.length < 2) return false;
        final x1 = converter.indexToX(points[0].candleIndex);
        final y1 = CoordinateConverter.priceToY(
          points[0].price,
          bounds,
          priceRange,
        );
        final x2 = converter.indexToX(points[1].candleIndex);
        final y2 = CoordinateConverter.priceToY(
          points[1].price,
          bounds,
          priceRange,
        );
        final rect = Rect.fromLTRB(
          math.min(x1, x2),
          math.min(y1, y2),
          math.max(x1, x2),
          math.max(y1, y2),
        );
        return rect.inflate(threshold).contains(pos);

      case DrawingTool.fibonacci:
        if (points.length < 2) return false;
        final p1 = points[0];
        final p2 = points[1];
        final x1 = converter.indexToX(p1.candleIndex);
        final x2 = converter.indexToX(p2.candleIndex);
        final minX = math.min(x1, x2) - threshold;
        final maxX = math.max(bounds.right, math.max(x1, x2)) + threshold;

        if (pos.dx < minX || pos.dx > maxX) return false;

        final priceDiff = p2.price - p1.price;
        const ratios = [0.0, 0.236, 0.382, 0.500, 0.618, 0.786, 1.0];
        for (final r in ratios) {
          final levelPrice = p1.price + (priceDiff * r);
          final y = CoordinateConverter.priceToY(
            levelPrice,
            bounds,
            priceRange,
          );
          if ((pos.dy - y).abs() <= threshold) return true;
        }
        return false;

      case DrawingTool.longPosition:
      case DrawingTool.shortPosition:
        final isLong = tool == DrawingTool.longPosition;
        final entry = points.first;
        final entryX = converter.indexToX(entry.candleIndex);
        final widthSpan = (properties['widthSpan'] as double?) ?? (40 * 11.0);
        final rightX = (entryX + widthSpan).clamp(entryX + 50.0, bounds.right);

        final targetPrice = properties['targetPrice'] as double? ??
            (isLong ? entry.price * 1.015 : entry.price * 0.985);
        final stopPrice = properties['stopPrice'] as double? ??
            (isLong ? entry.price * 0.9925 : entry.price * 1.0075);

        final targetY = CoordinateConverter.priceToY(
          targetPrice,
          bounds,
          priceRange,
        );
        final stopY = CoordinateConverter.priceToY(
          stopPrice,
          bounds,
          priceRange,
        );

        final minY = math.min(targetY, stopY);
        final maxY = math.max(targetY, stopY);
        final totalRect = Rect.fromLTRB(entryX, minY, rightX, maxY);
        return totalRect.inflate(threshold).contains(pos);
    }
  }
}
