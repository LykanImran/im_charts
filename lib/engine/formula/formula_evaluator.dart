import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/candle.dart';
import '../indicators/indicator_result.dart';
import 'formula_ast.dart';
import 'formula_parser.dart';

/// Evaluates a parsed formula AST over a series of candles.
class FormulaEvaluator {
  final List<Candle> candles;
  final Map<String, List<double?>> _scope = {};
  final List<IndicatorSeries> _plots = [];
  int _plotCounter = 0;

  FormulaEvaluator(this.candles) {
    _initializeBuiltinSeries();
  }

  void _initializeBuiltinSeries() {
    final n = candles.length;
    final opens = List<double?>.filled(n, null);
    final highs = List<double?>.filled(n, null);
    final lows = List<double?>.filled(n, null);
    final closes = List<double?>.filled(n, null);
    final volumes = List<double?>.filled(n, null);
    final hl2 = List<double?>.filled(n, null);
    final hlc3 = List<double?>.filled(n, null);
    final ohlc4 = List<double?>.filled(n, null);

    for (int i = 0; i < n; i++) {
      final c = candles[i];
      opens[i] = c.open;
      highs[i] = c.high;
      lows[i] = c.low;
      closes[i] = c.close;
      volumes[i] = c.volume;
      hl2[i] = (c.high + c.low) / 2.0;
      hlc3[i] = (c.high + c.low + c.close) / 3.0;
      ohlc4[i] = (c.open + c.high + c.low + c.close) / 4.0;
    }

    _scope['open'] = opens;
    _scope['o'] = opens;
    _scope['high'] = highs;
    _scope['h'] = highs;
    _scope['low'] = lows;
    _scope['l'] = lows;
    _scope['close'] = closes;
    _scope['c'] = closes;
    _scope['volume'] = volumes;
    _scope['v'] = volumes;
    _scope['hl2'] = hl2;
    _scope['hlc3'] = hlc3;
    _scope['ohlc4'] = ohlc4;
  }

  /// Evaluates an AST script or expression and returns a list of [IndicatorSeries].
  List<IndicatorSeries> evaluate(
    FormulaNode node, {
    String defaultTitle = 'Formula',
    Color defaultColor = const Color(0xFF00E5FF),
  }) {
    _plots.clear();
    _plotCounter = 0;

    if (node is ScriptNode) {
      List<double?>? lastResult;
      for (final stmt in node.statements) {
        if (stmt is AssignmentNode) {
          final res = _evaluateExpression(stmt.expression);
          _scope[stmt.variableName.toLowerCase()] = res;
          lastResult = res;
        } else if (stmt is PlotNode) {
          final res = _evaluateExpression(stmt.expression);
          _addPlot(
            res,
            title: stmt.title ?? 'Plot ${++_plotCounter}',
            color: stmt.color ?? defaultColor,
            strokeWidth: stmt.strokeWidth,
          );
          lastResult = res;
        } else {
          lastResult = _evaluateExpression(stmt);
        }
      }

      // If no explicit plot() calls were made, plot the final expression
      if (_plots.isEmpty && lastResult != null) {
        _addPlot(
          lastResult,
          title: defaultTitle,
          color: defaultColor,
        );
      }
    } else if (node is PlotNode) {
      final res = _evaluateExpression(node.expression);
      _addPlot(
        res,
        title: node.title ?? defaultTitle,
        color: node.color ?? defaultColor,
        strokeWidth: node.strokeWidth,
      );
    } else {
      final res = _evaluateExpression(node);
      _addPlot(
        res,
        title: defaultTitle,
        color: defaultColor,
      );
    }

    return _plots;
  }

  void _addPlot(
    List<double?> values, {
    required String title,
    required Color color,
    double strokeWidth = 1.5,
  }) {
    _plots.add(
      IndicatorSeries(
        id: 'plot_${_plots.length + 1}',
        label: title,
        color: color,
        strokeWidth: strokeWidth,
        values: values,
      ),
    );
  }

