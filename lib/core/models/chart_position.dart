import 'package:flutter/foundation.dart';

/// Side of an open position: Long (Buy) or Short (Sell).
enum PositionSide {
  long,
  short;

  bool get isLong => this == PositionSide.long;
  bool get isShort => this == PositionSide.short;

  String get label => isLong ? 'LONG' : 'SHORT';
}

/// Represents an executed open trading position displayed on the chart canvas
/// with real-time unrealized P&L tracking and connected protective TP/SL brackets.
@immutable
class ChartPosition {
  final String id;
  final String symbol;
  final PositionSide side;
  final double entryPrice;
  final double quantity;
  final double? takeProfitPrice;
  final double? stopLossPrice;
  final DateTime openedAt;
  final String? customLabel;
  final Map<String, dynamic>? metadata;

  const ChartPosition({
    required this.id,
    required this.symbol,
    required this.side,
    required this.entryPrice,
    this.quantity = 1.0,
    this.takeProfitPrice,
    this.stopLossPrice,
    required this.openedAt,
    this.customLabel,
    this.metadata,
  });

  bool get isLong => side.isLong;
  bool get isShort => side.isShort;
  bool get hasTakeProfit => takeProfitPrice != null;
  bool get hasStopLoss => stopLossPrice != null;

  /// Calculates net unrealized profit or loss in absolute currency units.
  double unrealizedPnL(double currentPrice) {
    if (isLong) {
      return (currentPrice - entryPrice) * quantity;
    } else {
      return (entryPrice - currentPrice) * quantity;
    }
  }

  /// Calculates net unrealized profit or loss percentage relative to entry price.
  double unrealizedPnLPercentage(double currentPrice) {
    if (entryPrice == 0) return 0.0;
    if (isLong) {
      return ((currentPrice - entryPrice) / entryPrice) * 100.0;
    } else {
      return ((entryPrice - currentPrice) / entryPrice) * 100.0;
    }
  }

  /// Returns target take profit distance percentage relative to entry price.
  double? get takeProfitPercentage {
    if (takeProfitPrice == null || entryPrice == 0) return null;
    if (isLong) {
      return ((takeProfitPrice! - entryPrice) / entryPrice) * 100.0;
    } else {
      return ((entryPrice - takeProfitPrice!) / entryPrice) * 100.0;
    }
  }

  /// Returns protective stop loss distance percentage relative to entry price.
  double? get stopLossPercentage {
    if (stopLossPrice == null || entryPrice == 0) return null;
    if (isLong) {
      return ((stopLossPrice! - entryPrice) / entryPrice) * 100.0;
    } else {
      return ((entryPrice - stopLossPrice!) / entryPrice) * 100.0;
    }
  }

  ChartPosition copyWith({
    String? id,
    String? symbol,
    PositionSide? side,
    double? entryPrice,
    double? quantity,
    ValueGetter<double?>? takeProfitPrice,
    ValueGetter<double?>? stopLossPrice,
    DateTime? openedAt,
    String? customLabel,
    Map<String, dynamic>? metadata,
  }) {
    return ChartPosition(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      side: side ?? this.side,
      entryPrice: entryPrice ?? this.entryPrice,
      quantity: quantity ?? this.quantity,
      takeProfitPrice: takeProfitPrice != null
          ? takeProfitPrice()
          : this.takeProfitPrice,
      stopLossPrice: stopLossPrice != null
          ? stopLossPrice()
          : this.stopLossPrice,
      openedAt: openedAt ?? this.openedAt,
      customLabel: customLabel ?? this.customLabel,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPosition &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          symbol == other.symbol &&
          side == other.side &&
          entryPrice == other.entryPrice &&
          quantity == other.quantity &&
          takeProfitPrice == other.takeProfitPrice &&
          stopLossPrice == other.stopLossPrice &&
          openedAt == other.openedAt;

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    side,
    entryPrice,
    quantity,
    takeProfitPrice,
    stopLossPrice,
    openedAt,
  );
}
