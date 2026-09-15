import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('VolumeProfile Engine Tests', () {
    test('Calculates price bins, POC, and Value Area for visible candles', () {
      final now = DateTime(2026, 1, 1, 10, 0);
      final candles = [
        Candle(
          timestamp: now,
          open: 100.0,
          high: 110.0,
          low: 95.0,
          close: 105.0,
          volume: 1000.0,
        ),
        Candle(
          timestamp: now.add(const Duration(minutes: 5)),
          open: 105.0,
          high: 115.0,
          low: 100.0,
          close: 112.0,
          volume: 2000.0,
        ),
        Candle(
          timestamp: now.add(const Duration(minutes: 10)),
          open: 112.0,
          high: 113.0,
          low: 102.0,
          close: 104.0,
          volume: 1500.0,
        ),
      ];

      final profile = VolumeProfile.calculate(candles, binCount: 10);

      expect(profile.bins.length, 10);
      expect(profile.totalVolume, greaterThan(0));
      expect(profile.maxBinVolume, greaterThan(0));
      expect(profile.pocBin, isNotNull);
      expect(profile.pocPrice, isNotNull);
      expect(profile.vahPrice, greaterThanOrEqualTo(profile.valPrice));
      expect(profile.vahPrice, lessThanOrEqualTo(115.0));
      expect(profile.valPrice, greaterThanOrEqualTo(95.0));
    });

    test('Handles empty candle list gracefully', () {
      final profile = VolumeProfile.calculate([]);

      expect(profile.bins, isEmpty);
      expect(profile.pocBin, isNull);
      expect(profile.pocPrice, isNull);
      expect(profile.totalVolume, 0.0);
      expect(profile.maxBinVolume, 0.0);
    });

    test('Allocates buyer vs seller volume based on candle direction', () {
      final now = DateTime(2026, 1, 1);
      final bullCandle = Candle(
        timestamp: now,
        open: 100.0,
        high: 110.0,
        low: 100.0,
        close: 110.0, // pure bull
        volume: 1000.0,
      );

      final profile = VolumeProfile.calculate([bullCandle], binCount: 5);

      double totalBuy = 0.0;
      double totalSell = 0.0;
      for (final b in profile.bins) {
        totalBuy += b.buyVolume;
        totalSell += b.sellVolume;
      }

      // Bullish candles allocate 65% buy, 35% sell
      expect(totalBuy, closeTo(650.0, 1.0));
      expect(totalSell, closeTo(350.0, 1.0));
    });
  });
}
