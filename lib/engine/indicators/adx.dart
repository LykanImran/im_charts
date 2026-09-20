import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Average Directional Index (ADX) with +DI and -DI lines.
/// Measures trend strength (ADX) and direction (+DI vs -DI).
/// Displayed in a sub-pane. ADX > 25 = strong trend.
class ADXIndicator extends Indicator {
  final int period;
  final Color adxColor;
  final Color plusDIColor;
  final Color minusDIColor;

  ADXIndicator({
    this.period = 14,
    this.adxColor = const Color(0xFFFFB300),
    this.plusDIColor = const Color(0xFF00E676),
    this.minusDIColor = const Color(0xFFFF3B30),
  }) : assert(period > 1);

  @override
  String get id => 'ADX_$period';

  @override
  String get name => 'ADX $period';

  @override
  bool get isOverlay => false;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final n = candles.length;
    final adx = List<double?>.filled(n, null);
    final plusDI = List<double?>.filled(n, null);
    final minusDI = List<double?>.filled(n, null);

    if (n < period + 1) {
      return _result(adx, plusDI, minusDI);
    }

    // Calculate True Range, +DM, -DM
    final tr = List<double>.filled(n, 0);
    final pdm = List<double>.filled(n, 0);
    final mdm = List<double>.filled(n, 0);

    for (int i = 1; i < n; i++) {
      final high = candles[i].high;
      final low = candles[i].low;
      final prevClose = candles[i - 1].close;
      final prevHigh = candles[i - 1].high;
      final prevLow = candles[i - 1].low;

      tr[i] = [high - low, (high - prevClose).abs(), (low - prevClose).abs()].reduce((a, b) => a > b ? a : b);

      final upMove = high - prevHigh;
      final downMove = prevLow - low;
      pdm[i] = (upMove > downMove && upMove > 0) ? upMove : 0;
      mdm[i] = (downMove > upMove && downMove > 0) ? downMove : 0;
    }

    // Smoothed (Wilder's) sums
    double atr = 0, aPdm = 0, aMdm = 0;
    for (int i = 1; i <= period; i++) {
      atr += tr[i]; aPdm += pdm[i]; aMdm += mdm[i];
    }

    double adxSum = 0;
    int adxCount = 0;

    for (int i = period; i < n; i++) {
      if (i > period) {
        atr = atr - (atr / period) + tr[i];
        aPdm = aPdm - (aPdm / period) + pdm[i];
        aMdm = aMdm - (aMdm / period) + mdm[i];
      }

      final pdi = atr > 0 ? (100.0 * aPdm / atr) : 0.0;
      final mdi = atr > 0 ? (100.0 * aMdm / atr) : 0.0;
      plusDI[i] = pdi;
      minusDI[i] = mdi;

      final diSum = pdi + mdi;
      final dx = diSum > 0 ? (100.0 * (pdi - mdi).abs() / diSum) : 0.0;

      adxSum += dx;
      adxCount++;
      if (adxCount >= period) {
        adx[i] = adxCount == period
            ? adxSum / period
            : ((adx[i - 1] ?? 0) * (period - 1) + dx) / period;
      }
    }

    return _result(adx, plusDI, minusDI);
  }

  IndicatorResult _result(List<double?> adxVals, List<double?> pdVals, List<double?> mdVals) {
    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: false,
      fixedMin: 0,
      fixedMax: 100,
      horizontalLevels: [25.0, 50.0],
      series: [
        IndicatorSeries(id: 'adx', label: 'ADX', color: adxColor, strokeWidth: 1.8, values: adxVals),
        IndicatorSeries(id: '+di', label: '+DI', color: plusDIColor, strokeWidth: 1.2, values: pdVals),
        IndicatorSeries(id: '-di', label: '-DI', color: minusDIColor, strokeWidth: 1.2, values: mdVals),
      ],
    );
  }
}
