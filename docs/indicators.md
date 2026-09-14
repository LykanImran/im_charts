# Technical Indicators Guide

`im_charts` features an extensible indicator computing and rendering pipeline. Indicators calculate technical data series and render either directly **over the candlestick canvas** (overlays) or in a **dedicated sub-pane** with an independent scale (sub-panes).

---

## 📈 Built-in Indicators

### 1. Exponential Moving Average (`EMAIndicator`)
A trend-following momentum indicator giving higher weight to recent prices:

```dart
// 20-period Fast Trend EMA
final ema20 = EMAIndicator(
  period: 20,
  color: const Color(0xFF2962FF),
);

// 50-period Slow Trend EMA
final ema50 = EMAIndicator(
  period: 50,
  color: const Color(0xFFE91E63),
);

controller.toggleIndicator(ema20);
```

---

### 2. Bollinger Bands (`BollingerBandsIndicator`)
A volatility indicator computing upper, middle (SMA 20), and lower bands based on standard deviations:

```dart
final bb = BollingerBandsIndicator(
  period: 20,
  multiplier: 2.0,
  middleColor: const Color(0xFFFF9800),
  bandColor: const Color(0x33FF9800),
);

controller.toggleIndicator(bb);
```

---

### 3. Relative Strength Index (`RSIIndicator`)
A bounded oscillator (0 to 100) measuring the speed and change of price movements:

```dart
final rsi = RSIIndicator(
  period: 14,
  color: const Color(0xFFAB47BC),
  overbought: 70.0,
  oversold: 30.0,
);

// Opens a dedicated 25% height sub-pane below the main chart
controller.toggleIndicator(rsi);
```

---

## ✍️ Authoring Custom Technical Indicators

Creating a custom indicator in `im_charts` is straightforward. Simply extend [`Indicator`](file:///Users/princeraj/Storage%20Drive/Files/Projects/charts/im_charts/lib/engine/indicators/indicator.dart) and implement `calculate(List<Candle> candles)`.

### Example: Simple Moving Average (SMA) Overlay

```dart
import 'dart:ui';
import 'package:im_charts/im_charts.dart';

class SMAIndicator extends Indicator {
  final int period;
  final Color color;

  SMAIndicator({
    this.period = 20,
    this.color = const Color(0xFFFFD600),
  });

  @override
  String get id => 'SMA_$period';

  @override
  String get name => 'SMA ($period)';

  @override
  bool get isOverlay => true; // true = renders on main chart

  @override
  IndicatorResult calculate(List<Candle> candles) {
    if (candles.isEmpty || candles.length < period) {
      return IndicatorResult(id: id, isOverlay: true, lines: []);
    }

    final values = <double?>[];

    for (int i = 0; i < candles.length; i++) {
      if (i < period - 1) {
        values.add(null); // Insufficient historical data
      } else {
        double sum = 0.0;
        for (int j = 0; j < period; j++) {
          sum += candles[i - j].close;
        }
        values.add(sum / period);
      }
    }

    return IndicatorResult(
      id: id,
      isOverlay: true,
      lines: [
        IndicatorLine(
          name: name,
          values: values,
          color: color,
          strokeWidth: 1.5,
        ),
      ],
    );
  }
}
```

Now activate your custom indicator:

```dart
controller.toggleIndicator(SMAIndicator(period: 10, color: Colors.amber));
```

---

### Example: Bounded Sub-Pane Oscillator

For indicators like Williams %R or Stochastic that require their own fixed scale:

```dart
class WilliamsRIndicator extends Indicator {
  final int period;

  WilliamsRIndicator({this.period = 14});

  @override
  String get id => 'WILLR_$period';

  @override
  String get name => '%R ($period)';

  @override
  bool get isOverlay => false; // false = renders in sub-pane below candles

  @override
  double? get fixedMin => -100.0;

  @override
  double? get fixedMax => 0.0;

  @override
  IndicatorResult calculate(List<Candle> candles) {
    // Calculate %R series ...
    return IndicatorResult(
      id: id,
      isOverlay: false,
      fixedMin: fixedMin,
      fixedMax: fixedMax,
      lines: [...],
    );
  }
}
```

---

## 🎛️ Controlling Indicators via Controller API

```dart
// Check if an indicator is currently active
bool isActive = controller.isIndicatorActive('EMA_20');

// Toggle (add if absent, remove if present)
controller.toggleIndicator(myIndicator);

// Explicit add / remove
controller.addIndicator(myIndicator);
controller.removeIndicator('EMA_20');

// Inspect active indicator instances
List<Indicator> activeList = controller.activeIndicators;
```
