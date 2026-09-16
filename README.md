<p align="center">
  <img src="https://raw.githubusercontent.com/LykanImran/im_charts/main/doc/assets/im_charts_banner.jpg" alt="Im Charts - Institutional Financial Charting Engine for Flutter" width="100%" />
</p>

# Im Charts (`im_charts`)

<p align="center">
  <a href="https://pub.dev/packages/im_charts"><img src="https://img.shields.io/pub/v/im_charts.svg" alt="Pub Version" /></a>
  <a href="https://pub.dev/packages/im_charts/score"><img src="https://img.shields.io/pub/points/im_charts" alt="Pub Points" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.24%2B-blue.svg" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.5%2B-0175C2.svg" alt="Dart" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android%20%7C%20Web-4E9A06.svg" alt="Platforms" /></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT" /></a>
  <a href="https://github.com/LykanImran/im_charts/actions"><img src="https://github.com/LykanImran/im_charts/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
</p>

<p align="center">
  <a href="https://lykanimran.github.io/im_charts/"><img src="https://img.shields.io/badge/Live_Web_Demo-Explore_Im_Charts-2962FF?style=for-the-badge&logo=googlechrome&logoColor=white" alt="Live Web Demo" /></a>
</p>

> 🌐 **Live Interactive Web Showcase**: **[https://lykanimran.github.io/im_charts/](https://lykanimran.github.io/im_charts/)**
> 
> Explore all 8 interactive modes directly in your browser without installing anything (Full Institutional Terminal, Direct Chart Trading with Brackets & Positions, Drawing Engine with 8-Handle Shape Resizing, Clean Headless Canvas, Dual Multi-Chart Grid, Theme Lab, and Embedded Portfolio Card).

**Im Charts** is an institutional-grade financial charting engine and professional trading terminal for **Flutter**, engineered from the ground up for high-frequency responsiveness on **Impeller** and **Skia**.

Designed to be **100% plug-and-play** out-of-the-box, while remaining **deeply customizable** for brokers, fintech platforms, crypto exchanges, and algorithmic trading interfaces.

---

## 📚 Master Documentation Index

Comprehensive guides and architectural deep-dives are located in the [`doc/`](doc/) directory:

| Guide | Description |
| :--- | :--- |
| 🚀 **[Getting Started](doc/getting_started.md)** | Installation, 3-minute plug & play, and integration patterns for Im Charts. |
| 🏛️ **[Architecture & Internals](doc/architecture.md)** | Skia/Impeller rendering pipeline, coordinate projections, and gesture routing. |
| 🔌 **[Data Sources & Real-Time Feeds](doc/data_sources.md)** | Connecting WebSockets, REST APIs, Binance, Zerodha Kite, and live tick aggregation. |
| 🎨 **[Customization & Theming](doc/customization.md)** | Custom themes (`ChartTheme`), candle presentation styles, and layout sizing. |
| 📈 **[Technical Indicators Guide](doc/indicators.md)** | Built-in indicators (EMA, SMA, Supertrend, Bollinger Bands, VWAP, MACD, RSI, Volume Profile VRVP) and writing custom indicators. |
| 📖 **[API Reference](doc/api_reference.md)** | Detailed documentation for all classes, methods, models, and enums. |
| 🤝 **[Contributing Guide](CONTRIBUTING.md)** | Development environment setup, running test suites, and PR submission guide. |

---

## ✨ Key Features

- **⚡ Institutional 2-Row Terminal Layout**:
  - **Row 1 (Primary Toolbar)**: Symbol Search Dialog (`⌘K`), Interval Dropdown (`1m` to `1W`), Candle Style Dropdown, Technical Indicators Selector (`fx`), Bar Replay Simulator (`⏮`), High-DPI Camera Snapshot (`📷`), Keyboard Shortcuts Cheatsheet (`⌨️`), Real-time Refresh, Dark/Light Theme Toggle, and Chart Settings Modal.
  - **Row 2 (Floating Telemetry Header)**: Glassmorphic overlay displaying Live Ticker, Exchange Badge (displays whatever exchange is passed), LTP with real-time dynamic color pulse, and high-density OHLCV telemetry strip.
- **🕯️ 6 Candlestick Presentation Styles**:
  - Standard Candlesticks, Hollow Candles, Heikin Ashi, Line Chart, Area Mountain Chart, and Western OHLC Tick Bars.
- **📈 Integrated Technical Indicators & Volume Profile**:
  - **⭐ Smart Money Concepts (SMC)**: Institutional price action engine auto-detecting **Fair Value Gaps (FVG)** with 50% Consequent Encroachment (CE) dashed midlines and mitigation tracking, **Break of Structure (BOS)** and **Change of Character (CHoCH)** fractal swing breaks, and institutional **Order Blocks (OB Demand/Supply)** directly on the Skia/Impeller canvas.
  - **⭐ Viral & High-Demand Indicators**: **Stochastic Oscillator** (14, 3, 3), **Parabolic SAR** (0.02, 0.2), **Chandelier Exit** (ATR trailing stop), **Average True Range (ATR 14)**, **Williams %R**, **Commodity Channel Index (CCI 20)**, and **Ichimoku Cloud** (9, 26, 52).
  - **⭐ Categorized & Starred Indicator Menu**: Indicators organized by `⭐ VIRAL & POPULAR`, `TREND & OVERLAYS`, `MOMENTUM & OSCILLATORS`, and `CUSTOM FORMULAS` with gold star badges and vibrant tags (`VIRAL`, `HOT`, `PRO`, `POPULAR`).
  - **Overlays**: Exponential Moving Averages (EMA 20, EMA 50), Simple Moving Average (SMA 20), **Supertrend Indicator** (ATR-based trend bands with green/red buy/sell directional shifts), Bollinger Bands (20, 2), Volume Weighted Average Price (**VWAP** with intraday session boundary reset and $\pm 2.0\sigma$ standard deviation volatility envelope bands).
  - **Visible Range Volume Profile (VRVP)**: Real-time volume profile over currently visible bars with Point of Control (POC), 70% Value Area High (VAH) and Value Area Low (VAL) dashed bounds, and color-coded buy/sell horizontal volume bars.
  - **Stacked Multi-SubPanes**: Simultaneously run multiple oscillators (e.g. **RSI 14**, **MACD 12, 26, 9**, **Stochastic**, **ATR**, **Williams %R**) stacked below the chart, each with auto-scaled coordinate spaces, dynamic zero-baseline histograms, and individual close buttons.
  - **Volume**: Real-time auto-scaled volume histogram.
- **↩️ Undo / Redo History Stack (`Ctrl+Z` / `Ctrl+Y` / `⌘Z` / `⌘Shift+Z`)**:
  - Full transactional history for drawings (creation, movement, resizing, color/width changes, and deletion).
- **🧲 Magnet Mode (Snap to OHLC)**:
  - Snap drawing anchors automatically to the nearest candle's Open, High, Low, or Close price wicks and bodies.
- **💾 JSON Serialization & Cloud Sync**:
  - Complete `toJson()` and `fromJson()` serialization on `ChartDrawing`, `DrawingPoint`, `ChartAlert`, and `ChartOrder` with `controller.exportDrawingsJson()` and `controller.importDrawingsJson()`.
- **🔔 Visual Price Alerts (`ChartAlert`)**:
  - Direct canvas amber dashed alert lines with draggable price levels.
  - Ticker alert pill on the vertical price scale (`🔔 ₹...`).
  - Integration with the hover `+` button dropdown (`🔔 Add Alert @ ₹...`).
  - Customizable trigger conditions (`crossing`, `crossingUp`, `crossingDown`) and reactive callbacks.
- **🖐️ TradingView-Identical Multi-Zone Interactions**:
  - **Native macOS / Windows Trackpad Pinch Zoom**: Focal-anchored horizontal zoom without emulation lag.
  - **2-Finger Trackpad Pan**: Smooth horizontal time scrolling.
  - **Price Scale Drag**: Stretch and compress price vertically with interactive `AUTO` scale reset badge.
  - **Time Scale Drag**: Dynamic timeframe scaling via bottom time axis drag.
- **⌨️ Keyboard Shortcuts & Hotkeys**:
  - `Ctrl + Z` / `⌘ + Z`: Undo last drawing action.
  - `Ctrl + Y` / `⌘ + Shift + Z`: Redo drawing action.
  - `Alt + H`: Quick-draw Horizontal Ray / Support & Resistance line at cursor.
  - `Alt + T`: Quick-draw Trendline.
  - `Alt + A`: Open instant Alert modal at hovered price.
  - `Alt + R`: Reset chart zoom and scaling to auto.
  - `Delete` / `Backspace`: Remove selected drawing or order.
  - `Left / Right Arrow`: Pan horizontally across historical time.
  - `+ / -`: Zoom in and zoom out.
  - `Escape`: Cancel active tool or dismiss overlays.
- **⏮️ Bar Replay / Backtesting Simulator**:
  - Cut historical candles back to any chosen point in time.
  - Step forward bar-by-bar or step backward.
  - Automated continuous playback with speed multipliers (`1x`, `2x`, `3x`, `5x`).
  - Floating glassmorphic control bar (`ReplayControlBar`) with instant exit button.
- **📷 High-DPI Chart Snapshot & CSV Export (`ChartExporter`)**:
  - High-resolution 2.0x retina PNG image rendering via `RepaintBoundary`.
  - Built-in preview modal dialog with direct download and clipboard copy capabilities.
  - `ChartExporter.exportCandlesToCsv(candles)` for algorithmic backtesting data export.
- **🎯 Direct On-Chart Trading, Orders & Open Positions**:
  - **Hover `+` Button**: Cursor-tracking `+` button rendered right before the vertical price axis.
  - **1-Click Order Execution**: Dropdown menu for Limit Buy, Limit Sell, and Brackets with support for custom consuming UI (`orderMenuBuilder`).
  - **Dotted Skia/Impeller Order Lines**: Green for Buy, Red for Sell, with real-time pill badges showing side, quantity, and limit price.
  - **Connected TP & SL Brackets**: Dedicated Take Profit (Cyan) and Stop Loss (Orange) dashed lines with vertical elbow connector arms.
  - **Drag-to-Modify**: Drag badges directly on the chart canvas to dynamically update order and bracket prices in real time.
  - **Executed Open Positions & Live P&L**: Skia/Impeller solid position lines with real-time unrealized P&L and percentage badge (`[LONG 100 @ ₹24,490.00 | +₹1,250.00 (+1.25%) | ✖ Close]`), attached TP/SL bracket arms, and 1-click market close button (`✖ Close`).
  - **Tabbed Ledger Drawer**: Interactive slide-over ledger tracking pending Orders and active Positions with 1-click cancellations and market exits.
  - **Lifecycle Callbacks**: Comprehensive `onOrderPlaced`, `onOrderModified`, `onOrderCancelled`, `onPositionOpened`, and `onPositionClosed` hooks.
- **📐 TradingView-Standard Drawing Instruments & Floating Action Bar**:
  - **10 Analysis Tools**: **Trendline** (with angle/delta badge), **Horizontal Line**, **Horizontal Ray** (infinite right breakout level), **Vertical Line** (time/event marker), **Rectangle** (Supply & Demand / SMC order block zone box with translucent fill and 8 corner/edge resize handles), **Fibonacci Retracement** (golden ratio bands), **Long Position** (interactive target & stop handles), **Short Position**, **Measure Ruler** (ΔPrice, Δ%, bar count), and **Cursor Pointer**.
  - **Dual Creation Gestures**: Supports both **Click-and-Drag** (drag & release) and **Click-Move-Click** (anchor 1 $\rightarrow$ hover $\rightarrow$ anchor 2).
  - **Interactive Anchor Handles**: Selected drawings display circular grab handles to modify individual coordinates or target/stop boundaries.
  - **Drag-to-Move**: Click & drag the body of any drawing to translate it smoothly across candles and price levels.
  - **Floating Action Bar**: Glassmorphic floating menu for selected drawings featuring 1-tap color swatches (Blue, Emerald, Crimson, Amber, Purple, White), stroke thickness (1–4px), lock/unlock, and delete (`🗑️`).
  - **Financial Coordinate Anchoring**: Stored in `(candleIndex, price)` to stay mathematically pinned across zoom, pan, and live tick streaming.
- **⏱️ Live Candle Close Countdown Timer & Watermark**:
  - **Countdown Timer Badge**: Live ticking badge on the vertical price axis showing exact time remaining before the active bar closes (e.g. `04:18`).
  - **Background Canvas Watermark**: Bold institutional typography featuring brand name (`IM CHARTS • NIFTY 50 • 5m • NSE`) rendered in the background pane at 4.5% opacity.
  - **Price Beacon Pulse Dot**: Radiant pulsing beacon tracking the active candle close price on canvas.
- **🚀 Skia & Impeller Direct Canvas Rendering**:
  - Zero widget overhead: Entire chart renders via a single, isolated `CustomPainter` with boundary clipping.

---

## ⚡ 3-Minute Plug & Play Quickstart

### 1. Add Dependency

Add to your Flutter project via terminal:

```bash
flutter pub add im_charts
```

Or add directly to `pubspec.yaml`:

```yaml
dependencies:
  im_charts: ^0.1.0
```

### 2. Run the Turnkey Trading Terminal

Drop `TradingScreen` (or `ImTradingScreen`) anywhere in your widget tree:

```dart
import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

void main() => runApp(const MaterialApp(home: TradingTerminalPage()));

class TradingTerminalPage extends StatelessWidget {
  const TradingTerminalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: TradingScreen(
        initialSymbol: 'NIFTY 50',
        initialExchange: 'NSE',
        initialTimeframe: Timeframe.fiveMinutes,
        initialCandleStyle: CandleStyle.candles,
      ),
    );
  }
}
```

### 3. Ultra-Easy Zero-Boilerplate Chart (`ImChart.simple`)

If you already have a list of candles or JSON data from your backend/broker API, render an institutional interactive chart in **just 3 lines of code**:

```dart
import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

class QuickChartCard extends StatelessWidget {
  final List<Candle> myCandles;
  const QuickChartCard({super.key, required this.myCandles});

  @override
  Widget build(BuildContext context) {
    return ImChart.simple(
      candles: myCandles,
      indicators: [
        EMAIndicator(period: 20, color: const Color(0xFF2962FF)),
      ],
      onOrderModified: (order) {
        // Called whenever an order line or TP/SL bracket is dragged on canvas!
        print('Updated order ${order.id} to ₹${order.price}');
      },
    );
  }
}
```

Or stream live WebSocket ticks with zero controller boilerplate:

```dart
ImChart.live(
  candles: initialCandles,
  liveTickStream: myWebSocketStream, // Stream<Tick>
  symbol: 'BTC/USDT',
);
```

---

## 🎮 Interactive Gestures Cheat Sheet

| Interaction | macOS / Windows Trackpad | Mouse | Mobile Touch |
| :--- | :--- | :--- | :--- |
| **Horizontal Zoom** | 2-finger pinch in / out | Mouse wheel scroll over canvas | 2-finger pinch in / out |
| **Pan in Time** | 2-finger horizontal swipe | Left click + drag on canvas | 1-finger swipe on canvas |
| **Vertical Price Scale** | Drag vertically on right price axis | Drag vertically on right price axis | Drag vertically on price axis |
| **Time Scale Zoom** | Drag on bottom time axis | Drag on bottom time axis | Drag on bottom time axis |
| **Reset Auto-Scale** | Double-tap price axis or tap `AUTO` pill | Double-tap price axis or tap `AUTO` pill | Tap `AUTO` badge |
| **Crosshair Inspection** | Hover cursor over canvas | Hover cursor over canvas | Long-press and drag |

---

## 🧩 Modular & Headless Usage (Clean Chart Without Top Header)

`im_charts` can be used either as a turnkey terminal or in a clean / headless configuration without the top header or toolbar:

```dart
// Option A: Turnkey terminal with custom header/toolbar toggles
TradingScreen(
  initialSymbol: 'NIFTY 50',
  showToolbar: false, // Omit top toolbar
  showHeader: false,  // Omit top telemetry header (pure clean canvas)
)
```

```dart
// Option B: Direct standalone canvas embedding in cards or dialogs
import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

class CustomDashboardCard extends StatefulWidget {
  const CustomDashboardCard({super.key});

  @override
  State<CustomDashboardCard> createState() => _CustomDashboardCardState();
}

class _CustomDashboardCardState extends State<CustomDashboardCard> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(initialPrice: 24500.0);
    _controller = TradingChartController(
      symbol: 'RELIANCE',
      dataSource: _dataSource,
      theme: ChartTheme.dark(),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 380,
        child: TradingChart(controller: _controller),
      ),
    );
  }
}
```

---

## 🎨 Instant Customization

Override colors, typography, or styling with `ChartTheme.copyWith(...)`:

```dart
final customTheme = ChartTheme.dark().copyWith(
  backgroundColor: const Color(0xFF0F141C),
  bullishColor: const Color(0xFF00E676),
  bearishColor: const Color(0xFFFF1744),
  gridColor: const Color(0xFF1B222D),
  currentPriceLineColor: const Color(0xFF2962FF),
);

// Apply directly
controller.setTheme(customTheme);
```

---

## 🧪 Interactive Showcase Hub & Runnable Example

🌐 **Live Web Demo**: **[https://lykanimran.github.io/im_charts/](https://lykanimran.github.io/im_charts/)**

A complete multi-mode showcase application is provided in the [`example/`](example/) directory:

```bash
# Run the example showcase locally on macOS, Web, iOS, or Android
cd example
flutter run
```

### Showcase Modes Included in `example/`:
1. **💡 Dashboard Hub**: Interactive catalog overview explaining every possibility with quick-launch triggers.
2. **🚀 Full Institutional Terminal**: Turnkey TradingView-grade setup with 2-row toolbars, technical indicators, and symbol search.
3. **🎯 Clean / Headless Chart**: Clean chart version with **no top header or toolbar**, maximizing canvas space.
4. **📊 Dual Multi-Chart Grid**: Synchronized side-by-side live charting engines (NIFTY 50 5m vs BANKNIFTY 15m).
5. **🎨 Custom Themes & Styles Lab**: Live dynamic switching between Cyberpunk, Bloomberg Amber, Dark, and Light themes + 6 candle styles.
6. **📱 Embedded Analytics Card**: Wealth-tech KPI card embedding a 320px area chart with quick timeframe filters.
7. **📈 Direct Chart Trading & Brackets**: Limit, Stop & Bracket orders with direct canvas drag-to-modify, SL/TP levels, and position overlay.
8. **✏️ Drawing Engine & 8-Handle Shape Resizing**: TradingView-standard drawing instruments (Trendlines, Horizontal lines with direct vertical drag, 8-handle Rectangle supply/demand boxes, Fibonacci, Long/Short position boxes, and Measure ruler).

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