  List<double?> _evaluateExpression(FormulaNode node) {
    final n = candles.length;

    if (node is NumberLiteralNode) {
      return List<double?>.filled(n, node.value);
    }

    if (node is SeriesVarNode) {
      final key = node.name.toLowerCase();
      final series = _scope[key];
      if (series != null) return series;

      // Special handling for tr (True Range) as a variable
      if (key == 'tr') {
        return _calculateTrueRange();
      }

      throw FormulaParseException(
        'Unknown variable or series "$key". Available: close, open, high, low, volume, hl2, hlc3, ohlc4, tr.',
        1,
        1,
      );
    }

    if (node is HistoryOffsetNode) {
      final source = _evaluateExpression(node.target);
      final offset = node.offset;
      final result = List<double?>.filled(n, null);
      for (int i = offset; i < n; i++) {
        result[i] = source[i - offset];
      }
      return result;
    }

    if (node is UnaryOpNode) {
      final inner = _evaluateExpression(node.expression);
      final result = List<double?>.filled(n, null);
      for (int i = 0; i < n; i++) {
        final val = inner[i];
        if (val == null) continue;
        switch (node.operator) {
          case '-':
            result[i] = -val;
            break;
          case '+':
            result[i] = val;
            break;
          case 'not':
          case '!':
            result[i] = (val == 0.0) ? 1.0 : 0.0;
            break;
        }
      }
      return result;
    }

    if (node is BinaryOpNode) {
      final left = _evaluateExpression(node.left);
      final right = _evaluateExpression(node.right);
      final result = List<double?>.filled(n, null);

      for (int i = 0; i < n; i++) {
        final a = left[i];
        final b = right[i];

        // Handle logical operators where null counts as false (0.0)
        if (node.operator == 'and' || node.operator == '&&') {
          final aBool = a != null && a != 0.0;
          final bBool = b != null && b != 0.0;
          result[i] = (aBool && bBool) ? 1.0 : 0.0;
          continue;
        }

        if (node.operator == 'or' || node.operator == '||') {
          final aBool = a != null && a != 0.0;
          final bBool = b != null && b != 0.0;
          result[i] = (aBool || bBool) ? 1.0 : 0.0;
          continue;
        }

        if (a == null || b == null) continue;

        switch (node.operator) {
          case '+':
            result[i] = a + b;
            break;
          case '-':
            result[i] = a - b;
            break;
          case '*':
            result[i] = a * b;
            break;
          case '/':
            result[i] = (b != 0.0) ? a / b : null;
            break;
          case '%':
            result[i] = (b != 0.0) ? a % b : null;
            break;
          case '^':
            result[i] = math.pow(a, b).toDouble();
            break;
          case '>':
            result[i] = a > b ? 1.0 : 0.0;
            break;
          case '<':
            result[i] = a < b ? 1.0 : 0.0;
            break;
          case '>=':
            result[i] = a >= b ? 1.0 : 0.0;
            break;
          case '<=':
            result[i] = a <= b ? 1.0 : 0.0;
            break;
          case '==':
            result[i] = (a - b).abs() < 1e-9 ? 1.0 : 0.0;
            break;
          case '!=':
            result[i] = (a - b).abs() >= 1e-9 ? 1.0 : 0.0;
            break;
        }
      }
      return result;
    }

    if (node is TernaryNode) {
      final cond = _evaluateExpression(node.condition);
      final ifTrue = _evaluateExpression(node.ifTrue);
      final ifFalse = _evaluateExpression(node.ifFalse);
      final result = List<double?>.filled(n, null);

      for (int i = 0; i < n; i++) {
        final c = cond[i];
        if (c != null && c != 0.0) {
          result[i] = ifTrue[i];
        } else {
          result[i] = ifFalse[i];
        }
      }
      return result;
    }

    if (node is FunctionCallNode) {
      return _evaluateFunctionCall(node);
    }

    return List<double?>.filled(n, null);
  }

