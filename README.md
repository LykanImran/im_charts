# im_charts

A high-performance financial charting engine and professional trading terminal for Flutter, built for institutional-grade responsiveness on Impeller and Skia.

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Features

- **Institutional 2-Row Terminal Layout**:
  - **Row 1 (Primary Tools)**: Symbol Search Dialog (`⌘K`), Interval Dropdown (`1m` - `1W`), Candle Style Dropdown, Technical Indicators Dropdown (`fx`), Real-time Refresh, Theme Toggle (Dark/Light), Chart Settings Modal.
  - **Row 2 (Market Telemetry)**: Live Ticker, Segmented Exchange Switcher (`[ NSE | BSE ]`), LTP with real-time dynamic color pulse, high-density OHLC telemetry strip, and viewport controls.
- **6 Chart Presentation Styles**: Standard Candlesticks, Hollow Candles, Heikin Ashi, Line Chart, Area Mountain Chart, and OHLC Tick Bars.
- **Integrated Technical Indicators**:
  - Overlays: Exponential Moving Averages (EMA 20, EMA 50), Bollinger Bands (20, 2).
  - Sub-panes: Relative Strength Index (RSI 14) with dynamic 70/30 threshold bounds.
  - Volume Histogram with auto-scaling.
- **Pure Flutter Architecture**: Direct canvas rendering (`CustomPainter`) with zero widget overhead for 60/120 FPS panning, pinch-to-zoom, and crosshair tracking.

---

## 🚀 Getting Started

Add `im_charts` to your `pubspec.yaml`:

```yaml
dependencies:
  im_charts:
    git:
      url: https://github.com/LykanImran/im_charts.git
```

---

## 💻 Quick Start

### 1. Turnkey Trading Terminal

For an immediate out-of-the-box trading terminal experience:

```dart
import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TradingScreen(
        initialSymbol: 'NIFTY 50',
        initialExchange: 'NSE',
        initialTimeframe: Timeframe.fiveMinutes,
      ),
    );
  }
}
```

---

### 2. Custom Layout & Modular Controller

You can also use the modular individual components:

```dart
import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

class CustomTradingView extends StatefulWidget {
  const CustomTradingView({super.key});

  @override
  State<CustomTradingView> createState() => _CustomTradingViewState();
}

class _CustomTradingViewState extends State<CustomTradingView> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(initialPrice: 24520.0);
    _controller = TradingChartController(
      symbol: 'NIFTY 50',
      dataSource: _dataSource,
      initialTimeframe: Timeframe.fiveMinutes,
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ChartToolbar(controller: _controller),
            ChartHeader(controller: _controller),
            Expanded(
              child: TradingChart(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 📱 Running the Example

An example app is included in the `example/` directory:

```bash
cd example
flutter run
```

---

## 🛠 Supported Platforms

- Android
- iOS
- macOS
- Web
- Windows
- Linux
