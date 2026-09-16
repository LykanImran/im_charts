import 'package:flutter/material.dart';

/// Types of tokens recognized by the formula scanner.
enum FormulaTokenType {
  number,
  identifier,
  string,
  color,

  // Arithmetic
  plus, // +
  minus, // -
  star, // *
  slash, // /
  percent, // %
  caret, // ^

  // Comparison
  equalEqual, // ==
  bangEqual, // !=
  less, // <
  lessEqual, // <=
  greater, // >
  greaterEqual, // >=

  // Assignment
  equal, // =

  // Logical
  and, // and, &&
  or, // or, ||
  not, // not, !
  question, // ?
  colon, // :

  // Delimiters
  openParen, // (
  closeParen, // )
  openBracket, // [
  closeBracket, // ]
  comma, // ,
  semicolon, // ;
  newline, // \n (statement separator)

  eof,
}

/// Token produced by [FormulaLexer].
class FormulaToken {
  final FormulaTokenType type;
  final String text;
  final dynamic literal;
  final int line;
  final int column;

  const FormulaToken({
    required this.type,
    required this.text,
    this.literal,
    required this.line,
    required this.column,
  });

  @override
  String toString() => '$type("$text" @ $line:$column)';
}

/// Exception thrown when lexical analysis fails.
class FormulaLexerException implements Exception {
  final String message;
  final int line;
  final int column;

  FormulaLexerException(this.message, this.line, this.column);

  @override
  String toString() => 'Lexer Error [$line:$column]: $message';
}

/// Lexer / Tokenizer for PineScript-like formulas and indicator scripts.
class FormulaLexer {
  final String source;
  final List<FormulaToken> _tokens = [];
  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _lineStart = 0;

  FormulaLexer(this.source);

  int get _column => _start - _lineStart + 1;

  List<FormulaToken> scanTokens() {
    while (!_isAtEnd) {
      _start = _current;
      _scanToken();
    }
    _tokens.add(
      FormulaToken(
        type: FormulaTokenType.eof,
        text: '',
        line: _line,
        column: _column,
      ),
    );
    return _tokens;
  }

  bool get _isAtEnd => _current >= source.length;

  String _advance() {
    return source[_current++];
  }

  bool _match(String expected) {
    if (_isAtEnd) return false;
    if (source[_current] != expected) return false;
    _current++;
    return true;
  }

  String _peek() {
    if (_isAtEnd) return '\x00';
    return source[_current];
  }

  String _peekNext() {
    if (_current + 1 >= source.length) return '\x00';
    return source[_current + 1];
  }

  void _scanToken() {
    final c = _advance();
    switch (c) {
      case ' ':
      case '\r':
      case '\t':
        // Ignore whitespace
        break;

      case '\n':
        _addToken(FormulaTokenType.newline);
        _line++;
        _lineStart = _current;
        break;

      case ';':
        _addToken(FormulaTokenType.semicolon);
        break;
      case '(':
        _addToken(FormulaTokenType.openParen);
        break;
      case ')':
        _addToken(FormulaTokenType.closeParen);
        break;
      case '[':
        _addToken(FormulaTokenType.openBracket);
        break;
      case ']':
        _addToken(FormulaTokenType.closeBracket);
        break;
      case ',':
        _addToken(FormulaTokenType.comma);
        break;
      case '+':
        _addToken(FormulaTokenType.plus);
        break;
      case '-':
        _addToken(FormulaTokenType.minus);
        break;
      case '*':
        _addToken(FormulaTokenType.star);
        break;
      case '%':
        _addToken(FormulaTokenType.percent);
        break;
      case '^':
        _addToken(FormulaTokenType.caret);
        break;
      case '?':
        _addToken(FormulaTokenType.question);
        break;
      case ':':
        _addToken(FormulaTokenType.colon);
        break;

      case '/':
        if (_match('/')) {
          // Line comment: skip until newline
          while (_peek() != '\n' && !_isAtEnd) {
            _advance();
          }
        } else if (_match('*')) {
          // Block comment
          while (!_isAtEnd && !(_peek() == '*' && _peekNext() == '/')) {
            if (_peek() == '\n') {
              _line++;
              _lineStart = _current + 1;
            }
            _advance();
          }
          if (!_isAtEnd) {
            _advance(); // '*'
            _advance(); // '/'
          }
        } else {
          _addToken(FormulaTokenType.slash);
        }
        break;

      case '!':
        _addToken(
          _match('=') ? FormulaTokenType.bangEqual : FormulaTokenType.not,
        );
        break;

      case '=':
        _addToken(
          _match('=') ? FormulaTokenType.equalEqual : FormulaTokenType.equal,
        );
        break;

      case '<':
        _addToken(
          _match('=') ? FormulaTokenType.lessEqual : FormulaTokenType.less,
        );
        break;

      case '>':
        _addToken(
          _match('=')
              ? FormulaTokenType.greaterEqual
              : FormulaTokenType.greater,
        );
        break;

      case '&':
        if (_match('&')) {
          _addToken(FormulaTokenType.and);
        } else {
          throw FormulaLexerException(
            'Unexpected character "&". Did you mean "&&"?',
            _line,
            _column,
          );
        }
        break;

      case '|':
        if (_match('|')) {
          _addToken(FormulaTokenType.or);
        } else {
          throw FormulaLexerException(
            'Unexpected character "|". Did you mean "||"?',
            _line,
            _column,
          );
        }
        break;

      case '#':
        _scanColor();
        break;

      case '"':
      case "'":
        _scanString(c);
        break;

      default:
        if (_isDigit(c)) {
          _scanNumber();
        } else if (_isAlpha(c)) {
          _scanIdentifier();
        } else {
          throw FormulaLexerException(
            'Unexpected character "$c"',
            _line,
            _column,
          );
        }
        break;
    }
  }

