# im_charts

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5%2B-0175C2.svg)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20iOS%20%7C%20Android%20%7C%20Web-4E9A06.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/Tests-62%2F62%20Passed-brightgreen.svg)](test/)
[![Live Web Demo](https://img.shields.io/badge/Live_Web_Demo-Explore_im__charts-2962FF?style=for-the-badge&logo=googlechrome&logoColor=white)](https://lykanimran.github.io/im_charts/)

> 🌐 **Live Interactive Web Showcase**: **[https://lykanimran.github.io/im_charts/](https://lykanimran.github.io/im_charts/)**
> 
> Explore all 7 interactive modes directly in your browser without installing anything (Full Institutional Terminal, Direct Chart Trading with Brackets & Positions, Clean Headless Canvas, Dual Multi-Chart Grid, Theme Lab, and Embedded Portfolio Card).

An institutional-grade financial charting engine and professional trading terminal for **Flutter**, engineered from the ground up for high-frequency responsiveness on **Impeller** and **Skia**.

Designed to be **100% plug-and-play** out-of-the-box, while remaining **deeply customizable** for brokers, fintech platforms, crypto exchanges, and algorithmic trading interfaces.

---

## 📚 Master Documentation Index

Comprehensive guides and architectural deep-dives are located in the [`docs/`](docs/) directory:

| Guide | Description |
| :--- | :--- |
| 🚀 **[Getting Started](docs/getting_started.md)** | Installation, 3-minute plug & play, and integration patterns. |
| 🏛️ **[Architecture & Internals](docs/architecture.md)** | Skia/Impeller rendering pipeline, coordinate projections, and gesture routing. |
| 🔌 **[Data Sources & Real-Time Feeds](docs/data_sources.md)** | Connecting WebSockets, REST APIs, Binance, Zerodha Kite, and live tick aggregation. |
| 🎨 **[Customization & Theming](docs/customization.md)** | Custom themes (`ChartTheme`), candle presentation styles, and layout sizing. |
| 📈 **[Technical Indicators Guide](docs/indicators.md)** | Built-in indicators (EMA, Bollinger Bands, VWAP, MACD, RSI, Volume Profile VRVP) and writing custom indicators. |
| 📖 **[API Reference](docs/api_reference.md)** | Detailed documentation for all classes, methods, models, and enums. |

---

## ✨ Key Features

- **⚡ Institutional 2-Row Terminal Layout**:
  - **Row 1 (Primary Toolbar)**: Symbol Search Dialog (`⌘K`), Interval Dropdown (`1m` to `1W`), Candle Style Dropdown, Technical Indicators Selector (`fx`), Bar Replay Simulator (`⏮`), High-DPI Camera Snapshot (`📷`), Keyboard Shortcuts Cheatsheet (`⌨️`), Real-time Refresh, Dark/Light Theme Toggle, and Chart Settings Modal.
  - **Row 2 (Floating Telemetry Header)**: Glassmorphic overlay displaying Live Ticker, Exchange Badge (displays whatever exchange is passed), LTP with real-time dynamic color pulse, and high-density OHLCV telemetry strip.
- **🕯️ 6 Candlestick Presentation Styles**:
  - Standard Candlesticks, Hollow Candles, Heikin Ashi, Line Chart, Area Mountain Chart, and Western OHLC Tick Bars.
- **📈 Integrated Technical Indicators & Volume Profile**:
  - **Overlays**: Exponential Moving Averages (EMA 20, EMA 50), Bollinger Bands (20, 2), Volume Weighted Average Price (**VWAP** with intraday session boundary reset and $\pm 2.0\sigma$ standard deviation volatility envelope bands).
  - **Visible Range Volume Profile (VRVP)**: Real-time volume profile over currently visible bars with Point of Control (POC), 70% Value Area High (VAH) and Value Area Low (VAL) dashed bounds, and color-coded buy/sell horizontal volume bars.
  - **Stacked Multi-SubPanes**: Simultaneously run multiple oscillators (e.g. **RSI 14** and **MACD 12, 26, 9**) stacked below the chart, each with auto-scaled coordinate spaces, dynamic zero-baseline histograms, and individual close buttons.
  - **Volume**: Real-time auto-scaled volume histogram.
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
- **📷 High-DPI Chart Snapshot & Export (`ChartExporter`)**:
  - High-resolution 2.0x retina PNG image rendering via `RepaintBoundary`.
  - Built-in preview modal dialog with direct download and clipboard copy capabilities.
- **🎯 Direct On-Chart Trading, Orders & Open Positions**:
  - **Hover `+` Button**: Cursor-tracking `+` button rendered right before the vertical price axis.
  - **1-Click Order Execution**: Dropdown menu for Limit Buy, Limit Sell, and Brackets with support for custom consuming UI (`orderMenuBuilder`).
  - **Dotted Skia/Impeller Order Lines**: Green for Buy, Red for Sell, with real-time pill badges showing side, quantity, and limit price.
  - **Connected TP & SL Brackets**: Dedicated Take Profit (Cyan) and Stop Loss (Orange) dashed lines with vertical elbow connector arms.
  - **Drag-to-Modify**: Drag badges directly on the chart canvas to dynamically update order and bracket prices in real time.
  - **Executed Open Positions & Live P&L**: Skia/Impeller solid position lines with real-time unrealized P&L and percentage badge (`[LONG 100 @ ₹24,490.00 | +₹1,250.00 (+1.25%) | ✖ Close]`), attached TP/SL bracket arms, and 1-click market close button (`✖ Close`).
  - **Tabbed Ledger Drawer**: Interactive slide-over ledger tracking pending Orders and active Positions with 1-click cancellations and market exits.
  - **Lifecycle Callbacks**: Comprehensive `onOrderPlaced`, `onOrderModified`, `onOrderCancelled`, `onPositionOpened`, and `onPositionClosed` hooks.
- **📐 Left Drawing Tools Bar**:
  - Left-docked professional toolbar with 7 analysis instruments: **Trendline** (2 anchor clicks), **Horizontal Ray** (support/resistance with price badge), **Fibonacci Retracement** (golden ratio bands: 0.0, 0.236, 0.382, 0.500, 0.618, 0.786, 1.0), **Long Position** (Risk:Reward box with green target and red stop zones), **Short Position** (Risk:Reward box), and **Measure Ruler** (ΔPrice, Δ%, bar count).
  - Financial coordinate anchoring `(candleIndex, price)` ensures drawings remain locked across horizontal zoom, pan, and real-time tick streaming.
- **⏱️ Live Candle Close Countdown Timer & Watermark**:
  - **Countdown Timer Badge**: Live ticking badge on the vertical price axis showing exact time remaining before the active bar closes (e.g. `04:18`).
  - **Background Canvas Watermark**: Bold institutional typography (`NIFTY 50 • 5m • NSE`) rendered in the background pane at 4.5% opacity.
  - **Price Beacon Pulse Dot**: Radiant pulsing beacon tracking the active candle close price on canvas.
- **🚀 Skia & Impeller Direct Canvas Rendering**:
  - Zero widget overhead: Entire chart renders via a single, isolated `CustomPainter` with boundary clipping.

---

## ⚡ 3-Minute Plug & Play Quickstart

### 1. Add Dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  im_charts:
    git:
      url: https://github.com/LykanImran/im_charts.git
```

### 2. Run the Turnkey Trading Terminal

Drop [`TradingScreen`](file:///Users/princeraj/Storage%20Drive/Files/Projects/charts/im_charts/lib/ui/trading_screen.dart) anywhere in your widget tree:

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

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
