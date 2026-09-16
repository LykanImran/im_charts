import 'dart:async';
import 'dart:math' as math;
import '../core/models/candle.dart';
import '../core/models/tick.dart';
import '../core/models/timeframe.dart';
import 'chart_data_source.dart';

/// Highly realistic deterministic Geometric Brownian Motion & micro-structure market simulator.
class MockTradingDataSource implements ChartDataSource {
  double initialPrice;
  final double volatility;
  final math.Random _random = math.Random(42);

  static const Map<String, double> defaultPrices = {
    'NIFTY 50': 24520.0,
    'BANKNIFTY': 51420.0,
    'FINNIFTY': 23890.0,
    'SENSEX': 80250.0,
    'RELIANCE': 2985.0,
    'TCS': 4210.0,
    'HDFCBANK': 1645.0,
    'INFY': 1890.0,
    'TATAMOTORS': 985.0,
    'ICICIBANK': 1230.0,
    'SBIN': 815.0,
    'BTC/USD': 65400.0,
    'ETH/USD': 3450.0,
  };

  StreamController<Tick>? _tickController;
  Timer? _tickTimer;
  double _currentPrice = 0.0;
  bool _isDisposed = false;

  MockTradingDataSource({
    this.initialPrice = 24500.0,
    this.volatility = 0.0015,
  }) {
    _currentPrice = initialPrice;
  }

  @override
  Future<List<Candle>> getHistoricalData({
    required String symbol,
    required Timeframe timeframe,
    int count = 500,
  }) async {
    final candles = <Candle>[];
    final now = DateTime.now();
    final alignedNow = timeframe.alignTimestamp(now);

    final symbolBasePrice = defaultPrices[symbol] ?? initialPrice;
    initialPrice = symbolBasePrice;

    // Generate historical backwards from now
    var price = symbolBasePrice;
    final tempList = <Candle>[];

    var currentTimestamp = alignedNow.subtract(timeframe.duration * count);

    for (int i = 0; i < count; i++) {
      // Geometric Brownian motion step with slight mean reversion
      final drift = 0.00005;
      final shock = (_random.nextDouble() - 0.49) * 2.0; // [-0.98, 1.02]
      final deltaPercent = drift + (volatility * shock);

      final open = price;
      final close = price * (1.0 + deltaPercent);

      // Intra-candle high and low
      final maxOC = math.max(open, close);
      final minOC = math.min(open, close);

      final highExtension = (_random.nextDouble() * volatility * 1.2) * price;
      final lowExtension = (_random.nextDouble() * volatility * 1.2) * price;

      final high = maxOC + highExtension;
      final low = math.max(0.01, minOC - lowExtension);

      // Volume with occasional spikes
      final isSpike = _random.nextDouble() < 0.08;
      final baseVolume = 1500.0 + (_random.nextDouble() * 4000.0);
      final volume = isSpike ? baseVolume * 3.5 : baseVolume;

      tempList.add(
        Candle(
          timestamp: currentTimestamp,
          open: double.parse(open.toStringAsFixed(2)),
          high: double.parse(high.toStringAsFixed(2)),
          low: double.parse(low.toStringAsFixed(2)),
          close: double.parse(close.toStringAsFixed(2)),
          volume: double.parse(volume.toStringAsFixed(0)),
        ),
      );

      price = close;
      currentTimestamp = currentTimestamp.add(timeframe.duration);
    }

    _currentPrice = price;
    candles.addAll(tempList);
    return candles;
  }

  @override
  Stream<Tick> getLiveTicks(String symbol) {
    _stopLiveSimulation();
    _tickController = StreamController<Tick>.broadcast(
      onListen: _startLiveSimulation,
      onCancel: _stopLiveSimulation,
    );
    return _tickController!.stream;
  }

  void _startLiveSimulation() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      // Small random walk micro-tick
      final shock = (_random.nextDouble() - 0.495) * 2.0;
      final tickDelta = _currentPrice * (volatility * 0.15) * shock;
      _currentPrice = math.max(1.0, _currentPrice + tickDelta);

      final tick = Tick(
        timestamp: DateTime.now(),
        price: double.parse(_currentPrice.toStringAsFixed(2)),
        volume: (_random.nextDouble() * 50.0) + 1.0,
      );

      _tickController?.add(tick);
    });
  }

  void _stopLiveSimulation() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopLiveSimulation();
    _tickController?.close();
    _tickController = null;
  }
}
