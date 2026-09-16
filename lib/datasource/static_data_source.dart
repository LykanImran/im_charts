import 'dart:async';
import '../core/models/candle.dart';
import '../core/models/tick.dart';
import '../core/models/timeframe.dart';
import 'chart_data_source.dart';

/// An in-memory, zero-boilerplate implementation of [ChartDataSource].
///
/// Enables developers to feed an existing [List<Candle>] or JSON map data
/// directly into Im Charts without writing custom data provider code.
class StaticChartDataSource implements ChartDataSource {
  final List<Candle> _candles;
  final StreamController<Tick> _tickController =
      StreamController<Tick>.broadcast();
  bool _isDisposed = false;

  /// Creates a static data source populated with the given [candles].
  StaticChartDataSource(List<Candle> candles) : _candles = List.of(candles);

  /// Convenient constructor to parse raw OHLCV maps (e.g. from a REST API) directly.
  factory StaticChartDataSource.fromMapList(List<Map<String, dynamic>> rawList) {
    final candles = rawList.map((map) {
      return Candle(
        timestamp: map['timestamp'] is DateTime
            ? map['timestamp'] as DateTime
            : DateTime.fromMillisecondsSinceEpoch(
                map['timestamp'] is int
                    ? map['timestamp'] as int
                    : int.tryParse(map['timestamp'].toString()) ?? 0,
              ),
        open: (map['open'] as num).toDouble(),
        high: (map['high'] as num).toDouble(),
        low: (map['low'] as num).toDouble(),
        close: (map['close'] as num).toDouble(),
        volume: (map['volume'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
    return StaticChartDataSource(candles);
  }

  /// Returns an unmodifiable view of current candles.
  List<Candle> get candles => List.unmodifiable(_candles);

  @override
  Future<List<Candle>> getHistoricalData({
    required String symbol,
    required Timeframe timeframe,
    int count = 500,
  }) async {
    if (_candles.isEmpty) return [];
    if (_candles.length <= count) {
      return List.unmodifiable(_candles);
    }
    return List.unmodifiable(_candles.sublist(_candles.length - count));
  }

  @override
  Stream<Tick> getLiveTicks(String symbol) {
    return _tickController.stream;
  }

  /// Replaces all candles with [newCandles].
  void updateCandles(List<Candle> newCandles) {
    _candles
      ..clear()
      ..addAll(newCandles);
  }

  /// Appends a new closed or live [candle] to the dataset.
  void appendCandle(Candle candle) {
    _candles.add(candle);
  }

  /// Emits a new real-time [Tick] through the live stream.
  void pushTick(Tick tick) {
    if (!_isDisposed && !_tickController.isClosed) {
      _tickController.add(tick);
    }
  }

  /// Emits a live price tick with current timestamp.
  void pushPrice(double price, {double volume = 1.0}) {
    pushTick(
      Tick(
        timestamp: DateTime.now(),
        price: price,
        volume: volume,
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tickController.close();
  }
}
