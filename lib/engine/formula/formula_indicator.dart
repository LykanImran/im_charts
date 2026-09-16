import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import '../indicators/indicator.dart';
import '../indicators/indicator_result.dart';
import 'formula_evaluator.dart';
import 'formula_parser.dart';

/// Technical indicator driven dynamically by a user-defined PineScript formula.
class FormulaIndicator implements Indicator {
  final String _id;
  final String _name;
  final String formula;
  final bool _isOverlay;
  final Color defaultColor;
  final double strokeWidth;

  FormulaIndicator({
    String? id,
    String name = 'Custom Formula',
    required this.formula,
    bool isOverlay = true,
    this.defaultColor = const Color(0xFF00E5FF),
    this.strokeWidth = 1.5,
  })  : _name = name,
        _id = id ??
            'formula_${name.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
        _isOverlay = isOverlay;

  @override
  String get id => _id;

  @override
  String get name => _name;

  @override
  bool get isOverlay => _isOverlay;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    if (candles.isEmpty || formula.trim().isEmpty) {
      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: isOverlay,
        series: const [],
      );
    }

    try {
      final parser = FormulaParser.fromString(formula);
      final ast = parser.parseScript();
      final evaluator = FormulaEvaluator(candles);
      final series = evaluator.evaluate(
        ast,
        defaultTitle: name,
        defaultColor: defaultColor,
      );

      return IndicatorResult(
        indicatorId: id,
        name: name,
        isOverlay: isOverlay,
        series: series,
      );
    } catch (e) {
      // If formula fails to evaluate, return empty result without crashing
      return IndicatorResult(
        indicatorId: id,
        name: '$name (Error)',
        isOverlay: isOverlay,
        series: const [],
      );
    }
  }
}
