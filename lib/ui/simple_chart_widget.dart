import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/candle.dart';
import '../core/models/candle_style.dart';
import '../core/models/chart_order.dart';
import '../core/models/chart_position.dart';
import '../core/models/chart_theme.dart';
import '../core/models/tick.dart';
import '../core/models/timeframe.dart';
import '../datasource/static_data_source.dart';
import '../engine/chart_controller.dart';
import '../engine/indicators/indicator.dart';
import 'chart_drawing_toolbar.dart';
import 'chart_header.dart';
import 'chart_toolbar.dart';
import 'chart_widget.dart';

/// The easiest, zero-boilerplate entry point for **Im Charts**.
///
/// Can be used in three ways:
/// 1. **Zero-boilerplate static chart**:
///    ```dart
///    ImChart.simple(
///      candles: myCandleList,
///    )
///    ```
/// 2. **Instant live streaming chart**:
///    ```dart
///    ImChart.live(
///      initialCandles: myCandleList,
///      liveTickStream: myTickStream,
///    )
///    ```
/// 3. **Controller-driven chart**:
///    ```dart
///    ImChart(
///      controller: myChartController,
///    )
///    ```
class ImChart extends StatefulWidget {
  final TradingChartController? controller;
  final List<Candle>? candles;
  final Stream<Tick>? liveTickStream;

  final String symbol;
  final String exchange;
  final String brandName;
  final Timeframe timeframe;
  final CandleStyle candleStyle;
  final ChartTheme? theme;
  final List<Indicator>? indicators;
  final List<ChartOrder>? orders;
  final List<ChartPosition>? positions;

  final bool showToolbar;
  final bool showHeader;
  final bool showDrawingToolbar;
  final bool showVolume;
  final bool showVolumeProfile;
  final bool showSMC;
  final bool showWatermark;
  final bool showCountdownTimer;
  final bool enableChartTrading;

  final GlobalKey? repaintBoundaryKey;
  final void Function(ChartOrder order)? onOrderPlaced;
  final void Function(ChartOrder order)? onOrderModified;
  final void Function(String orderId)? onOrderCancelled;
  final void Function(ChartPosition position)? onPositionClosed;

  /// Default constructor accommodating both controller-driven and props-driven usage.
  const ImChart({
    super.key,
    this.controller,
    this.candles,
    this.liveTickStream,
    this.symbol = 'NIFTY 50',
    this.exchange = 'NSE',
    this.brandName = 'Im Charts',
    this.timeframe = Timeframe.fiveMinutes,
    this.candleStyle = CandleStyle.candles,
    this.theme,
    this.indicators,
    this.orders,
    this.positions,
    this.showToolbar = false,
    this.showHeader = true,
    this.showDrawingToolbar = false,
    this.showVolume = true,
    this.showVolumeProfile = false,
    this.showSMC = false,
    this.showWatermark = true,
    this.showCountdownTimer = true,
    this.enableChartTrading = true,
    this.repaintBoundaryKey,
    this.onOrderPlaced,
    this.onOrderModified,
    this.onOrderCancelled,
    this.onPositionClosed,
  });

  /// Instant zero-boilerplate constructor for an existing list of candles.
  const ImChart.simple({
    super.key,
    required List<Candle> this.candles,
    this.symbol = 'NIFTY 50',
    this.exchange = 'NSE',
    this.brandName = 'Im Charts',
    this.timeframe = Timeframe.fiveMinutes,
    this.candleStyle = CandleStyle.candles,
    this.theme,
    this.indicators,
    this.orders,
    this.positions,
    this.showToolbar = false,
    this.showHeader = true,
    this.showDrawingToolbar = false,
    this.showVolume = true,
    this.showVolumeProfile = false,
    this.showSMC = false,
    this.showWatermark = true,
    this.showCountdownTimer = true,
    this.enableChartTrading = true,
    this.repaintBoundaryKey,
    this.onOrderPlaced,
    this.onOrderModified,
    this.onOrderCancelled,
    this.onPositionClosed,
  })  : controller = null,
        liveTickStream = null;

  /// Instant zero-boilerplate constructor for real-time live streaming charts.
  const ImChart.live({
    super.key,
    required List<Candle> this.candles,
    required Stream<Tick> this.liveTickStream,
    this.symbol = 'NIFTY 50',
    this.exchange = 'NSE',
    this.brandName = 'Im Charts',
    this.timeframe = Timeframe.fiveMinutes,
    this.candleStyle = CandleStyle.candles,
    this.theme,
    this.indicators,
    this.orders,
    this.positions,
    this.showToolbar = false,
    this.showHeader = true,
    this.showDrawingToolbar = false,
    this.showVolume = true,
    this.showVolumeProfile = false,
    this.showSMC = false,
    this.showWatermark = true,
    this.showCountdownTimer = true,
    this.enableChartTrading = true,
    this.repaintBoundaryKey,
    this.onOrderPlaced,
    this.onOrderModified,
    this.onOrderCancelled,
    this.onPositionClosed,
  }) : controller = null;

