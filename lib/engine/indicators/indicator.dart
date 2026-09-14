import '../../core/models/candle.dart';
import 'indicator_result.dart';

/// Abstract definition for technical indicators.
abstract class Indicator {
  String get id;
  String get name;
  bool get isOverlay;

  /// Pure computation function that produces an [IndicatorResult] from [candles].
  IndicatorResult calculate(List<Candle> candles);
}
