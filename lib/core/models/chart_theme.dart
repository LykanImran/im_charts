import 'package:flutter/material.dart';

/// Styling and color tokens for the charting engine.
class ChartTheme {
  final Color backgroundColor;
  final Color bullishColor;
  final Color bearishColor;
  final Color bullishTransparent;
  final Color bearishTransparent;
  final Color gridColor;
  final Color axisTextColor;
  final Color axisLineColor;
  final Color crosshairColor;
  final Color crosshairBadgeBackground;
  final Color crosshairBadgeTextColor;
  final Color currentPriceLineColor;
  final Color currentPriceBadgeBackground;
  final Color currentPriceBadgeTextColor;
  final TextStyle axisTextStyle;
  final TextStyle tooltipTextStyle;

  const ChartTheme({
    required this.backgroundColor,
    required this.bullishColor,
    required this.bearishColor,
    required this.bullishTransparent,
    required this.bearishTransparent,
    required this.gridColor,
    required this.axisTextColor,
    required this.axisLineColor,
    required this.crosshairColor,
    required this.crosshairBadgeBackground,
    required this.crosshairBadgeTextColor,
    required this.currentPriceLineColor,
    required this.currentPriceBadgeBackground,
    required this.currentPriceBadgeTextColor,
    required this.axisTextStyle,
    required this.tooltipTextStyle,
  });

  /// Premium dark trading terminal theme (TradingView / Bloomberg dark aesthetic).
  factory ChartTheme.dark() {
    const bull = Color(0xFF089981);
    const bear = Color(0xFFF23645);
    const axisText = Color(0xFF868993);

    return ChartTheme(
      backgroundColor: const Color(0xFF131722),
      bullishColor: bull,
      bearishColor: bear,
      bullishTransparent: bull.withValues(alpha: 0.35),
      bearishTransparent: bear.withValues(alpha: 0.35),
      gridColor: const Color(0xFF1E222D),
      axisTextColor: axisText,
      axisLineColor: const Color(0xFF2A2E39),
      crosshairColor: const Color(0xFF787B86),
      crosshairBadgeBackground: const Color(0xFF2A2E39),
      crosshairBadgeTextColor: Colors.white,
      currentPriceLineColor: const Color(0xFF2962FF),
      currentPriceBadgeBackground: const Color(0xFF2962FF),
      currentPriceBadgeTextColor: Colors.white,
      axisTextStyle: const TextStyle(
        color: axisText,
        fontSize: 10,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w400,
      ),
      tooltipTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Clean modern light theme.
  factory ChartTheme.light() {
    const bull = Color(0xFF089981);
    const bear = Color(0xFFF23645);
    const axisText = Color(0xFF787B86);

    return ChartTheme(
      backgroundColor: Colors.white,
      bullishColor: bull,
      bearishColor: bear,
      bullishTransparent: bull.withValues(alpha: 0.35),
      bearishTransparent: bear.withValues(alpha: 0.35),
      gridColor: const Color(0xFFF0F3FA),
      axisTextColor: axisText,
      axisLineColor: const Color(0xFFE0E3EB),
      crosshairColor: const Color(0xFF9598A1),
      crosshairBadgeBackground: const Color(0xFF131722),
      crosshairBadgeTextColor: Colors.white,
      currentPriceLineColor: const Color(0xFF2962FF),
      currentPriceBadgeBackground: const Color(0xFF2962FF),
      currentPriceBadgeTextColor: Colors.white,
      axisTextStyle: const TextStyle(
        color: axisText,
        fontSize: 10,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w400,
      ),
      tooltipTextStyle: const TextStyle(
        color: Color(0xFF131722),
        fontSize: 11,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
