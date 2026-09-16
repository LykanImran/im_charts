# Changelog

All notable changes to the `im_charts` package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added
- **Institutional Trading Terminal**:
  - `TradingScreen` turnkey trading terminal widget embedding primary toolbars, telemetry overlay header, drawing instruments, and high-performance canvas.
  - Row 1 primary toolbar: Symbol search dialog (`Cmd+K`), timeframe selector (`1m` to `1W`), candle styles dropdown, technical indicators modal (`fx`), bar replay simulator, high-DPI camera snapshot, shortcuts modal, and theme settings.
  - Row 2 floating telemetry header: Symbol name, category tag (`INDEX`, `EQ`, `CRYPTO`), exchange badge, live dynamic LTP with color pulse, net change, and high-density OHLCV strip.
- **6 Candlestick Presentation Styles**:
  - Standard Candlesticks, Hollow Candles, Heikin Ashi, Line Chart, Area Mountain Chart, and Western OHLC Tick Bars.
- **Integrated Technical Indicators**:
  - Overlay indicators: Exponential Moving Averages (EMA), Bollinger Bands (with configurable standard deviations), and Volume Weighted Average Price (VWAP with intraday anchor resets and volatility bands).
  - Visible Range Volume Profile (VRVP): Dynamic Point of Control (POC), 70% Value Area High (VAH) / Value Area Low (VAL), and buy/sell volume distribution.
  - Stacked Sub-Panes: RSI and MACD (MACD line, signal line, and color-coded zero-baseline histogram) with independent auto-scaling coordinate spaces.
- **Multi-Zone Touch & Trackpad Scaling**:
  - Native macOS & Windows trackpad pinch-to-zoom (centered at pointer).
  - 2-finger horizontal trackpad pan.
  - Vertical price scale drag with manual scale lock and interactive `AUTO` reset badge.
  - Horizontal time scale drag.
- **Interactive Drawing Engine**:
  - Trendline, Horizontal Line (with direct vertical drag and price badge update), Rectangle / Supply & Demand Zone Box (with 8 interactive corner and edge resize handles), Fibonacci Retracement, Long & Short Position Risk:Reward Boxes, and Measure Ruler.
  - Floating glassmorphic quick-action toolbar (`DrawingActionToolbar`) for color selection, stroke thickness, lock/unlock, and deletion.
  - Dual creation workflow: Click-and-Drag or Click-Move-Click with real-time rubber-band preview geometry.
- **Visual Price Alerts & Direct Chart Trading**:
  - `ChartAlert`: Draggable visual alert lines with price scale badges and crossing trigger callbacks.
  - `ChartOrder`: Interactive limit orders with stop-loss (SL) and take-profit (TP) bracket handles.
  - `ChartPosition`: Interactive open position badges with live unrealized P&L and 1-click close buttons.
  - Hover `+` button dropdown for instant order placement and alert creation at hovered price.
- **Im Charts Brand Aliases**:
  - First-class type aliases: `ImChart`, `ImTradingScreen`, `ImChartsApp`, `ImChartController`.
  - Institutional background canvas watermark typography (`IM CHARTS • SYMBOL • TIMEFRAME • EXCHANGE`).
