/// Side of the order: Buy or Sell.
enum OrderSide {
  buy,
  sell;

  bool get isBuy => this == OrderSide.buy;
  bool get isSell => this == OrderSide.sell;
}

/// Type of order placed on the chart.
enum OrderType {
  limit,
  stop,
  stopLimit,
  market;

  String get label {
    switch (this) {
      case OrderType.limit:
        return 'LIMIT';
      case OrderType.stop:
        return 'STOP';
      case OrderType.stopLimit:
        return 'STOP LIMIT';
      case OrderType.market:
        return 'MARKET';
    }
  }
}

/// Execution status of an order.
enum OrderStatus { active, filled, cancelled }

/// Represents a trading order displayed on the chart canvas with support
/// for attached Take Profit (TP) and Stop Loss (SL) brackets.
class ChartOrder {
  final String id;
  final String symbol;
  final OrderSide side;
  final OrderType type;
  final double price;
  final double quantity;
  final double? takeProfitPrice;
  final double? stopLossPrice;
  final String? customLabel;
  final OrderStatus status;
  final Map<String, dynamic>? metadata;

  const ChartOrder({
    required this.id,
    required this.symbol,
    required this.side,
    this.type = OrderType.limit,
    required this.price,
    this.quantity = 1.0,
    this.takeProfitPrice,
    this.stopLossPrice,
    this.customLabel,
    this.status = OrderStatus.active,
    this.metadata,
  });

  bool get isBuy => side.isBuy;
  bool get isSell => side.isSell;
  bool get hasTakeProfit => takeProfitPrice != null;
  bool get hasStopLoss => stopLossPrice != null;

  /// Returns the distance percentage of the Take Profit relative to the order price.
  double? get takeProfitPercentage {
    if (takeProfitPrice == null || price == 0) return null;
    final pct = ((takeProfitPrice! - price) / price) * 100.0;
    return isBuy ? pct : -pct;
  }

  /// Returns the distance percentage of the Stop Loss relative to the order price.
  double? get stopLossPercentage {
    if (stopLossPrice == null || price == 0) return null;
    final pct = ((stopLossPrice! - price) / price) * 100.0;
    return isBuy ? pct : -pct;
  }

  ChartOrder copyWith({
    String? id,
    String? symbol,
    OrderSide? side,
    OrderType? type,
    double? price,
    double? quantity,
    double? Function()? takeProfitPrice,
    double? Function()? stopLossPrice,
    String? customLabel,
    OrderStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return ChartOrder(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      side: side ?? this.side,
      type: type ?? this.type,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      takeProfitPrice:
          takeProfitPrice != null ? takeProfitPrice() : this.takeProfitPrice,
      stopLossPrice:
          stopLossPrice != null ? stopLossPrice() : this.stopLossPrice,
      customLabel: customLabel ?? this.customLabel,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'side': side.name,
        'type': type.name,
        'price': price,
        'quantity': quantity,
        if (takeProfitPrice != null) 'takeProfitPrice': takeProfitPrice,
        if (stopLossPrice != null) 'stopLossPrice': stopLossPrice,
        if (customLabel != null) 'customLabel': customLabel,
        'status': status.name,
        if (metadata != null) 'metadata': metadata,
      };

  factory ChartOrder.fromJson(Map<String, dynamic> json) {
    return ChartOrder(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      side: OrderSide.values.firstWhere(
        (s) => s.name == json['side'],
        orElse: () => OrderSide.buy,
      ),
      type: OrderType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => OrderType.limit,
      ),
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      takeProfitPrice: (json['takeProfitPrice'] as num?)?.toDouble(),
      stopLossPrice: (json['stopLossPrice'] as num?)?.toDouble(),
      customLabel: json['customLabel'] as String?,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.active,
      ),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartOrder &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          symbol == other.symbol &&
          side == other.side &&
          type == other.type &&
          price == other.price &&
          quantity == other.quantity &&
          takeProfitPrice == other.takeProfitPrice &&
          stopLossPrice == other.stopLossPrice &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        id,
        symbol,
        side,
        type,
        price,
        quantity,
        takeProfitPrice,
        stopLossPrice,
        status,
      );
}