  void _scanNumber() {
    while (_isDigit(_peek())) {
      _advance();
    }
    if (_peek() == '.' && _isDigit(_peekNext())) {
      _advance(); // Consume '.'
      while (_isDigit(_peek())) {
        _advance();
      }
    }
    final text = source.substring(_start, _current);
    final value = double.parse(text);
    _addTokenWithLiteral(FormulaTokenType.number, value);
  }

  void _scanColor() {
    // #RRGGBB or #AARRGGBB
    while (_isHexDigit(_peek())) {
      _advance();
    }
    final text = source.substring(_start, _current);
    final hexCode = text.substring(1); // strip '#'
    if (hexCode.length == 6) {
      final val = int.parse('FF$hexCode', radix: 16);
      _addTokenWithLiteral(FormulaTokenType.color, Color(val));
    } else if (hexCode.length == 8) {
      final val = int.parse(hexCode, radix: 16);
      _addTokenWithLiteral(FormulaTokenType.color, Color(val));
    } else {
      throw FormulaLexerException(
        'Invalid hex color "$text". Expected format #RRGGBB or #AARRGGBB.',
        _line,
        _column,
      );
    }
  }

  void _scanString(String quoteChar) {
    while (_peek() != quoteChar && !_isAtEnd) {
      if (_peek() == '\n') {
        _line++;
        _lineStart = _current + 1;
      }
      _advance();
    }

    if (_isAtEnd) {
      throw FormulaLexerException(
          'Unterminated string literal.', _line, _column);
    }

    _advance(); // Consume closing quote
    final value = source.substring(_start + 1, _current - 1);
    _addTokenWithLiteral(FormulaTokenType.string, value);
  }

  void _scanIdentifier() {
    while (_isAlphaNumeric(_peek())) {
      _advance();
    }
    final text = source.substring(_start, _current);
    final lower = text.toLowerCase();

    // Check keywords
    switch (lower) {
      case 'and':
        _addToken(FormulaTokenType.and);
        break;
      case 'or':
        _addToken(FormulaTokenType.or);
        break;
      case 'not':
        _addToken(FormulaTokenType.not);
        break;
      default:
        _addToken(FormulaTokenType.identifier);
        break;
    }
  }

  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _isHexDigit(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 70) || // A-F
        (code >= 97 && code <= 102); // a-f
  }

  bool _isAlpha(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        code == 95; // _
  }

  bool _isAlphaNumeric(String c) => _isAlpha(c) || _isDigit(c);

  void _addToken(FormulaTokenType type) {
    _addTokenWithLiteral(type, null);
  }

  void _addTokenWithLiteral(FormulaTokenType type, dynamic literal) {
    final text = source.substring(_start, _current);
    _tokens.add(
      FormulaToken(
        type: type,
        text: text,
        literal: literal,
        line: _line,
        column: _column,
      ),
    );
  }
}