  @override
  State<ImChart> createState() => _ImChartState();
}

class _ImChartState extends State<ImChart> {
  TradingChartController? _internalController;
  StaticChartDataSource? _internalDataSource;
  StreamSubscription<Tick>? _liveTickSubscription;
  final GlobalKey _chartKey = GlobalKey();

  TradingChartController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _initInternalController();
    }
  }

  void _initInternalController() {
    _internalDataSource = StaticChartDataSource(widget.candles ?? []);
    final ctrl = TradingChartController(
      symbol: widget.symbol,
      exchange: widget.exchange,
      brandName: widget.brandName,
      dataSource: _internalDataSource!,
      initialTimeframe: widget.timeframe,
      initialCandleStyle: widget.candleStyle,
      theme: widget.theme ?? ChartTheme.dark(),
    );

    ctrl.showVolume = widget.showVolume;
    ctrl.showVolumeProfile = widget.showVolumeProfile;
    ctrl.showSMC = widget.showSMC;
    ctrl.showWatermark = widget.showWatermark;
    ctrl.showCountdownTimer = widget.showCountdownTimer;

    if (widget.orders != null) {
      ctrl.setOrders(widget.orders!);
    }
    if (widget.positions != null) {
      ctrl.setPositions(widget.positions!);
    }

    ctrl.initialize().then((_) {
      if (mounted && widget.indicators != null) {
        for (final indicator in widget.indicators!) {
          ctrl.toggleIndicator(indicator);
        }
      }
    });

    if (widget.liveTickStream != null) {
      _liveTickSubscription = widget.liveTickStream!.listen((tick) {
        _internalDataSource?.pushTick(tick);
      });
    }

    _internalController = ctrl;
  }

  @override
  void didUpdateWidget(ImChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != null && _internalController != null) {
      _disposeInternal();
    } else if (widget.controller == null && _internalController == null) {
      _initInternalController();
    } else if (_internalController != null) {
      if (widget.candles != null && widget.candles != oldWidget.candles) {
        _internalDataSource?.updateCandles(widget.candles!);
        _internalController?.setCandles(widget.candles!);
      }
      if (widget.orders != null && widget.orders != oldWidget.orders) {
        _internalController?.setOrders(widget.orders!);
      }
      if (widget.positions != null && widget.positions != oldWidget.positions) {
        _internalController?.setPositions(widget.positions!);
      }
      if (widget.showVolumeProfile != oldWidget.showVolumeProfile) {
        _internalController?.showVolumeProfile = widget.showVolumeProfile;
      }
      if (widget.showSMC != oldWidget.showSMC) {
        _internalController?.showSMC = widget.showSMC;
      }
      if (widget.candleStyle != oldWidget.candleStyle) {
        _internalController?.setCandleStyle(widget.candleStyle);
      }
      if (widget.timeframe != oldWidget.timeframe) {
        _internalController?.setTimeframe(widget.timeframe);
      }
    }
  }

  void _disposeInternal() {
    _liveTickSubscription?.cancel();
    _liveTickSubscription = null;
    _internalController?.dispose();
    _internalController = null;
    _internalDataSource?.dispose();
    _internalDataSource = null;
  }

  @override
  void dispose() {
    _disposeInternal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _effectiveController;
    final repaintKey = widget.repaintBoundaryKey ?? _chartKey;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = controller.theme;

        final chartCore = Stack(
          children: [
            Positioned.fill(
              child: TradingChart(
                controller: controller,
                repaintBoundaryKey: repaintKey,
                enableChartTrading: widget.enableChartTrading,
                showWatermark: widget.showWatermark,
                showCountdownTimer: widget.showCountdownTimer,
                brandName: widget.brandName,
                onOrderPlaced: widget.onOrderPlaced,
                onOrderModified: widget.onOrderModified,
                onOrderCancelled: widget.onOrderCancelled,
                onPositionClosed: widget.onPositionClosed,
              ),
            ),
            if (widget.showHeader)
              Positioned(
                top: 0,
                left: 0,
                right: 65,
                child: ChartHeader(controller: controller),
              ),
          ],
        );

        if (!widget.showToolbar && !widget.showDrawingToolbar) {
          return Container(
            color: theme.backgroundColor,
            child: ClipRect(child: chartCore),
          );
        }

        return Container(
          color: theme.backgroundColor,
          child: Column(
            children: [
              if (widget.showToolbar)
                ChartToolbar(
                  controller: controller,
                  repaintBoundaryKey: repaintKey,
                ),
              Expanded(
                child: Row(
                  children: [
                    if (widget.showDrawingToolbar)
                      ChartDrawingToolbar(controller: controller),
                    Expanded(
                      child: ClipRect(child: chartCore),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
