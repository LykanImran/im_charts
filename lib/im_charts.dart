/// Im Charts — A high-performance financial charting engine and professional trading terminal for Flutter.
library;

import 'engine/chart_controller.dart';
import 'engine/chart_sync_group.dart';
import 'engine/formula/formula_indicator.dart';
import 'ui/multi_chart_container.dart';
import 'ui/trading_screen.dart';

// Core Models
export 'core/models/candle.dart';
export 'core/models/candle_style.dart';
export 'core/models/chart_alert.dart';
export 'core/models/chart_drawing.dart';
export 'core/models/chart_order.dart';
export 'core/models/chart_position.dart';
export 'core/models/chart_save_state.dart';
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
export 'datasource/static_data_source.dart';

// Engine & Indicators
export 'engine/candle_builder.dart';
export 'engine/chart_controller.dart';
export 'engine/chart_sync_group.dart';
export 'engine/formula/formula_ast.dart';
export 'engine/formula/formula_evaluator.dart';
export 'engine/formula/formula_indicator.dart';
export 'engine/formula/formula_lexer.dart';
export 'engine/formula/formula_parser.dart';
export 'engine/indicators/atr.dart';
export 'engine/indicators/bollinger_bands.dart';
export 'engine/indicators/cci.dart';
export 'engine/indicators/chandelier_exit.dart';
export 'engine/indicators/ema.dart';
export 'engine/indicators/ichimoku.dart';
export 'engine/indicators/indicator.dart';
export 'engine/indicators/indicator_result.dart';
export 'engine/indicators/macd.dart';
export 'engine/indicators/parabolic_sar.dart';
export 'engine/indicators/rsi.dart';
export 'engine/indicators/sma.dart';
export 'engine/indicators/smart_money_concepts.dart';
export 'engine/indicators/stochastic.dart';
export 'engine/indicators/supertrend.dart';
export 'engine/indicators/volume_profile.dart';
export 'engine/indicators/vwap.dart';
export 'engine/indicators/williams_r.dart';

// Renderer & Panes
export 'renderer/chart_painter.dart';
export 'renderer/pane.dart';
export 'renderer/renderers/smc_renderer.dart';

// UI Components
export 'ui/chart_drawing_toolbar.dart';
export 'ui/drawing_action_toolbar.dart';
export 'ui/chart_header.dart';
export 'ui/chart_save_status_badge.dart';
export 'ui/chart_settings_modal.dart';
export 'ui/chart_toolbar.dart';
export 'ui/chart_widget.dart';
export 'ui/formula_editor_modal.dart';
export 'ui/multi_chart_container.dart';
export 'ui/replay_control_bar.dart';
export 'ui/simple_chart_widget.dart';
export 'ui/symbol_search_modal.dart';
export 'ui/trading_screen.dart';

// --- Im Charts Brand Type Aliases ---

/// Convenient alias for [TradingScreen] under the brand name **Im Charts**.
typedef ImTradingScreen = TradingScreen;

/// Convenient alias for [TradingApp] under the brand name **Im Charts**.
typedef ImChartsApp = TradingApp;

/// Convenient alias for [TradingChartController] under the brand name **Im Charts**.
typedef ImChartController = TradingChartController;

/// Convenient alias for [MultiChartContainer] under the brand name **Im Charts**.
typedef ImMultiChart = MultiChartContainer;

/// Convenient alias for [ChartSyncGroup] under the brand name **Im Charts**.
typedef ImChartSyncGroup = ChartSyncGroup;

/// Convenient alias for [FormulaIndicator] under the brand name **Im Charts**.
typedef ImFormulaIndicator = FormulaIndicator;
