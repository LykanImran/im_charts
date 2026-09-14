import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/coordinates/viewport.dart';
import '../core/models/candle.dart';
import '../core/models/candle_style.dart';
import '../core/models/chart_theme.dart';
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

  final List<Indicator> _activeIndicators = [];
  List<IndicatorResult> _overlayResults = [];
  IndicatorResult? _subPaneResult;

  Offset? _crosshairPosition;
  Candle? _hoveredCandle;
  bool _showVolume = true;
  bool _showGrid = true;
  bool _showCrosshair = true;
  bool _isLoading = true;

  // Vertical Price Scale (TradingView manual scale & pan)
  double _verticalScale = 1.0;
  double _verticalPan = 0.0;

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
  Offset? get crosshairPosition => _showCrosshair ? _crosshairPosition : null;
  bool get showVolume => _showVolume;
  bool get showGrid => _showGrid;
  bool get showCrosshair => _showCrosshair;
  bool get isLoading => _isLoading;
  bool get isDarkTheme => theme.backgroundColor == const Color(0xFF131722);

  double get verticalScale => _verticalScale;
  double get verticalPan => _verticalPan;
  bool get isManualPriceScale => (_verticalScale - 1.0).abs() > 0.001 || _verticalPan.abs() > 0.001;

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
    _tickSubscription?.cancel();
    super.dispose();
  }
}
