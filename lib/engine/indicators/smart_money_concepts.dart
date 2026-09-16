import '../../core/models/candle.dart';

/// Represents a Fair Value Gap (FVG / Imbalance) identified between three consecutive candles.
class FVGZone {
  final int startIndex;
  final int endIndex;
  final double topPrice;
  final double bottomPrice;
  final double midPrice; // 50% Consequent Encroachment (CE)
  final bool isBullish;
  final bool isMitigated;
  final int? mitigatedIndex;

  const FVGZone({
    required this.startIndex,
    required this.endIndex,
    required this.topPrice,
    required this.bottomPrice,
    required this.midPrice,
    required this.isBullish,
    this.isMitigated = false,
    this.mitigatedIndex,
  });

  FVGZone copyWith({
    int? endIndex,
    bool? isMitigated,
    int? mitigatedIndex,
  }) {
    return FVGZone(
      startIndex: startIndex,
      endIndex: endIndex ?? this.endIndex,
      topPrice: topPrice,
      bottomPrice: bottomPrice,
      midPrice: midPrice,
      isBullish: isBullish,
      isMitigated: isMitigated ?? this.isMitigated,
      mitigatedIndex: mitigatedIndex ?? this.mitigatedIndex,
    );
  }
}

/// Type of market structure shift.
enum StructureType {
  /// Break of Structure (trend continuation)
  bos,

  /// Change of Character (trend reversal)
  choch,
}

/// Represents a structural break of a prior swing high or swing low.
class StructureBreak {
  final int swingIndex;
  final int breakIndex;
  final double price;
  final bool isBullish;
  final StructureType type;

  const StructureBreak({
    required this.swingIndex,
    required this.breakIndex,
    required this.price,
    required this.isBullish,
    required this.type,
  });

  String get label => type == StructureType.choch ? 'CHoCH' : 'BOS';
}

/// Represents an institutional supply or demand Order Block.
class OrderBlockZone {
  final int candleIndex;
  final int endIndex;
  final double topPrice;
  final double bottomPrice;
  final bool isBullish; // true = Demand OB, false = Supply OB
  final bool isMitigated;

  const OrderBlockZone({
    required this.candleIndex,
    required this.endIndex,
    required this.topPrice,
    required this.bottomPrice,
    required this.isBullish,
    this.isMitigated = false,
  });

  OrderBlockZone copyWith({
    int? endIndex,
    bool? isMitigated,
  }) {
    return OrderBlockZone(
      candleIndex: candleIndex,
      endIndex: endIndex ?? this.endIndex,
      topPrice: topPrice,
      bottomPrice: bottomPrice,
      isBullish: isBullish,
      isMitigated: isMitigated ?? this.isMitigated,
    );
  }
}

/// Result of the Smart Money Concepts detection engine.
class SmartMoneyConcepts {
  final List<FVGZone> fvgZones;
  final List<StructureBreak> structureBreaks;
  final List<OrderBlockZone> orderBlocks;

  const SmartMoneyConcepts({
    required this.fvgZones,
    required this.structureBreaks,
    required this.orderBlocks,
  });

