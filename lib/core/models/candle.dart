import 'package:flutter/foundation.dart';

/// Represents an immutable OHLCV (Open, High, Low, Close, Volume) data bar.
@immutable
class Candle {
  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  }) : assert(high >= low, 'High ($high) must be >= Low ($low)');

  /// Returns true if this is a bullish candle (close >= open).
  bool get isBullish => close >= open;

  /// Returns true if this is a bearish candle (close < open).
  bool get isBearish => close < open;

  /// Absolute price change between open and close.
  double get priceChange => close - open;

  /// Percentage change relative to open.
  double get percentageChange => open == 0 ? 0.0 : ((close - open) / open) * 100.0;

  /// Total bar height from low to high.
  double get range => high - low;

  Candle copyWith({
    DateTime? timestamp,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
  }) {
    return Candle(
      timestamp: timestamp ?? this.timestamp,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Candle &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          open == other.open &&
          high == other.high &&
          low == other.low &&
          close == other.close &&
          volume == other.volume;

  @override
  int get hashCode => Object.hash(timestamp, open, high, low, close, volume);

  @override
  String toString() =>
      'Candle(time: ${timestamp.toIso8601String()}, O: $open, H: $high, L: $low, C: $close, V: $volume)';
}
