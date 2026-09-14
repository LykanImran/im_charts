import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('ExampleApp renders dashboard hub and switches modes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Initial render defaults to Showcase Hub Dashboard
    await tester.pumpWidget(const ExampleApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Financial Charting Possibilities'), findsOneWidget);
    expect(find.text('Dashboard Hub'), findsOneWidget);
    expect(find.text('Full Terminal'), findsOneWidget);
    expect(find.text('Clean Chart'), findsOneWidget);

    // 2. Switch to Full Terminal mode
    await tester.tap(find.text('Full Terminal'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('NIFTY 50'), findsWidgets);
    expect(find.text('Search symbol...'), findsOneWidget);

    // 3. Switch to Clean Chart mode (no top toolbar / header)
    await tester.tap(find.text('Clean Chart'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('CLEAN CANVAS MODE'), findsOneWidget);
  });
}