  List<double?> _evaluateFunctionCall(FunctionCallNode call) {
    final name = call.name.toLowerCase();
    final n = candles.length;

    switch (name) {
      case 'sma':
        _assertArgCount(call, 2);
        final src = _evaluateExpression(call.arguments[0]);
        final period = _extractIntArg(call.arguments[1], 'period');
        return _calculateSma(src, period);

      case 'ema':
        _assertArgCount(call, 2);
        final src = _evaluateExpression(call.arguments[0]);
        final period = _extractIntArg(call.arguments[1], 'period');
        return _calculateEma(src, period);

      case 'wma':
        _assertArgCount(call, 2);
        final src = _evaluateExpression(call.arguments[0]);
        final period = _extractIntArg(call.arguments[1], 'period');
        return _calculateWma(src, period);

      case 'stdev':
        _assertArgCount(call, 2);
        final src = _evaluateExpression(call.arguments[0]);
        final period = _extractIntArg(call.arguments[1], 'period');
        return _calculateStdev(src, period);

      case 'highest':
        _assertArgCount(call, 2);
        final src = _evaluateExpression(call.arguments[0]);
        final period = _extractIntArg(call.arguments[1], 'period');
        return _calculateHighest(src, period);

      case 'lowest':
        _assertArgCount(call, 2);
        final src = _evaluateExpression(call.arguments[0]);
        final period = _extractIntArg(call.arguments[1], 'period');
        return _calculateLowest(src, period);

      case 'rsi':
        _assertArgCount(call, 2);
        final src = _evaluateExpression(call.arguments[0]);
        final period = _extractIntArg(call.arguments[1], 'period');
        return _calculateRsi(src, period);

      case 'atr':
        _assertArgCount(call, 1);
        final period = _extractIntArg(call.arguments[0], 'period');
        return _calculateAtr(period);

      case 'tr':
        return _calculateTrueRange();

      case 'change':
        _assertArgCount(call, 1);
        final src = _evaluateExpression(call.arguments[0]);
        final result = List<double?>.filled(n, null);
        for (int i = 1; i < n; i++) {
          final curr = src[i];
          final prev = src[i - 1];
          if (curr != null && prev != null) {
            result[i] = curr - prev;
          }
        }
        return result;

      // Mathematical scalar functions mapped across vectors
      case 'abs':
        _assertArgCount(call, 1);
        return _mapSingle(call.arguments[0], (v) => v.abs());

      case 'sqrt':
        _assertArgCount(call, 1);
        return _mapSingle(
          call.arguments[0],
          (v) => v >= 0 ? math.sqrt(v) : null,
        );

      case 'log':
        _assertArgCount(call, 1);
        return _mapSingle(
          call.arguments[0],
          (v) => v > 0 ? math.log(v) : null,
        );

      case 'exp':
        _assertArgCount(call, 1);
        return _mapSingle(call.arguments[0], (v) => math.exp(v));

      case 'round':
        _assertArgCount(call, 1);
        return _mapSingle(call.arguments[0], (v) => v.roundToDouble());

      case 'floor':
        _assertArgCount(call, 1);
        return _mapSingle(call.arguments[0], (v) => v.floorToDouble());

      case 'ceil':
        _assertArgCount(call, 1);
        return _mapSingle(call.arguments[0], (v) => v.ceilToDouble());

      case 'max':
        _assertArgCount(call, 2);
        return _mapDouble(call.arguments[0], call.arguments[1], math.max);

      case 'min':
        _assertArgCount(call, 2);
        return _mapDouble(call.arguments[0], call.arguments[1], math.min);

      case 'pow':
        _assertArgCount(call, 2);
        return _mapDouble(
          call.arguments[0],
          call.arguments[1],
          (a, b) => math.pow(a, b).toDouble(),
        );

      default:
        throw FormulaParseException(
          'Unknown function "$name". Available functions: sma, ema, wma, stdev, highest, lowest, rsi, atr, tr, change, abs, sqrt, log, exp, max, min, pow.',
          1,
          1,
        );
    }
  }

