import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

/// Direct Chart Trading & Bracket Orders Showcase:
/// Demonstrates institutional TradingView-style order execution directly from the chart:
/// - Hover '+' button tracking crosshair Y before the vertical price axis
/// - 1-click Limit order placement & Bracket menu (Buy/Sell with Take Profit & Stop Loss)
/// - Skia/Impeller dotted horizontal order lines with connected bracket arms
/// - Drag-to-modify price badges with live coordinate math
/// - Quick cancellation (✖) and live bidirectional synchronization with an orders ledger.
class ChartTradingDemoScreen extends StatefulWidget {
  const ChartTradingDemoScreen({super.key});

  @override
  State<ChartTradingDemoScreen> createState() => _ChartTradingDemoScreenState();
}

class _ChartTradingDemoScreenState extends State<ChartTradingDemoScreen> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;
  bool _showOrdersDrawer = true;
  int _selectedLedgerTab = 0; // 0 = Orders, 1 = Positions

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(
      initialPrice: 24500.0,
      volatility: 0.0015,
    );
    _controller = TradingChartController(
      symbol: 'NIFTY 50',
      exchange: 'NSE',
      dataSource: _dataSource,
      initialTimeframe: Timeframe.fiveMinutes,
      initialCandleStyle: CandleStyle.candles,
      theme: ChartTheme.dark(),
    );

    _controller.initialize().then((_) {
      if (!mounted) return;
      _seedSampleOrders();
    });
  }

  void _seedSampleOrders() {
    // Populate sample active orders with Take Profit and Stop Loss brackets
    final buyOrder = ChartOrder(
      id: 'ord_sample_buy',
      symbol: 'NIFTY 50',
      side: OrderSide.buy,
      type: OrderType.limit,
      price: 24450.00,
      quantity: 100,
      takeProfitPrice: 24580.00,
      stopLossPrice: 24380.00,
    );

    final sellOrder = ChartOrder(
      id: 'ord_sample_sell',
      symbol: 'NIFTY 50',
      side: OrderSide.sell,
      type: OrderType.limit,
      price: 24560.00,
      quantity: 50,
      takeProfitPrice: 24420.00,
      stopLossPrice: 24630.00,
    );

    // Populate executed open position with live unrealized P&L
    final samplePosition = ChartPosition(
      id: 'pos_sample_long',
      symbol: 'NIFTY 50',
      side: PositionSide.long,
      entryPrice: 24490.00,
      quantity: 100,
      takeProfitPrice: 24620.00,
      stopLossPrice: 24410.00,
      openedAt: DateTime.now().subtract(const Duration(minutes: 15)),
    );

    _controller.setOrders([buyOrder, sellOrder]);
    _controller.setPositions([samplePosition]);
  }

  @override
  void dispose() {
    _controller.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  void _addQuickOrder(OrderSide side, bool withBrackets) {
    final currentPrice = _controller.currentCandle?.close ?? 24500.0;
    final isBuy = side == OrderSide.buy;
    final orderPrice = double.parse(
      (currentPrice * (isBuy ? 0.997 : 1.003)).toStringAsFixed(2),
    );
    final tp = withBrackets
        ? double.parse(
            (orderPrice * (isBuy ? 1.015 : 0.985)).toStringAsFixed(2),
          )
        : null;
    final sl = withBrackets
        ? double.parse(
            (orderPrice * (isBuy ? 0.990 : 1.010)).toStringAsFixed(2),
          )
        : null;

    final order = ChartOrder(
      id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
      symbol: _controller.symbol,
      side: side,
      type: OrderType.limit,
      price: orderPrice,
      quantity: 100,
      takeProfitPrice: tp,
      stopLossPrice: sl,
    );

    _controller.placeOrder(order);
    _showFeedback(
      '${isBuy ? 'BUY' : 'SELL'} Limit Order Placed @ $orderPrice',
      isBuy ? const Color(0xFF00E676) : const Color(0xFFFF3B30),
    );
  }

  void _addQuickPosition(PositionSide side) {
    final currentPrice = _controller.currentCandle?.close ?? 24500.0;
    final isLong = side == PositionSide.long;
    final tp = double.parse(
      (currentPrice * (isLong ? 1.012 : 0.988)).toStringAsFixed(2),
    );
    final sl = double.parse(
      (currentPrice * (isLong ? 0.992 : 1.008)).toStringAsFixed(2),
    );

    final pos = ChartPosition(
      id: 'pos_${DateTime.now().millisecondsSinceEpoch}',
      symbol: _controller.symbol,
      side: side,
      entryPrice: currentPrice,
      quantity: 100,
      takeProfitPrice: tp,
      stopLossPrice: sl,
      openedAt: DateTime.now(),
    );

    _controller.openPosition(pos);
    _showFeedback(
      'Opened ${side.label} Position: 100 @ ₹${currentPrice.toStringAsFixed(2)}',
      isLong ? const Color(0xFF2962FF) : const Color(0xFFE91E63),
    );
  }

  void _showFeedback(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: color.withValues(alpha: 0.9),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Interactive Instructions & Quick-Action Bar
            _buildInteractiveHeader(),

            // 2. Main Chart Canvas with Order Lines & Hover '+' Button
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TradingChart(
                      controller: _controller,
                      enableChartTrading: true,
                      onOrderPlaced: (order) {
                        _showFeedback(
                          'Order Placed: ${order.side.name.toUpperCase()} ${order.quantity.toInt()} @ ${order.price.toStringAsFixed(2)}',
                          order.isBuy
                              ? const Color(0xFF00E676)
                              : const Color(0xFFFF3B30),
                        );
                      },
                      onOrderCancelled: (orderId) {
                        _showFeedback(
                          'Order $orderId Cancelled',
                          const Color(0xFFFF9100),
                        );
                      },
                    ),
                  ),

                  // Floating symbol telemetry badge at top left
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xDD1E222D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF2A2E39),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'NIFTY 50',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LIVE CHART TRADING',
                            style: TextStyle(
                              color: const Color(
                                0xFF00E5FF,
                              ).withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Collapsible Orders Ledger Panel (Bottom Right)
                  if (_showOrdersDrawer)
                    Positioned(
                      left: 14,
                      bottom: 36,
                      width: 480,
                      child: _buildOrdersLedger(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF131722),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2E39), width: 1)),
      ),
      child: Row(
        children: [
          // Banner Icon & Instructions
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2962FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.touch_app_outlined,
              size: 18,
              color: Color(0xFF2962FF),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hover before the right price axis to reveal the "+" button. Click to place Limit orders with TP/SL.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '💡 Drag order pills up/down to modify prices • Click ✖ on canvas to cancel • Click "+Bracket" for TP/SL',
                  style: TextStyle(color: Color(0xFF868993), fontSize: 10.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Quick Action Buttons
          _buildActionButton(
            label: '+ Buy Bracket',
            color: const Color(0xFF00E676),
            onTap: () => _addQuickOrder(OrderSide.buy, true),
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            label: '+ Sell Bracket',
            color: const Color(0xFFFF3B30),
            onTap: () => _addQuickOrder(OrderSide.sell, true),
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            label: '+ Long Pos',
            color: const Color(0xFF2962FF),
            onTap: () => _addQuickPosition(PositionSide.long),
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            label: '+ Short Pos',
            color: const Color(0xFFE91E63),
            onTap: () => _addQuickPosition(PositionSide.short),
          ),
          const SizedBox(width: 6),
          _buildActionButton(
            label: 'Reset',
            color: const Color(0xFF868993),
            onTap: _seedSampleOrders,
          ),
          const SizedBox(width: 8),
          // Toggle Ledger Drawer
          IconButton(
            tooltip: _showOrdersDrawer
                ? 'Hide Orders Table'
                : 'Show Orders Table',
            icon: Icon(
              _showOrdersDrawer
                  ? Icons.table_chart
                  : Icons.table_chart_outlined,
              size: 18,
              color: _showOrdersDrawer
                  ? const Color(0xFF2962FF)
                  : Colors.white70,
            ),
            onPressed: () =>
                setState(() => _showOrdersDrawer = !_showOrdersDrawer),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: color.withValues(alpha: 0.25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersLedger() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final orders = _controller.orders;
        final positions = _controller.positions;
        final currentPrice = _controller.currentCandle?.close ?? 24500.0;

        return Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: const Color(0xF2161A25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2E39), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Tabs
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF2A2E39), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Orders Tab Pill
                    InkWell(
                      onTap: () => setState(() => _selectedLedgerTab = 0),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedLedgerTab == 0
                              ? const Color(0xFF2962FF).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _selectedLedgerTab == 0
                                ? const Color(0xFF2962FF)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 13,
                              color: Color(0xFF00E5FF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Orders (${orders.length})',
                              style: TextStyle(
                                color: _selectedLedgerTab == 0
                                    ? Colors.white
                                    : const Color(0xFF868993),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Positions Tab Pill
                    InkWell(
                      onTap: () => setState(() => _selectedLedgerTab = 1),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedLedgerTab == 1
                              ? const Color(0xFFAB47BC).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _selectedLedgerTab == 1
                                ? const Color(0xFFAB47BC)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.trending_up,
                              size: 13,
                              color: Color(0xFFAB47BC),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Positions (${positions.length})',
                              style: TextStyle(
                                color: _selectedLedgerTab == 1
                                    ? Colors.white
                                    : const Color(0xFF868993),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Clear / Action Button
                    if (_selectedLedgerTab == 0 && orders.isNotEmpty)
                      GestureDetector(
                        onTap: _controller.clearOrders,
                        child: const Text(
                          'Cancel All',
                          style: TextStyle(
                            color: Color(0xFFFF3B30),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (_selectedLedgerTab == 1 && positions.isNotEmpty)
                      GestureDetector(
                        onTap: _controller.clearPositions,
                        child: const Text(
                          'Close All',
                          style: TextStyle(
                            color: Color(0xFFFF3B30),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Tab 0: Orders List
              if (_selectedLedgerTab == 0) ...[
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No active working orders on chart.\nHover near the right price axis to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF868993), fontSize: 11),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: orders.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFF2A2E39)),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final isBuy = order.isBuy;
                        final sideColor = isBuy
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF3B30);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              // Side Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: sideColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  order.side.name.toUpperCase(),
                                  style: TextStyle(
                                    color: sideColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${order.quantity.toInt()} @ ₹${order.price.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${order.type.name.toUpperCase()})',
                                          style: const TextStyle(
                                            color: Color(0xFF868993),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (order.hasTakeProfit)
                                          Text(
                                            'TP: ₹${order.takeProfitPrice!.toStringAsFixed(2)}  ',
                                            style: const TextStyle(
                                              color: Color(0xFF00E5FF),
                                              fontSize: 10,
                                            ),
                                          ),
                                        if (order.hasStopLoss)
                                          Text(
                                            'SL: ₹${order.stopLossPrice!.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Color(0xFFFF9100),
                                              fontSize: 10,
                                            ),
                                          ),
                                        if (!order.hasTakeProfit &&
                                            !order.hasStopLoss)
                                          const Text(
                                            'No brackets',
                                            style: TextStyle(
                                              color: Color(0xFF868993),
                                              fontSize: 10,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Cancel Button
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Color(0xFFFF3B30),
                                ),
                                tooltip: 'Cancel Order',
                                onPressed: () {
                                  _controller.cancelOrder(order.id);
                                  _showFeedback(
                                    'Order ${order.id} Cancelled',
                                    const Color(0xFFFF3B30),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],

              // Tab 1: Positions List with live P&L
              if (_selectedLedgerTab == 1) ...[
                if (positions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No executed open positions.\nClick "+ Long Pos" or "+ Short Pos" above to open one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF868993), fontSize: 11),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: positions.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFF2A2E39)),
                      itemBuilder: (context, index) {
                        final pos = positions[index];
                        final isLong = pos.isLong;
                        final sideColor = isLong
                            ? const Color(0xFF2962FF)
                            : const Color(0xFFE91E63);
                        final pnl = pos.unrealizedPnL(currentPrice);
                        final pnlPct = pos.unrealizedPnLPercentage(
                          currentPrice,
                        );
                        final isProfit = pnl >= 0;
                        final pnlColor = isProfit
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF3B30);
                        final pnlSign = isProfit ? '+' : '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              // Side Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: sideColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pos.side.label,
                                  style: TextStyle(
                                    color: sideColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${pos.quantity.toInt()} @ ₹${pos.entryPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '$pnlSign₹${pnl.abs().toStringAsFixed(2)} ($pnlSign${pnlPct.toStringAsFixed(2)}%)',
                                          style: TextStyle(
                                            color: pnlColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (pos.hasTakeProfit)
                                          Text(
                                            'TP: ₹${pos.takeProfitPrice!.toStringAsFixed(2)}  ',
                                            style: const TextStyle(
                                              color: Color(0xFF00E5FF),
                                              fontSize: 10,
                                            ),
                                          ),
                                        if (pos.hasStopLoss)
                                          Text(
                                            'SL: ₹${pos.stopLossPrice!.toStringAsFixed(2)}  ',
                                            style: const TextStyle(
                                              color: Color(0xFFFF9100),
                                              fontSize: 10,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 6),

                              // Close Button
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Color(0xFFFF5252),
                                ),
                                tooltip: 'Close Position',
                                onPressed: () {
                                  _controller.closePosition(pos.id);
                                  _showFeedback(
                                    'Position ${pos.id} Closed',
                                    const Color(0xFFFF5252),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
