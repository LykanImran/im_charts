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

---

### 3. Volume Weighted Average Price (`VWAPIndicator`)
An intraday benchmark overlay tracking the volume-weighted average price across daily trading sessions, equipped with $\pm 2.0\sigma$ standard deviation volatility envelope bands:

```dart
final vwap = VWAPIndicator(
  multiplier: 2.0,
  vwapColor: const Color(0xFFFFD600), // Vibrant gold benchmark line
  bandColor: const Color(0x1A2962FF), // Soft blue volatility fill
  bandLineColor: const Color(0x802962FF),
);

controller.toggleIndicator(vwap);
```
- **Intraday Session Boundary Reset**: Automatically resets cumulative volume and typical price $\frac{H + L + C}{3} \times V$ when crossing into a new trading day.
- **Volatility Envelope**: Computes standard deviation $\sigma = \sqrt{\frac{\sum V \cdot (TP - VWAP)^2}{\sum V}}$ with upper and lower boundary bands.

---

### 4. Moving Average Convergence Divergence (`MACDIndicator`)
A momentum oscillator calculating the difference between Fast and Slow Exponential Moving Averages, accompanied by a Signal EMA and zero-baseline histogram:

```dart
final macd = MACDIndicator(
  fastPeriod: 12,
  slowPeriod: 26,
  signalPeriod: 9,
  macdColor: const Color(0xFF2962FF),   // Blue MACD line
  signalColor: const Color(0xFFFF6D00), // Orange signal line
);

// Opens a dedicated auto-scaled sub-pane below the chart
controller.toggleIndicator(macd);
```
- **MACD Line**: $EMA_{12}(Close) - EMA_{26}(Close)$
- **Signal Line**: $EMA_9(MACD)$
- **Histogram**: Dynamic green (`#089981` / positive) and red (`#F23645` / negative) vertical bars rendered outward from the horizontal $0.0$ baseline level.

---

### 5. Relative Strength Index (`RSIIndicator`)
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

### 6. Visible Range Volume Profile (`VolumeProfile` / VRVP)
An institutional order flow indicator that calculates and visualizes volume distribution strictly over the currently visible price action bars. It identifies high-liquidity zones, fair value areas, and critical price magnets:

```dart
// Calculate volume profile over visible candles
final profile = VolumeProfile.calculate(
  visibleCandles,
  binCount: 30,             // Number of horizontal price brackets
  valueAreaPercent: 0.70,   // Standard 70% Value Area threshold
);

// Toggle directly via the chart controller
controller.toggleVolumeProfile();
```

#### Key Components:
- **Point of Control (POC)**: The single horizontal price bin that traded the highest total volume. Rendered as a solid, high-visibility crimson red line across the viewport with an interactive `POC ₹...` pill badge.
- **Value Area High (VAH) & Value Area Low (VAL)**: Upper and lower price bounds enclosing exactly 70% of all traded volume in the visible range. Drawn with subtle dashed reference lines and price tags.
- **Buy / Sell Volume Breakdown**: Every horizontal bin decomposes volume into bullish (close $\ge$ open) and bearish (close $<$ open) sub-segments painted on the right side of the canvas.
- **Dynamic Recalculation**: Automatically updates as the trader pans, zooms, or streams new candles into view.

---

### 7. Smart Money Concepts (`SmartMoneyConcepts` / SMC)
The industry standard institutional price action engine:
- **Fair Value Gaps (FVG)**: 3-candle imbalance zones with 50% Consequent Encroachment (CE) dashed midlines. Traces mitigation dynamically when future prices penetrate the imbalance.
- **Break of Structure (BOS) & Change of Character (CHoCH)**: Fractal swing high/low break detection with labeled dotted structure break lines.
- **Order Blocks (OB)**: Supply and demand institutional accumulation/distribution candles preceding strong market moves.

```dart
// Auto-detect SMC on candle series
final smc = SmartMoneyConcepts.calculate(candles);

// Toggle SMC directly on controller
controller.toggleSMC();

// Or enable directly on ImChart with zero boilerplate
ImChart.simple(
  candles: myCandles,
  showSMC: true,
);
```

---

### 8. Stochastic Oscillator (`StochasticIndicator`)
Classic momentum sub-pane oscillator calculating Fast %K and Slow %D lines with 80 (Overbought) and 20 (Oversold) bands:

```dart
final stoch = StochasticIndicator(
  kPeriod: 14,
  kSmooth: 3,
  dPeriod: 3,
);
controller.toggleIndicator(stoch);
```

---

### 9. Parabolic SAR (`ParabolicSarIndicator`)
Stop-and-Reverse trend-following overlay plotting trailing dots above and below candles with acceleration factor step `0.02` up to `0.20`:

```dart
final psar = ParabolicSarIndicator(accelerationStep: 0.02, maxAcceleration: 0.2);
controller.toggleIndicator(psar);
```

---

### 10. Chandelier Exit (`ChandelierExitIndicator`)
Wilder's ATR-based trailing stop overlay designed by Chuck LeBeau:

```dart
final chandelier = ChandelierExitIndicator(period: 22, multiplier: 3.0);
controller.toggleIndicator(chandelier);
```

---

### 11. Average True Range (`ATRIndicator`), Williams %R, CCI & Ichimoku
- **ATR 14**: Sub-pane volatility oscillator based on smoothed True Range.
- **Williams %R**: Momentum oscillator bounded from -100 to 0 with -20 / -80 levels.
- **CCI 20**: Commodity Channel Index measuring statistical deviations.
- **Ichimoku Cloud**: Tenkan-sen (9), Kijun-sen (26), Senkou Span A & B (52).

```dart
controller.toggleIndicator(ATRIndicator(period: 14));
controller.toggleIndicator(WilliamsRIndicator(period: 14));
controller.toggleIndicator(CCIIndicator(period: 20));
controller.toggleIndicator(IchimokuIndicator());
```

---

## ✍️ Authoring Custom Technical Indicators

Creating a custom indicator in `im_charts` is straightforward. Simply extend `Indicator` and implement `calculate(List<Candle> candles)`.

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
