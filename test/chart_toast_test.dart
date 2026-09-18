import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('ChartToast Responsive & Behavior Tests', () {
    tearDown(() {
      ChartToast.dismiss();
    });

    testWidgets('Renders top-right with fixed width on Desktop/Web (width >= 600)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const Center(child: Text('Content'));
              },
            ),
          ),
        ),
      );

      ChartToast.success(
        testContext,
        'Snapshot saved successfully',
        title: 'Export Complete',
      );
      await tester.pumpAndSettle();

      // Check text presence
      expect(find.text('Snapshot saved successfully'), findsOneWidget);
      expect(find.text('Export Complete'), findsOneWidget);

      // Verify Positioned placement on Desktop/Web
      final positionedFinder = find.byType(Positioned);
      bool foundDesktopPositioned = false;
      for (final element in tester.elementList(positionedFinder)) {
        final Positioned widget = element.widget as Positioned;
        if (widget.right == 18.0 && widget.top == 18.0 && widget.width == 350.0) {
          foundDesktopPositioned = true;
          break;
        }
      }
      expect(
        foundDesktopPositioned,
        isTrue,
        reason: 'Desktop/Web toast must have top: 18, right: 18, width: 350',
      );

      // Advance clock past toast duration
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Snapshot saved successfully'), findsNothing);
    });

    testWidgets('Renders center-top with full width on Mobile (width < 600)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const Center(child: Text('Mobile Content'));
              },
            ),
          ),
        ),
      );

      ChartToast.info(
        testContext,
        'Order placed at market',
      );
      await tester.pumpAndSettle();

      expect(find.text('Order placed at market'), findsOneWidget);

      // Verify Positioned placement on Mobile
      final positionedFinder = find.byType(Positioned);
      bool foundMobilePositioned = false;
      for (final element in tester.elementList(positionedFinder)) {
        final Positioned widget = element.widget as Positioned;
        if (widget.left == 14.0 && widget.right == 14.0 && widget.width == null) {
          foundMobilePositioned = true;
          break;
        }
      }
      expect(
        foundMobilePositioned,
        isTrue,
        reason: 'Mobile toast must have left: 14, right: 14, and full responsive width',
      );

      // Advance clock past toast duration
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Order placed at market'), findsNothing);
    });

    testWidgets('Manual dismiss removes toast immediately',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      ChartToast.alert(testContext, 'High volatility detected');
      await tester.pumpAndSettle();

      expect(find.text('High volatility detected'), findsOneWidget);

      // Dismiss explicitly
      ChartToast.dismiss();
      await tester.pumpAndSettle();

      expect(find.text('High volatility detected'), findsNothing);
    });
  });
}
