import 'package:flutter/material.dart';
import 'chart_controller.dart';

/// Coordinator that manages synchronization between multiple [TradingChartController] instances.
///
/// Supports linking:
/// - Crosshair cursor and hovered timestamp across assets / timeframes
/// - Horizontal pan / time scrolling
/// - Focal zoom scale
class ChartSyncGroup extends ChangeNotifier {
  final List<TradingChartController> _controllers = [];
  bool _syncCrosshair;
  bool _syncTimeScroll;
  bool _syncTimeZoom;
  bool _isBroadcasting = false;

  ChartSyncGroup({
    bool syncCrosshair = true,
    bool syncTimeScroll = true,
    bool syncTimeZoom = true,
  })  : _syncCrosshair = syncCrosshair,
        _syncTimeScroll = syncTimeScroll,
        _syncTimeZoom = syncTimeZoom;

  /// Unmodifiable view of registered controllers.
  List<TradingChartController> get controllers =>
      List.unmodifiable(_controllers);

  /// Whether crosshair position is synchronized across charts.
  bool get syncCrosshair => _syncCrosshair;
  set syncCrosshair(bool value) {
    if (_syncCrosshair == value) return;
    _syncCrosshair = value;
    if (!_syncCrosshair) {
      clearCrosshair();
    }
    notifyListeners();
  }

  /// Whether time pan and scroll offset are synchronized across charts.
  bool get syncTimeScroll => _syncTimeScroll;
  set syncTimeScroll(bool value) {
    if (_syncTimeScroll == value) return;
    _syncTimeScroll = value;
    notifyListeners();
  }

  /// Whether zoom level and candle width are synchronized across charts.
  bool get syncTimeZoom => _syncTimeZoom;
  set syncTimeZoom(bool value) {
    if (_syncTimeZoom == value) return;
    _syncTimeZoom = value;
    notifyListeners();
  }

  /// Registers a controller into this sync group.
  void register(TradingChartController controller) {
    if (!_controllers.contains(controller)) {
      _controllers.add(controller);
      controller.syncGroup = this;
      notifyListeners();
    }
  }

  /// Unregisters a controller from this sync group.
  void unregister(TradingChartController controller) {
    if (_controllers.remove(controller)) {
      if (controller.syncGroup == this) {
        controller.syncGroup = null;
      }
      notifyListeners();
    }
  }

  /// Broadcasts crosshair movement from [source] to all sibling charts.
  void broadcastCrosshair({
    required TradingChartController source,
    required DateTime? timestamp,
    double? yPriceRatio,
  }) {
    if (!_syncCrosshair || _isBroadcasting) return;
    _isBroadcasting = true;
    try {
      for (final target in _controllers) {
        if (target != source && !target.isDisposed) {
          target.receiveSyncedCrosshair(timestamp, yPriceRatio);
        }
      }
    } finally {
      _isBroadcasting = false;
    }
  }

  /// Broadcasts horizontal pan delta from [source] to all sibling charts.
  void broadcastPan({
    required TradingChartController source,
    required double deltaX,
  }) {
    if (!_syncTimeScroll || _isBroadcasting) return;
    _isBroadcasting = true;
    try {
      for (final target in _controllers) {
        if (target != source && !target.isDisposed) {
          target.receiveSyncedPan(deltaX);
        }
      }
    } finally {
      _isBroadcasting = false;
    }
  }

  /// Broadcasts zoom factor from [source] to all sibling charts.
  void broadcastZoom({
    required TradingChartController source,
    required double scaleFactor,
    required double focalPointRatio,
  }) {
    if (!_syncTimeZoom || _isBroadcasting) return;
    _isBroadcasting = true;
    try {
      for (final target in _controllers) {
        if (target != source && !target.isDisposed) {
          target.receiveSyncedZoom(scaleFactor, focalPointRatio);
        }
      }
    } finally {
      _isBroadcasting = false;
    }
  }

  /// Clears crosshairs across all controllers.
  void clearCrosshair({TradingChartController? source}) {
    if (_isBroadcasting) return;
    _isBroadcasting = true;
    try {
      for (final target in _controllers) {
        if (target != source && !target.isDisposed) {
          target.receiveSyncedCrosshair(null, null);
        }
      }
    } finally {
      _isBroadcasting = false;
    }
  }

  /// Finds the index of the candle with the closest timestamp to [targetTime].
  static int findClosestCandleIndex(
    List<DateTime> timestamps,
    DateTime targetTime,
  ) {
    if (timestamps.isEmpty) return -1;
    if (timestamps.length == 1) return 0;

    int low = 0;
    int high = timestamps.length - 1;
    final targetMs = targetTime.millisecondsSinceEpoch;

    // Check bounds first
    if (targetMs <= timestamps.first.millisecondsSinceEpoch) return 0;
    if (targetMs >= timestamps.last.millisecondsSinceEpoch) return high;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final midMs = timestamps[mid].millisecondsSinceEpoch;
      if (midMs == targetMs) {
        return mid;
      } else if (midMs < targetMs) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // Binary search finished: low and high are closest candidates
    final lowIdx = low.clamp(0, timestamps.length - 1);
    final highIdx = high.clamp(0, timestamps.length - 1);
    final diffLow =
        (timestamps[lowIdx].millisecondsSinceEpoch - targetMs).abs();
    final diffHigh =
        (timestamps[highIdx].millisecondsSinceEpoch - targetMs).abs();
    return diffLow < diffHigh ? lowIdx : highIdx;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      if (controller.syncGroup == this) {
        controller.syncGroup = null;
      }
    }
    _controllers.clear();
    super.dispose();
  }
}
