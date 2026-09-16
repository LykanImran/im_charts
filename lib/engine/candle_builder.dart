import 'dart:math' as math;
import '../core/models/candle.dart';
import '../core/models/tick.dart';
import '../core/models/timeframe.dart';

/// Aggregates a stream of real-time [Tick] events into normalized [Candle] bars.
class CandleBuilder {
  final Timeframe timeframe;
  final List<Candle> _candles;

  CandleBuilder({required this.timeframe, List<Candle>? initialCandles})
    : _candles = initialCandles != null
          ? List<Candle>.from(initialCandles)
          : <Candle>[];

  List<Candle> get candles => List.unmodifiable(_candles);

  Candle? get currentCandle => _candles.isNotEmpty ? _candles.last : null;

  /// Ingests a new [Tick] and either updates the latest candle or initiates a new candle.
  /// Returns the updated or newly created [Candle].
  Candle onTick(Tick tick) {
    final alignedTime = timeframe.alignTimestamp(tick.timestamp);

    if (_candles.isEmpty) {
      final initialCandle = Candle(
        timestamp: alignedTime,
        open: tick.price,
        high: tick.price,
        low: tick.price,
        close: tick.price,
        volume: tick.volume,
      );
      _candles.add(initialCandle);
      return initialCandle;
    }

    final last = _candles.last;

    // Check if tick belongs to the current candle or begins a new timeframe interval
    if (alignedTime.isAtSameMomentAs(last.timestamp)) {
      final updated = last.copyWith(
        high: math.max(last.high, tick.price),
        low: math.min(last.low, tick.price),
        close: tick.price,
        volume: last.volume + tick.volume,
      );
      _candles[_candles.length - 1] = updated;
      return updated;
    } else if (alignedTime.isAfter(last.timestamp)) {
      final newCandle = Candle(
        timestamp: alignedTime,
        open: tick.price,
        high: tick.price,
        low: tick.price,
        close: tick.price,
        volume: tick.volume,
      );
      _candles.add(newCandle);
      return newCandle;
    } else {
      // Out of order or historical tick - in real-world, can be handled or ignored.
      return last;
    }
  }

  /// Clears the candles in this builder.
  void clear() {
    _candles.clear();
  }

  /// Sets the candles collection wholesale (e.g. after fetching historical data).
  void setCandles(List<Candle> candles) {
    _candles.clear();
    _candles.addAll(candles);
  }
}
