import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/models/candle_style.dart';
import 'core/models/chart_theme.dart';
import 'core/models/timeframe.dart';
import 'datasource/mock_data_source.dart';
import 'engine/chart_controller.dart';
import 'engine/indicators/ema.dart';
import 'engine/indicators/rsi.dart';
import 'ui/chart_header.dart';
import 'ui/chart_toolbar.dart';
import 'ui/chart_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TradingApp());
}

class TradingApp extends StatefulWidget {
  const TradingApp({super.key});

  @override
  State<TradingApp> createState() => _TradingAppState();
}

class _TradingAppState extends State<TradingApp> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(initialPrice: 24520.0, volatility: 0.0018);
    _controller = TradingChartController(
      symbol: 'NIFTY 50',
      exchange: 'NSE',
      dataSource: _dataSource,
      initialTimeframe: Timeframe.fiveMinutes,
      initialCandleStyle: CandleStyle.candles,
      theme: ChartTheme.dark(),
    );

    // Initialize data & activate starter indicators
    _controller.initialize().then((_) {
      if (mounted) {
        _controller.toggleIndicator(EMAIndicator(period: 20, color: const Color(0xFF2962FF)));
        _controller.toggleIndicator(RSIIndicator(period: 14));
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
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final isDark = _controller.isDarkTheme;

        return MaterialApp(
          title: 'First Demat Chart Engine',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2962FF),
              surface: Colors.white,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF131722),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2962FF),
              surface: Color(0xFF131722),
            ),
          ),
          home: Scaffold(
            backgroundColor: _controller.theme.backgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  // Row 1: Primary Toolbar (Search, Interval dropdown, Candles dropdown, Indicators dropdown, Refresh, Theme, Settings)
                  ChartToolbar(controller: _controller),

                  // Row 2: Symbol & Telemetry Bar (Selected symbol, NSE/BSE, LTP, OHLC Data, Quick Nav)
                  ChartHeader(controller: _controller),

                  // Row 3: High-Performance Canvas Chart
                  Expanded(
                    child: TradingChart(controller: _controller),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
