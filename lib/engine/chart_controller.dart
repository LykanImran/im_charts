import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/coordinates/viewport.dart';
import '../core/models/candle.dart';
import '../core/models/candle_style.dart';
import '../core/models/chart_alert.dart';
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
import 'indicators/volume_profile.dart';

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
  List<IndicatorResult> _subPaneResults = [];
  IndicatorResult? _subPaneResult;

  Offset? _crosshairPosition;
  Candle? _hoveredCandle;
  bool _showVolume = true;
  bool _showGrid = true;
  bool _showCrosshair = true;
  bool _isLoading = true;
  bool _showCountdownTimer = true;
  bool _showWatermark = true;
  String _brandName;

  // Visible Range Volume Profile (VRVP)
  bool _showVolumeProfile = false;
  VolumeProfile? _volumeProfile;

  // Visual Price Alerts
  final List<ChartAlert> _alerts = [];
  void Function(ChartAlert alert)? onAlertTriggered;

  // Bar Replay Mode
  bool _isReplayMode = false;
  int? _replayIndex;
  bool _isReplaying = false;
  Timer? _replayTimer;
  double _replaySpeed = 1.0;

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
    String brandName = 'Im Charts',
    Timeframe initialTimeframe = Timeframe.fiveMinutes,
    CandleStyle initialCandleStyle = CandleStyle.candles,
    ChartTheme? theme,
  })  : _symbol = symbol,
        _exchange = exchange,
        _brandName = brandName,
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
  int get allCandlesCount => _candleBuilder.candles.length;
  List<Candle> get candles => (_isReplayMode && _replayIndex != null)
      ? _candleBuilder.candles.sublist(0, math.min(_replayIndex! + 1, _candleBuilder.candles.length))
      : _candleBuilder.candles;
  Candle? get currentCandle => (_isReplayMode && _replayIndex != null && _candleBuilder.candles.isNotEmpty)
      ? _candleBuilder.candles[math.min(_replayIndex!, _candleBuilder.candles.length - 1)]
      : _candleBuilder.currentCandle;
  Candle? get hoveredCandle => _hoveredCandle ?? currentCandle;
  List<IndicatorResult> get overlayResults => _overlayResults;
  List<IndicatorResult> get subPaneResults => List.unmodifiable(_subPaneResults);
  IndicatorResult? get subPaneResult => _subPaneResults.isNotEmpty ? _subPaneResults.first : null;
  List<Indicator> get activeIndicators => List.unmodifiable(_activeIndicators);
  List<ChartOrder> get orders => List.unmodifiable(_orders);
  List<ChartPosition> get positions => List.unmodifiable(_positions);
  List<ChartDrawing> get drawings => List.unmodifiable(_drawings);
  List<ChartAlert> get alerts => List.unmodifiable(_alerts);

  bool get showVolumeProfile => _showVolumeProfile;
  set showVolumeProfile(bool val) {
    if (_showVolumeProfile != val) {
      _showVolumeProfile = val;
      _recalculateIndicators();
      notifyListeners();
    }
  }
  void toggleVolumeProfile() {
    showVolumeProfile = !_showVolumeProfile;
  }
  VolumeProfile? get volumeProfile => _volumeProfile;

  bool get isReplayMode => _isReplayMode;
  int? get replayIndex => _replayIndex;
  bool get isReplaying => _isReplaying;
  double get replaySpeed => _replaySpeed;
  ChartDrawing? get previewDrawing => _previewDrawing;
  ChartDrawing? get selectedDrawing {
    for (final d in _drawings) {
      if (d.isSelected) return d;
    }
    return null;
  }
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

  /// Brand name displayed in watermarks and institutional overlays (defaults to 'Im Charts').
  String get brandName => _brandName;
  set brandName(String val) {
    if (_brandName != val) {
      _brandName = val;
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

  /// Updates a specific anchor point index of a drawing.
  void updateDrawingPoint(String id, int pointIndex, DrawingPoint newPoint) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index >= 0) {
      final drawing = _drawings[index];
      if (drawing.isLocked) return;
      if (pointIndex >= 0 && pointIndex < drawing.points.length) {
        final updatedPoints = List<DrawingPoint>.from(drawing.points);
        updatedPoints[pointIndex] = newPoint;
        _drawings[index] = drawing.copyWith(points: updatedPoints);
        notifyListeners();
      }
    }
  }

  /// Translates all points and prices of a drawing by a given candle and price delta.
  void translateDrawing(String id, int deltaCandles, double deltaPrice) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index >= 0) {
      final drawing = _drawings[index];
      if (drawing.isLocked) return;

      final updatedPoints = drawing.points.map((p) {
        return p.copyWith(
          candleIndex: p.candleIndex + deltaCandles,
          price: double.parse((p.price + deltaPrice).toStringAsFixed(2)),
        );
      }).toList();

      final updatedProps = Map<String, dynamic>.from(drawing.properties);
      if (updatedProps.containsKey('targetPrice')) {
        updatedProps['targetPrice'] = double.parse(
          ((updatedProps['targetPrice'] as double) + deltaPrice).toStringAsFixed(2),
        );
      }
      if (updatedProps.containsKey('stopPrice')) {
        updatedProps['stopPrice'] = double.parse(
          ((updatedProps['stopPrice'] as double) + deltaPrice).toStringAsFixed(2),
        );
      }

      _drawings[index] = drawing.copyWith(
        points: updatedPoints,
        properties: updatedProps,
      );
      notifyListeners();
    }
  }

  /// Updates arbitrary metadata properties on a drawing (e.g. targetPrice, stopPrice, widthSpan).
  void updateDrawingProperties(String id, Map<String, dynamic> newProperties) {
    final index = _drawings.indexWhere((d) => d.id == id);
    if (index >= 0) {
      final drawing = _drawings[index];
      if (drawing.isLocked) return;
      final mergedProps = Map<String, dynamic>.from(drawing.properties)..addAll(newProperties);
      _drawings[index] = drawing.copyWith(properties: mergedProps);
      notifyListeners();
    }
  }

  /// Updates the color of the currently selected drawing.
  void setSelectedDrawingColor(Color color) {
    final sel = selectedDrawing;
    if (sel != null && !sel.isLocked) {
      final index = _drawings.indexWhere((d) => d.id == sel.id);
      if (index >= 0) {
        _drawings[index] = _drawings[index].copyWith(color: color);
        notifyListeners();
      }
    }
  }

  /// Updates the stroke width of the currently selected drawing.
  void setSelectedDrawingStrokeWidth(double strokeWidth) {
    final sel = selectedDrawing;
    if (sel != null && !sel.isLocked) {
      final index = _drawings.indexWhere((d) => d.id == sel.id);
      if (index >= 0) {
        _drawings[index] = _drawings[index].copyWith(strokeWidth: strokeWidth);
        notifyListeners();
      }
    }
  }

  /// Toggles the lock state of the currently selected drawing.
  void toggleSelectedDrawingLocked() {
    final sel = selectedDrawing;
    if (sel != null) {
      final index = _drawings.indexWhere((d) => d.id == sel.id);
      if (index >= 0) {
        _drawings[index] = _drawings[index].copyWith(isLocked: !sel.isLocked);
        notifyListeners();
      }
    }
  }

  /// Deletes the currently selected drawing.
  void deleteSelectedDrawing() {
    final sel = selectedDrawing;
    if (sel != null) {
      removeDrawing(sel.id);
    }
  }

  /// Cancels in-progress drawing, resets tool to pointer, and clears preview.
  void cancelActiveDrawing() {
    _activeDrawingTool = DrawingTool.pointer;
    _previewDrawing = null;
    notifyListeners();
  }

  // Visual Price Alerts
  void addAlert(ChartAlert alert) {
    _alerts.removeWhere((a) => a.id == alert.id);
    _alerts.add(alert);
    notifyListeners();
  }

  void updateAlert(ChartAlert alert) {
    final index = _alerts.indexWhere((a) => a.id == alert.id);
    if (index >= 0) {
      _alerts[index] = alert;
      notifyListeners();
    }
  }

  void removeAlert(String id) {
    _alerts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  // Stackable Multiple Sub-Panes
  void removeSubPane(String indicatorId) {
    _activeIndicators.removeWhere((i) => i.id == indicatorId);
    _recalculateIndicators();
    notifyListeners();
  }

  // Bar Replay Mode & Simulator
  void startReplay([int? startIndex]) {
    _isReplayMode = true;
    final total = _candleBuilder.candles.length;
    final defaultIndex = total > 40 ? total - 40 : (total ~/ 2);
    _replayIndex = (startIndex ?? defaultIndex).clamp(1, math.max(1, total - 1));
    _isReplaying = false;
    _replayTimer?.cancel();
    _recalculateIndicators();
    scrollToLatest();
    notifyListeners();
  }

  void stepReplayForward() {
    if (!_isReplayMode || _replayIndex == null) return;
    if (_replayIndex! < _candleBuilder.candles.length - 1) {
      _replayIndex = _replayIndex! + 1;
      _recalculateIndicators();
      notifyListeners();
    } else {
      pauseReplay();
    }
  }

  void stepReplayBackward() {
    if (!_isReplayMode || _replayIndex == null) return;
    if (_replayIndex! > 5) {
      _replayIndex = _replayIndex! - 1;
      _recalculateIndicators();
      notifyListeners();
    }
  }

  void toggleReplayPlay() {
    if (_isReplaying) {
      pauseReplay();
    } else {
      playReplay();
    }
  }

  void playReplay() {
    if (!_isReplayMode) return;
    _isReplaying = true;
    _replayTimer?.cancel();
    final intervalMs = (1000 / _replaySpeed).round().clamp(100, 3000);
    _replayTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_replayIndex != null && _replayIndex! < _candleBuilder.candles.length - 1) {
        _replayIndex = _replayIndex! + 1;
        _recalculateIndicators();
        notifyListeners();
      } else {
        pauseReplay();
      }
    });
    notifyListeners();
  }

  void pauseReplay() {
    _isReplaying = false;
    _replayTimer?.cancel();
    notifyListeners();
  }

  void setReplaySpeed(double speed) {
    _replaySpeed = speed;
    if (_isReplaying) {
      playReplay();
    } else {
      notifyListeners();
    }
  }

  void exitReplay() {
    pauseReplay();
    _isReplayMode = false;
    _replayIndex = null;
    _recalculateIndicators();
    scrollToLatest();
    notifyListeners();
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
    if (_isReplayMode) return; // Freeze live ticks while in replay simulator
    final prevClose = currentCandle?.close ?? tick.price;
    final updatedCandle = _candleBuilder.onTick(tick);
    _checkAlerts(prevClose, tick.price);
    _recalculateIndicators();
    // Update hovered candle if it was tracking latest
    if (_crosshairPosition == null) {
      _hoveredCandle = updatedCandle;
    }
    notifyListeners();
  }

  void _checkAlerts(double prevPrice, double currentPrice) {
    for (int i = 0; i < _alerts.length; i++) {
      final alert = _alerts[i];
      if (alert.isActive && !alert.isTriggered && alert.checkTrigger(currentPrice, prevPrice)) {
        final triggered = alert.copyWith(
          isTriggered: true,
          triggeredAt: DateTime.now(),
        );
        _alerts[i] = triggered;
        onAlertTriggered?.call(triggered);
      }
    }
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
    _subPaneResults = [];
    _subPaneResult = null;

    final candleList = candles;
    if (candleList.isEmpty) {
      _volumeProfile = null;
      return;
    }

    for (final ind in _activeIndicators) {
      final res = ind.calculate(candleList);
      if (res.isOverlay) {
        _overlayResults.add(res);
      } else {
        _subPaneResults.add(res);
      }
    }
    _subPaneResult = _subPaneResults.isNotEmpty ? _subPaneResults.first : null;

    // Calculate Visible Range Volume Profile (VRVP) if enabled
    if (_showVolumeProfile) {
      final visible = _viewport.calculateVisibleIndices(candleList.length);
      final start = visible.start.clamp(0, candleList.length);
      final end = (visible.end + 1).clamp(start, candleList.length);
      final visCandles = candleList.sublist(start, end);
      _volumeProfile = VolumeProfile.calculate(visCandles);
    } else {
      _volumeProfile = null;
    }
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _tickSubscription?.cancel();
    _replayTimer?.cancel();
    super.dispose();
  }
}
