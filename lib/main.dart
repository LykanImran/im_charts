import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class TradingApp extends StatelessWidget {
  const TradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'First Demat Chart Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF131722),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2962FF),
          surface: Color(0xFF131722),
        ),
      ),
      home: const TradingScreen(),
    );
  }
}

class TradingScreen extends StatefulWidget {
  const TradingScreen({super.key});

  @override
  State<TradingScreen> createState() => _TradingScreenState();
}

class _TradingScreenState extends State<TradingScreen> {
  late final MockTradingDataSource _dataSource;
  late final TradingChartController _controller;

  @override
  void initState() {
    super.initState();
    _dataSource = MockTradingDataSource(initialPrice: 24520.0, volatility: 0.0018);
    _controller = TradingChartController(
      symbol: 'NIFTY 50',
      dataSource: _dataSource,
      initialTimeframe: Timeframe.fiveMinutes,
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Terminal Header (Ticker, LTP, Net Change, OHLCV tooltips)
            ChartHeader(controller: _controller),

            // 2. Control Toolbar (Timeframes, Indicators, Zoom, Pan controls)
            ChartToolbar(controller: _controller),

            // 3. High-Performance Canvas Chart
            Expanded(
              child: TradingChart(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}
