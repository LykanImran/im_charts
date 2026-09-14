# Data Sources & Real-Time Feeds

`im_charts` is data-agnostic. It can connect to any WebSocket, REST API, or streaming broker feed by implementing the simple **[`ChartDataSource`](file:///Users/princeraj/Storage%20Drive/Files/Projects/charts/im_charts/lib/datasource/chart_data_source.dart)** interface.

---

## 🔌 The `ChartDataSource` Contract

```dart
abstract class ChartDataSource {
  /// Fetches historical OHLCV candlestick data for the given symbol and timeframe.
  Future<List<Candle>> fetchHistoricalCandles({
    required String symbol,
    required Timeframe timeframe,
    required DateTime start,
    required DateTime end,
  });

  /// Streams live market ticks (LTP, volume, timestamp) for real-time updates.
  Stream<Tick> streamRealtimeTicks(String symbol);

  /// Streams pre-aggregated realtime candles (optional; if omitted, ticks are used).
  Stream<Candle>? streamRealtimeCandles(String symbol, Timeframe timeframe) => null;

  /// Closes streams, WebSockets, and timers.
  void dispose();
}
```

---

## 🛠️ Step-by-Step Implementation Examples

### 1. Connecting a WebSocket & REST Feed (e.g., Binance / Crypto)

Here is a complete, real-world example connecting to a WebSocket ticker and REST OHLC endpoint:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:im_charts/im_charts.dart';

class BinanceDataSource implements ChartDataSource {
  WebSocketChannel? _channel;
  StreamController<Tick>? _tickController;

  @override
  Future<List<Candle>> fetchHistoricalCandles({
    required String symbol,
    required Timeframe timeframe,
    required DateTime start,
    required DateTime end,
  }) async {
    final interval = _mapTimeframeToBinance(timeframe);
    final url = Uri.parse(
      'https://api.binance.com/api/v3/klines?symbol=$symbol&interval=$interval&limit=500',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load Binance candles: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) {
      return Candle(
        timestamp: DateTime.fromMillisecondsSinceEpoch(item[0] as int),
        open: double.parse(item[1].toString()),
        high: double.parse(item[2].toString()),
        low: double.parse(item[3].toString()),
        close: double.parse(item[4].toString()),
        volume: double.parse(item[5].toString()),
      );
    }).toList();
  }

  @override
  Stream<Tick> streamRealtimeTicks(String symbol) {
    _tickController = StreamController<Tick>.broadcast();
    final wsUrl = Uri.parse(
      'wss://stream.binance.com:9443/ws/${symbol.toLowerCase()}@trade',
    );
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen((data) {
      final json = jsonDecode(data as String);
      final price = double.parse(json['p'].toString());
      final volume = double.parse(json['q'].toString());
      final timestamp = DateTime.fromMillisecondsSinceEpoch(json['T'] as int);

      _tickController?.add(
        Tick(price: price, volume: volume, timestamp: timestamp),
      );
    }, onError: (err) {
      _tickController?.addError(err);
    });

    return _tickController!.stream;
  }

  String _mapTimeframeToBinance(Timeframe tf) {
    return switch (tf) {
      Timeframe.oneMinute => '1m',
      Timeframe.fiveMinutes => '5m',
      Timeframe.fifteenMinutes => '15m',
      Timeframe.thirtyMinutes => '30m',
      Timeframe.oneHour => '1h',
      Timeframe.fourHours => '4h',
      Timeframe.oneDay => '1d',
      Timeframe.oneWeek => '1w',
    };
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _tickController?.close();
  }
}
```

---

### 2. Using with Zerodha Kite Connect / Indian Brokers

For Indian equities (NSE/BSE), brokers like Zerodha Kite, Angel One, or Upstox provide historical data via REST and real-time ticks over binary WebSockets:

```dart
class KiteConnectDataSource implements ChartDataSource {
  final String apiKey;
  final String accessToken;
  final KiteTicker kiteTicker;

  KiteConnectDataSource({required this.apiKey, required this.accessToken, required this.kiteTicker});

  @override
  Future<List<Candle>> fetchHistoricalCandles({
    required String symbol,
    required Timeframe timeframe,
    required DateTime start,
    required DateTime end,
  }) async {
    // 1. Fetch historical OHLCV using Kite REST API
    final records = await kiteApi.getHistoricalData(symbol, timeframe.apiValue, start, end);
    return records.map((r) => Candle(
      timestamp: r.date,
      open: r.open,
      high: r.high,
      low: r.low,
      close: r.close,
      volume: r.volume.toDouble(),
    )).toList();
  }

  @override
  Stream<Tick> streamRealtimeTicks(String symbol) {
    // 2. Forward Kite binary ticks to im_charts stream
    return kiteTicker.onTick.map((kiteTick) => Tick(
      price: kiteTick.lastPrice,
      volume: kiteTick.lastQuantity.toDouble(),
      timestamp: kiteTick.timestamp ?? DateTime.now(),
    ));
  }

  @override
  void dispose() {
    kiteTicker.disconnect();
  }
}
```

---

## ⏱️ Real-Time Tick Aggregation (`CandleBuilder`)

When you stream live ticks (`Stream<Tick>`), `im_charts` automatically aggregates them into live candlesticks via [`CandleBuilder`](file:///Users/princeraj/Storage%20Drive/Files/Projects/charts/im_charts/lib/engine/candle_builder.dart):

1. **Intra-candle updates**: When a tick arrives within the active interval, `currentCandle` updates its `high = max(high, tick.price)`, `low = min(low, tick.price)`, `close = tick.price`, and increments `volume`.
2. **Interval crossing**: When a tick timestamp crosses into the next timeframe window (e.g. at `09:20:00` for a 5-minute candle), `CandleBuilder` finalizes the previous candle, appends it to the immutable history, and spawns a new live candle with `open = tick.price`.
3. **Zero configuration required**: All interval truncation and math is automated.

---

## 🧪 Testing with `MockTradingDataSource`

For development, testing, and widget previews, use the built-in [`MockTradingDataSource`](file:///Users/princeraj/Storage%20Drive/Files/Projects/charts/im_charts/lib/datasource/mock_data_source.dart):

```dart
final mockFeed = MockTradingDataSource(
  initialPrice: 24500.0,
  volatility: 0.002, // 0.2% price swings
  tickInterval: const Duration(milliseconds: 300), // Live tick cadence
);
```
