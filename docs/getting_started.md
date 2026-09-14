# Getting Started with im_charts

Welcome to **`im_charts`** — an institutional-grade financial charting engine and professional trading terminal built specifically for Flutter (Impeller & Skia). 

`im_charts` is designed from the ground up to be **100% plug-and-play** for rapid integration, while remaining **infinitely customizable** for bespoke trading dashboards, broker terminals, and fintech apps.

> 🌐 **Interactive Web Demo**: Try `im_charts` directly in your browser at **[https://lykanimran.github.io/im_charts/](https://lykanimran.github.io/im_charts/)**!

---

## 📦 Installation

Add `im_charts` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  im_charts:
    git:
      url: https://github.com/LykanImran/im_charts.git
```

Run in terminal:

```bash
flutter pub get
```

Then import the master library:

```dart
import 'package:im_charts/im_charts.dart';
```

---

## ⚡ Quickstart: 3 Levels of Integration

### Level 1: Turnkey Trading Terminal (Zero Boilerplate)

The easiest way to embed a full TradingView-grade charting experience with interactive toolbars, symbol search, intervals, indicators, themes, and telemetry headers:

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

> **What you get out-of-the-box:**
> - Institutional 2-row toolbar (Symbol search, Interval dropdown, Candle style selector, Indicators selector, Theme toggle, Settings modal).
> - Real-time telemetry header (Ticker, NSE/BSE toggle, LTP, dynamic % change badge, live OHLCV metrics).
> - High-performance Skia/Impeller canvas with volume histogram, EMA 20, and RSI sub-pane.
> - Full gesture support (macOS trackpad pinch zoom, 2-finger pan, price scale drag, time scale drag, auto-scale reset pill).

---

### Level 2: Embedded Terminal with External Controller

If you want to control the chart from outside (e.g. from your app's bottom navigation, drawer, or external broker state):

```dart
import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

class ControlledChartPage extends StatefulWidget {
  const ControlledChartPage({super.key});

  @override
  State<ControlledChartPage> createState() => _ControlledChartPageState();
}

class _ControlledChartPageState extends State<ControlledChartPage> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;

  @override
  void initState() {
    super.initState();
    // 1. Instantiate data source
    _dataSource = MockTradingDataSource(initialPrice: 24500.0);

    // 2. Instantiate controller
    _controller = TradingChartController(
      symbol: 'RELIANCE',
      exchange: 'NSE',
      dataSource: _dataSource,
      initialTimeframe: Timeframe.fifteenMinutes,
      theme: ChartTheme.dark(),
    );

    // 3. Initialize chart & start starter indicators
    _controller.initialize().then((_) {
      if (mounted) {
        _controller.toggleIndicator(
          EMAIndicator(period: 20, color: const Color(0xFF2962FF)),
        );
      }
    });
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
      appBar: AppBar(
        title: const Text('My Broker Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.resetView(),
          ),
        ],
      ),
      body: TradingScreen(
        controller: _controller,
        showToolbar: true,
        showHeader: true,
      ),
    );
  }
}
```

---

### Level 3: Standalone Chart Canvas (Headless / Modular)

If you only need the **raw interactive chart canvas** inside a Card, Dialog, or Custom Dashboard without the default toolbar:

```dart
import 'package:flutter/material.dart';
import 'package:im_charts/im_charts.dart';

class MinimalChartCard extends StatefulWidget {
  const MinimalChartCard({super.key});

  @override
  State<MinimalChartCard> createState() => _MinimalChartCardState();
}

class _MinimalChartCardState extends State<MinimalChartCard> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(initialPrice: 100.0);
    _controller = TradingChartController(
      symbol: 'AAPL',
      dataSource: _dataSource,
      theme: ChartTheme.light(),
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
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 350,
        child: TradingChart(controller: _controller),
      ),
    );
  }
}
```

---

### Level 4: Direct On-Chart Trading & Bracket Orders

Enable the institutional hover `+` button, 1-click Limit order menus, Take Profit & Stop Loss brackets, and direct drag-to-modify order interactions:

```dart
TradingScreen(
  controller: _controller,
  enableChartTrading: true,
  onOrderPlaced: (ChartOrder order) {
    print('Order placed: ${order.side.name} ${order.quantity} @ ${order.price}');
  },
  onOrderCancelled: (String orderId) {
    print('Order cancelled: $orderId');
  },
  // Optional: Provide custom order popup menu
  orderMenuBuilder: (context, price, controller, closeMenu) {
    return AlertDialog(
      title: Text('Place Order @ $price'),
      actions: [
        TextButton(
          onPressed: () {
            controller.placeOrder(ChartOrder(
              id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
              symbol: controller.symbol,
              side: OrderSide.buy,
              price: price,
              quantity: 10,
            ));
            closeMenu();
          },
          child: const Text('Buy'),
        ),
      ],
    );
  },
)
```

---

## 🎮 Interactive Gestures Cheat Sheet

`im_charts` delivers a responsive, TradingView-identical desktop and mobile feel:

| Action | macOS / Windows Trackpad | Mouse | Mobile Touch |
| :--- | :--- | :--- | :--- |
| **Horizontal Zoom** | 2-finger pinch in / out (focal centered) | Wheel scroll over canvas | 2-finger pinch in / out |
| **Pan / Scroll in Time** | 2-finger horizontal swipe | Left click + drag on canvas | 1-finger swipe on canvas |
| **Vertical Price Scale** | Click & drag vertically on price scale | Click & drag vertically on price scale | 1-finger drag on price scale |
| **Time Axis Zoom** | Click & drag on bottom time scale | Click & drag on bottom time scale | 1-finger drag on time scale |
| **Reset Auto-Scale** | Double-tap price scale or click `AUTO` pill | Double-tap price scale or click `AUTO` pill | Tap `AUTO` badge or double-tap scale |
| **Crosshair Inspection** | Move cursor over chart | Move cursor over chart | Long-press and drag |
| **Hover Order '+' Button** | Move cursor near right price axis | Move cursor near right price axis | Long-press crosshair |
| **Drag-to-Modify Price** | Drag order / TP / SL badge up/down | Drag order / TP / SL badge up/down | Drag badge up/down |
| **Quick Order Cancel** | Click `✖` at right end of badge | Click `✖` at right end of badge | Tap `✖` on badge |

---

## 📖 Deep Dive Documentation

Continue exploring the documentation:

1. **[Architecture & Engine Internals](architecture.md)** — Learn how the Skia/Impeller pipeline, coordinate math, and pan-zoom engines function.
2. **[Data Sources & Real-time Feeds](data_sources.md)** — Connect WebSockets, REST APIs, Zerodha Kite, Binance, or custom broker backends.
3. **[Customization Guide](customization.md)** — Custom themes, palettes, typography, candle styling, and modular layouts.
4. **[Technical Indicators](indicators.md)** — Using built-in indicators and authoring your own custom indicators.
5. **[API Reference](api_reference.md)** — Complete, class-by-class technical reference for all public APIs.
