import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../engine/chart_controller.dart';
import '../renderer/chart_painter.dart';

enum _ChartDragMode { none, priceAxis, timeAxis, mainChart }

/// Top-level chart presentation widget integrating the custom rendering pipeline,
/// multi-zone scale interactions (Price Axis drag, Time Axis drag, Pinch Zoom), and pointer tracking.
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
  double _lastTrackpadScale = 1.0;
  bool _isPinching = false;
  Offset _lastFocalPoint = Offset.zero;
  Offset _lastTapDownPosition = Offset.zero;
  _ChartDragMode _dragMode = _ChartDragMode.none;
  Offset? _hoverPosition;

  static const double _priceAxisWidth = 65.0;
  static const double _timeAxisHeight = 24.0;

  MouseCursor _resolveCursor(double width, double height) {
    if (_hoverPosition == null) return SystemMouseCursors.basic;

    final priceAxisLeft = width - _priceAxisWidth;
    final timeAxisTop = height - _timeAxisHeight;

    final isPriceAxis = _hoverPosition!.dx >= priceAxisLeft && _hoverPosition!.dy < timeAxisTop;
    final isTimeAxis = _hoverPosition!.dy >= timeAxisTop && _hoverPosition!.dx < priceAxisLeft;
    final isCorner = _hoverPosition!.dx >= priceAxisLeft && _hoverPosition!.dy >= timeAxisTop;

    if (isPriceAxis) {
      return SystemMouseCursors.resizeUpDown;
    } else if (isTimeAxis) {
      return SystemMouseCursors.resizeLeftRight;
    } else if (isCorner) {
      return SystemMouseCursors.click;
    }
    return SystemMouseCursors.precise;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final priceAxisLeft = width - _priceAxisWidth;
        final timeAxisTop = height - _timeAxisHeight;

        controller.updateDimensions(width, height);

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

            final theme = controller.theme;

            return MouseRegion(
              cursor: _resolveCursor(width, height),
              onHover: (event) {
                final pos = event.localPosition;
                setState(() => _hoverPosition = pos);

                // Only send crosshair updates when cursor is inside main chart area
                if (pos.dx < priceAxisLeft && pos.dy < timeAxisTop) {
                  controller.setCrosshairPosition(pos);
                } else {
                  controller.setCrosshairPosition(null);
                }
              },
              onExit: (_) {
                setState(() => _hoverPosition = null);
                controller.setCrosshairPosition(null);
              },
              child: Listener(
                onPointerPanZoomStart: (event) {
                  _lastTrackpadScale = 1.0;
                },
                onPointerPanZoomUpdate: (event) {
                  final pos = event.localPosition;

                  // Native Trackpad pinch-to-zoom (macOS / Desktop precision trackpads)
                  if ((event.scale - 1.0).abs() > 0.001) {
                    final scaleRatio = event.scale / _lastTrackpadScale;
                    _lastTrackpadScale = event.scale;

                    if (pos.dx >= priceAxisLeft) {
                      // Pinch over price axis: scale price vertically
                      if (scaleRatio > 1.0) {
                        controller.zoomInPrice();
                      } else {
                        controller.zoomOutPrice();
                      }
                    } else {
                      // Pinch over main chart canvas: horizontal focal zoom centered at trackpad pointer
                      controller.onZoom(scaleRatio, pos);
                    }
                  } else {
                    // Native Trackpad 2-finger pan / swipe
                    if (event.panDelta.dx.abs() > 0.1) {
                      controller.onPan(event.panDelta.dx);
                    }
                    if (controller.isManualPriceScale && event.panDelta.dy.abs() > 0.1) {
                      controller.onVerticalPan(event.panDelta.dy, timeAxisTop);
                    }
                  }
                },
                onPointerPanZoomEnd: (event) {
                  _lastTrackpadScale = 1.0;
                },
                onPointerSignal: (pointerSignal) {
                  // Desktop / Web mouse wheel & trackpad scroll zoom
                  if (pointerSignal is PointerScrollEvent) {
                    final pos = pointerSignal.localPosition;
                    final dx = pointerSignal.scrollDelta.dx;
                    final dy = pointerSignal.scrollDelta.dy;

                    if (pos.dx >= priceAxisLeft) {
                      // Wheel over price axis -> scale price vertically
                      if (dy < 0) {
                        controller.zoomInPrice();
                      } else if (dy > 0) {
                        controller.zoomOutPrice();
                      }
                    } else if (pos.dy >= timeAxisTop) {
                      // Wheel over time axis -> scale timeframe horizontally
                      if (dy < 0 || dx < 0) {
                        controller.zoomIn();
                      } else if (dy > 0 || dx > 0) {
                        controller.zoomOut();
                      }
                    } else {
                      // Over main chart canvas:
                      // If dominant horizontal trackpad scroll (2-finger swipe)
                      if (dx.abs() > dy.abs() && dx.abs() > 0.5) {
                        controller.onPan(-dx);
                      } else if (dy.abs() > 0.0) {
                        // Smooth exponential focal zoom based on scroll delta
                        final zoomFactor = math.exp(-dy * 0.003).clamp(0.7, 1.3);
                        controller.onZoom(zoomFactor, pos);
                      }
                    }
                  }
                },
                child: Stack(
                  children: [
                    // Main interactive canvas gesture detector
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          _lastTapDownPosition = details.localPosition;
                        },
                        onScaleStart: (details) {
                          _isPinching = false;
                          _lastScale = 1.0;
                          _lastFocalPoint = details.localFocalPoint;
                          final start = details.localFocalPoint;

                          if (start.dx >= priceAxisLeft && start.dy < timeAxisTop) {
                            _dragMode = _ChartDragMode.priceAxis;
                          } else if (start.dy >= timeAxisTop && start.dx < priceAxisLeft) {
                            _dragMode = _ChartDragMode.timeAxis;
                          } else if (start.dx >= priceAxisLeft && start.dy >= timeAxisTop) {
                            _dragMode = _ChartDragMode.none;
                            controller.resetView();
                          } else {
                            _dragMode = _ChartDragMode.mainChart;
                          }
                        },
                        onScaleUpdate: (details) {
                          final deltaX = details.localFocalPoint.dx - _lastFocalPoint.dx;
                          final deltaY = details.localFocalPoint.dy - _lastFocalPoint.dy;

                          switch (_dragMode) {
                            case _ChartDragMode.priceAxis:
                              if (deltaY.abs() > 0.05) {
                                controller.onVerticalScale(deltaY);
                              }
                              break;

                            case _ChartDragMode.timeAxis:
                              if (deltaX.abs() > 0.05) {
                                controller.onTimeScale(deltaX);
                              }
                              break;

                            case _ChartDragMode.mainChart:
                              // Pinch Zoom (2+ touch points or continuous scaling gesture)
                              if (details.pointerCount >= 2 ||
                                  _isPinching ||
                                  (details.scale - 1.0).abs() > 0.01) {
                                _isPinching = true;
                                final scaleRatio = details.scale / _lastScale;
                                controller.onZoom(scaleRatio, details.localFocalPoint);
                                _lastScale = details.scale;
                              } else {
                                // Single-pointer Pan
                                if (deltaX.abs() > 0.1) {
                                  controller.onPan(deltaX);
                                }
                                if (controller.isManualPriceScale && deltaY.abs() > 0.1) {
                                  controller.onVerticalPan(deltaY, timeAxisTop);
                                }
                                // Update crosshair tracking
                                if (details.localFocalPoint.dx < priceAxisLeft &&
                                    details.localFocalPoint.dy < timeAxisTop) {
                                  controller.setCrosshairPosition(details.localFocalPoint);
                                }
                              }
                              break;

                            case _ChartDragMode.none:
                              break;
                          }

                          _lastFocalPoint = details.localFocalPoint;
                        },
                        onScaleEnd: (_) {
                          _dragMode = _ChartDragMode.none;
                          _isPinching = false;
                          _lastScale = 1.0;
                        },
                        onDoubleTap: () {
                          // Zone-aware double-tap reset (TradingView behavior)
                          if (_lastTapDownPosition.dx >= priceAxisLeft) {
                            // Double tap on price scale -> reset auto-scale
                            controller.resetPriceScale();
                          } else if (_lastTapDownPosition.dy >= timeAxisTop) {
                            // Double tap on time scale -> reset timeframe zoom
                            controller.resetTimeScale();
                          } else {
                            // Double tap on main chart -> reset complete view
                            controller.resetView();
                          }
                        },
                        onLongPressStart: (details) {
                          if (details.localPosition.dx < priceAxisLeft &&
                              details.localPosition.dy < timeAxisTop) {
                            controller.setCrosshairPosition(details.localPosition);
                          }
                        },
                        onLongPressMoveUpdate: (details) {
                          if (details.localPosition.dx < priceAxisLeft &&
                              details.localPosition.dy < timeAxisTop) {
                            controller.setCrosshairPosition(details.localPosition);
                          }
                        },
                        onLongPressEnd: (_) {
                          controller.setCrosshairPosition(null);
                        },
                        child: ClipRect(
                          child: CustomPaint(
                            size: Size(width, height),
                            painter: ChartPainter(
                              candles: controller.candles,
                              viewport: controller.viewport,
                              theme: controller.theme,
                              timeframe: controller.timeframe,
                              candleStyle: controller.candleStyle,
                              overlayIndicators: controller.overlayResults,
                              subPaneIndicator: controller.subPaneResult,
                              crosshairPosition: controller.crosshairPosition,
                              showVolume: controller.showVolume,
                              showGrid: controller.showGrid,
                              verticalScale: controller.verticalScale,
                              verticalPan: controller.verticalPan,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // TradingView-style "Auto" Scale Pill in the bottom right of the price axis
                    if (controller.isManualPriceScale)
                      Positioned(
                        right: 4,
                        bottom: _timeAxisHeight + 6,
                        child: GestureDetector(
                          key: const Key('auto_scale_pill'),
                          onTap: controller.resetPriceScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2962FF),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_mode, size: 10, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'AUTO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Bottom-right corner reset button (at X/Y intersection)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      width: _priceAxisWidth,
                      height: _timeAxisHeight,
                      child: GestureDetector(
                        onTap: controller.resetView,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.backgroundColor,
                            border: Border(
                              top: BorderSide(color: theme.gridColor, width: 0.8),
                              left: BorderSide(color: theme.gridColor, width: 0.8),
                            ),
                          ),
                          child: Text(
                            controller.isManualPriceScale ? 'RESET' : 'AUTO',
                            style: TextStyle(
                              color: controller.isManualPriceScale
                                  ? const Color(0xFF2962FF)
                                  : theme.axisTextColor.withValues(alpha: 0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
