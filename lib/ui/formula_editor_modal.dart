import 'package:flutter/material.dart';
import '../engine/chart_controller.dart';
import '../engine/formula/formula_indicator.dart';
import '../engine/formula/formula_parser.dart';

/// Modal dialog for authoring, testing, and mounting custom PineScript formulas.
class FormulaEditorModal extends StatefulWidget {
  final TradingChartController controller;

  const FormulaEditorModal({
    super.key,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required TradingChartController controller,
  }) {
    return showDialog(
      context: context,
      builder: (context) => FormulaEditorModal(controller: controller),
    );
  }

  @override
  State<FormulaEditorModal> createState() => _FormulaEditorModalState();
}

class _FormulaEditorModalState extends State<FormulaEditorModal> {
  final _nameController = TextEditingController(text: 'Upper Band');
  final _formulaController = TextEditingController(
    text: 'sma(close, 20) + 2 * stdev(close, 20)',
  );

  bool _isOverlay = true;
  Color _selectedColor = const Color(0xFF00E5FF);
  String? _validationError;
  bool _isValid = true;

  final List<Color> _palette = const [
    Color(0xFF00E5FF), // Cyan
    Color(0xFF00E676), // Green
    Color(0xFFFF5252), // Red
    Color(0xFFFFB300), // Amber
    Color(0xFFAB47BC), // Purple
    Color(0xFF2962FF), // Blue
  ];

  static const List<Map<String, dynamic>> _presets = [
    {
      'title': 'Upper Bollinger',
      'name': 'Upper Band',
      'formula': 'sma(close, 20) + 2 * stdev(close, 20)',
      'isOverlay': true,
      'color': Color(0xFF00E5FF),
    },
    {
      'title': 'Lower Bollinger',
      'name': 'Lower Band',
      'formula': 'sma(close, 20) - 2 * stdev(close, 20)',
      'isOverlay': true,
      'color': Color(0xFFFF5252),
    },
    {
      'title': 'Pivot HLC3',
      'name': 'Pivot HLC3',
      'formula': 'hlc3',
      'isOverlay': true,
      'color': Color(0xFFFFB300),
    },
    {
      'title': 'ATR Trailing Band',
      'name': 'ATR Trailing',
      'formula': 'close - 2.0 * atr(14)',
      'isOverlay': true,
      'color': Color(0xFF00E676),
    },
    {
      'title': 'RSI Momentum',
      'name': 'RSI 14',
      'formula': 'rsi(close, 14)',
      'isOverlay': false,
      'color': Color(0xFFAB47BC),
    },
    {
      'title': 'Candle Spread',
      'name': 'Bull Spread',
      'formula': 'close > open ? (high - low) : 0',
      'isOverlay': false,
      'color': Color(0xFF00E676),
    },
    {
      'title': 'Dual Band Script',
      'name': 'Dual Bands',
      'formula':
          'basis = sma(close, 20)\ndev = 2.0 * stdev(close, 20)\nplot(basis + dev, color=#00E676, title="Upper")\nplot(basis - dev, color=#FF5252, title="Lower")',
      'isOverlay': true,
      'color': Color(0xFF2962FF),
    },
  ];

  @override
  void initState() {
    super.initState();
    _validateFormula();
    _formulaController.addListener(_validateFormula);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _formulaController.dispose();
    super.dispose();
  }

  void _validateFormula() {
    final text = _formulaController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _isValid = false;
        _validationError = 'Formula cannot be empty.';
      });
      return;
    }

    try {
      final parser = FormulaParser.fromString(text);
      parser.parseScript();
      setState(() {
        _isValid = true;
        _validationError = null;
      });
    } catch (e) {
      setState(() {
        _isValid = false;
        _validationError =
            e.toString().replaceFirst('Formula Parse Error ', '');
      });
    }
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _nameController.text = preset['name'] as String;
      _formulaController.text = preset['formula'] as String;
      _isOverlay = preset['isOverlay'] as bool;
      _selectedColor = preset['color'] as Color;
    });
  }

  void _addFormulaIndicator() {
    if (!_isValid) return;

    final formula = _formulaController.text.trim();
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Custom Formula';

    final indicator = FormulaIndicator(
      name: name,
      formula: formula,
      isOverlay: _isOverlay,
      defaultColor: _selectedColor,
    );

    widget.controller.toggleIndicator(indicator);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E222D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2E39), width: 1),
      ),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF00E5FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Custom Pine Formula Indicator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: Color(0xFF787B86), size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Presets row
            const Text(
              'QUICK PRESETS',
              style: TextStyle(
                color: Color(0xFF787B86),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _applyPreset(p),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2E39),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p['title'] as String,
                          style: const TextStyle(
                            color: Color(0xFFB2B5BE),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Indicator Name & Overlay toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INDICATOR LABEL',
                        style: TextStyle(
                          color: Color(0xFF787B86),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131722),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF363A45)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.centerLeft,
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISPLAY PANE',
                      style: TextStyle(
                        color: Color(0xFF787B86),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF131722),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF363A45)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Overlay',
                                style: TextStyle(fontSize: 11)),
                            selected: _isOverlay,
                            onSelected: (val) =>
                                setState(() => _isOverlay = true),
                            backgroundColor: Colors.transparent,
                            selectedColor: const Color(0xFF2962FF),
                            labelStyle: TextStyle(
                              color: _isOverlay
                                  ? Colors.white
                                  : const Color(0xFF787B86),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('Sub-Pane',
                                style: TextStyle(fontSize: 11)),
                            selected: !_isOverlay,
                            onSelected: (val) =>
                                setState(() => _isOverlay = false),
                            backgroundColor: Colors.transparent,
                            selectedColor: const Color(0xFF2962FF),
                            labelStyle: TextStyle(
                              color: !_isOverlay
                                  ? Colors.white
                                  : const Color(0xFF787B86),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Color Picker
            Row(
              children: [
                const Text(
                  'COLOR:',
                  style: TextStyle(
                    color: Color(0xFF787B86),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                ..._palette.map((c) {
                  final isSelected = _selectedColor == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _selectedColor = c),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 14),

            // Formula Code Editor
            const Text(
              'PINESCRIPT / FORMULA EXPRESSION',
              style: TextStyle(
                color: Color(0xFF787B86),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131722),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isValid
                        ? const Color(0xFF363A45)
                        : const Color(0xFFFF5252),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _formulaController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFE0E0E0),
                    fontSize: 12,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Validation status bar
            if (_isValid)
              Row(
                children: const [
                  Icon(Icons.check_circle_outline,
                      color: Color(0xFF00E676), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Valid expression syntax',
                    style: TextStyle(color: Color(0xFF00E676), fontSize: 11),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFFF5252), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _validationError ?? 'Syntax error',
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF787B86)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isValid ? _addFormulaIndicator : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    disabledBackgroundColor:
                        const Color(0xFF2962FF).withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Add to Chart',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
