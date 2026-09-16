import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('ChartOrder Model Tests', () {
    test('Calculates percentages accurately for Buy orders', () {
      final order = ChartOrder(
        id: 'ord_1',
        symbol: 'NIFTY 50',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: 100.0,
        quantity: 10,
        takeProfitPrice: 110.0,
        stopLossPrice: 95.0,
      );

      expect(order.isBuy, isTrue);
      expect(order.isSell, isFalse);
      expect(order.hasTakeProfit, isTrue);
      expect(order.hasStopLoss, isTrue);
      // For buy: TP at 110 is +10%, SL at 95 is -5%
      expect(order.takeProfitPercentage, closeTo(10.0, 0.001));
      expect(order.stopLossPercentage, closeTo(-5.0, 0.001));
    });

    test('Calculates percentages accurately for Sell orders', () {
      final order = ChartOrder(
        id: 'ord_2',
        symbol: 'BANKNIFTY',
        side: OrderSide.sell,
        type: OrderType.limit,
        price: 200.0,
        quantity: 25,
        takeProfitPrice: 180.0,
        stopLossPrice: 210.0,
      );

      expect(order.isBuy, isFalse);
      expect(order.isSell, isTrue);
      // For sell: TP at 180 is +10% profit, SL at 210 is -5% loss
      expect(order.takeProfitPercentage, closeTo(10.0, 0.001));
      expect(order.stopLossPercentage, closeTo(-5.0, 0.001));
    });

    test('copyWith creates modified copy correctly', () {
      final order = ChartOrder(
        id: 'ord_3',
        symbol: 'TCS',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: 3500.0,
        quantity: 10,
      );

      final modified = order.copyWith(
        price: 3550.0,
        takeProfitPrice: () => 3650.0,
        stopLossPrice: () => 3450.0,
      );

      expect(modified.id, 'ord_3');
      expect(modified.price, 3550.0);
      expect(modified.takeProfitPrice, 3650.0);
      expect(modified.stopLossPrice, 3450.0);
      expect(order.price, 3500.0); // original unchanged
    });
  });

  group('TradingChartController Order APIs', () {
    late MockTradingDataSource dataSource;
    late TradingChartController controller;

    setUp(() {
      dataSource = MockTradingDataSource(initialPrice: 100.0);
      controller = TradingChartController(
        symbol: 'TEST',
        exchange: 'NSE',
        dataSource: dataSource,
      );
    });

    tearDown(() {
      controller.dispose();
      dataSource.dispose();
    });

    test('placeOrder adds order and fires callbacks', () async {
      await controller.initialize();

      ChartOrder? placedOrder;
      controller.onOrderPlaced = (order) => placedOrder = order;

      final order = ChartOrder(
        id: 'order_test_1',
        symbol: 'TEST',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: 98.50,
        quantity: 100,
      );

      controller.placeOrder(order);

      expect(controller.orders.length, 1);
      expect(controller.orders.first.id, 'order_test_1');
      expect(placedOrder?.id, 'order_test_1');
    });

    test('updateOrderPrice modifies price and notifies listeners', () async {
      await controller.initialize();

      final order = ChartOrder(
        id: 'order_test_2',
        symbol: 'TEST',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: 100.0,
        quantity: 50,
      );
      controller.placeOrder(order);

      ChartOrder? modifiedOrder;
      controller.onOrderModified = (ord) => modifiedOrder = ord;

      controller.updateOrderPrice('order_test_2', 105.50);

      expect(controller.orders.first.price, 105.50);
      expect(modifiedOrder?.price, 105.50);
    });

    test('updateOrderBrackets sets and clears TP/SL', () async {
      await controller.initialize();

      final order = ChartOrder(
        id: 'order_test_3',
        symbol: 'TEST',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: 100.0,
        quantity: 50,
      );
      controller.placeOrder(order);

      // Add brackets
      controller.updateOrderBrackets(
        'order_test_3',
        takeProfitPrice: 110.0,
        stopLossPrice: 95.0,
      );
      expect(controller.orders.first.takeProfitPrice, 110.0);
      expect(controller.orders.first.stopLossPrice, 95.0);

      // Clear TP only
      controller.updateOrderBrackets('order_test_3', clearTakeProfit: true);
      expect(controller.orders.first.takeProfitPrice, isNull);
      expect(controller.orders.first.stopLossPrice, 95.0);

      // Clear SL only
      controller.updateOrderBrackets('order_test_3', clearStopLoss: true);
      expect(controller.orders.first.stopLossPrice, isNull);
    });

    test('cancelOrder removes order and triggers callback', () async {
      await controller.initialize();

      final order = ChartOrder(
        id: 'order_test_4',
        symbol: 'TEST',
        side: OrderSide.sell,
        type: OrderType.limit,
        price: 102.0,
        quantity: 20,
      );
      controller.placeOrder(order);
      expect(controller.orders.length, 1);

      String? cancelledId;
      controller.onOrderCancelled = (id) => cancelledId = id;

      controller.cancelOrder('order_test_4');

      expect(controller.orders.isEmpty, isTrue);
      expect(cancelledId, 'order_test_4');
    });

    test('setOrders and clearOrders batch management', () async {
      await controller.initialize();

      final o1 = ChartOrder(
        id: 'o1',
        symbol: 'TEST',
        side: OrderSide.buy,
        type: OrderType.limit,
        price: 95.0,
        quantity: 10,
      );
      final o2 = ChartOrder(
        id: 'o2',
        symbol: 'TEST',
        side: OrderSide.sell,
        type: OrderType.limit,
        price: 105.0,
        quantity: 10,
      );

      controller.setOrders([o1, o2]);
      expect(controller.orders.length, 2);

      controller.clearOrders();
      expect(controller.orders.isEmpty, isTrue);
    });

    test('Bidirectional priceAtY and yAtPrice coordinate mapping', () async {
      await controller.initialize();

      // Ensure dimensions are updated
      controller.updateDimensions(800.0, 500.0);

      // Test conversion round-trip
      const testPrice = 100.0;
      final y = controller.yAtPrice(testPrice);
      final derivedPrice = controller.priceAtY(y);

      expect(derivedPrice, closeTo(testPrice, 0.05));
    });
  });
}
