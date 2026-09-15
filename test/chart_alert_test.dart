import 'package:flutter_test/flutter_test.dart';
import 'package:im_charts/im_charts.dart';

void main() {
  group('ChartAlert Model & Evaluation Tests', () {
    test('Crossing trigger evaluation works in both directions', () {
      final alert = ChartAlert(
        id: 'alt_1',
        symbol: 'NIFTY 50',
        price: 24500.0,
        condition: AlertTriggerCondition.crossing,
        createdAt: DateTime.now(),
      );

      // Price crosses upwards: 24490 -> 24510
      expect(alert.checkTrigger(24510.0, 24490.0), isTrue);

      // Price crosses downwards: 24510 -> 24490
      expect(alert.checkTrigger(24490.0, 24510.0), isTrue);

      // Price moves without crossing: 24480 -> 24490
      expect(alert.checkTrigger(24490.0, 24480.0), isFalse);
    });

    test('CrossingUp trigger evaluation works only upwards', () {
      final alert = ChartAlert(
        id: 'alt_up',
        symbol: 'NIFTY 50',
        price: 24500.0,
        condition: AlertTriggerCondition.crossingUp,
        createdAt: DateTime.now(),
      );

      // Upwards cross: 24495 -> 24505
      expect(alert.checkTrigger(24505.0, 24495.0), isTrue);

      // Downwards cross: 24505 -> 24495
      expect(alert.checkTrigger(24495.0, 24505.0), isFalse);
    });

    test('CrossingDown trigger evaluation works only downwards', () {
      final alert = ChartAlert(
        id: 'alt_down',
        symbol: 'NIFTY 50',
        price: 24500.0,
        condition: AlertTriggerCondition.crossingDown,
        createdAt: DateTime.now(),
      );

      // Downwards cross: 24505 -> 24495
      expect(alert.checkTrigger(24495.0, 24505.0), isTrue);

      // Upwards cross: 24495 -> 24505
      expect(alert.checkTrigger(24505.0, 24495.0), isFalse);
    });

    test('Inactive or already triggered alert never fires', () {
      final inactive = ChartAlert(
        id: 'alt_inactive',
        symbol: 'NIFTY 50',
        price: 24500.0,
        isActive: false,
        createdAt: DateTime.now(),
      );
      expect(inactive.checkTrigger(24510.0, 24490.0), isFalse);

      final triggered = ChartAlert(
        id: 'alt_triggered',
        symbol: 'NIFTY 50',
        price: 24500.0,
        isTriggered: true,
        createdAt: DateTime.now(),
      );
      expect(triggered.checkTrigger(24510.0, 24490.0), isFalse);
    });
  });

  group('TradingChartController Alert Lifecycle Tests', () {
    test('addAlert, updateAlert, removeAlert, and clearAlerts', () async {
      final dataSource = MockTradingDataSource();
      final controller = TradingChartController(
        symbol: 'NIFTY 50',
        exchange: 'NSE',
        dataSource: dataSource,
      );
      await controller.initialize();

      expect(controller.alerts, isEmpty);

      final alert = ChartAlert(
        id: 'alt_ctrl_1',
        symbol: 'NIFTY 50',
        price: 24550.0,
        note: 'Breakout Resistance',
        createdAt: DateTime.now(),
      );

      controller.addAlert(alert);
      expect(controller.alerts.length, 1);
      expect(controller.alerts.first.price, 24550.0);

      // Update
      controller.updateAlert(alert.copyWith(price: 24600.0));
      expect(controller.alerts.first.price, 24600.0);

      // Remove
      controller.removeAlert('alt_ctrl_1');
      expect(controller.alerts, isEmpty);

      // Add multiple and clear
      controller.addAlert(alert.copyWith(id: 'a1'));
      controller.addAlert(alert.copyWith(id: 'a2'));
      expect(controller.alerts.length, 2);
      controller.clearAlerts();
      expect(controller.alerts, isEmpty);

      controller.dispose();
      dataSource.dispose();
    });
  });
}
