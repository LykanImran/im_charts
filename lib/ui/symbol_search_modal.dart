import 'package:flutter/material.dart';
import '../engine/chart_controller.dart';

class SymbolItem {
  final String symbol;
  final String name;
  final String exchange;
  final String category; // 'Indices', 'Stocks', 'Crypto', 'Futures'
  final double price;
  final double changePercent;

  const SymbolItem({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.category,
    required this.price,
    required this.changePercent,
  });
}

class SymbolSearchModal extends StatefulWidget {
  final TradingChartController controller;

  const SymbolSearchModal({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    TradingChartController controller,
  ) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => SymbolSearchModal(controller: controller),
    );
  }

  @override
  State<SymbolSearchModal> createState() => _SymbolSearchModalState();
}

class _SymbolSearchModalState extends State<SymbolSearchModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  final List<SymbolItem> _symbols = const [
    // Indices
    SymbolItem(
      symbol: 'NIFTY 50',
      name: 'NIFTY 50 Index (National Stock Exchange)',
      exchange: 'NSE',
      category: 'Indices',
      price: 24520.0,
      changePercent: 0.35,
    ),
    SymbolItem(
      symbol: 'BANKNIFTY',
      name: 'Nifty Bank Index',
      exchange: 'NSE',
      category: 'Indices',
      price: 51420.0,
      changePercent: -0.22,
    ),
    SymbolItem(
      symbol: 'FINNIFTY',
      name: 'Nifty Financial Services',
      exchange: 'NSE',
      category: 'Indices',
      price: 23890.0,
      changePercent: 0.15,
    ),
    SymbolItem(
      symbol: 'SENSEX',
      name: 'BSE SENSEX 30 Index',
      exchange: 'BSE',
      category: 'Indices',
      price: 80250.0,
      changePercent: 0.28,
    ),

    // Stocks
    SymbolItem(
      symbol: 'RELIANCE',
      name: 'Reliance Industries Ltd.',
      exchange: 'NSE',
      category: 'Stocks',
      price: 2985.0,
      changePercent: 0.85,
    ),
    SymbolItem(
      symbol: 'TCS',
      name: 'Tata Consultancy Services Ltd.',
      exchange: 'NSE',
      category: 'Stocks',
      price: 4210.0,
      changePercent: -0.45,
    ),
    SymbolItem(
      symbol: 'HDFCBANK',
      name: 'HDFC Bank Ltd.',
      exchange: 'NSE',
      category: 'Stocks',
      price: 1645.0,
      changePercent: 0.62,
    ),
    SymbolItem(
      symbol: 'INFY',
      name: 'Infosys Limited',
      exchange: 'NSE',
      category: 'Stocks',
      price: 1890.0,
      changePercent: 1.12,
    ),
    SymbolItem(
      symbol: 'TATAMOTORS',
      name: 'Tata Motors Passenger Vehicles Ltd.',
      exchange: 'NSE',
      category: 'Stocks',
      price: 985.0,
      changePercent: -1.05,
    ),
    SymbolItem(
      symbol: 'ICICIBANK',
      name: 'ICICI Bank Ltd.',
      exchange: 'NSE',
      category: 'Stocks',
      price: 1230.0,
      changePercent: 0.44,
    ),
    SymbolItem(
      symbol: 'SBIN',
      name: 'State Bank of India',
      exchange: 'NSE',
      category: 'Stocks',
      price: 815.0,
      changePercent: -0.18,
    ),

    // Crypto
    SymbolItem(
      symbol: 'BTC/USD',
      name: 'Bitcoin / US Dollar Spot',
      exchange: 'CRYPTO',
      category: 'Crypto',
      price: 65400.0,
      changePercent: 2.34,
    ),
    SymbolItem(
      symbol: 'ETH/USD',
      name: 'Ethereum / US Dollar Spot',
      exchange: 'CRYPTO',
      category: 'Crypto',
      price: 3450.0,
      changePercent: 1.82,
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.controller.theme;
    final isDark = widget.controller.isDarkTheme;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _symbols.where((s) {
      final matchesCategory =
          _selectedCategory == 'All' || s.category == _selectedCategory;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return s.symbol.toLowerCase().contains(query) ||
          s.name.toLowerCase().contains(query);
    }).toList();

    final categories = ['All', 'Indices', 'Stocks', 'Crypto'];

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.gridColor, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 600,
        height: 520,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Search bar & Close
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF131722)
                          : const Color(0xFFF0F3FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2962FF).withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 20,
                          color: Color(0xFF2962FF),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search symbol, index, company...',
                              hintStyle: TextStyle(
                                color: theme.axisTextColor,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                            child: Icon(
                              Icons.clear,
                              size: 18,
                              color: theme.axisTextColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: theme.axisTextColor),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2962FF)
                              : (isDark
                                  ? const Color(0xFF2A2E39)
                                  : const Color(0xFFE0E3EB)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.gridColor),
            const SizedBox(height: 6),

            // List of Symbols
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 40,
                            color: theme.axisTextColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No symbols found for "${_searchCtrl.text}"',
                            style: TextStyle(
                              color: theme.axisTextColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: theme.gridColor),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isCurrent =
                            widget.controller.symbol == item.symbol;
                        final isBull = item.changePercent >= 0;

                        return InkWell(
                          onTap: () {
                            widget.controller.setSymbol(
                              item.symbol,
                              exchange: item.exchange,
                            );
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(6),
                          hoverColor: const Color(
                            0xFF2962FF,
                          ).withValues(alpha: 0.1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(
                                      0xFF2962FF,
                                    ).withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                // Symbol & Exchange Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A2E39)
                                        : const Color(0xFFE0E3EB),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.exchange,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.symbol,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme.axisTextColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      item.price >= 1000
                                          ? item.price.toStringAsFixed(2)
                                          : item.price.toStringAsFixed(2),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${isBull ? '+' : ''}${item.changePercent.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        color: isBull
                                            ? theme.bullishColor
                                            : theme.bearishColor,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Color(0xFF2962FF),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
