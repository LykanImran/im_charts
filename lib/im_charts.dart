/// A high-performance financial charting engine and professional trading terminal for Flutter.
library;

// Core Models
export 'core/models/candle.dart';
export 'core/models/candle_style.dart';
export 'core/models/chart_alert.dart';
export 'core/models/chart_drawing.dart';
export 'core/models/chart_order.dart';
export 'core/models/chart_position.dart';
export 'core/models/chart_theme.dart';
export 'core/models/price_range.dart';
export 'core/models/tick.dart';
export 'core/models/timeframe.dart';

// Coordinates, Viewport & Utils
export 'core/coordinates/coordinate_converter.dart';
export 'core/coordinates/viewport.dart';
export 'core/utils/chart_exporter.dart';

// Data Sources
export 'datasource/chart_data_source.dart';
export 'datasource/mock_data_source.dart';

// Engine & Indicators
export 'engine/candle_builder.dart';
export 'engine/chart_controller.dart';
export 'engine/indicators/bollinger_bands.dart';
export 'engine/indicators/ema.dart';
export 'engine/indicators/indicator.dart';
export 'engine/indicators/indicator_result.dart';
export 'engine/indicators/macd.dart';
export 'engine/indicators/rsi.dart';
export 'engine/indicators/volume_profile.dart';
export 'engine/indicators/vwap.dart';

// Renderer & Panes
export 'renderer/chart_painter.dart';
export 'renderer/pane.dart';

// UI Components
export 'ui/chart_drawing_toolbar.dart';
export 'ui/chart_header.dart';
export 'ui/chart_settings_modal.dart';
export 'ui/chart_toolbar.dart';
export 'ui/chart_widget.dart';
export 'ui/replay_control_bar.dart';
export 'ui/symbol_search_modal.dart';
export 'ui/trading_screen.dart';
