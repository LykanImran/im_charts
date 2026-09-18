# Im Charts API Reference

Comprehensive technical reference for all public classes, methods, models, and enums provided by **Im Charts (`im_charts`)**.

---

## 🏷️ Brand Type Aliases

Im Charts provides first-class brand aliases for clean, idiomatic integration:

- **`ImChart`**: Alias for `TradingChart`.
- **`ImTradingScreen`**: Alias for `TradingScreen`.
- **`ImChartsApp`**: Alias for `TradingApp`.
- **`ImChartController`**: Alias for `TradingChartController`.

---

## 📱 Widgets

### `TradingScreen` / `ImTradingScreen`
Top-level turnkey trading terminal widget embedding the primary toolbar, telemetry overlay header, left drawing tools bar, and high-performance chart canvas.

```dart
const TradingScreen({
  super.key,
  String initialSymbol = 'NIFTY 50',
  String initialExchange = 'NSE',
  String brandName = 'Im Charts',
  ChartDataSource? dataSource,
  Timeframe initialTimeframe = Timeframe.fiveMinutes,
  CandleStyle initialCandleStyle = CandleStyle.candles,
  ChartTheme? initialTheme,
  TradingChartController? controller,
  bool showToolbar = true,
  bool showHeader = true,
  bool showDrawingToolbar = true,
  bool showWatermark = true,
  bool showCountdownTimer = true,
  bool enableChartTrading = true,
});
```

- `initialSymbol`: Ticker symbol loaded on startup (e.g. `'NIFTY 50'`, `'RELIANCE'`, `'BTCUSDT'`).
- `initialExchange`: Market exchange designation (`'NSE'`, `'BSE'`, `'NASDAQ'`).
- `brandName`: Brand name displayed on canvas watermarks and overlays. Defaults to `'Im Charts'`.
- `dataSource`: Optional data source implementing `ChartDataSource`. Defaults to `MockTradingDataSource`.
- `initialTimeframe`: Default candlestick interval. Defaults to `Timeframe.fiveMinutes`.
- `initialCandleStyle`: Default presentation style. Defaults to `CandleStyle.candles`.
- `initialTheme`: Color tokens. Defaults to `ChartTheme.dark()`.
- `controller`: Optional caller-owned `TradingChartController`. If provided, lifecycle is managed externally.
- `showToolbar`: Whether to render Row 1 primary toolbar. Default is `true`.
- `showHeader`: Whether to render Row 2 telemetry overlay header. Default is `true`.
- `showDrawingToolbar`: Whether to dock the left drawing tools bar. Default is `true`.
- `showWatermark`: Whether to render bold symbol & timeframe background typography. Default is `true`.
- `showCountdownTimer`: Whether to display the live candle close countdown badge on the price axis. Default is `true`.
- `enableChartTrading`: Whether to enable interactive order lines, hover `+` button, and brackets. Default is `true`.

---

### `ChartDrawingToolbar`
Left-docked vertical toolbar providing 1-click access to technical analysis instruments.

```dart
const ChartDrawingToolbar({
  super.key,
  required TradingChartController controller,
  bool isCollapsible = true,
});
```

---

### `DrawingActionToolbar`
Floating glassmorphic contextual quick-action toolbar displayed when any drawing is selected. Provides color swatches, stroke widths (1–4px), lock/unlock, and instant deletion.

```dart
const DrawingActionToolbar({
  super.key,
  required TradingChartController controller,
  required ChartDrawing selectedDrawing,
});
```

---

### `TradingChart`
Standalone high-performance canvas presentation widget.

```dart
const TradingChart({
  super.key,
  required TradingChartController controller,
  bool showWatermark = true,
  bool showCountdownTimer = true,
  bool enableChartTrading = true,
  OrderMenuBuilder? orderMenuBuilder,
});
```

---

### `ChartToolbar`
Institutional Row 1 primary toolbar containing Symbol Search, Interval Dropdown, Candle Style Dropdown, Technical Indicators Selector, Refresh, Theme Toggle, and Settings Modal.

```dart
const ChartToolbar({
  super.key,
  required TradingChartController controller,
});
```

---

### `ChartHeader`
TradingView-style floating telemetry overlay displaying live market ticker, exchange selector, LTP, dynamic percentage change badge, and live OHLCV data strip.

