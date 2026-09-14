import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/coordinates/viewport.dart';
import '../core/models/candle.dart';
import '../core/models/candle_style.dart';
import '../core/models/chart_drawing.dart';
import '../core/models/chart_order.dart';
import '../core/models/chart_position.dart';
import '../core/models/chart_theme.dart';
import '../core/models/price_range.dart';
import '../core/models/tick.dart';
import '../core/models/timeframe.dart';
import '../datasource/chart_data_source.dart';
import 'candle_builder.dart';
import 'indicators/indicator.dart';
import 'indicators/indicator_result.dart';

/// Top-level controller managing chart state, gestures, viewport, indicators, and live data stream.
class TradingChartController extends ChangeNotifier {
  String _symbol;
  String _exchange = 'NSE';
  final ChartDataSource dataSource;
  ChartTheme theme;

  Timeframe _timeframe;
  CandleStyle _candleStyle = CandleStyle.candles;
  ChartViewport _viewport;
  late CandleBuilder _candleBuilder;
  StreamSubscription<Tick>? _tickSubscription;
  Timer? _countdownTicker;

  final List<Indicator> _activeIndicators = [];
  List<IndicatorResult> _overlayResults = [];
  IndicatorResult? _subPaneResult;

  Offset? _crosshairPosition;
  Candle? _hoveredCandle;
  bool _showVolume = true;
  bool _showGrid = true;
  bool _showCrosshair = true;
  bool _isLoading = true;
  bool _showCountdownTimer = true;
  bool _showWatermark = true;

  // Vertical Price Scale (TradingView manual scale & pan)
  double _verticalScale = 1.0;
  double _verticalPan = 0.0;

  // Active Chart Orders & Brackets (TP & SL)
  final List<ChartOrder> _orders = [];
  void Function(ChartOrder order)? onOrderPlaced;
  void Function(ChartOrder order)? onOrderModified;
  void Function(String orderId)? onOrderCancelled;

  // Open Executed Positions
  final List<ChartPosition> _positions = [];
  void Function(ChartPosition position)? onPositionOpened;
  void Function(ChartPosition position)? onPositionClosed;

  // Interactive Drawings
  final List<ChartDrawing> _drawings = [];
  ChartDrawing? _previewDrawing;
  DrawingTool _activeDrawingTool = DrawingTool.pointer;
  void Function(ChartDrawing drawing)? onDrawingAdded;
  void Function(String drawingId)? onDrawingRemoved;

  TradingChartController({
    required String symbol,
    required this.dataSource,
    String exchange = 'NSE',
    Timeframe initialTimeframe = Timeframe.fiveMinutes,
    CandleStyle initialCandleStyle = CandleStyle.candles,
    ChartTheme? theme,
  })  : _symbol = symbol,
        _exchange = exchange,
        _timeframe = initialTimeframe,
        _candleStyle = initialCandleStyle,
        theme = theme ?? ChartTheme.dark(),
        _viewport = const ChartViewport() {
    _candleBuilder = CandleBuilder(timeframe: _timeframe);
    _startCountdownTicker();
  }

