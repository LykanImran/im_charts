import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Volume Weighted Average Price (VWAP) Indicator.
///
/// Intraday benchmark calculated from cumulative (Typical Price × Volume) / Cumulative Volume.
/// Resets at session/day boundaries. Includes optional standard deviation bands.
class VWAPIndicator extends Indicator {
  final double bandMultiplier;
  final Color vwapColor;
  final Color bandColor;
  final double strokeWidth;
  final bool showBands;

  VWAPIndicator({
    this.bandMultiplier = 2.0,
    this.vwapColor = const Color(0xFFAB47BC),
    this.bandColor = const Color(0xFF7E57C2),
    this.strokeWidth = 1.5,
    this.showBands = true,
  });

  @override
  String get id => 'VWAP';

  @override
  String get name => 'VWAP';

  @override
  bool get isOverlay => true;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final vwapValues = List<double?>.filled(candles.length, null);
    final upperValues = List<double?>.filled(candles.length, null);
    final lowerValues = List<double?>.filled(candles.length, null);

    if (candles.isEmpty) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: true,
        series: [
          IndicatorSeries(
            id: 'vwap',
            label: 'VWAP',
            color: vwapColor,
            strokeWidth: strokeWidth,
            values: vwapValues,
          ),
        ],
      );
    }

    double cumTypicalVolume = 0.0;
    double cumVolume = 0.0;
    double cumTypicalSquareVolume = 0.0;
    DateTime? lastDate;

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final candleDate = DateTime(
        candle.timestamp.year,
        candle.timestamp.month,
        candle.timestamp.day,
      );

      // Reset at intraday session / day boundaries
      if (lastDate != null && candleDate != lastDate) {
        cumTypicalVolume = 0.0;
        cumVolume = 0.0;
        cumTypicalSquareVolume = 0.0;
      }
      lastDate = candleDate;

      final typicalPrice = (candle.high + candle.low + candle.close) / 3.0;
      final volume = candle.volume > 0 ? candle.volume : 1.0;

      cumTypicalVolume += typicalPrice * volume;
      cumVolume += volume;
      cumTypicalSquareVolume += typicalPrice * typicalPrice * volume;

      if (cumVolume > 0) {
        final vwap = cumTypicalVolume / cumVolume;
        vwapValues[i] = vwap;

        if (showBands) {
          final variance = (cumTypicalSquareVolume / cumVolume) - (vwap * vwap);
          final stdDev = math.sqrt(math.max(0.0, variance));
          upperValues[i] = vwap + (bandMultiplier * stdDev);
          lowerValues[i] = vwap - (bandMultiplier * stdDev);
        }
      }
    }

    final series = <IndicatorSeries>[
      if (showBands)
        IndicatorSeries(
          id: 'upper',
          label: 'Upper ($bandMultiplierσ)',
          color: bandColor.withValues(alpha: 0.6),
          strokeWidth: 1.0,
          values: upperValues,
        ),
      IndicatorSeries(
        id: 'vwap',
        label: 'VWAP',
        color: vwapColor,
        strokeWidth: strokeWidth,
        values: vwapValues,
      ),
      if (showBands)
        IndicatorSeries(
          id: 'lower',
          label: 'Lower ($bandMultiplierσ)',
          color: bandColor.withValues(alpha: 0.6),
          strokeWidth: 1.0,
          values: lowerValues,
        ),
    ];

    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: series,
    );
  }
}
