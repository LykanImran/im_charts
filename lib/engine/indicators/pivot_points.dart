import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import 'indicator.dart';
import 'indicator_result.dart';

/// Classic Pivot Points — P, R1, R2, R3, S1, S2, S3 as horizontal overlay levels.
/// Computed from the previous session's High, Low, and Close.
/// The most recent complete session is used (second-to-last candle group by day).
class PivotPointsIndicator extends Indicator {
  final Color pivotColor;
  final Color resistanceColor;
  final Color supportColor;

  PivotPointsIndicator({
    this.pivotColor = const Color(0xFFFFFFFF),
    this.resistanceColor = const Color(0xFF00E676),
    this.supportColor = const Color(0xFFFF3B30),
  });

  @override
  String get id => 'PIVOT';

  @override
  String get name => 'Pivot Points';

  @override
  bool get isOverlay => true;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    final n = candles.length;
    final empty = List<double?>.filled(n, null);

    if (n < 2) {
      return _result(empty, empty, empty, empty, empty, empty, empty);
    }

    // Use the last-completed candle as the "previous session"
    final prev = candles[n - 2];
    final h = prev.high;
    final l = prev.low;
    final c = prev.close;

    final p = (h + l + c) / 3.0;
    final r1 = (2 * p) - l;
    final r2 = p + (h - l);
    final r3 = h + 2 * (p - l);
    final s1 = (2 * p) - h;
    final s2 = p - (h - l);
    final s3 = l - 2 * (h - p);

    // Flat lines across all candles
    List<double?> flat(double v) => List<double?>.filled(n, v);

    return _result(flat(p), flat(r1), flat(r2), flat(r3), flat(s1), flat(s2), flat(s3));
  }

  IndicatorResult _result(
    List<double?> p,
    List<double?> r1, List<double?> r2, List<double?> r3,
    List<double?> s1, List<double?> s2, List<double?> s3,
  ) {
    return IndicatorResult(
      indicatorId: id,
      name: name,
      isOverlay: true,
      series: [
        IndicatorSeries(id: 'P',  label: 'P',  color: pivotColor,      strokeWidth: 1.0, values: p,  isDashed: true),
        IndicatorSeries(id: 'R1', label: 'R1', color: resistanceColor, strokeWidth: 0.8, values: r1, isDashed: true),
        IndicatorSeries(id: 'R2', label: 'R2', color: resistanceColor, strokeWidth: 0.8, values: r2, isDashed: true),
        IndicatorSeries(id: 'R3', label: 'R3', color: resistanceColor, strokeWidth: 0.8, values: r3, isDashed: true),
        IndicatorSeries(id: 'S1', label: 'S1', color: supportColor,    strokeWidth: 0.8, values: s1, isDashed: true),
        IndicatorSeries(id: 'S2', label: 'S2', color: supportColor,    strokeWidth: 0.8, values: s2, isDashed: true),
        IndicatorSeries(id: 'S3', label: 'S3', color: supportColor,    strokeWidth: 0.8, values: s3, isDashed: true),
      ],
    );
  }
}