  void _startCountdownTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_showCountdownTimer && _candleBuilder.currentCandle != null) {
        notifyListeners();
      }
    });
  }

  // Getters
  String get symbol => _symbol;
  String get exchange => _exchange;
  Timeframe get timeframe => _timeframe;
  CandleStyle get candleStyle => _candleStyle;
  ChartViewport get viewport => _viewport;
  List<Candle> get candles => _candleBuilder.candles;
  Candle? get currentCandle => _candleBuilder.currentCandle;
  Candle? get hoveredCandle => _hoveredCandle ?? currentCandle;
  List<IndicatorResult> get overlayResults => _overlayResults;
  IndicatorResult? get subPaneResult => _subPaneResult;
  List<Indicator> get activeIndicators => List.unmodifiable(_activeIndicators);
  List<ChartOrder> get orders => List.unmodifiable(_orders);
  List<ChartPosition> get positions => List.unmodifiable(_positions);
  List<ChartDrawing> get drawings => List.unmodifiable(_drawings);
  ChartDrawing? get previewDrawing => _previewDrawing;
  DrawingTool get activeDrawingTool => _activeDrawingTool;
  set activeDrawingTool(DrawingTool tool) {
    if (_activeDrawingTool != tool) {
      _activeDrawingTool = tool;
      _previewDrawing = null;
      notifyListeners();
    }
  }

  bool get showCountdownTimer => _showCountdownTimer;
  set showCountdownTimer(bool val) {
    if (_showCountdownTimer != val) {
      _showCountdownTimer = val;
      notifyListeners();
    }
  }

  bool get showWatermark => _showWatermark;
  set showWatermark(bool val) {
    if (_showWatermark != val) {
      _showWatermark = val;
      notifyListeners();
    }
  }

  /// Formatted countdown to current candle close (e.g. '04:12' or '00:23').
  String get candleCountdownText {
    final candle = currentCandle;
    if (candle == null) return '';
    final closeTime = candle.timestamp.add(_timeframe.duration);
    final remaining = closeTime.difference(DateTime.now());
    if (remaining.isNegative) return '00:00';

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    if (remaining.inHours > 0) {
      final hours = remaining.inHours;
      final m = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Offset? get crosshairPosition => _showCrosshair ? _crosshairPosition : null;
  bool get showVolume => _showVolume;
  bool get showGrid => _showGrid;
  bool get showCrosshair => _showCrosshair;
  bool get isLoading => _isLoading;
  bool get isDarkTheme => theme.backgroundColor == const Color(0xFF131722);

  double get verticalScale => _verticalScale;
  double get verticalPan => _verticalPan;
  bool get isManualPriceScale => (_verticalScale - 1.0).abs() > 0.001 || _verticalPan.abs() > 0.001;

  /// Visible auto-scaled price range with vertical scale & pan applied.
  PriceRange get currentPriceRange {
    final candleList = _candleBuilder.candles;
    if (candleList.isEmpty) return const PriceRange(0.0, 1.0);
    final visible = _viewport.calculateVisibleIndices(candleList.length);
    final base = PriceRange.fromCandles(
      candleList,
      start: visible.start,
      end: visible.end,
    ).withPadding(topPaddingPercent: 0.08, bottomPaddingPercent: 0.08);

    return base.applyVerticalScaleAndPan(
      scale: _verticalScale,
      pan: _verticalPan,
    );
  }

  /// Height of the main chart canvas pane (excluding sub-pane and bottom time axis).
  double get mainPaneHeight {
    final totalHeight = _viewport.viewportHeight;
    final availableHeight = (totalHeight - 24.0).clamp(10.0, totalHeight);
    if (_subPaneResult != null) {
      return availableHeight * (1.0 - 0.25);
    }
    return availableHeight;
  }

  /// Converts screen Y coordinate inside main pane to financial price.
  double priceAtY(double y) {
    final chartWidth = (_viewport.viewportWidth - 65.0).clamp(10.0, double.infinity);
    final bounds = Rect.fromLTWH(0, 0, chartWidth, mainPaneHeight);
    return CoordinateConverter.yToPrice(y, bounds, currentPriceRange);
  }

  /// Converts financial price to screen Y coordinate inside main pane.
  double yAtPrice(double price) {
    final chartWidth = (_viewport.viewportWidth - 65.0).clamp(10.0, double.infinity);
    final bounds = Rect.fromLTWH(0, 0, chartWidth, mainPaneHeight);
    return CoordinateConverter.priceToY(price, bounds, currentPriceRange);
  }

  /// Places an active order on the chart canvas.
  void placeOrder(ChartOrder order) {
    _orders.removeWhere((o) => o.id == order.id);
    _orders.add(order);
    onOrderPlaced?.call(order);
    notifyListeners();
  }

  /// Updates the limit price of an existing order.
  void updateOrderPrice(String orderId, double newPrice) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final updated = _orders[index].copyWith(price: newPrice);
      _orders[index] = updated;
      onOrderModified?.call(updated);
      notifyListeners();
    }
  }

  /// Updates or attaches Take Profit and/or Stop Loss brackets to an order.
  void updateOrderBrackets(
    String orderId, {
    double? takeProfitPrice,
    double? stopLossPrice,
    bool clearTakeProfit = false,
    bool clearStopLoss = false,
  }) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      final existing = _orders[index];
      final updated = existing.copyWith(
        takeProfitPrice: clearTakeProfit ? () => null : (takeProfitPrice != null ? () => takeProfitPrice : null),
        stopLossPrice: clearStopLoss ? () => null : (stopLossPrice != null ? () => stopLossPrice : null),
      );
      _orders[index] = updated;
      onOrderModified?.call(updated);
      notifyListeners();
    }
  }

  /// Cancels an order and removes it from the chart canvas.
  void cancelOrder(String orderId) {
    final removed = _orders.where((o) => o.id == orderId).toList();
    _orders.removeWhere((o) => o.id == orderId);
    if (removed.isNotEmpty) {
      onOrderCancelled?.call(orderId);
      notifyListeners();
    }
  }

  /// Replaces active orders on the chart.
  void setOrders(List<ChartOrder> orders) {
    _orders
      ..clear()
      ..addAll(orders);
    notifyListeners();
  }

  /// Clears all active orders from the chart.
  void clearOrders() {
    _orders.clear();
    notifyListeners();
  }

  /// Opens an executed position on the chart.
  void openPosition(ChartPosition position) {
    _positions.removeWhere((p) => p.id == position.id);
    _positions.add(position);
    onPositionOpened?.call(position);
    notifyListeners();
  }

  /// Updates an open position (e.g. adjust TP/SL or average price).
  void updatePosition(ChartPosition position) {
    final index = _positions.indexWhere((p) => p.id == position.id);
    if (index >= 0) {
      _positions[index] = position;
      notifyListeners();
    }
  }

  /// Closes an open position and removes it from the chart canvas.
  void closePosition(String positionId) {
    final index = _positions.indexWhere((p) => p.id == positionId);
    if (index >= 0) {
      final removed = _positions.removeAt(index);
      onPositionClosed?.call(removed);
      notifyListeners();
    }
  }

  /// Replaces open positions on the chart.
  void setPositions(List<ChartPosition> positions) {
    _positions
      ..clear()
      ..addAll(positions);
    notifyListeners();
  }

  /// Clears all open positions from the chart.
  void clearPositions() {
    if (_positions.isNotEmpty) {
      _positions.clear();
      notifyListeners();
    }
  }

  /// Adds a new user drawing to the chart canvas.
  void addDrawing(ChartDrawing drawing) {
    _drawings.add(drawing);
    _previewDrawing = null;
    onDrawingAdded?.call(drawing);
    notifyListeners();
  }

  /// Updates an existing drawing (e.g. dragging an anchor point).
  void updateDrawing(ChartDrawing drawing) {
    final index = _drawings.indexWhere((d) => d.id == drawing.id);
    if (index >= 0) {
      _drawings[index] = drawing;
      notifyListeners();
    }
  }

  /// Removes a drawing from the chart canvas.
  void removeDrawing(String id) {
    final removed = _drawings.where((d) => d.id == id).toList();
    _drawings.removeWhere((d) => d.id == id);
    if (removed.isNotEmpty) {
      onDrawingRemoved?.call(id);
      notifyListeners();
    }
  }

  /// Clears all drawings from the chart canvas.
  void clearDrawings() {
    _drawings.clear();
    _previewDrawing = null;
    notifyListeners();
  }

  /// Updates the live drawing preview while the user is actively drawing.
  void setPreviewDrawing(ChartDrawing? preview) {
    _previewDrawing = preview;
    notifyListeners();
  }

  /// Selects a drawing by ID or deselects all if null.
  void selectDrawing(String? id) {
    bool changed = false;
    for (int i = 0; i < _drawings.length; i++) {
      final isSel = _drawings[i].id == id;
      if (_drawings[i].isSelected != isSel) {
        _drawings[i] = _drawings[i].copyWith(isSelected: isSel);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Loads initial historical data and establishes real-time tick ingestion.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final historical = await dataSource.getHistoricalData(
        symbol: _symbol,
        timeframe: _timeframe,
        count: 500,
      );
      _candleBuilder.setCandles(historical);
      _recalculateIndicators();

      // Listen to real-time live ticks
      _tickSubscription?.cancel();
      _tickSubscription = dataSource.getLiveTicks(_symbol).listen(_onLiveTick);
    } catch (e) {
      debugPrint('Error loading chart data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onLiveTick(Tick tick) {
    final updatedCandle = _candleBuilder.onTick(tick);
    _recalculateIndicators();
    // Update hovered candle if it was tracking latest
    if (_crosshairPosition == null) {
      _hoveredCandle = updatedCandle;
    }
    notifyListeners();
  }

  /// Sets a new symbol and reloads chart data.
  Future<void> setSymbol(String newSymbol, {String? exchange}) async {
    if (_symbol == newSymbol && (exchange == null || _exchange == exchange)) return;
    _symbol = newSymbol;
    if (exchange != null) {
      _exchange = exchange;
    }
    _crosshairPosition = null;
    _hoveredCandle = null;
    _verticalScale = 1.0;
    _verticalPan = 0.0;
    _candleBuilder = CandleBuilder(timeframe: _timeframe);
    await initialize();
  }

  /// Switches exchange (NSE vs BSE).
  void setExchange(String newExchange) {
    if (_exchange == newExchange) return;
    _exchange = newExchange;
    notifyListeners();
  }

  /// Changes chart timeframe and refreshes historical candles.
  Future<void> setTimeframe(Timeframe newTimeframe) async {
    if (_timeframe == newTimeframe) return;
    _timeframe = newTimeframe;
    _candleBuilder = CandleBuilder(timeframe: newTimeframe);
    _crosshairPosition = null;
    _hoveredCandle = null;
    await initialize();
  }

  /// Changes the candle presentation style (Candles, Hollow, Heikin Ashi, Line, Area, Bars).
  void setCandleStyle(CandleStyle style) {
    if (_candleStyle == style) return;
    _candleStyle = style;
    notifyListeners();
  }

  /// Manually refreshes historical data and restarts stream.
  Future<void> refreshData() async {
    await initialize();
  }

  /// Toggles dark / light theme.
  void toggleTheme() {
    if (isDarkTheme) {
      theme = ChartTheme.light();
    } else {
      theme = ChartTheme.dark();
    }
    notifyListeners();
  }

  /// Sets an explicit theme.
  void setTheme(ChartTheme newTheme) {
    theme = newTheme;
    notifyListeners();
  }

  /// Toggles grid lines on/off.
  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
  }

  /// Toggles crosshair on/off.
  void toggleCrosshair() {
    _showCrosshair = !_showCrosshair;
    if (!_showCrosshair) {
      _crosshairPosition = null;
    }
    notifyListeners();
  }

  /// Updates viewport canvas dimensions (called by LayoutBuilder in UI).
  void updateDimensions(double width, double height) {
    if (_viewport.viewportWidth != width || _viewport.viewportHeight != height) {
      _viewport = _viewport.copyWith(
        viewportWidth: width,
        viewportHeight: height,
      );
    }
  }

  /// Updates crosshair position and extracts hovered candle under pointer.
  void setCrosshairPosition(Offset? position) {
    if (!_showCrosshair) {
      _crosshairPosition = null;
      return;
    }
    _crosshairPosition = position;
    if (position != null && candles.isNotEmpty) {
      final converter = CoordinateConverter(
        viewport: _viewport,
        totalCandles: candles.length,
      );
      final index = converter.xToIndex(position.dx);
      if (index >= 0 && index < candles.length) {
        _hoveredCandle = candles[index];
      }
    } else {
      _hoveredCandle = null;
    }
    notifyListeners();
  }

  /// Horizontal scroll / pan gesture handler.
  void onPan(double deltaX) {
    final maxScroll = (candles.length * _viewport.candleTotalWidth).toDouble();
    const minScroll = -120.0; // Allow right margin expansion
    final newOffset = (_viewport.scrollOffset + deltaX).clamp(minScroll, math.max(0.0, maxScroll)).toDouble();

    _viewport = _viewport.copyWith(scrollOffset: newOffset);
    notifyListeners();
  }

  /// Focal-point aware horizontal zoom (pinch zoom or mouse wheel).
  void onZoom(double scaleFactor, Offset focalPoint) {
    const minWidth = 2.0;
    const maxWidth = 50.0;
    final oldCandleWidth = _viewport.candleWidth;
    final newWidth = (oldCandleWidth * scaleFactor).clamp(minWidth, maxWidth);
    if (newWidth == oldCandleWidth) return;

    final oldTotal = _viewport.candleTotalWidth;
    final newTotal = newWidth + _viewport.candleSpacing;
    final ratio = newTotal / oldTotal;

    // Anchor calculation to keep candle under focalPoint.dx stationary
    final focalX = focalPoint.dx;
    final distFromRight = _viewport.viewportWidth - _viewport.rightMargin - focalX + _viewport.scrollOffset;
    final newScrollOffset = (_viewport.scrollOffset + distFromRight * (ratio - 1.0)).clamp(
      -120.0,
      math.max(0.0, candles.length * newTotal).toDouble(),
    );

    _viewport = _viewport.copyWith(
      candleWidth: newWidth,
      scrollOffset: newScrollOffset,
    );
    notifyListeners();
  }

  /// Vertical scale drag on price scale (Y-axis zoom).
  void onVerticalScale(double deltaY) {
    // deltaY > 0 -> dragged down -> zoom out (expand span)
    // deltaY < 0 -> dragged up -> zoom in (compress span)
    final factor = 1.0 + (deltaY / 120.0);
    _verticalScale = (_verticalScale * factor).clamp(0.05, 30.0);
    notifyListeners();
  }

  /// Vertical pan when manual price scaling is active.
  void onVerticalPan(double deltaY, double paneHeight) {
    if (paneHeight <= 0) return;
    final normalizedDelta = deltaY / paneHeight;
    _verticalPan += normalizedDelta * _verticalScale;
    notifyListeners();
  }

  /// Horizontal scale drag on time scale (X-axis zoom).
  void onTimeScale(double deltaX) {
    // deltaX > 0 -> dragged right -> zoom in (widen candle width)
    // deltaX < 0 -> dragged left -> zoom out (narrow candle width)
    final scaleRatio = 1.0 + (deltaX / 120.0);
    final newWidth = (_viewport.candleWidth * scaleRatio).clamp(2.0, 50.0);
    if (newWidth == _viewport.candleWidth) return;

    final oldTotal = _viewport.candleTotalWidth;
    final newTotal = newWidth + _viewport.candleSpacing;
    final ratio = newTotal / oldTotal;

    final newOffset = (_viewport.scrollOffset * ratio).clamp(-120.0, double.infinity);
    _viewport = _viewport.copyWith(
      candleWidth: newWidth,
      scrollOffset: newOffset,
    );
    notifyListeners();
  }

  /// Zoom in horizontally by 25%.
  void zoomIn() {
    final newWidth = (_viewport.candleWidth * 1.25).clamp(2.0, 50.0);
    _viewport = _viewport.copyWith(candleWidth: newWidth);
    notifyListeners();
  }

  /// Zoom out horizontally by 20%.
  void zoomOut() {
    final newWidth = (_viewport.candleWidth * 0.8).clamp(2.0, 50.0);
    _viewport = _viewport.copyWith(candleWidth: newWidth);
    notifyListeners();
  }

  /// Zoom in price scale vertically.
  void zoomInPrice() {
    _verticalScale = (_verticalScale * 0.85).clamp(0.05, 30.0);
    notifyListeners();
  }

  /// Zoom out price scale vertically.
  void zoomOutPrice() {
    _verticalScale = (_verticalScale * 1.15).clamp(0.05, 30.0);
    notifyListeners();
  }

  /// Resets vertical price scale back to auto-scale.
  void resetPriceScale() {
    _verticalScale = 1.0;
    _verticalPan = 0.0;
    notifyListeners();
  }

  /// Resets horizontal time scale back to default.
  void resetTimeScale() {
    _viewport = _viewport.copyWith(
      candleWidth: 8.0,
      scrollOffset: 0.0,
    );
    notifyListeners();
  }

  /// Resets both time and price scale to default view.
  void resetView() {
    _viewport = _viewport.copyWith(
      candleWidth: 8.0,
      scrollOffset: 0.0,
    );
    _verticalScale = 1.0;
    _verticalPan = 0.0;
    _crosshairPosition = null;
    _hoveredCandle = null;
    notifyListeners();
  }

  /// Jumps to the latest forming candle.
  void scrollToLatest() {
    _viewport = _viewport.copyWith(scrollOffset: 0.0);
    notifyListeners();
  }

  /// Toggles volume histogram on/off.
  void toggleVolume() {
    _showVolume = !_showVolume;
    notifyListeners();
  }

  /// Toggles an indicator on or off.
  void toggleIndicator(Indicator indicator) {
    final existingIndex = _activeIndicators.indexWhere((i) => i.id == indicator.id);
    if (existingIndex >= 0) {
      _activeIndicators.removeAt(existingIndex);
    } else {
      _activeIndicators.add(indicator);
    }
    _recalculateIndicators();
    notifyListeners();
  }

  bool isIndicatorActive(String id) {
    return _activeIndicators.any((i) => i.id == id);
  }

  void _recalculateIndicators() {
    _overlayResults = [];
    _subPaneResult = null;

    final candleList = _candleBuilder.candles;
    if (candleList.isEmpty) return;

    for (final ind in _activeIndicators) {
      final res = ind.calculate(candleList);
      if (res.isOverlay) {
        _overlayResults.add(res);
      } else {
        // Single primary sub-pane indicator (e.g. RSI)
        _subPaneResult = res;
      }
    }
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _tickSubscription?.cancel();
    super.dispose();
  }
}
