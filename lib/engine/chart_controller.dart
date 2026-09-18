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
import '../core/models/chart_save_state.dart';
import '../core/models/chart_theme.dart';
import '../core/models/price_range.dart';
import '../core/models/tick.dart';
import '../core/models/timeframe.dart';
import '../datasource/chart_data_source.dart';
import 'candle_builder.dart';
import 'chart_sync_group.dart';
import 'indicators/indicator.dart';
import 'indicators/indicator_result.dart';
import 'indicators/smart_money_concepts.dart';
import 'indicators/sma.dart';
import 'indicators/supertrend.dart';
import 'indicators/volume_profile.dart';
import 'dart:convert';

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

  ChartSyncGroup? _syncGroup;
  bool _isDisposed = false;
  bool _isReceivingSync = false;

  ChartSaveState _saveState = ChartSaveState.saved;
  Timer? _autoSaveTimer;
  Future<void> Function(String serializedData)? onSaveCallback;

  // Visible Range Volume Profile (VRVP)
  bool _showVolumeProfile = false;
  VolumeProfile? _volumeProfile;

  // Smart Money Concepts (SMC: FVG, BOS, CHoCH, Order Blocks)
  bool _showSMC = false;
  SmartMoneyConcepts? _smc;

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

  // Interactive Drawing State
  final List<ChartDrawing> _drawings = [];
  DrawingTool _activeDrawingTool = DrawingTool.pointer;
  ChartDrawing? _previewDrawing;
  void Function(ChartDrawing drawing)? onDrawingAdded;
  void Function(String drawingId)? onDrawingRemoved;

  // Undo / Redo History Stack for Drawings
  final List<List<ChartDrawing>> _undoStack = [];
  final List<List<ChartDrawing>> _redoStack = [];
  static const int _maxUndoHistory = 50;

  // Magnet Snapping Mode
  bool _magnetMode = false;

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
      ? _candleBuilder.candles.sublist(
          0,
          math.min(_replayIndex! + 1, _candleBuilder.candles.length),
        )
      : _candleBuilder.candles;
  Candle? get currentCandle => (_isReplayMode &&
          _replayIndex != null &&
          _candleBuilder.candles.isNotEmpty)
      ? _candleBuilder.candles[math.min(
          _replayIndex!,
          _candleBuilder.candles.length - 1,
        )]
      : _candleBuilder.currentCandle;
  Candle? get hoveredCandle => _hoveredCandle ?? currentCandle;
  List<IndicatorResult> get overlayResults => _overlayResults;
  List<IndicatorResult> get subPaneResults =>
      List.unmodifiable(_subPaneResults);
  IndicatorResult? get subPaneResult =>
      _subPaneResults.isNotEmpty ? _subPaneResults.first : null;
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

  bool get showSMC => _showSMC;
  set showSMC(bool val) {
    if (_showSMC != val) {
      _showSMC = val;
      _recalculateIndicators();
      notifyListeners();
    }
  }

  void toggleSMC() {
    showSMC = !_showSMC;
  }

  SmartMoneyConcepts? get smc => _smc;

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

  bool get isDisposed => _isDisposed;
  ChartSaveState get saveState => _saveState;
  ChartSyncGroup? get syncGroup => _syncGroup;
  set syncGroup(ChartSyncGroup? group) {
    if (_syncGroup == group) return;
    _syncGroup = group;
    notifyListeners();
  }

  void joinSyncGroup(ChartSyncGroup group) => group.register(this);
  void leaveSyncGroup() => _syncGroup?.unregister(this);

  Offset? get crosshairPosition => _showCrosshair ? _crosshairPosition : null;
  bool get showVolume => _showVolume;
  set showVolume(bool val) {
    if (_showVolume != val) {
      _showVolume = val;
      notifyListeners();
    }
  }
  bool get showGrid => _showGrid;
  bool get showCrosshair => _showCrosshair;
  bool get isLoading => _isLoading;
  bool get isDarkTheme => theme.isDark;

  double get verticalScale => _verticalScale;
  double get verticalPan => _verticalPan;
  bool get isManualPriceScale =>
      (_verticalScale - 1.0).abs() > 0.001 || _verticalPan.abs() > 0.001;

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
    final chartWidth = (_viewport.viewportWidth - 65.0).clamp(
      10.0,
      double.infinity,
    );
    final bounds = Rect.fromLTWH(0, 0, chartWidth, mainPaneHeight);
    return CoordinateConverter.yToPrice(y, bounds, currentPriceRange);
  }

  /// Converts financial price to screen Y coordinate inside main pane.
  double yAtPrice(double price) {
    final chartWidth = (_viewport.viewportWidth - 65.0).clamp(
      10.0,
      double.infinity,
    );
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
        takeProfitPrice: clearTakeProfit
            ? () => null
            : (takeProfitPrice != null ? () => takeProfitPrice : null),
        stopLossPrice: clearStopLoss
            ? () => null
            : (stopLossPrice != null ? () => stopLossPrice : null),
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

  // --- Drawing History & Undo / Redo ---

  /// Whether there is a previous drawing state available to undo.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there is a subsequent drawing state available to redo.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Records the current state of drawings to the undo stack.
  void recordDrawingSnapshot() {
    _undoStack.add(_drawings.map((d) => d.copyWith()).toList());
    if (_undoStack.length > _maxUndoHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  /// Undoes the last drawing modification.
  void undo() {
    if (!canUndo) return;
    _redoStack.add(_drawings.map((d) => d.copyWith()).toList());
    _drawings
      ..clear()
      ..addAll(_undoStack.removeLast());
    notifyListeners();
    triggerAutoSave();
  }

  /// Reapplies drawings to the next forward state in history.
  void redo() {
    if (!canRedo) return;
    _undoStack.add(_drawings.map((d) => d.copyWith()).toList());
    _drawings
      ..clear()
      ..addAll(_redoStack.removeLast());
    notifyListeners();
    triggerAutoSave();
  }

  // --- Magnet Mode (Snap to OHLC) ---

  /// Whether magnet mode is active (snapping drawing anchors to candle OHLC).
  bool get magnetMode => _magnetMode;

  /// Toggles magnet snapping mode on or off.
  void toggleMagnetMode() {
    _magnetMode = !_magnetMode;
    notifyListeners();
  }

  /// Sets magnet snapping mode directly.
  void setMagnetMode(bool enabled) {
    if (_magnetMode != enabled) {
      _magnetMode = enabled;
      notifyListeners();
    }
  }

  /// Snaps a drawing point's price to the closest candle Open, High, Low, or Close
  /// if magnet mode is enabled and candles exist at or near [rawPoint.candleIndex].
  DrawingPoint snapPointToCandle(DrawingPoint rawPoint) {
    if (!_magnetMode) return rawPoint;
    final candleList = candles;
    if (candleList.isEmpty) return rawPoint;

    final targetIndex = rawPoint.candleIndex.clamp(0, candleList.length - 1);
    final c = candleList[targetIndex];

    final ohlc = [c.open, c.high, c.low, c.close];
    double closest = ohlc[0];
    double minDiff = (rawPoint.price - closest).abs();

    for (int i = 1; i < ohlc.length; i++) {
      final diff = (rawPoint.price - ohlc[i]).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = ohlc[i];
      }
    }

    return rawPoint.copyWith(price: closest);
  }

  // --- Drawing JSON Serialization ---

  /// Serializes all current drawings into a JSON string.
  String exportDrawingsJson() {
    final list = _drawings.map((d) => d.toJson()).toList();
    return jsonEncode(list);
  }

  /// Imports drawings from a JSON string, restoring them onto the chart.
  void importDrawingsJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        recordDrawingSnapshot();
        _drawings
          ..clear()
          ..addAll(decoded.map(
            (item) => ChartDrawing.fromJson(item as Map<String, dynamic>),
          ));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error importing drawings JSON: $e');
    }
  }

  /// Adds a new user drawing to the chart canvas.
  void addDrawing(ChartDrawing drawing) {
    recordDrawingSnapshot();
    _drawings.add(drawing);
    _previewDrawing = null;
    onDrawingAdded?.call(drawing);
    notifyListeners();
    triggerAutoSave();
  }

  /// Updates an existing drawing (e.g. dragging an anchor point).
  void updateDrawing(ChartDrawing drawing) {
    final index = _drawings.indexWhere((d) => d.id == drawing.id);
    if (index >= 0) {
      _drawings[index] = drawing;
      notifyListeners();
      triggerAutoSave();
    }
  }

  /// Removes a drawing from the chart canvas.
  void removeDrawing(String id) {
    final removed = _drawings.where((d) => d.id == id).toList();
    if (removed.isNotEmpty) {
      recordDrawingSnapshot();
      _drawings.removeWhere((d) => d.id == id);
      onDrawingRemoved?.call(id);
      notifyListeners();
      triggerAutoSave();
    }
  }

  /// Clears all drawings from the chart canvas.
  void clearDrawings() {
    if (_drawings.isNotEmpty) {
      recordDrawingSnapshot();
      _drawings.clear();
      _previewDrawing = null;
      notifyListeners();
      triggerAutoSave();
    }
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
          ((updatedProps['targetPrice'] as double) + deltaPrice)
              .toStringAsFixed(2),
        );
      }
      if (updatedProps.containsKey('stopPrice')) {
        updatedProps['stopPrice'] = double.parse(
          ((updatedProps['stopPrice'] as double) + deltaPrice).toStringAsFixed(
            2,
          ),
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
      final mergedProps = Map<String, dynamic>.from(drawing.properties)
        ..addAll(newProperties);
      _drawings[index] = drawing.copyWith(properties: mergedProps);
      notifyListeners();
    }
  }

  /// Updates the color of the currently selected drawing.
  void setSelectedDrawingColor(Color color) {
    final sel = selectedDrawing;
    if (sel != null && !sel.isLocked) {
      recordDrawingSnapshot();
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
      recordDrawingSnapshot();
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
    _replayIndex = (startIndex ?? defaultIndex).clamp(
      1,
      math.max(1, total - 1),
    );
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
      if (_replayIndex != null &&
          _replayIndex! < _candleBuilder.candles.length - 1) {
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

  /// Directly sets the candle dataset and recalculates all active technical indicators.
  void setCandles(List<Candle> candles) {
    _candleBuilder.setCandles(candles);
    _recalculateIndicators();
    if (_crosshairPosition == null) {
      _hoveredCandle = currentCandle;
    }
    notifyListeners();
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
      if (alert.isActive &&
          !alert.isTriggered &&
          alert.checkTrigger(currentPrice, prevPrice)) {
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
    if (_symbol == newSymbol && (exchange == null || _exchange == exchange)) {
      return;
    }
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
    triggerAutoSave();
  }

  /// Changes the candle presentation style (Candles, Hollow, Heikin Ashi, Line, Area, Bars).
  void setCandleStyle(CandleStyle style) {
    if (_candleStyle == style) return;
    _candleStyle = style;
    notifyListeners();
    triggerAutoSave();
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
    triggerAutoSave();
  }

  /// Sets an explicit theme.
  void setTheme(ChartTheme newTheme) {
    theme = newTheme;
    notifyListeners();
    triggerAutoSave();
  }

  /// Toggles grid lines on/off.
  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
    triggerAutoSave();
  }

  /// Toggles crosshair on/off.
  void toggleCrosshair() {
    _showCrosshair = !_showCrosshair;
    if (!_showCrosshair) {
      _crosshairPosition = null;
    }
    notifyListeners();
    triggerAutoSave();
  }

  /// Updates viewport canvas dimensions (called by LayoutBuilder in UI).
  void updateDimensions(double width, double height) {
    if (_viewport.viewportWidth != width ||
        _viewport.viewportHeight != height) {
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
      if (_syncGroup != null && !_isReceivingSync) {
        _syncGroup!.clearCrosshair(source: this);
      }
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

    if (_syncGroup != null && !_isReceivingSync) {
      final hoveredTime = _hoveredCandle?.timestamp;
      final yRatio = (position != null && _viewport.viewportHeight > 0)
          ? (position.dy / _viewport.viewportHeight).clamp(0.0, 1.0)
          : null;
      _syncGroup!.broadcastCrosshair(
        source: this,
        timestamp: hoveredTime,
        yPriceRatio: yRatio,
      );
    }
    notifyListeners();
  }

  /// Handles crosshair synchronization from another chart in the [ChartSyncGroup].
  void receiveSyncedCrosshair(DateTime? timestamp, double? yPriceRatio) {
    if (!_showCrosshair || timestamp == null || candles.isEmpty) {
      _crosshairPosition = null;
      _hoveredCandle = null;
      notifyListeners();
      return;
    }

    final timestamps = candles.map((c) => c.timestamp).toList();
    final matchIdx =
        ChartSyncGroup.findClosestCandleIndex(timestamps, timestamp);
    if (matchIdx < 0 || matchIdx >= candles.length) {
      _crosshairPosition = null;
      _hoveredCandle = null;
      notifyListeners();
      return;
    }

    _isReceivingSync = true;
    try {
      final converter = CoordinateConverter(
        viewport: _viewport,
        totalCandles: candles.length,
      );
      final targetX = converter.indexToX(matchIdx);
      final targetY = (yPriceRatio != null && _viewport.viewportHeight > 0)
          ? (yPriceRatio * _viewport.viewportHeight)
              .clamp(0.0, _viewport.viewportHeight)
          : (_viewport.viewportHeight * 0.5);

      _crosshairPosition = Offset(targetX, targetY);
      _hoveredCandle = candles[matchIdx];
      notifyListeners();
    } finally {
      _isReceivingSync = false;
    }
  }

  /// Horizontal scroll / pan gesture handler.
  void onPan(double deltaX) {
    _applyPan(deltaX);
    if (_syncGroup != null && !_isReceivingSync) {
      _syncGroup!.broadcastPan(source: this, deltaX: deltaX);
    }
  }

  void _applyPan(double deltaX) {
    final maxScroll = (candles.length * _viewport.candleTotalWidth).toDouble();
    const minScroll = -120.0; // Allow right margin expansion
    final newOffset = (_viewport.scrollOffset + deltaX)
        .clamp(minScroll, math.max(0.0, maxScroll))
        .toDouble();

    _viewport = _viewport.copyWith(scrollOffset: newOffset);
    notifyListeners();
  }

  /// Handles synchronized horizontal pan from [ChartSyncGroup].
  void receiveSyncedPan(double deltaX) {
    _isReceivingSync = true;
    try {
      _applyPan(deltaX);
    } finally {
      _isReceivingSync = false;
    }
  }

  /// Unified atomic pinch-to-zoom & pan method.
  /// Smoothly adjusts candleWidth clamped to [1.5, 60.0] while anchoring the zoom
  /// around [focalPoint] and translating by [panDeltaX], preserving focal stability
  /// identical to TradingView.
  void onPinchZoom(double scaleFactor, Offset focalPoint, double panDeltaX) {
    _applyPinchZoom(scaleFactor, focalPoint, panDeltaX);
    if (_syncGroup != null &&
        !_isReceivingSync &&
        _viewport.viewportWidth > 0) {
      final ratio = (focalPoint.dx / _viewport.viewportWidth).clamp(0.0, 1.0);
      _syncGroup!.broadcastZoom(
        source: this,
        scaleFactor: scaleFactor,
        focalPointRatio: ratio,
      );
    }
  }

  /// Focal-point aware horizontal zoom (pinch zoom or mouse wheel).
  void onZoom(double scaleFactor, Offset focalPoint) {
    onPinchZoom(scaleFactor, focalPoint, 0.0);
  }

  void _applyZoom(double scaleFactor, Offset focalPoint) {
    _applyPinchZoom(scaleFactor, focalPoint, 0.0);
  }

  void _applyPinchZoom(
    double scaleFactor,
    Offset focalPoint,
    double panDeltaX,
  ) {
    if (scaleFactor.isNaN || scaleFactor.isInfinite || scaleFactor <= 0) {
      if (panDeltaX.abs() > 0.01) {
        _applyPan(panDeltaX);
      }
      return;
    }
    const minWidth = 1.5;
    const maxWidth = 60.0;
    final oldCandleWidth = _viewport.candleWidth;
    final newWidth = (oldCandleWidth * scaleFactor).clamp(minWidth, maxWidth);

    final oldTotal = _viewport.candleTotalWidth;
    final newTotal = newWidth + _viewport.candleSpacing;
    final ratio = newTotal / oldTotal;

    // Anchor calculation to keep candle under focalPoint.dx stationary
    final focalX =
        focalPoint.dx.clamp(0.0, math.max(1.0, _viewport.viewportWidth));
    final distFromRight = _viewport.viewportWidth -
        _viewport.rightMargin -
        focalX +
        _viewport.scrollOffset;

    // Prevent zoom out from introducing unwanted future whitespace if not already overscrolled
    final minScroll = _viewport.scrollOffset < 0 ? -120.0 : 0.0;
    final maxScroll = math.max(0.0, candles.length * newTotal).toDouble();
    final zoomDeltaScroll = distFromRight * (ratio - 1.0);
    final newScrollOffset =
        (_viewport.scrollOffset + zoomDeltaScroll + panDeltaX).clamp(
      minScroll,
      maxScroll,
    );

    if (newWidth == oldCandleWidth &&
        newScrollOffset == _viewport.scrollOffset) {
      return;
    }

    _viewport = _viewport.copyWith(
      candleWidth: newWidth,
      scrollOffset: newScrollOffset,
    );
    notifyListeners();
  }

  /// Handles synchronized zoom from [ChartSyncGroup].
  void receiveSyncedZoom(double scaleFactor, double focalPointRatio) {
    _isReceivingSync = true;
    try {
      final focalPoint = Offset(
        focalPointRatio * _viewport.viewportWidth,
        _viewport.viewportHeight * 0.5,
      );
      _applyZoom(scaleFactor, focalPoint);
    } finally {
      _isReceivingSync = false;
    }
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
    final newWidth = (_viewport.candleWidth * scaleRatio).clamp(1.5, 60.0);
    if (newWidth == _viewport.candleWidth) return;

    final oldTotal = _viewport.candleTotalWidth;
    final newTotal = newWidth + _viewport.candleSpacing;
    final ratio = newTotal / oldTotal;

    final newOffset = (_viewport.scrollOffset * ratio).clamp(
      -120.0,
      double.infinity,
    );
    _viewport = _viewport.copyWith(
      candleWidth: newWidth,
      scrollOffset: newOffset,
    );
    notifyListeners();
  }

  /// Zoom in horizontally by 25%.
  void zoomIn() {
    final newWidth = (_viewport.candleWidth * 1.25).clamp(1.5, 60.0);
    _viewport = _viewport.copyWith(candleWidth: newWidth);
    notifyListeners();
  }

  /// Zoom out horizontally by 20%.
  void zoomOut() {
    final newWidth = (_viewport.candleWidth * 0.8).clamp(1.5, 60.0);
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
    _viewport = _viewport.copyWith(candleWidth: 8.0, scrollOffset: 0.0);
    notifyListeners();
  }

  /// Resets both time and price scale to default view.
  void resetView() {
    _viewport = _viewport.copyWith(candleWidth: 8.0, scrollOffset: 0.0);
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

  /// Sets horizontal scroll offset directly with boundary clamping.
  void setScrollOffset(double offset) {
    final maxScroll = (candles.length * _viewport.candleWidth).clamp(0.0, double.infinity);
    final clamped = offset.clamp(-120.0, maxScroll);
    if (_viewport.scrollOffset != clamped) {
      _viewport = _viewport.copyWith(scrollOffset: clamped);
      notifyListeners();
    }
  }

  /// Toggles volume histogram on/off.
  void toggleVolume() {
    _showVolume = !_showVolume;
    notifyListeners();
  }

  /// Toggles an indicator on or off.
  void toggleIndicator(Indicator indicator) {
    final existingIndex = _activeIndicators.indexWhere(
      (i) => i.id == indicator.id,
    );
    if (existingIndex >= 0) {
      _activeIndicators.removeAt(existingIndex);
    } else {
      _activeIndicators.add(indicator);
    }
    _recalculateIndicators();
    notifyListeners();
    triggerAutoSave();
  }

  /// Clears all active indicators from the chart.
  void clearIndicators() {
    if (_activeIndicators.isEmpty) return;
    _activeIndicators.clear();
    _recalculateIndicators();
    notifyListeners();
    triggerAutoSave();
  }

  bool isIndicatorActive(String id) {
    return _activeIndicators.any((i) => i.id == id);
  }

  // --- Convenience SMA and Supertrend indicator getters & toggles ---

  /// Whether SMA 20 is currently active on the chart.
  bool get showSma => isIndicatorActive('SMA_20');

  /// Toggles Simple Moving Average (SMA) on or off.
  void toggleSma([int period = 20]) =>
      toggleIndicator(SMAIndicator(period: period));

  /// Whether Supertrend is currently active on the chart.
  bool get showSupertrend =>
      _activeIndicators.any((i) => i is SupertrendIndicator);

  /// Toggles Supertrend trend-following indicator on or off.
  void toggleSupertrend({int period = 10, double multiplier = 3.0}) =>
      toggleIndicator(
        SupertrendIndicator(period: period, multiplier: multiplier),
      );

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

    // Calculate Smart Money Concepts (SMC) if enabled
    if (_showSMC) {
      _smc = SmartMoneyConcepts.calculate(candleList);
    } else {
      _smc = null;
    }
  }

  /// Persists the current chart configuration and drawings asynchronously.
  Future<void> saveChart() async {
    if (_saveState == ChartSaveState.saving) return;
    _saveState = ChartSaveState.saving;
    notifyListeners();

    try {
      final json = exportSettingsJson();
      if (onSaveCallback != null) {
        await onSaveCallback!(json);
      } else {
        // Visual feedback delay
        await Future.delayed(const Duration(milliseconds: 650));
      }
      _saveState = ChartSaveState.saved;
    } catch (e) {
      debugPrint('Error saving chart: $e');
      _saveState = ChartSaveState.unsaved;
    } finally {
      notifyListeners();
    }
  }

  /// Schedules an auto-save operation with debouncing.
  void triggerAutoSave() {
    _autoSaveTimer?.cancel();
    if (_saveState != ChartSaveState.saving) {
      _saveState = ChartSaveState.unsaved;
      notifyListeners();
    }
    _autoSaveTimer = Timer(const Duration(milliseconds: 750), () {
      if (!_isDisposed) {
        saveChart();
      }
    });
  }

  /// Serializes chart layout, settings, timeframe, candle style, and drawings to JSON.
  String exportSettingsJson() {
    final map = <String, dynamic>{
      'symbol': _symbol,
      'exchange': _exchange,
      'timeframe': _timeframe.name,
      'candleStyle': _candleStyle.name,
      'showVolume': _showVolume,
      'showGrid': _showGrid,
      'showCrosshair': _showCrosshair,
      'showWatermark': _showWatermark,
      'showCountdownTimer': _showCountdownTimer,
      'showVolumeProfile': _showVolumeProfile,
      'showSMC': _showSMC,
      'isDarkTheme': isDarkTheme,
      'drawings': _drawings.map((d) => d.toJson()).toList(),
      'activeIndicators': _activeIndicators.map((i) => i.id).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(map);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _autoSaveTimer?.cancel();
    _syncGroup?.unregister(this);
    _countdownTicker?.cancel();
    _tickSubscription?.cancel();
    _replayTimer?.cancel();
    super.dispose();
  }
}
