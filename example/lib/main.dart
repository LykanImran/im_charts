import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'im_charts Trading Terminal Demo',
      debugShowCheckedModeBanner: false,
      home: TradingScreen(
        initialSymbol: 'NIFTY 50',
        initialExchange: 'NSE',
        initialTimeframe: Timeframe.fiveMinutes,
        initialCandleStyle: CandleStyle.candles,
      ),
    );
  }
}
