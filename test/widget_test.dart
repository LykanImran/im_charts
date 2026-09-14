import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/main.dart';

void main() {
  testWidgets('TradingApp smoke test renders symbol and timeframes', (WidgetTester tester) async {
    // Pump TradingApp
    await tester.pumpWidget(const TradingApp());

    // Advance frames to allow asynchronous historical candle loading to complete
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify symbol 'NIFTY 50' is rendered in header
    expect(find.text('NIFTY 50'), findsOneWidget);

    // Verify timeframes are rendered in toolbar
    expect(find.text('1m'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(find.text('15m'), findsOneWidget);
    expect(find.text('1H'), findsOneWidget);

    // Verify technical indicators are available
    expect(find.text('EMA 20'), findsOneWidget);
    expect(find.text('RSI 14'), findsOneWidget);
  });
}