```dart
const ChartHeader({
  super.key,
  required TradingChartController controller,
});
```

---

## 🎛️ State & Engine

### `TradingChartController`
Central state management controller coordinating data ingestion, viewport calculations, indicators, and interactions. Extends `ChangeNotifier`.

#### Key Properties
- `String get symbol`: Current ticker symbol.
- `String get exchange`: Current market exchange.
- `Timeframe get timeframe`: Active candle interval.
- `CandleStyle get candleStyle`: Active presentation style.
- `ChartViewport get viewport`: Current viewport parameters.
- `List<Candle> get candles`: Complete historical candle list.
- `Candle? get currentCandle`: Active forming candle.
- `Candle? get hoveredCandle`: Candle under crosshair pointer or latest candle.
- `List<IndicatorResult> get overlayResults`: Computed overlay indicator series.
- `IndicatorResult? get subPaneResult`: Primary sub-pane oscillator result (backward compatible).
- `List<IndicatorResult> get subPaneResults`: All active stacked sub-pane oscillator results.
- `bool get showVolumeProfile`: Whether Visible Range Volume Profile is displayed.
- `VolumeProfile? get volumeProfile`: Active computed volume profile across visible bars.
- `List<ChartAlert> get alerts`: Active price alerts.
- `List<ChartOrder> get orders`: Active orders on chart.
- `List<ChartPosition> get positions`: Open executed positions on chart.
- `bool get isManualPriceScale`: `true` if user has dragged vertical price scale.
- `bool get isDarkTheme`: `true` if dark mode palette is active.
- `bool get isReplayMode`: `true` if historical bar replay simulator is active.
- `bool get isReplaying`: `true` if continuous playback is currently running.
- `int get replaySpeed`: Current replay playback speed multiplier (`1` to `5`).

#### Key Methods
- `Future<void> initialize()`: Fetches historical candles and starts real-time streaming.
- `void setSymbol(String newSymbol)`: Switches symbol, loads new history, and updates ticker.
- `void setExchange(String newExchange)`: Updates active market exchange.
- `void setTimeframe(Timeframe newTimeframe)`: Switches timeframe and rebuilds candle aggregation.
- `void setCandleStyle(CandleStyle newStyle)`: Updates rendering presentation.
- `void onZoom(double scaleFactor, Offset focalPoint)`: Focal-anchored horizontal zoom.
- `void onPan(double deltaX)`: Horizontal scroll through time.
- `void onVerticalScale(double deltaY)`: Scales price axis vertically.
- `void onTimeScale(double deltaX)`: Zooms candle width via time axis drag.
- `void resetView()`: Resets all zoom, manual price scaling, and scroll to default.
- `void resetPriceScale()`: Restores auto-scale mode on price axis.
- `void scrollToLatest()`: Animates/scrolls viewport to the latest candle.
- `void toggleIndicator(Indicator indicator)`: Toggles active status of an indicator (supports multiple sub-panes).
- `void removeSubPane(Indicator indicator)`: Closes and removes a specific sub-pane oscillator.
- `void toggleVolumeProfile()`: Toggles Visible Range Volume Profile overlay.
- `void toggleTheme()`: Toggles between `ChartTheme.dark()` and `ChartTheme.light()`.
- `void placeOrder(ChartOrder order)`: Submits new chart order with optional TP/SL brackets.
- `void cancelOrder(String id)`: Cancels pending order by ID.
- `void openPosition(ChartPosition position)`: Registers an executed market position.
- `void closePosition(String id)`: Closes an open position at market.
- `void updatePosition(ChartPosition position)`: Modifies open position (e.g. adjusts TP/SL).
- `void addAlert(ChartAlert alert)`: Registers a new price alert line on canvas.
- `void updateAlert(ChartAlert alert)`: Modifies alert price threshold or condition.
- `void removeAlert(String id)`: Deletes an alert by ID.
- `void clearAlerts()`: Removes all active alerts.
- `void startReplay({int? fromIndex})`: Initializes bar replay simulator sliced to historical index.
- `void stepReplayForward()`: Advances replay simulation by 1 candle.
- `void stepReplayBackward()`: Steps replay simulation backward by 1 candle.
- `void toggleReplayPlay()`: Toggles automated replay playback on/off.
- `void setReplaySpeed(int speed)`: Sets replay timer rate (`1x`, `2x`, `3x`, `5x`).
- `void exitReplay()`: Exits simulator and restores live real-time candle stream.

