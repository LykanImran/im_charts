/// Trigger conditions for on-chart price alerts.
enum AlertTriggerCondition {
  /// Triggers when the price crosses the alert level in either direction.
  crossing('Crossing'),

  /// Triggers when the price crosses above the alert level from below.
  crossingUp('Crossing Up'),

  /// Triggers when the price crosses below the alert level from above.
  crossingDown('Crossing Down');

  final String label;
  const AlertTriggerCondition(this.label);
}

/// Represents an active or triggered visual price alert on the chart canvas.
class ChartAlert {
  final String id;
  final String symbol;
  final double price;
  final String note;
  final AlertTriggerCondition condition;
  final DateTime createdAt;
  final bool isTriggered;
  final bool isActive;
  final DateTime? triggeredAt;

  const ChartAlert({
    required this.id,
    required this.symbol,
    required this.price,
    this.note = 'Price Alert',
    this.condition = AlertTriggerCondition.crossing,
    required this.createdAt,
    this.isTriggered = false,
    this.isActive = true,
    this.triggeredAt,
  });

  /// Evaluates whether the current price update satisfies this alert's trigger condition.
  bool checkTrigger(double currentPrice, double previousPrice) {
    if (!isActive || isTriggered) return false;

    switch (condition) {
      case AlertTriggerCondition.crossingUp:
        return previousPrice < price && currentPrice >= price;
      case AlertTriggerCondition.crossingDown:
        return previousPrice > price && currentPrice <= price;
      case AlertTriggerCondition.crossing:
        return (previousPrice - price) * (currentPrice - price) <= 0 &&
            previousPrice != currentPrice;
    }
  }

  ChartAlert copyWith({
    String? id,
    String? symbol,
    double? price,
    String? note,
    AlertTriggerCondition? condition,
    DateTime? createdAt,
    bool? isTriggered,
    bool? isActive,
    DateTime? triggeredAt,
  }) {
    return ChartAlert(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      price: price ?? this.price,
      note: note ?? this.note,
      condition: condition ?? this.condition,
      createdAt: createdAt ?? this.createdAt,
      isTriggered: isTriggered ?? this.isTriggered,
      isActive: isActive ?? this.isActive,
      triggeredAt: triggeredAt ?? this.triggeredAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartAlert &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          symbol == other.symbol &&
          price == other.price &&
          note == other.note &&
          condition == other.condition &&
          isTriggered == other.isTriggered &&
          isActive == other.isActive;

  @override
  int get hashCode =>
      id.hashCode ^
      symbol.hashCode ^
      price.hashCode ^
      note.hashCode ^
      condition.hashCode ^
      isTriggered.hashCode ^
      isActive.hashCode;
}
