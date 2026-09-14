import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/trading_screen.dart';

export 'im_charts.dart';

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
