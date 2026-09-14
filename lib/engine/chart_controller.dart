import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/coordinates/viewport.dart';
import '../core/models/candle.dart';
import '../core/models/chart_theme.dart';
import '../core/models/tick.dart';
import '../core/models/timeframe.dart';
import '../datasource/chart_data_source.dart';
import 'candle_builder.dart';
import 'indicators/indicator.dart';
import 'indicators/indicator_result.dart';

/// Top-level controller managing chart state, gestures, viewport, indicators, and live data stream.
class TradingChartController extends ChangeNotifier {
  final String symbol;
  final ChartDataSource dataSource;
  ChartTheme theme;

  Timeframe _timeframe;
  ChartViewport _viewport;
  late CandleBuilder _candleBuilder;
  StreamSubscription<Tick>? _tickSubscription;

  final List<Indicator> _activeIndicators = [];
  List<IndicatorResult> _overlayResults = [];
  IndicatorResult? _subPaneResult;

  Offset? _crosshairPosition;
  Candle? _hoveredCandle;
  bool _showVolume = true;
  bool _isLoading = true;

  TradingChartController({
    required this.symbol,
    required this.dataSource,
    Timeframe initialTimeframe = Timeframe.fiveMinutes,
    ChartTheme? theme,
  })  : _timeframe = initialTimeframe,
        theme = theme ?? ChartTheme.dark(),
        _viewport = const ChartViewport() {
    _candleBuilder = CandleBuilder(timeframe: _timeframe);
  }

  // Getters
  Timeframe get timeframe => _timeframe;
  ChartViewport get viewport => _viewport;
  List<Candle> get candles => _candleBuilder.candles;
  Candle? get currentCandle => _candleBuilder.currentCandle;
  Candle? get hoveredCandle => _hoveredCandle ?? currentCandle;
  List<IndicatorResult> get overlayResults => _overlayResults;
  IndicatorResult? get subPaneResult => _subPaneResult;
  List<Indicator> get activeIndicators => List.unmodifiable(_activeIndicators);
  Offset? get crosshairPosition => _crosshairPosition;
  bool get showVolume => _showVolume;
  bool get isLoading => _isLoading;

  /// Loads initial historical data and establishes real-time tick ingestion.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final historical = await dataSource.getHistoricalData(
        symbol: symbol,
        timeframe: _timeframe,
        count: 500,
      );
      _candleBuilder.setCandles(historical);
      _recalculateIndicators();

      // Listen to real-time live ticks
      _tickSubscription?.cancel();
      _tickSubscription = dataSource.getLiveTicks(symbol).listen(_onLiveTick);
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

  /// Changes chart timeframe and refreshes historical candles.
  Future<void> setTimeframe(Timeframe newTimeframe) async {
    if (_timeframe == newTimeframe) return;
    _timeframe = newTimeframe;
    _candleBuilder = CandleBuilder(timeframe: newTimeframe);
    _crosshairPosition = null;
    _hoveredCandle = null;
    await initialize();
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

  /// Pinch zoom gesture handler.
  void onZoom(double scaleFactor, Offset focalPoint) {
    const minWidth = 2.0;
    const maxWidth = 45.0;
    final newWidth = (_viewport.candleWidth * scaleFactor).clamp(minWidth, maxWidth);

    _viewport = _viewport.copyWith(candleWidth: newWidth);
    notifyListeners();
  }

  /// Zooms in by 20%.
  void zoomIn() {
    final newWidth = (_viewport.candleWidth * 1.25).clamp(2.0, 45.0);
    _viewport = _viewport.copyWith(candleWidth: newWidth);
    notifyListeners();
  }

  /// Zooms out by 20%.
  void zoomOut() {
    final newWidth = (_viewport.candleWidth * 0.8).clamp(2.0, 45.0);
    _viewport = _viewport.copyWith(candleWidth: newWidth);
    notifyListeners();
  }

  /// Resets scroll and zoom to default view.
  void resetView() {
    _viewport = _viewport.copyWith(
      candleWidth: 8.0,
      scrollOffset: 0.0,
    );
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
