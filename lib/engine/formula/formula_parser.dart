import 'package:flutter/material.dart';
import 'formula_ast.dart';
import 'formula_lexer.dart';

/// Exception thrown when parsing formula fails.
class FormulaParseException implements Exception {
  final String message;
  final int line;
  final int column;

  FormulaParseException(this.message, this.line, this.column);

  @override
  String toString() => 'Formula Parse Error [$line:$column]: $message';
}

/// Recursive descent parser for PineScript-like formulas and indicator scripts.
class FormulaParser {
  final List<FormulaToken> tokens;
  int _current = 0;

  FormulaParser(this.tokens);

  factory FormulaParser.fromString(String source) {
    final lexer = FormulaLexer(source);
    final tokens = lexer.scanTokens();
    return FormulaParser(tokens);
  }

  /// Parses the tokens into a [ScriptNode].
  ScriptNode parseScript() {
    final statements = <FormulaNode>[];

    _skipSeparators();
    while (!_isAtEnd) {
      final stmt = _parseStatement();
      statements.add(stmt);
      _skipSeparators();
    }

    if (statements.isEmpty) {
      throw FormulaParseException('Empty script provided.', 1, 1);
    }

    return ScriptNode(statements);
  }

  /// Convenience method to parse a single expression.
  FormulaNode parseExpression() {
    _skipSeparators();
    final expr = _expression();
    if (!_isAtEnd && _peek().type != FormulaTokenType.newline) {
      throw _error(_peek(), 'Unexpected token after expression.');
    }
    return expr;
  }

  void _skipSeparators() {
    while (!_isAtEnd &&
        (_peek().type == FormulaTokenType.newline ||
            _peek().type == FormulaTokenType.semicolon)) {
      _advance();
    }
  }

  FormulaNode _parseStatement() {
    // Check for assignment: identifier = ...
    if (_check(FormulaTokenType.identifier) &&
        _checkNext(FormulaTokenType.equal)) {
      final idToken = _advance();
      _advance(); // Consume '='
      final expr = _expression();
      return AssignmentNode(idToken.text, expr);
    }

    // Check for plot(...)
    if (_check(FormulaTokenType.identifier) &&
        _peek().text.toLowerCase() == 'plot' &&
        _checkNext(FormulaTokenType.openParen)) {
      return _parsePlot();
    }

    // Otherwise, bare expression
    final expr = _expression();
    return expr;
  }

