import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/core/models/candle.dart';
import 'package:im_charts/engine/formula/formula_ast.dart';
import 'package:im_charts/engine/formula/formula_evaluator.dart';
import 'package:im_charts/engine/formula/formula_indicator.dart';
import 'package:im_charts/engine/formula/formula_lexer.dart';
import 'package:im_charts/engine/formula/formula_parser.dart';

void main() {
  group('PineScript Formula Parser Tests', () {
    List<Candle> generateTestCandles(int count) {
      final list = <Candle>[];
      final baseTime = DateTime(2026, 9, 14, 9, 15);
      double price = 100.0;
      for (int i = 0; i < count; i++) {
        final change = (i % 2 == 0) ? 2.0 : -1.0;
        final open = price;
        final close = price + change;
        final high = (open > close ? open : close) + 1.5;
        final low = (open < close ? open : close) - 1.5;
        list.add(
          Candle(
            timestamp: baseTime.add(Duration(minutes: i * 5)),
            open: open,
            high: high,
            low: low,
            close: close,
            volume: 1000.0 + (i * 10),
          ),
        );
        price = close;
      }
      return list;
    }

    test('Lexer tokenizes expressions, colors, strings, and operators', () {
      const src =
          'basis = sma(close, 20) + 2.5 * stdev(close, 20)\nplot(basis, color=#00E676, title="Upper")';
      final lexer = FormulaLexer(src);
      final tokens = lexer.scanTokens();

      expect(tokens.any((t) => t.type == FormulaTokenType.identifier), isTrue);
      expect(tokens.any((t) => t.type == FormulaTokenType.color), isTrue);
      expect(tokens.any((t) => t.type == FormulaTokenType.string), isTrue);
      expect(tokens.any((t) => t.type == FormulaTokenType.plus), isTrue);
      expect(tokens.any((t) => t.type == FormulaTokenType.star), isTrue);
      expect(tokens.last.type, equals(FormulaTokenType.eof));
    });

    test('Parser parses arithmetic precedence correctly', () {
      final parser = FormulaParser.fromString('2 + 3 * 4');
      final ast = parser.parseExpression();

      expect(ast, isA<BinaryOpNode>());
      final bin = ast as BinaryOpNode;
      expect(bin.operator, equals('+'));
      expect(bin.left, isA<NumberLiteralNode>());
      expect(bin.right, isA<BinaryOpNode>());
      final rightBin = bin.right as BinaryOpNode;
      expect(rightBin.operator, equals('*'));
    });

    test('Parser parses ternary and bar history indexing', () {
      final parser = FormulaParser.fromString('close > open[1] ? high : low');
      final ast = parser.parseExpression();

      expect(ast, isA<TernaryNode>());
      final ternary = ast as TernaryNode;
      expect(ternary.condition, isA<BinaryOpNode>());
      expect(ternary.ifTrue, isA<SeriesVarNode>());
      expect(ternary.ifFalse, isA<SeriesVarNode>());
    });

    test('Evaluator evaluates basic series and arithmetic', () {
      final candles = generateTestCandles(20);
      final parser = FormulaParser.fromString('high - low');
      final ast = parser.parseScript();

      final evaluator = FormulaEvaluator(candles);
      final plots = evaluator.evaluate(ast);

      expect(plots.length, equals(1));
      final values = plots.first.values;
      expect(values.length, equals(20));

      for (int i = 0; i < 20; i++) {
        expect(values[i], closeTo(candles[i].high - candles[i].low, 1e-4));
      }
    });

    test('Evaluator calculates SMA and history offsets', () {
      final candles = generateTestCandles(30);
      final parser = FormulaParser.fromString('sma(close, 10)');
      final ast = parser.parseScript();

      final evaluator = FormulaEvaluator(candles);
      final plots = evaluator.evaluate(ast);

      final values = plots.first.values;
      expect(values.length, equals(30));
      // First 9 items null for 10-period SMA
      for (int i = 0; i < 9; i++) {
        expect(values[i], isNull);
      }
      expect(values[9], isNotNull);
      expect(values[29], isNotNull);

      // History offset: close[1]
      final histParser = FormulaParser.fromString('close[1]');
      final histPlots =
          FormulaEvaluator(candles).evaluate(histParser.parseScript());
      final histVals = histPlots.first.values;
      expect(histVals[0], isNull);
      expect(histVals[1], equals(candles[0].close));
      expect(histVals[2], equals(candles[1].close));
    });

    test('Evaluator calculates RSI, ATR, and standard deviation', () {
      final candles = generateTestCandles(40);
      final evaluator = FormulaEvaluator(candles);

      // RSI
      final rsiPlots = evaluator.evaluate(
        FormulaParser.fromString('rsi(close, 14)').parseScript(),
      );
      expect(rsiPlots.first.values[14], isNotNull);
      expect(rsiPlots.first.values[39], inInclusiveRange(0.0, 100.0));

      // ATR
      final atrPlots = evaluator.evaluate(
        FormulaParser.fromString('atr(14)').parseScript(),
      );
      expect(atrPlots.first.values[13], isNotNull);
      expect(atrPlots.first.values[39], greaterThan(0.0));

      // STDEV
      final stdevPlots = evaluator.evaluate(
        FormulaParser.fromString('stdev(close, 10)').parseScript(),
      );
      expect(stdevPlots.first.values[9], isNotNull);
      expect(stdevPlots.first.values[39], greaterThan(0.0));
    });

    test('Evaluator executes multi-line script with multiple plots', () {
      final candles = generateTestCandles(30);
      const script = '''
      basis = sma(close, 10)
      dev = 2.0 * stdev(close, 10)
      plot(basis + dev, title="Upper Band", color=#00E676)
      plot(basis - dev, title="Lower Band", color=#FF5252)
      ''';

      final parser = FormulaParser.fromString(script);
      final ast = parser.parseScript();
      final evaluator = FormulaEvaluator(candles);
      final plots = evaluator.evaluate(ast);

      expect(plots.length, equals(2));
      expect(plots[0].label, equals('Upper Band'));
      expect(plots[0].color, equals(const Color(0xFF00E676)));
      expect(plots[1].label, equals('Lower Band'));
      expect(plots[1].color, equals(const Color(0xFFFF5252)));

      // At index 20, upper should be > lower
      expect(plots[0].values[20]!, greaterThan(plots[1].values[20]!));
    });

    test('FormulaIndicator integrates smoothly as an Indicator', () {
      final candles = generateTestCandles(25);
      final ind = FormulaIndicator(
        name: 'My Channel',
        formula: 'close > open ? 1.0 : -1.0',
        isOverlay: false,
      );

      expect(ind.id, equals('formula_my_channel'));
      expect(ind.name, equals('My Channel'));
      expect(ind.isOverlay, isFalse);

      final result = ind.calculate(candles);
      expect(result.series.length, equals(1));
      expect(result.series.first.values.length, equals(25));
      for (int i = 0; i < 25; i++) {
        final expected = candles[i].close > candles[i].open ? 1.0 : -1.0;
        expect(result.series.first.values[i], equals(expected));
      }
    });
  });
}