---

## 📐 Coordinates & Viewport

### `ChartViewport`
Immutable viewport parameters defining canvas geometry.

```dart
const ChartViewport({
  double candleWidth = 8.0,
  double candleSpacing = 2.0,
  double scrollOffset = 0.0,
  double viewportWidth = 0.0,
  double viewportHeight = 0.0,
  double rightMargin = 50.0,
});
```

- `candleTotalWidth`: `candleWidth + candleSpacing`.
- `calculateVisibleIndices(int totalCandles)`: Returns `VisibleIndices(start, end)` within viewport window.

---

### `CoordinateConverter`
Bidirectional projection mathematics between market price/time and canvas pixels.

- `static double priceToY(double price, Rect bounds, PriceRange range)`: Maps market price to pixel Y.
- `static double yToPrice(double y, Rect bounds, PriceRange range)`: Maps pixel Y to market price.
- `double indexToX(int index)`: Maps candle index to pixel X.
- `int xToIndex(double x)`: Maps pixel X to nearest candle index.

---

### `PriceRange`
Encapsulates minimum and maximum price boundaries.

- `PriceRange(double minPrice, double maxPrice)`
- `PriceRange.fromCandles(List<Candle> candles, {int start, int end})`: Extracts price bounds for slice.
- `PriceRange withPadding({double topPaddingPercent, double bottomPaddingPercent})`: Adds margin.
- `PriceRange applyVerticalScaleAndPan({double scale, double pan})`: Stretches or shifts price scale.

---

## 📊 Models & Enums

### `Candle`
Standard OHLCV financial bar.

```dart
class Candle {
  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  bool get isBullish => close >= open;
  double get priceChange => close - open;
  double get percentageChange => open != 0 ? (priceChange / open) * 100 : 0.0;
}
```

---

### `Tick`
Real-time market tick event.

```dart
class Tick {
  final double price;
  final double volume;
  final DateTime timestamp;
}
```

---

### `Timeframe`
Candlestick aggregation intervals.

- `Timeframe.oneMinute` (`1m`)
- `Timeframe.fiveMinutes` (`5m`)
- `Timeframe.fifteenMinutes` (`15m`)
- `Timeframe.thirtyMinutes` (`30m`)
- `Timeframe.oneHour` (`1H`)
- `Timeframe.fourHours` (`4H`)
- `Timeframe.oneDay` (`1D`)
- `Timeframe.oneWeek` (`1W`)

---

### `CandleStyle`
Visual presentation modes.

- `CandleStyle.candles` (Standard filled candles)
- `CandleStyle.hollowCandles` (Hollow bull, filled bear)
- `CandleStyle.heikinAshi` (Smoothed trend candles)
- `CandleStyle.line` (Close price polyline)
- `CandleStyle.area` (Gradient mountain chart)
- `CandleStyle.bars` (Western OHLC bars)

---

### `ChartTheme`
Design tokens and styling parameters.

- `factory ChartTheme.dark()`
- `factory ChartTheme.light()`
- `ChartTheme copyWith({...})`

---

### `ChartDrawing`
Interactive technical analysis chart drawing model.

```dart
class ChartDrawing {
  final String id;
  final DrawingTool tool;
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;
  final bool isSelected;
  final Map<String, dynamic> properties;
}
```

---

### `DrawingPoint`
Geometric anchor point stored in financial coordinates `(candleIndex, price)`.

```dart
class DrawingPoint {
  final int candleIndex;
  final double price;
  final DateTime? timestamp;
}
```

---

### `DrawingTool`
Supported drawing instruments.

- `DrawingTool.pointer` (Standard cursor)
- `DrawingTool.trendline` (2-point angled trendline)
- `DrawingTool.horizontalLine` (1-point horizontal support/resistance ray)
- `DrawingTool.rectangle` (2-point Supply/Demand box with translucent shading and 4-corner handles)
- `DrawingTool.fibonacci` (2-point Fibonacci retracement with golden ratio bands)
- `DrawingTool.longPosition` (1-point Risk:Reward box with target/stop zones)
- `DrawingTool.shortPosition` (1-point short Risk:Reward box)
- `DrawingTool.ruler` (2-point measurement ruler calculating ΔPrice, Δ%, and bar count)