  /// Automatically scans [candles] for Fair Value Gaps, BOS / CHoCH, and Order Blocks.
  ///
  /// [swingPivotLookback]: number of bars to left and right to qualify a swing high/low (default 3).
  /// [maxUnmitigatedFVG]: maximum unmitigated FVGs to keep active (default 15).
  static SmartMoneyConcepts calculate(
    List<Candle> candles, {
    int swingPivotLookback = 3,
    int maxUnmitigatedFVG = 15,
  }) {
    if (candles.length < 3) {
      return const SmartMoneyConcepts(
        fvgZones: [],
        structureBreaks: [],
        orderBlocks: [],
      );
    }

    final fvgList = <FVGZone>[];
    final obList = <OrderBlockZone>[];

    // 1. Detect Fair Value Gaps (3-bar pattern: candle[i-2], candle[i-1], candle[i])
    for (int i = 2; i < candles.length; i++) {
      final c0 = candles[i - 2];
      final c1 = candles[i - 1];
      final c2 = candles[i];

      // Bullish FVG: Low of candle 3 is strictly above High of candle 1
      if (c2.low > c0.high && c1.isBullish) {
        final top = c2.low;
        final bottom = c0.high;
        final mid = (top + bottom) / 2.0;

        // Check if subsequent bars mitigate it
        bool mitigated = false;
        int? mitIndex;
        int endIdx = candles.length - 1;

        for (int j = i + 1; j < candles.length; j++) {
          if (candles[j].low <= bottom) {
            mitigated = true;
            mitIndex = j;
            endIdx = j;
            break;
          }
        }

        fvgList.add(
          FVGZone(
            startIndex: i - 1,
            endIndex: endIdx,
            topPrice: top,
            bottomPrice: bottom,
            midPrice: mid,
            isBullish: true,
            isMitigated: mitigated,
            mitigatedIndex: mitIndex,
          ),
        );
      }
      // Bearish FVG: High of candle 3 is strictly below Low of candle 1
      else if (c2.high < c0.low && !c1.isBullish) {
        final top = c0.low;
        final bottom = c2.high;
        final mid = (top + bottom) / 2.0;

        bool mitigated = false;
        int? mitIndex;
        int endIdx = candles.length - 1;

        for (int j = i + 1; j < candles.length; j++) {
          if (candles[j].high >= top) {
            mitigated = true;
            mitIndex = j;
            endIdx = j;
            break;
          }
        }

        fvgList.add(
          FVGZone(
            startIndex: i - 1,
            endIndex: endIdx,
            topPrice: top,
            bottomPrice: bottom,
            midPrice: mid,
            isBullish: false,
            isMitigated: mitigated,
            mitigatedIndex: mitIndex,
          ),
        );
      }
    }

    // 2. Detect Order Blocks (OB)
    // Bullish OB: last bearish candle before an aggressive bullish expansion of >= 2 candles
    // Bearish OB: last bullish candle before an aggressive bearish expansion of >= 2 candles
    for (int i = 1; i < candles.length - 2; i++) {
      final prev = candles[i];
      final next1 = candles[i + 1];
      final next2 = candles[i + 2];

      if (!prev.isBullish && next1.isBullish && next2.isBullish) {
        final impulse = next2.close - prev.close;
        final prevRange = (prev.high - prev.low).abs();
        if (impulse > prevRange * 1.5) {
          // Check mitigation
          bool mit = false;
          int endIdx = candles.length - 1;
          for (int j = i + 3; j < candles.length; j++) {
            if (candles[j].low <= prev.low) {
              mit = true;
              endIdx = j;
              break;
            }
          }
          obList.add(
            OrderBlockZone(
              candleIndex: i,
              endIndex: endIdx,
              topPrice: prev.high,
              bottomPrice: prev.low,
              isBullish: true,
              isMitigated: mit,
            ),
          );
        }
      } else if (prev.isBullish && !next1.isBullish && !next2.isBullish) {
        final impulse = prev.close - next2.close;
        final prevRange = (prev.high - prev.low).abs();
        if (impulse > prevRange * 1.5) {
          bool mit = false;
          int endIdx = candles.length - 1;
          for (int j = i + 3; j < candles.length; j++) {
            if (candles[j].high >= prev.high) {
              mit = true;
              endIdx = j;
              break;
            }
          }
          obList.add(
            OrderBlockZone(
              candleIndex: i,
              endIndex: endIdx,
              topPrice: prev.high,
              bottomPrice: prev.low,
              isBullish: false,
              isMitigated: mit,
            ),
          );
        }
      }
    }

    // 3. Detect Swing Highs / Lows and Break of Structure (BOS / CHoCH)
    final structureBreaks = <StructureBreak>[];
    final swingHighs = <int, double>{};
    final swingLows = <int, double>{};

    final k = swingPivotLookback;
    for (int i = k; i < candles.length - k; i++) {
      final currentHigh = candles[i].high;
      final currentLow = candles[i].low;

      bool isHigh = true;
      bool isLow = true;

      for (int step = 1; step <= k; step++) {
        if (candles[i - step].high >= currentHigh ||
            candles[i + step].high >= currentHigh) {
          isHigh = false;
        }
        if (candles[i - step].low <= currentLow ||
            candles[i + step].low <= currentLow) {
          isLow = false;
        }
      }

      if (isHigh) swingHighs[i] = currentHigh;
      if (isLow) swingLows[i] = currentLow;
    }

    // Evaluate structural breaks
    bool? currentTrendIsBullish;

    // Iterate through candles to find when price closes above a swing high or below a swing low
    for (int i = 0; i < candles.length; i++) {
      final close = candles[i].close;

      // Check breaks of swing highs
      for (final entry in swingHighs.entries) {
        final swingIdx = entry.key;
        final swingPrice = entry.value;

        if (i > swingIdx && close > swingPrice) {
          // Check if this swing high was already broken by an earlier bar
          final alreadyBroken = structureBreaks.any(
            (b) => b.swingIndex == swingIdx,
          );
          if (!alreadyBroken) {
            final isChoch = currentTrendIsBullish == false;
            currentTrendIsBullish = true;
            structureBreaks.add(
              StructureBreak(
                swingIndex: swingIdx,
                breakIndex: i,
                price: swingPrice,
                isBullish: true,
                type: isChoch ? StructureType.choch : StructureType.bos,
              ),
            );
          }
        }
      }

      // Check breaks of swing lows
      for (final entry in swingLows.entries) {
        final swingIdx = entry.key;
        final swingPrice = entry.value;

        if (i > swingIdx && close < swingPrice) {
          final alreadyBroken = structureBreaks.any(
            (b) => b.swingIndex == swingIdx,
          );
          if (!alreadyBroken) {
            final isChoch = currentTrendIsBullish == true;
            currentTrendIsBullish = false;
            structureBreaks.add(
              StructureBreak(
                swingIndex: swingIdx,
                breakIndex: i,
                price: swingPrice,
                isBullish: false,
                type: isChoch ? StructureType.choch : StructureType.bos,
              ),
            );
          }
        }
      }
    }

    return SmartMoneyConcepts(
      fvgZones: fvgList,
      structureBreaks: structureBreaks,
      orderBlocks: obList,
    );
  }
}
