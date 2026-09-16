import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/core/models/tick.dart';
import 'package:im_charts/core/models/timeframe.dart';
import 'package:im_charts/engine/candle_builder.dart';

void main() {
  group('CandleBuilder Tests', () {
    test(
      'Aggregates ticks into single candle within same timeframe interval',
      () {
        final builder = CandleBuilder(timeframe: Timeframe.oneMinute);
        final baseTime = DateTime(2026, 9, 14, 9, 15, 10);

        builder.onTick(Tick(timestamp: baseTime, price: 100.0, volume: 10));
        builder.onTick(
          Tick(
            timestamp: baseTime.add(const Duration(seconds: 15)),
            price: 105.0,
            volume: 5,
          ),
        );
        builder.onTick(
          Tick(
            timestamp: baseTime.add(const Duration(seconds: 30)),
            price: 98.0,
            volume: 8,
          ),
        );
        final lastCandle = builder.onTick(
          Tick(
            timestamp: baseTime.add(const Duration(seconds: 45)),
            price: 102.0,
            volume: 12,
          ),
        );

        expect(builder.candles.length, equals(1));
        expect(lastCandle.open, equals(100.0));
        expect(lastCandle.high, equals(105.0));
        expect(lastCandle.low, equals(98.0));
        expect(lastCandle.close, equals(102.0));
        expect(lastCandle.volume, equals(35.0));
      },
    );

    test('Creates new candle on timeframe interval boundary cross', () {
      final builder = CandleBuilder(timeframe: Timeframe.oneMinute);
      final t1 = DateTime(2026, 9, 14, 9, 15, 30);
      final t2 = DateTime(2026, 9, 14, 9, 16, 5);

      builder.onTick(Tick(timestamp: t1, price: 100.0, volume: 10));
      builder.onTick(Tick(timestamp: t2, price: 103.0, volume: 15));

      expect(builder.candles.length, equals(2));
      expect(builder.candles[0].close, equals(100.0));
      expect(builder.candles[1].open, equals(103.0));
      expect(
        builder.candles[1].timestamp,
        equals(DateTime(2026, 9, 14, 9, 16, 0)),
      );
    });
  });
}
