import 'package:flutter/material.dart';

/// Base abstract class for all nodes in the Formula Abstract Syntax Tree (AST).
abstract class FormulaNode {
  const FormulaNode();
}

/// Represents a numeric literal (e.g. 20, 3.14, -1.5).
class NumberLiteralNode extends FormulaNode {
  final double value;
  const NumberLiteralNode(this.value);

  @override
  String toString() => 'Number($value)';
}

/// Represents a string literal (e.g. "Upper Band").
class StringLiteralNode extends FormulaNode {
  final String value;
  const StringLiteralNode(this.value);

  @override
  String toString() => 'String("$value")';
}

/// Represents a color literal (e.g. #00E676, #FF5252).
class ColorLiteralNode extends FormulaNode {
  final Color color;
  const ColorLiteralNode(this.color);

  @override
  String toString() =>
      'Color(0x${color.toARGB32().toRadixString(16).padLeft(8, '0')})';
}

/// Represents a reference to a candle series variable
/// (e.g. close, open, high, low, volume, hl2, hlc3, ohlc4).
class SeriesVarNode extends FormulaNode {
  final String name;
  const SeriesVarNode(this.name);

  @override
  String toString() => 'Var($name)';
}

/// Represents historical bar indexing (e.g. `close[1]`, `high[2]`).
class HistoryOffsetNode extends FormulaNode {
  final FormulaNode target;
  final int offset;
  const HistoryOffsetNode(this.target, this.offset);

  @override
  String toString() => '$target[$offset]';
}

/// Represents unary prefix operators (e.g. `-x`, `+x`, `not x`, `!x`).
class UnaryOpNode extends FormulaNode {
  final String operator;
  final FormulaNode expression;
  const UnaryOpNode(this.operator, this.expression);

  @override
  String toString() => 'Unary($operator $expression)';
}

/// Represents binary operators (+, -, *, /, %, ^, >, <, >=, <=, ==, !=, and, or).
class BinaryOpNode extends FormulaNode {
  final String operator;
  final FormulaNode left;
  final FormulaNode right;
  const BinaryOpNode(this.operator, this.left, this.right);

  @override
  String toString() => 'Binary($left $operator $right)';
}

/// Represents ternary conditional expressions: `condition ? ifTrue : ifFalse`.
class TernaryNode extends FormulaNode {
  final FormulaNode condition;
  final FormulaNode ifTrue;
  final FormulaNode ifFalse;
  const TernaryNode(this.condition, this.ifTrue, this.ifFalse);

  @override
  String toString() => 'Ternary($condition ? $ifTrue : $ifFalse)';
}

/// Represents a function invocation (e.g. `sma(close, 20)`, `rsi(close, 14)`).
class FunctionCallNode extends FormulaNode {
  final String name;
  final List<FormulaNode> arguments;
  final Map<String, FormulaNode> namedArguments;

  const FunctionCallNode(
    this.name,
    this.arguments, [
    this.namedArguments = const {},
  ]);

  @override
  String toString() => 'Call($name(${arguments.join(', ')}))';
}

/// Represents a variable assignment in a script: `basis = sma(close, 20)`.
class AssignmentNode extends FormulaNode {
  final String variableName;
  final FormulaNode expression;
  const AssignmentNode(this.variableName, this.expression);

  @override
  String toString() => 'Assign($variableName = $expression)';
}

/// Represents a `plot(series, title="...", color=...)` statement.
class PlotNode extends FormulaNode {
  final FormulaNode expression;
  final String? title;
  final Color? color;
  final double strokeWidth;

  const PlotNode(
    this.expression, {
    this.title,
    this.color,
    this.strokeWidth = 1.5,
  });

  @override
  String toString() => 'Plot($expression, title: $title)';
}

/// Represents a complete multi-statement script.
class ScriptNode extends FormulaNode {
  final List<FormulaNode> statements;
  const ScriptNode(this.statements);

  @override
  String toString() => 'Script(${statements.length} statements)';
}
