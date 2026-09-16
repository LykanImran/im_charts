# Customization & Theming Guide

`im_charts` is built to adapt seamlessly to your application's brand identity, color tokens, typography, and layout hierarchy.

---

## 🎨 Design System & `ChartTheme`

Every visual aspect of the chart is governed by `ChartTheme`.

### Factory Themes

- **`ChartTheme.dark()`**: Institutional TradingView / Bloomberg dark aesthetic (`#131722` background, `#089981` bull, `#F23645` bear).
- **`ChartTheme.light()`**: Crisp paper-white modern presentation (`#FFFFFF` background, `#089981` bull, `#F23645` bear, `#F0F3FA` grid).

---

### Creating Custom Themes with `copyWith`

Use `copyWith` to override specific tokens while retaining standard defaults:

```dart
// Example: Cyberpunk / Matrix Neon Theme
final neonTheme = ChartTheme.dark().copyWith(
  backgroundColor: const Color(0xFF0D1117),
  bullishColor: const Color(0xFF00FF66), // Electric Lime
  bearishColor: const Color(0xFFFF0055), // Cyber Magenta
  gridColor: const Color(0xFF161B22),
  currentPriceLineColor: const Color(0xFF00E5FF),
  currentPriceBadgeBackground: const Color(0xFF00E5FF),
  axisTextColor: const Color(0xFF8B949E),
);

// Example: Robinhood Emerald Clean Theme
final emeraldTheme = ChartTheme.light().copyWith(
  bullishColor: const Color(0xFF00C805),
  bearishColor: const Color(0xFFFF5000),
  backgroundColor: Colors.white,
  gridColor: const Color(0xFFF7F7F7),
);
```

---

### Complete Color & Typography Token Reference

| Property | Type | Description |
| :--- | :--- | :--- |
| `backgroundColor` | `Color` | Main chart background fill |
| `bullishColor` | `Color` | Green/Bull candle body and wick color |
| `bearishColor` | `Color` | Red/Bear candle body and wick color |
| `bullishTransparent` | `Color` | Translucent fill for area mountain charts |
| `bearishTransparent` | `Color` | Translucent fill for area drops |
| `gridColor` | `Color` | Subtle horizontal/vertical background grid lines |
| `axisTextColor` | `Color` | Text color for price and timestamp labels |
| `axisLineColor` | `Color` | Dividing border line for price and time scales |
| `crosshairColor` | `Color` | Dashed crosshair tracking line |
| `crosshairBadgeBackground` | `Color` | Chip background on the axis during crosshair hover |
| `crosshairBadgeTextColor` | `Color` | Text color inside the crosshair axis pill |
| `currentPriceLineColor` | `Color` | Horizontal dotted line tracking live market price |
| `currentPriceBadgeBackground` | `Color` | Badge background on the right price scale for live LTP |
| `currentPriceBadgeTextColor` | `Color` | Text color inside the live price badge |
| `axisTextStyle` | `TextStyle` | Font size, family, and weight for scale numbers |
| `tooltipTextStyle` | `TextStyle` | Font styling for interactive data tooltips |

---

## 🕯️ Candlestick Presentation Styles

`im_charts` supports 6 distinct rendering styles out of the box via `CandleStyle`:

```dart
// Change candle style at any time:
controller.setCandleStyle(CandleStyle.hollowCandles);
```

| Style | Enum | Visual Characteristics |
| :--- | :--- | :--- |
| **Standard Candles** | `CandleStyle.candles` | Filled solid rectangles with high/low wicks. |
| **Hollow Candles** | `CandleStyle.hollowCandles` | Green candles hollow if close > open; red candles filled. |
| **Heikin Ashi** | `CandleStyle.heikinAshi` | Average-price trend-filtered candles. |
| **Line Chart** | `CandleStyle.line` | Crisp 2px polyline tracking close prices with anti-aliasing. |
| **Area Mountain** | `CandleStyle.area` | Linear gradient fill under close price line. |
| **Bars (OHLC)** | `CandleStyle.bars` | Institutional Western tick bars with left open and right close tick. |

---

## 🎚️ Viewport & Layout Sizing

You can customize default candle widths, margins, and spacing via `ChartViewport`:

```dart
const customViewport = ChartViewport(
  candleWidth: 10.0,       // Default candle width in pixels
  candleSpacing: 3.0,     // Spacing between candles
  rightMargin: 60.0,      // Empty whitespace margin on the right of the latest candle
  scrollOffset: 0.0,      // Initial scroll position
);
```

---

## 🧩 Building Custom Headers & Toolbars

If you want a totally custom UI around the chart:

```dart
class MyCustomDashboard extends StatelessWidget {
  final TradingChartController controller;

  const MyCustomDashboard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. My Custom Header
        Container(
          height: 50,
          color: Colors.black,
          child: Row(
            children: [
              Text('My Custom Symbol', style: TextStyle(color: Colors.white)),
              const Spacer(),
              ElevatedButton(
                onPressed: () => controller.zoomIn(),
                child: const Text('Zoom In'),
              ),
            ],
          ),
        ),

        // 2. Chart Canvas without default toolbar or header
        Expanded(
          child: TradingScreen(
            controller: controller,
            showToolbar: false, // Disables Row 1
            showHeader: false,  // Disables Row 2
          ),
        ),
      ],
    );
  }
}
```

---

## 🏷️ Custom Brand Watermarks

Im Charts renders an institutional background canvas watermark behind the candles at 4.5% opacity. You can customize the brand name or set it dynamically:

```dart
// Option 1: Via TradingScreen / ImTradingScreen
TradingScreen(
  initialSymbol: 'NIFTY 50',
  brandName: 'Im Charts', // Defaults to 'Im Charts'
  showWatermark: true,
)

// Option 2: Programmatically via Controller
controller.brandName = 'Im Charts';
controller.showWatermark = true;
```
