import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../engine/chart_controller.dart';
import '../renderer/chart_painter.dart';

/// Top-level chart presentation widget integrating the custom rendering pipeline and gesture inputs.
class TradingChart extends StatefulWidget {
  final TradingChartController controller;

  const TradingChart({
    super.key,
    required this.controller,
  });

  @override
  State<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends State<TradingChart> {
  double _lastScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        controller.updateDimensions(constraints.maxWidth, constraints.maxHeight);

        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.isLoading) {
              return Container(
                color: controller.theme.backgroundColor,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2962FF)),
                  ),
                ),
              );
            }

            return MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (event) {
                controller.setCrosshairPosition(event.localPosition);
              },
              onExit: (_) {
                controller.setCrosshairPosition(null);
              },
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  // Desktop / Web mouse wheel zoom
                  if (pointerSignal is PointerScrollEvent) {
                    if (pointerSignal.scrollDelta.dy < 0) {
                      controller.zoomIn();
                    } else if (pointerSignal.scrollDelta.dy > 0) {
                      controller.zoomOut();
                    }
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) {
                    _lastScale = 1.0;
                    _lastFocalPoint = details.localFocalPoint;
                  },
                  onScaleUpdate: (details) {
                    // Pan (horizontal movement)
                    final deltaX = details.localFocalPoint.dx - _lastFocalPoint.dx;
                    if (deltaX.abs() > 0.1) {
                      controller.onPan(deltaX);
                    }

                    // Pinch-to-zoom
                    if (details.scale != 1.0) {
                      final scaleRatio = details.scale / _lastScale;
                      controller.onZoom(scaleRatio, details.localFocalPoint);
                      _lastScale = details.scale;
                    }

                    _lastFocalPoint = details.localFocalPoint;
                  },
                  onDoubleTap: controller.resetView,
                  onLongPressStart: (details) {
                    controller.setCrosshairPosition(details.localPosition);
                  },
                  onLongPressMoveUpdate: (details) {
                    controller.setCrosshairPosition(details.localPosition);
                  },
                  onLongPressEnd: (_) {
                    controller.setCrosshairPosition(null);
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: ChartPainter(
                      candles: controller.candles,
                      viewport: controller.viewport,
                      theme: controller.theme,
                      timeframe: controller.timeframe,
                      overlayIndicators: controller.overlayResults,
                      subPaneIndicator: controller.subPaneResult,
                      crosshairPosition: controller.crosshairPosition,
                      showVolume: controller.showVolume,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
