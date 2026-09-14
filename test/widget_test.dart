import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/main.dart';

void main() {
  testWidgets('TradingApp renders Row 1 primary tools and Row 2 symbol telemetry', (WidgetTester tester) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Row 1: Search trigger
    expect(find.text('Search symbol...'), findsOneWidget);

    // Row 1: Interval dropdown showing initial timeframe '5m'
    expect(find.text('5m'), findsOneWidget);

    // Row 1: Candles dropdown showing initial style 'Candles'
    expect(find.text('Candles'), findsOneWidget);

    // Row 1: Indicators dropdown
    expect(find.text('Indicators'), findsOneWidget);

    // Row 1: Refresh and Settings tooltips/icons
    expect(find.byTooltip('Refresh Chart Data'), findsOneWidget);
    expect(find.byTooltip('Chart Settings'), findsOneWidget);

    // Row 2: Selected Symbol Name
    expect(find.text('NIFTY 50'), findsOneWidget);

    // Row 2: Exchange Selector (NSE & BSE)
    expect(find.text('NSE'), findsOneWidget);
    expect(find.text('BSE'), findsOneWidget);
  });

  testWidgets('Interval dropdown opens menu with all timeframes', (WidgetTester tester) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the interval dropdown button
    await tester.tap(find.text('5m'));
    await tester.pumpAndSettle();

    // Verify timeframes are shown in popup menu
    expect(find.text('1m (1 Minute)'), findsOneWidget);
    expect(find.text('15m (15 Minutes)'), findsOneWidget);
    expect(find.text('1H (1 Hour)'), findsOneWidget);
    expect(find.text('4H (4 Hours)'), findsOneWidget);
    expect(find.text('1D (1 Day)'), findsOneWidget);

    // Select 15m
    await tester.tap(find.text('15m (15 Minutes)'));
    await tester.pumpAndSettle();

    // Verify interval dropdown now displays 15m
    expect(find.text('15m'), findsOneWidget);
  });

  testWidgets('Candles dropdown opens menu and allows style selection', (WidgetTester tester) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap candles dropdown button
    await tester.tap(find.text('Candles'));
    await tester.pumpAndSettle();

    // Verify candle styles are displayed
    expect(find.text('Hollow Candles'), findsOneWidget);
    expect(find.text('Heikin Ashi'), findsOneWidget);
    expect(find.text('Line'), findsOneWidget);
    expect(find.text('Area'), findsOneWidget);
    expect(find.text('Bars (OHLC)'), findsOneWidget);

    // Select Line
    await tester.tap(find.text('Line'));
    await tester.pumpAndSettle();

    // Verify toolbar now displays Line
    expect(find.text('Line'), findsOneWidget);
  });

  testWidgets('Exchange selector toggles between NSE and BSE', (WidgetTester tester) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap BSE
    await tester.tap(find.text('BSE'));
    await tester.pumpAndSettle();

    // Tap NSE
    await tester.tap(find.text('NSE'));
    await tester.pumpAndSettle();
  });

  testWidgets('Search button opens symbol search dialog and displays symbols', (WidgetTester tester) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Search
    await tester.tap(find.text('Search symbol...'));
    await tester.pumpAndSettle();

    // Verify search modal is open
    expect(find.text('Indices'), findsOneWidget);
    expect(find.text('Stocks'), findsOneWidget);
    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.text('TCS'), findsOneWidget);

    // Select RELIANCE
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();

    // Verify symbol in header changed to RELIANCE
    expect(find.text('RELIANCE'), findsOneWidget);
  });

  testWidgets('Dragging price scale engages manual scale and shows AUTO pill', (WidgetTester tester) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Initially AUTO pill is not visible because auto-scale is active
    expect(find.byKey(const Key('auto_scale_pill')), findsNothing);

    // Find the chart widget size
    final chartFinder = find.byType(TradingChart);
    expect(chartFinder, findsOneWidget);
    final chartRect = tester.getRect(chartFinder);

    // Drag vertically on the right price scale (width 65px)
    final priceAxisPoint = Offset(chartRect.right - 30, chartRect.top + 100);
    await tester.dragFrom(priceAxisPoint, const Offset(0, 80));
    await tester.pumpAndSettle();

    // Now AUTO pill should be visible
    expect(find.byKey(const Key('auto_scale_pill')), findsOneWidget);

    // Tapping AUTO should reset manual price scale
    await tester.tap(find.byKey(const Key('auto_scale_pill')));
    await tester.pumpAndSettle();

    // AUTO pill is hidden after reset
    expect(find.byKey(const Key('auto_scale_pill')), findsNothing);
  });

  testWidgets('Dragging time scale horizontally zooms candle width', (WidgetTester tester) async {
    await tester.pumpWidget(const TradingApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    final chartFinder = find.byType(TradingChart);
    final chartRect = tester.getRect(chartFinder);

    // Drag horizontally on the bottom time scale (height 24px)
    final timeAxisPoint = Offset(chartRect.center.dx, chartRect.bottom - 12);
    await tester.dragFrom(timeAxisPoint, const Offset(60, 0));
    await tester.pumpAndSettle();

    // Drag left to zoom out
    await tester.dragFrom(timeAxisPoint, const Offset(-100, 0));
    await tester.pumpAndSettle();
  });
}

