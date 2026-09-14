import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('ExampleApp smoke test renders trading terminal', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Check that header elements render
    expect(find.text('NIFTY 50'), findsOneWidget);
    expect(find.text('Search symbol...'), findsOneWidget);
  });
}