  void _assertArgCount(FunctionCallNode call, int expected) {
    if (call.arguments.length != expected) {
      throw FormulaParseException(
        'Function "${call.name}" expects $expected arguments, but got ${call.arguments.length}.',
        1,
        1,
      );
    }
  }

  int _extractIntArg(FormulaNode node, String paramName) {
    if (node is NumberLiteralNode) {
      return node.value.toInt();
    }
    throw FormulaParseException(
      'Argument "$paramName" must be a constant integer number.',
      1,
      1,
    );
  }

  List<double?> _mapSingle(
    FormulaNode arg,
    double? Function(double v) transform,
  ) {
    final src = _evaluateExpression(arg);
    final result = List<double?>.filled(src.length, null);
    for (int i = 0; i < src.length; i++) {
      final v = src[i];
      if (v != null) {
        result[i] = transform(v);
      }
    }
    return result;
  }

  List<double?> _mapDouble(
    FormulaNode arg1,
    FormulaNode arg2,
    double? Function(double a, double b) transform,
  ) {
    final s1 = _evaluateExpression(arg1);
    final s2 = _evaluateExpression(arg2);
    final n = math.min(s1.length, s2.length);
    final result = List<double?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      final a = s1[i];
      final b = s2[i];
      if (a != null && b != null) {
        result[i] = transform(a, b);
      }
    }
    return result;
  }

  List<double?> _calculateSma(List<double?> src, int period) {
    final n = src.length;
    final result = List<double?>.filled(n, null);
    if (period <= 0 || n < period) return result;

    double sum = 0.0;
    int count = 0;

    for (int i = 0; i < n; i++) {
      final val = src[i];
      if (val != null) {
        sum += val;
        count++;
      }
      if (i >= period) {
        final removeVal = src[i - period];
        if (removeVal != null) {
          sum -= removeVal;
          count--;
        }
      }
      if (i >= period - 1 && count == period) {
        result[i] = sum / period;
      }
    }
    return result;
  }

  List<double?> _calculateEma(List<double?> src, int period) {
    final n = src.length;
    final result = List<double?>.filled(n, null);
    if (period <= 0 || n < period) return result;

    final multiplier = 2.0 / (period + 1);

    // Initial SMA for seed
    double initialSum = 0.0;
    for (int i = 0; i < period; i++) {
      final v = src[i];
      if (v == null) return result;
      initialSum += v;
    }

    double currentEma = initialSum / period;
    result[period - 1] = currentEma;

    for (int i = period; i < n; i++) {
      final val = src[i];
      if (val != null) {
        currentEma = (val - currentEma) * multiplier + currentEma;
        result[i] = currentEma;
      } else {
        result[i] = currentEma;
      }
    }
    return result;
  }

  List<double?> _calculateWma(List<double?> src, int period) {
    final n = src.length;
    final result = List<double?>.filled(n, null);
    if (period <= 0 || n < period) return result;

    final weightSum = (period * (period + 1)) / 2.0;

    for (int i = period - 1; i < n; i++) {
      double sum = 0.0;
      bool valid = true;
      for (int j = 0; j < period; j++) {
        final val = src[i - period + 1 + j];
        if (val == null) {
          valid = false;
          break;
        }
        sum += val * (j + 1);
      }
      if (valid) {
        result[i] = sum / weightSum;
      }
    }
    return result;
  }

  List<double?> _calculateStdev(List<double?> src, int period) {
    final n = src.length;
    final result = List<double?>.filled(n, null);
    if (period <= 1 || n < period) return result;

    final sma = _calculateSma(src, period);

    for (int i = period - 1; i < n; i++) {
      final mean = sma[i];
      if (mean == null) continue;

      double sumSquares = 0.0;
      bool valid = true;
      for (int j = 0; j < period; j++) {
        final val = src[i - j];
        if (val == null) {
          valid = false;
          break;
        }
        sumSquares += (val - mean) * (val - mean);
      }
      if (valid) {
        result[i] = math.sqrt(sumSquares / (period - 1));
      }
    }
    return result;
  }

  List<double?> _calculateHighest(List<double?> src, int period) {
    final n = src.length;
    final result = List<double?>.filled(n, null);
    if (period <= 0 || n < period) return result;

    for (int i = period - 1; i < n; i++) {
      double maxVal = -double.infinity;
      bool hasVal = false;
      for (int j = 0; j < period; j++) {
        final val = src[i - j];
        if (val != null && val > maxVal) {
          maxVal = val;
          hasVal = true;
        }
      }
      if (hasVal) {
        result[i] = maxVal;
      }
    }
    return result;
  }

  List<double?> _calculateLowest(List<double?> src, int period) {
    final n = src.length;
    final result = List<double?>.filled(n, null);
    if (period <= 0 || n < period) return result;

    for (int i = period - 1; i < n; i++) {
      double minVal = double.infinity;
      bool hasVal = false;
      for (int j = 0; j < period; j++) {
        final val = src[i - j];
        if (val != null && val < minVal) {
          minVal = val;
          hasVal = true;
        }
      }
      if (hasVal) {
        result[i] = minVal;
      }
    }
    return result;
  }

  List<double?> _calculateTrueRange() {
    final n = candles.length;
    final tr = List<double?>.filled(n, null);
    if (n == 0) return tr;

    tr[0] = candles[0].high - candles[0].low;

    for (int i = 1; i < n; i++) {
      final c = candles[i];
      final prevClose = candles[i - 1].close;
      final hl = c.high - c.low;
      final hc = (c.high - prevClose).abs();
      final lc = (c.low - prevClose).abs();
      tr[i] = math.max(hl, math.max(hc, lc));
    }
    return tr;
  }

  List<double?> _calculateAtr(int period) {
    final n = candles.length;
    final result = List<double?>.filled(n, null);
    if (period <= 0 || n < period) return result;

    final tr = _calculateTrueRange();

    // Wilder's smoothed ATR
    double sum = 0.0;
    for (int i = 0; i < period; i++) {
      sum += tr[i]!;
    }
    double currentAtr = sum / period;
    result[period - 1] = currentAtr;

    for (int i = period; i < n; i++) {
      currentAtr = (currentAtr * (period - 1) + tr[i]!) / period;
      result[i] = currentAtr;
    }
    return result;
  }

  List<double?> _calculateRsi(List<double?> src, int period) {
    final n = src.length;
    final rsi = List<double?>.filled(n, null);
    if (period <= 0 || n <= period) return rsi;

    double gainSum = 0.0;
    double lossSum = 0.0;

    for (int i = 1; i <= period; i++) {
      final curr = src[i];
      final prev = src[i - 1];
      if (curr == null || prev == null) return rsi;
      final diff = curr - prev;
      if (diff >= 0) {
        gainSum += diff;
      } else {
        lossSum += -diff;
      }
    }

    double avgGain = gainSum / period;
    double avgLoss = lossSum / period;

    rsi[period] = (avgLoss == 0.0)
        ? 100.0
        : 100.0 - (100.0 / (1.0 + (avgGain / avgLoss)));

    for (int i = period + 1; i < n; i++) {
      final curr = src[i];
      final prev = src[i - 1];
      if (curr == null || prev == null) continue;

      final diff = curr - prev;
      final gain = diff > 0 ? diff : 0.0;
      final loss = diff < 0 ? -diff : 0.0;

      avgGain = ((avgGain * (period - 1)) + gain) / period;
      avgLoss = ((avgLoss * (period - 1)) + loss) / period;

      if (avgLoss == 0.0) {
        rsi[i] = 100.0;
      } else {
        final rs = avgGain / avgLoss;
        rsi[i] = 100.0 - (100.0 / (1.0 + rs));
      }
    }

    return rsi;
  }
}