---

### `ChartOrder`
Direct on-chart limit/stop order with optional connected Take Profit and Stop Loss brackets.

```dart
class ChartOrder {
  final String id;
  final String symbol;
  final OrderSide side; // OrderSide.buy or OrderSide.sell
  final OrderType type; // OrderType.limit, OrderType.stop, OrderType.market
  final double price;
  final double quantity;
  final double? takeProfitPrice;
  final double? stopLossPrice;
  final OrderStatus status; // pending, partiallyFilled, filled, cancelled, rejected
  final DateTime placedAt;
}
```

---

### `ChartPosition`
Executed open market position with real-time unrealized P&L calculation and 1-click market close.

```dart
class ChartPosition {
  final String id;
  final String symbol;
  final PositionSide side; // PositionSide.long or PositionSide.short
  final double entryPrice;
  final double quantity;
  final double? takeProfitPrice;
  final double? stopLossPrice;
  final DateTime openedAt;

  double unrealizedPnL(double currentPrice);
  double unrealizedPnLPercentage(double currentPrice);
}
```

---

### `ChartAlert`
Canvas-rendered visual price alert line with draggable threshold and trigger detection.

```dart
class ChartAlert {
  final String id;
  final String symbol;
  final double price;
  final AlertTriggerCondition condition; // crossing, crossingUp, crossingDown
  final String? message;
  final DateTime createdAt;
  final bool isTriggered;
  final bool isActive;

  bool checkTrigger(double previousPrice, double currentPrice);
}
```

---

### `VolumeProfile`
Visible Range Volume Profile calculating high-liquidity nodes, POC, and 70% Value Area.

```dart
class VolumeProfile {
  final List<VolumeProfileBin> bins;
  final double pointOfControl; // POC price
  final double valueAreaHigh;   // VAH
  final double valueAreaLow;    // VAL
  final double totalVolume;
  final double maxBinVolume;

  static VolumeProfile calculate(
    List<Candle> visibleCandles, {
    int binCount = 30,
    double valueAreaPercent = 0.70,
  });
}
```

---

## 🛠️ Utilities & Widgets

### `ChartExporter`
High-DPI retina canvas snapshot generator and preview dialog.

- `static Future<Uint8List?> captureChart(GlobalKey boundaryKey, {double pixelRatio = 2.0})`: Captures high-res PNG byte array.
- `static Future<void> showSnapshotDialog(BuildContext context, Uint8List pngBytes, {String symbol = 'CHART'})`: Displays interactive modal with download and clipboard triggers.

---

### `ReplayControlBar`
Floating glassmorphic playback control toolbar rendered during bar replay simulation.

```dart
const ReplayControlBar({
  super.key,
  required TradingChartController controller,
  VoidCallback? onExit,
});
```

---

### `ChartLayoutMode`
Defines responsive layout behavior for `TradingChart` and `ImChart`.

```dart
enum ChartLayoutMode {
  /// Automatically switches between desktop and mobile layouts based on container width (< 600px).
  auto,

  /// Forces full desktop trading terminal layout.
  desktop,

  /// Forces mobile layout with compact price axis (52px), 44px touch targets, and mobile ergonomics.
  mobile,
}
```

---

### `ChartToast`
Responsive trading terminal notification and toast system.

- Automatically positions at the **top-right** with a **fixed 350px width** on Desktop/Web (`width >= 600px`), preventing full-screen expansion.
- Automatically docks to **center-top** with **full device width** on Mobile (`width < 600px`).
- Features entrance slide/fade animations and auto-dismiss after 2.5 seconds.

```dart
// Semantic helper methods
ChartToast.success(context, 'Snapshot saved successfully', title: 'Export Complete');
ChartToast.info(context, 'Position closed: LONG 100 @ ₹24,490.00');
ChartToast.alert(context, 'Alert set at ₹24,500.00 for NIFTY 50');
ChartToast.error(context, 'Connection timeout');
ChartToast.dismiss(); // Immediately clears active toast
```



