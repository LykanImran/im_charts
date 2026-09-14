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
  line(
    label: 'Line',
    shortLabel: 'Line',
    icon: Icons.show_chart,
  ),
  area(
    label: 'Area',
    shortLabel: 'Area',
    icon: Icons.area_chart,
  ),
  bars(
    label: 'Bars (OHLC)',
    shortLabel: 'Bars',
    icon: Icons.bar_chart,
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
