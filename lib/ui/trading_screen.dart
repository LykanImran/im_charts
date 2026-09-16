import 'package:flutter/material.dart';
import '../core/models/candle_style.dart';
import '../core/models/chart_order.dart';
import '../core/models/chart_position.dart';
import '../core/models/chart_theme.dart';
import '../core/models/timeframe.dart';
import '../datasource/chart_data_source.dart';
import '../datasource/mock_data_source.dart';
import '../engine/chart_controller.dart';
import '../engine/indicators/ema.dart';
import '../engine/indicators/rsi.dart';
import 'chart_drawing_toolbar.dart';
import 'chart_header.dart';
import 'chart_toolbar.dart';
import 'chart_widget.dart';

/// Top-level trading terminal widget combining toolbar, header, and chart.
class TradingScreen extends StatefulWidget {
  final String initialSymbol;
  final String initialExchange;
  final ChartDataSource? dataSource;
  final Timeframe initialTimeframe;
  final CandleStyle initialCandleStyle;
  final ChartTheme? initialTheme;
  final TradingChartController? controller;
  final bool showToolbar;
  final bool showHeader;
  final bool showDrawingToolbar;
  final bool showWatermark;
  final bool showCountdownTimer;
  final String? brandName;
  final bool enableChartTrading;
  final Widget Function(
    BuildContext context,
    double price,
    TradingChartController controller,
    VoidCallback closeMenu,
  )? orderMenuBuilder;
  final void Function(ChartOrder order)? onOrderPlaced;
  final void Function(String orderId)? onOrderCancelled;
  final void Function(ChartPosition position)? onPositionClosed;

  const TradingScreen({
    super.key,
    this.initialSymbol = 'NIFTY 50',
    this.initialExchange = 'NSE',
    this.dataSource,
    this.initialTimeframe = Timeframe.fiveMinutes,
    this.initialCandleStyle = CandleStyle.candles,
    this.initialTheme,
    this.controller,
    this.showToolbar = true,
    this.showHeader = true,
    this.showDrawingToolbar = true,
    this.showWatermark = true,
    this.showCountdownTimer = true,
    this.brandName = 'Im Charts',
    this.enableChartTrading = true,
    this.orderMenuBuilder,
    this.onOrderPlaced,
    this.onOrderCancelled,
    this.onPositionClosed,
  });

  @override
  State<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends State<TradingScreen> {
  ChartDataSource? _dataSource;
  late final TradingChartController _controller;
  bool _internalController = false;
  bool _internalDataSource = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _internalController = false;
    } else {
      _internalController = true;
      if (widget.dataSource != null) {
        _dataSource = widget.dataSource!;
      } else {
        _dataSource = MockTradingDataSource(
          initialPrice: 24520.0,
          volatility: 0.0018,
        );
        _internalDataSource = true;
      }

      _controller = TradingChartController(
        symbol: widget.initialSymbol,
        exchange: widget.initialExchange,
        dataSource: _dataSource!,
        brandName: widget.brandName ?? 'Im Charts',
        initialTimeframe: widget.initialTimeframe,
        initialCandleStyle: widget.initialCandleStyle,
        theme: widget.initialTheme ?? ChartTheme.dark(),
      );

      // Initialize data & activate starter indicators
      _controller.initialize().then((_) {
        if (mounted) {
          _controller.toggleIndicator(
            EMAIndicator(period: 20, color: const Color(0xFF2962FF)),
          );
          _controller.toggleIndicator(RSIIndicator(period: 14));
        }
      });
    }
  }

  @override
  void dispose() {
    if (_internalController) {
      _controller.dispose();
    }
    if (_internalDataSource) {
      _dataSource?.dispose();
    }
    super.dispose();
  }

  final GlobalKey _chartRepaintKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final theme = _controller.theme;

        return Theme(
          data: ThemeData(
            brightness:
                _controller.isDarkTheme ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: theme.backgroundColor,
          ),
          child: Scaffold(
            backgroundColor: theme.backgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  // Row 1: Primary TradingView Toolbar (Search, Intervals, Candle Style, Indicators, Refresh, Theme, Settings)
                  if (widget.showToolbar)
                    ChartToolbar(
                      controller: _controller,
                      repaintBoundaryKey: _chartRepaintKey,
                    ),

                  // Main Chart Canvas with Left Drawing Toolbar and Overlay Header (TradingView architecture)
                  Expanded(
                    child: Row(
                      children: [
                        // Left-docked interactive Drawing Toolbar
                        if (widget.showDrawingToolbar)
                          ChartDrawingToolbar(controller: _controller),

                        // Main High-Performance Canvas & Floating Telemetry Header
                        Expanded(
                          child: ClipRect(
                            child: Stack(
                              children: [
                                // The High-Performance Canvas Chart spans 100% of the available area
                                Positioned.fill(
                                  child: TradingChart(
                                    controller: _controller,
                                    repaintBoundaryKey: _chartRepaintKey,
                                    enableChartTrading:
                                        widget.enableChartTrading,
                                    showWatermark: widget.showWatermark,
                                    showCountdownTimer:
                                        widget.showCountdownTimer,
                                    brandName: widget.brandName,
                                    orderMenuBuilder: widget.orderMenuBuilder,
                                    onOrderPlaced: widget.onOrderPlaced,
                                    onOrderCancelled: widget.onOrderCancelled,
                                    onPositionClosed: widget.onPositionClosed,
                                  ),
                                ),

                                // Overlay Symbol & Telemetry Header floating at top-left
                                if (widget.showHeader)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right:
                                        65, // Leaves the price axis unobscured
                                    child: ChartHeader(controller: _controller),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Standalone turnkey application wrapper for the trading terminal.
class TradingApp extends StatelessWidget {
  const TradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Im Charts',
      debugShowCheckedModeBanner: false,
      home: TradingScreen(),
    );
  }
}
