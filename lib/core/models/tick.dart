import 'package:flutter/foundation.dart';

/// Represents a single trade/tick event from a real-time market data feed.
@immutable
class Tick {
  final DateTime timestamp;
  final double price;
  final double volume;

  const Tick({
    required this.timestamp,
    required this.price,
    this.volume = 0.0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tick &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          price == other.price &&
          volume == other.volume;

  @override
  int get hashCode => Object.hash(timestamp, price, volume);

  @override
  String toString() =>
      'Tick(time: ${timestamp.toIso8601String()}, price: $price, volume: $volume)';
}
