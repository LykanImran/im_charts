import '../../core/models/candle.dart';

/// Represents a single horizontal price bucket in the Volume Profile.
class VolumeProfileBin {
  final double lowerPrice;
  final double upperPrice;
  final double centerPrice;
  final double buyVolume;
  final double sellVolume;

  const VolumeProfileBin({
    required this.lowerPrice,
    required this.upperPrice,
    required this.centerPrice,
    required this.buyVolume,
    required this.sellVolume,
  });

  double get totalVolume => buyVolume + sellVolume;
}

/// Calculated Visible Range Volume Profile (VRVP) containing all price bins,
/// the Point of Control (POC), and the Value Area (VAH / VAL).
class VolumeProfile {
  final List<VolumeProfileBin> bins;
  final VolumeProfileBin? pocBin;
  final double? pocPrice;
  final double vahPrice;
  final double valPrice;
  final double maxBinVolume;
  final double totalVolume;

  const VolumeProfile({
    required this.bins,
    required this.pocBin,
    required this.pocPrice,
    required this.vahPrice,
    required this.valPrice,
    required this.maxBinVolume,
    required this.totalVolume,
  });

  /// Computes the Volume Profile for the given list of visible candles.
  /// [binCount] specifies the number of discrete price buckets (default 30).
  /// [valueAreaPercent] specifies the percentage of volume inside the Value Area (default 0.70 for 70%).
  static VolumeProfile calculate(
    List<Candle> visibleCandles, {
    int binCount = 30,
    double valueAreaPercent = 0.70,
  }) {
    if (visibleCandles.isEmpty || binCount <= 0) {
      return const VolumeProfile(
        bins: [],
        pocBin: null,
        pocPrice: null,
        vahPrice: 0.0,
        valPrice: 0.0,
        maxBinVolume: 0.0,
        totalVolume: 0.0,
      );
    }

    // 1. Find min and max price across visible candles
    double minPrice = visibleCandles.first.low;
    double maxPrice = visibleCandles.first.high;
    for (final candle in visibleCandles) {
      if (candle.low < minPrice) minPrice = candle.low;
      if (candle.high > maxPrice) maxPrice = candle.high;
    }

    if (maxPrice <= minPrice) {
      maxPrice = minPrice + 1.0;
    }

    final priceRange = maxPrice - minPrice;
    final binSize = priceRange / binCount;

    final buyVolumes = List<double>.filled(binCount, 0.0);
    final sellVolumes = List<double>.filled(binCount, 0.0);

    // 2. Distribute candle volumes into overlapping price bins
    for (final candle in visibleCandles) {
      if (candle.volume <= 0) continue;

      final isBull = candle.isBullish;
      final cLow = candle.low.clamp(minPrice, maxPrice);
      final cHigh = candle.high.clamp(minPrice, maxPrice);

      // Volume split: Bullish candles are ~65% buyer volume, bearish are ~65% seller volume
      final buyFraction = isBull ? 0.65 : 0.35;
      final sellFraction = 1.0 - buyFraction;

      final startBin = ((cLow - minPrice) / binSize).floor().clamp(0, binCount - 1);
      final endBin = ((cHigh - minPrice) / binSize).floor().clamp(0, binCount - 1);

      final span = endBin - startBin + 1;
      final volPerBin = candle.volume / span;

      for (int b = startBin; b <= endBin; b++) {
        buyVolumes[b] += volPerBin * buyFraction;
        sellVolumes[b] += volPerBin * sellFraction;
      }
    }

    // 3. Construct VolumeProfileBin objects and locate POC
    final bins = <VolumeProfileBin>[];
    double maxVolume = 0.0;
    int pocIndex = 0;
    double totalVol = 0.0;

    for (int i = 0; i < binCount; i++) {
      final bLow = minPrice + (i * binSize);
      final bHigh = bLow + binSize;
      final bCenter = (bLow + bHigh) / 2.0;
      final bBuy = buyVolumes[i];
      final bSell = sellVolumes[i];
      final bTotal = bBuy + bSell;

      bins.add(VolumeProfileBin(
        lowerPrice: bLow,
        upperPrice: bHigh,
        centerPrice: bCenter,
        buyVolume: bBuy,
        sellVolume: bSell,
      ));

      totalVol += bTotal;
      if (bTotal > maxVolume) {
        maxVolume = bTotal;
        pocIndex = i;
      }
    }

    final pocBin = bins.isNotEmpty ? bins[pocIndex] : null;
    final pocPrice = pocBin?.centerPrice;

    // 4. Calculate Value Area (VAH & VAL) expanding symmetrically from POC
    double currentVaVolume = pocBin?.totalVolume ?? 0.0;
    final targetVaVolume = totalVol * valueAreaPercent;

    int upperIdx = pocIndex;
    int lowerIdx = pocIndex;

    while (currentVaVolume < targetVaVolume && (upperIdx < binCount - 1 || lowerIdx > 0)) {
      final nextUpperVol = (upperIdx < binCount - 1) ? bins[upperIdx + 1].totalVolume : -1.0;
      final nextLowerVol = (lowerIdx > 0) ? bins[lowerIdx - 1].totalVolume : -1.0;

      if (nextUpperVol >= nextLowerVol && nextUpperVol >= 0) {
        upperIdx++;
        currentVaVolume += nextUpperVol;
      } else if (nextLowerVol >= 0) {
        lowerIdx--;
        currentVaVolume += nextLowerVol;
      } else {
        break;
      }
    }

    final vahPrice = bins[upperIdx].upperPrice;
    final valPrice = bins[lowerIdx].lowerPrice;

    return VolumeProfile(
      bins: bins,
      pocBin: pocBin,
      pocPrice: pocPrice,
      vahPrice: vahPrice,
      valPrice: valPrice,
      maxBinVolume: maxVolume,
      totalVolume: totalVol,
    );
  }
}