  FormulaNode _parsePlot() {
    _advance(); // Consume 'plot'
    _consume(FormulaTokenType.openParen, 'Expected "(" after plot.');

    final expr = _expression();
    String? title;
    Color? color;
    double strokeWidth = 1.5;

    while (_match(FormulaTokenType.comma)) {
      if (_isAtEnd || _check(FormulaTokenType.closeParen)) break;

      // Check for named arguments: title="...", color=#...
      if (_check(FormulaTokenType.identifier) &&
          _checkNext(FormulaTokenType.equal)) {
        final paramName = _advance().text.toLowerCase();
        _advance(); // Consume '='

        if (paramName == 'title') {
          if (_check(FormulaTokenType.string)) {
            title = _advance().literal as String;
          } else {
            throw _error(_peek(), 'Expected string literal for title.');
          }
        } else if (paramName == 'color') {
          if (_check(FormulaTokenType.color)) {
            color = _advance().literal as Color;
          } else {
            throw _error(
                _peek(), 'Expected color literal (e.g. #00E676) for color.');
          }
        } else if (paramName == 'width' || paramName == 'linewidth') {
          if (_check(FormulaTokenType.number)) {
            strokeWidth = _advance().literal as double;
          } else {
            throw _error(_peek(), 'Expected number for width.');
          }
        } else {
          // Unknown parameter, ignore expression
          _expression();
        }
      } else {
        // Positional argument
        if (_check(FormulaTokenType.color)) {
          color = _advance().literal as Color;
        } else if (_check(FormulaTokenType.string)) {
          title = _advance().literal as String;
        } else {
          _expression();
        }
      }
    }

    _consume(FormulaTokenType.closeParen, 'Expected ")" after plot arguments.');
    return PlotNode(
      expr,
      title: title,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  FormulaNode _expression() {
    return _ternary();
  }

  FormulaNode _ternary() {
    var expr = _logicalOr();

    if (_match(FormulaTokenType.question)) {
      final ifTrue = _expression();
      _consume(FormulaTokenType.colon, 'Expected ":" in ternary operator.');
      final ifFalse = _ternary();
      expr = TernaryNode(expr, ifTrue, ifFalse);
    }

    return expr;
  }

  FormulaNode _logicalOr() {
    var expr = _logicalAnd();

    while (_match(FormulaTokenType.or)) {
      final right = _logicalAnd();
      expr = BinaryOpNode('or', expr, right);
    }

    return expr;
  }

  FormulaNode _logicalAnd() {
    var expr = _equality();

    while (_match(FormulaTokenType.and)) {
      final right = _equality();
      expr = BinaryOpNode('and', expr, right);
    }

    return expr;
  }

  FormulaNode _equality() {
    var expr = _comparison();

    while (_matchAny([
      FormulaTokenType.equalEqual,
      FormulaTokenType.bangEqual,
    ])) {
      final opToken = _previous();
      final right = _comparison();
      expr = BinaryOpNode(opToken.text, expr, right);
    }

    return expr;
  }

  FormulaNode _comparison() {
    var expr = _term();

    while (_matchAny([
      FormulaTokenType.greater,
      FormulaTokenType.greaterEqual,
      FormulaTokenType.less,
      FormulaTokenType.lessEqual,
    ])) {
      final opToken = _previous();
      final right = _term();
      expr = BinaryOpNode(opToken.text, expr, right);
    }

    return expr;
  }

  FormulaNode _term() {
    var expr = _factor();

    while (_matchAny([FormulaTokenType.plus, FormulaTokenType.minus])) {
      final opToken = _previous();
      final right = _factor();
      expr = BinaryOpNode(opToken.text, expr, right);
    }

    return expr;
  }

  FormulaNode _factor() {
    var expr = _exponent();

    while (_matchAny([
      FormulaTokenType.star,
      FormulaTokenType.slash,
      FormulaTokenType.percent,
    ])) {
      final opToken = _previous();
      final right = _exponent();
      expr = BinaryOpNode(opToken.text, expr, right);
    }

    return expr;
  }

  FormulaNode _exponent() {
    var expr = _unary();

    while (_match(FormulaTokenType.caret)) {
      final right = _unary();
      expr = BinaryOpNode('^', expr, right);
    }

    return expr;
  }

  FormulaNode _unary() {
    if (_matchAny([
      FormulaTokenType.minus,
      FormulaTokenType.plus,
      FormulaTokenType.not,
    ])) {
      final opToken = _previous();
      final right = _unary();
      return UnaryOpNode(opToken.text, right);
    }

    return _postfix();
  }

  FormulaNode _postfix() {
    var expr = _primary();

    while (true) {
      if (_match(FormulaTokenType.openBracket)) {
        // History offset: series[1]
        if (!_check(FormulaTokenType.number)) {
          throw _error(
            _peek(),
            'Expected integer offset inside bracket index "[ ]".',
          );
        }
        final numToken = _advance();
        final offset = (numToken.literal as double).toInt();
        _consume(
          FormulaTokenType.closeBracket,
          'Expected "]" after history offset.',
        );
        expr = HistoryOffsetNode(expr, offset);
      } else {
        break;
      }
    }

    return expr;
  }

  FormulaNode _primary() {
    if (_match(FormulaTokenType.number)) {
      return NumberLiteralNode(_previous().literal as double);
    }

    if (_match(FormulaTokenType.string)) {
      return StringLiteralNode(_previous().literal as String);
    }

    if (_match(FormulaTokenType.color)) {
      return ColorLiteralNode(_previous().literal as Color);
    }

    if (_match(FormulaTokenType.openParen)) {
      final expr = _expression();
      _consume(FormulaTokenType.closeParen, 'Expected ")" after expression.');
      return expr;
    }

    if (_match(FormulaTokenType.identifier)) {
      final idToken = _previous();

      // Check if it's a function call: identifier(...)
      if (_match(FormulaTokenType.openParen)) {
        final args = <FormulaNode>[];
        final namedArgs = <String, FormulaNode>{};

        if (!_check(FormulaTokenType.closeParen)) {
          do {
            if (_check(FormulaTokenType.identifier) &&
                _checkNext(FormulaTokenType.equal)) {
              final name = _advance().text;
              _advance(); // '='
              final argExpr = _expression();
              namedArgs[name] = argExpr;
            } else {
              args.add(_expression());
            }
          } while (_match(FormulaTokenType.comma));
        }

        _consume(
          FormulaTokenType.closeParen,
          'Expected ")" after function arguments.',
        );
        return FunctionCallNode(idToken.text, args, namedArgs);
      }

      // Plain variable reference
      return SeriesVarNode(idToken.text);
    }

    throw _error(_peek(), 'Expected expression but found "${_peek().text}".');
  }

  bool _match(FormulaTokenType type) {
    if (_check(type)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _matchAny(List<FormulaTokenType> types) {
    for (final type in types) {
      if (_check(type)) {
        _advance();
        return true;
      }
    }
    return false;
  }

  bool _check(FormulaTokenType type) {
    if (_isAtEnd) return false;
    return _peek().type == type;
  }

  bool _checkNext(FormulaTokenType type) {
    if (_current + 1 >= tokens.length) return false;
    return tokens[_current + 1].type == type;
  }

  FormulaToken _advance() {
    if (!_isAtEnd) _current++;
    return _previous();
  }

  bool get _isAtEnd => _peek().type == FormulaTokenType.eof;
  FormulaToken _peek() => tokens[_current];
  FormulaToken _previous() => tokens[_current - 1];

  FormulaToken _consume(FormulaTokenType type, String message) {
    if (_check(type)) return _advance();
    throw _error(_peek(), message);
  }

  FormulaParseException _error(FormulaToken token, String message) {
    return FormulaParseException(message, token.line, token.column);
  }
}
