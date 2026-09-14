import '../core/models/candle.dart';
import '../core/models/tick.dart';
import '../core/models/timeframe.dart';

/// Normalized contract for market data providers (REST + WebSocket).
/// The chart engine only interacts with this interface, maintaining zero coupling
/// to any specific broker or provider API.
abstract class ChartDataSource {
  /// Fetches historical OHLCV bars for the specified [symbol] and [timeframe].
  Future<List<Candle>> getHistoricalData({
    required String symbol,
    required Timeframe timeframe,
    int count = 500,
  });

  /// Real-time stream of live trades/ticks for the given [symbol].
  Stream<Tick> getLiveTicks(String symbol);

  /// Disposes any active connections or timers.
  void dispose();
}
