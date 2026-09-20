import 'package:flutter/material.dart';

/// Available chart rendering presentation styles.
enum CandleStyle {
  candles(
    label: 'Candles',
    shortLabel: 'Candles',
    icon: Icons.candlestick_chart,
  ),
  hollowCandles(
    label: 'Hollow Candles',
    shortLabel: 'Hollow',
    icon: Icons.candlestick_chart_outlined,
  ),
  heikinAshi(
    label: 'Heikin Ashi',
    shortLabel: 'Heikin Ashi',
    icon: Icons.waterfall_chart,
  ),
  line(label: 'Line', shortLabel: 'Line', icon: Icons.show_chart),
  area(label: 'Area', shortLabel: 'Area', icon: Icons.area_chart),
  bars(label: 'Bars (OHLC)', shortLabel: 'Bars', icon: Icons.bar_chart),
  baseline(
    label: 'Baseline',
    shortLabel: 'Baseline',
    icon: Icons.stacked_line_chart,
  ),
  stepLine(
    label: 'Step Line',
    shortLabel: 'Step',
    icon: Icons.timeline,
  );

  final String label;
  final String shortLabel;
  final IconData icon;

  const CandleStyle({
    required this.label,
    required this.shortLabel,
    required this.icon,
  });
}
