import 'package:flutter/material.dart';

/// Available interactive drawing tools on the chart.
enum DrawingTool {
  pointer,
  trendline,
  horizontalLine,
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
      case DrawingTool.longPosition:
      case DrawingTool.shortPosition:
        return 1;
      case DrawingTool.trendline:
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
}
