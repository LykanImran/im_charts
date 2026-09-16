import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/models/chart_alert.dart';
import '../core/models/chart_drawing.dart';
import '../core/models/chart_order.dart';
import '../core/models/chart_position.dart';
import '../engine/chart_controller.dart';
import '../renderer/chart_painter.dart';
import 'replay_control_bar.dart';

enum _ChartDragMode {
  none,
  priceAxis,
  timeAxis,
  mainChart,
  drawingCreation,
  drawingHandle,
  drawingMove,
  horizontalLineDrag,
}

/// Top-level chart presentation widget integrating the custom rendering pipeline,
/// multi-zone scale interactions (Price Axis drag, Time Axis drag, Pinch Zoom),
/// chart trading (hover '+' button, order lines, SL/TP brackets, open positions), and pointer tracking.
class TradingChart extends StatefulWidget {
  final TradingChartController controller;
  final bool enableChartTrading;
  final bool showWatermark;
  final bool showCountdownTimer;
  final String? brandName;
  final GlobalKey? repaintBoundaryKey;
  final Widget Function(
    BuildContext context,
    double price,
    TradingChartController controller,
    VoidCallback closeMenu,
  )? orderMenuBuilder;
  final void Function(ChartOrder order)? onOrderPlaced;
  final void Function(ChartOrder order)? onOrderModified;
  final void Function(String orderId)? onOrderCancelled;
  final void Function(ChartPosition position)? onPositionClosed;

  const TradingChart({
    super.key,
    required this.controller,
    this.enableChartTrading = true,
    this.showWatermark = true,
    this.showCountdownTimer = true,
    this.brandName,
    this.repaintBoundaryKey,
    this.orderMenuBuilder,
    this.onOrderPlaced,
    this.onOrderModified,
    this.onOrderCancelled,
    this.onPositionClosed,
  });

  @override
  State<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends State<TradingChart> {
  static const double _priceAxisWidth = 65.0;
  static const double _timeAxisHeight = 24.0;
  final GlobalKey _defaultRepaintKey = GlobalKey();

  double _lastScale = 1.0;
  double _lastTrackpadScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;
  Offset _lastTapDownPosition = Offset.zero;
  bool _isPinching = false;
  _ChartDragMode _dragMode = _ChartDragMode.none;
  final FocusNode _focusNode = FocusNode();

  // Multi-point tool creation state (click-move-click OR drag-release)
  DrawingPoint? _drawingAnchorPoint;
  bool _hasDraggedDuringCreation = false;
  Offset? _drawingDragStartPos;

  // Selected drawing handle dragging state
  int? _draggingHandleIndex;
  String? _draggingDrawingId;

  // Track hover position for dynamic cursor resolution
  Offset? _hoverPosition;

  // Active order dragging telemetry state
  String? _draggingOrderId;
  String? _draggingKind; // 'order', 'tp', 'sl'
  double? _draggingCurrentPrice;

  MouseCursor _resolveCursor(double width, double height) {
    if (_dragMode == _ChartDragMode.horizontalLineDrag) {
      return SystemMouseCursors.resizeUpDown;
    }

    if (_dragMode == _ChartDragMode.drawingHandle &&
        _draggingDrawingId != null) {
      for (final d in widget.controller.drawings) {
        if (d.id == _draggingDrawingId && _draggingHandleIndex != null) {
          return d.getHandleCursor(_draggingHandleIndex!);
        }
      }
      return SystemMouseCursors.grab;
    }

    if (_hoverPosition == null) return SystemMouseCursors.basic;

    final priceAxisLeft = width - _priceAxisWidth;
    final timeAxisTop = height - _timeAxisHeight;

    final isPriceAxis =
        _hoverPosition!.dx >= priceAxisLeft && _hoverPosition!.dy < timeAxisTop;
    final isTimeAxis =
        _hoverPosition!.dy >= timeAxisTop && _hoverPosition!.dx < priceAxisLeft;
    final isCorner = _hoverPosition!.dx >= priceAxisLeft &&
        _hoverPosition!.dy >= timeAxisTop;

    if (isPriceAxis) {
      return SystemMouseCursors.resizeUpDown;
    } else if (isTimeAxis) {
      return SystemMouseCursors.resizeLeftRight;
    } else if (isCorner) {
      return SystemMouseCursors.click;
    }

    // When a drawing tool is active, show crosshair cursor
    if (widget.controller.activeDrawingTool != DrawingTool.pointer) {
      return SystemMouseCursors.precise;
    }

    // Main canvas cursor resolution
    if (widget.controller.candles.isNotEmpty) {
      final chartWidth = priceAxisLeft;
      final chartHeight = widget.controller.mainPaneHeight;
      final bounds = Rect.fromLTWH(0, 0, chartWidth, chartHeight);
      final converter = CoordinateConverter(
        viewport: widget.controller.viewport,
        totalCandles: widget.controller.candles.length,
      );
      final priceRange = widget.controller.currentPriceRange;

      // 1. Check if hovering over an interactive handle on selected drawing
      final sel = widget.controller.selectedDrawing;
      if (sel != null && !sel.isLocked) {
        final handle = sel.hitTestHandle(
          _hoverPosition!,
          bounds,
          priceRange,
          converter,
        );
        if (handle != null) return sel.getHandleCursor(handle);
        if (sel.hitTest(_hoverPosition!, bounds, priceRange, converter)) {
          return sel.tool == DrawingTool.horizontalLine
              ? SystemMouseCursors.resizeUpDown
              : SystemMouseCursors.move;
        }
      }

      // 2. Check if hovering over any horizontal line (always resizeUpDown like TradingView)
      for (final d in widget.controller.drawings) {
        if (d.tool == DrawingTool.horizontalLine &&
            d.hitTest(_hoverPosition!, bounds, priceRange, converter)) {
          return SystemMouseCursors.resizeUpDown;
        }
      }

      // 3. Check if hovering over any other drawing
      for (final d in widget.controller.drawings) {
        if (d.hitTest(_hoverPosition!, bounds, priceRange, converter)) {
          return SystemMouseCursors.click;
        }
      }
    }

    return SystemMouseCursors.precise;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final controller = widget.controller;

    if (isAlt) {
      if (event.logicalKey == LogicalKeyboardKey.keyH) {
        final price = _hoverPosition != null
            ? double.parse(
                controller.priceAtY(_hoverPosition!.dy).toStringAsFixed(2),
              )
            : (controller.currentCandle?.close ?? 0.0);
        final drawing = ChartDrawing(
          id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
          tool: DrawingTool.horizontalLine,
          points: [
            DrawingPoint(
              candleIndex: controller.candles.length - 1,
              price: price,
            ),
          ],
          color: const Color(0xFF2962FF),
        );
        controller.addDrawing(drawing);
        controller.selectDrawing(drawing.id);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyT) {
        controller.activeDrawingTool = DrawingTool.trendline;
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
        final price = _hoverPosition != null
            ? double.parse(
                controller.priceAtY(_hoverPosition!.dy).toStringAsFixed(2),
              )
            : (controller.currentCandle?.close ?? 0.0);
        final alert = ChartAlert(
          id: 'alt_${DateTime.now().millisecondsSinceEpoch}',
          symbol: controller.symbol,
          price: price,
          note: 'Crossing $price',
          createdAt: DateTime.now(),
        );
        controller.addAlert(alert);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
        controller.resetView();
        return KeyEventResult.handled;
      }
    }

    final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (isCtrlOrCmd) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (isShift) {
          if (controller.canRedo) {
            controller.redo();
            return KeyEventResult.handled;
          }
        } else {
          if (controller.canUndo) {
            controller.undo();
            return KeyEventResult.handled;
          }
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyY) {
        if (controller.canRedo) {
          controller.redo();
          return KeyEventResult.handled;
        }
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (controller.selectedDrawing != null) {
        controller.deleteSelectedDrawing();
        return KeyEventResult.handled;
      }
      final selected = controller.drawings.where((d) => d.isSelected).toList();
      for (final d in selected) {
        controller.removeDrawing(d.id);
      }
      return selected.isNotEmpty
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      controller.onPan(40.0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      controller.onPan(-40.0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.add) {
      controller.zoomIn();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus) {
      controller.zoomOut();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _drawingAnchorPoint = null;
        _hasDraggedDuringCreation = false;
        _draggingHandleIndex = null;
        _draggingDrawingId = null;
      });
      controller.cancelActiveDrawing();
      controller.selectDrawing(null);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.isLoading) {
                return Container(
                  color: controller.theme.backgroundColor,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF2962FF),
                      ),
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

                    // If actively drawing a multi-point tool, update preview
                    if (controller.activeDrawingTool != DrawingTool.pointer &&
                        _drawingAnchorPoint != null &&
                        controller.candles.isNotEmpty) {
                      final converter = CoordinateConverter(
                        viewport: controller.viewport,
                        totalCandles: controller.candles.length,
                      );
                      final hoverIndex = converter.xToIndex(pos.dx);
                      final hoverPrice = double.parse(
                        controller.priceAtY(pos.dy).toStringAsFixed(2),
                      );
                      controller.setPreviewDrawing(
                        ChartDrawing(
                          id: 'preview',
                          tool: controller.activeDrawingTool,
                          points: [
                            _drawingAnchorPoint!,
                            DrawingPoint(
                              candleIndex: hoverIndex,
                              price: hoverPrice,
                            ),
                          ],
                          color: const Color(0xFF2962FF).withValues(alpha: 0.8),
                        ),
                      );
                    }
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
                      if (controller.isManualPriceScale &&
                          event.panDelta.dy.abs() > 0.1) {
                        controller.onVerticalPan(
                          event.panDelta.dy,
                          timeAxisTop,
                        );
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
                          final zoomFactor =
                              math.exp(-dy * 0.003).clamp(0.7, 1.3);
                          controller.onZoom(zoomFactor, pos);
                        }
                      }
                    }
                  },
                  child: Stack(
                    children: [
                      // Main interactive canvas gesture detector
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (event) {
                            _lastTapDownPosition = event.localPosition;
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) {
                              _lastTapDownPosition = details.localPosition;
                              final pos = details.localPosition;

                              // Handle drawing tool interaction
                              if (controller.activeDrawingTool !=
                                      DrawingTool.pointer &&
                                  pos.dx < priceAxisLeft &&
                                  pos.dy < timeAxisTop &&
                                  controller.candles.isNotEmpty) {
                                final converter = CoordinateConverter(
                                  viewport: controller.viewport,
                                  totalCandles: controller.candles.length,
                                );
                                final clickedIndex = converter.xToIndex(pos.dx);
                                final clickedPrice = double.parse(
                                  controller
                                      .priceAtY(pos.dy)
                                      .toStringAsFixed(2),
                                );
                                final tool = controller.activeDrawingTool;

                                final rawPoint = DrawingPoint(
                                  candleIndex: clickedIndex,
                                  price: clickedPrice,
                                );
                                final snappedPoint =
                                    controller.snapPointToCandle(rawPoint);

                                if (tool == DrawingTool.horizontalLine ||
                                    tool == DrawingTool.horizontalRay ||
                                    tool == DrawingTool.verticalLine) {
                                  final Color drawingColor;
                                  if (tool == DrawingTool.verticalLine) {
                                    drawingColor = const Color(0xFFFF9100);
                                  } else if (tool ==
                                      DrawingTool.horizontalRay) {
                                    drawingColor = const Color(0xFF00E676);
                                  } else {
                                    drawingColor = const Color(0xFF00E5FF);
                                  }

                                  final drawing = ChartDrawing(
                                    id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
                                    tool: tool,
                                    points: [snappedPoint],
                                    color: drawingColor,
                                  );
                                  controller.addDrawing(drawing);
                                  controller.selectDrawing(drawing.id);
                                  controller.activeDrawingTool =
                                      DrawingTool.pointer;
                                } else if (tool == DrawingTool.longPosition ||
                                    tool == DrawingTool.shortPosition) {
                                  final isLong =
                                      tool == DrawingTool.longPosition;
                                  final drawing = ChartDrawing(
                                    id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
                                    tool: tool,
                                    points: [snappedPoint],
                                    properties: {
                                      'targetPrice': double.parse(
                                        (isLong
                                                ? snappedPoint.price * 1.015
                                                : snappedPoint.price * 0.985)
                                            .toStringAsFixed(2),
                                      ),
                                      'stopPrice': double.parse(
                                        (isLong
                                                ? snappedPoint.price * 0.9925
                                                : snappedPoint.price * 1.0075)
                                            .toStringAsFixed(2),
                                      ),
                                      'widthSpan': 40 * 11.0,
                                    },
                                  );
                                  controller.addDrawing(drawing);
                                  controller.selectDrawing(drawing.id);
                                  controller.activeDrawingTool =
                                      DrawingTool.pointer;
                                } else {
                                  // Multi-point tools (trendline, rectangle, fibonacci, ruler)
                                  if (_drawingAnchorPoint == null) {
                                    setState(() {
                                      _drawingAnchorPoint = snappedPoint;
                                      _hasDraggedDuringCreation = false;
                                      _drawingDragStartPos = pos;
                                    });
                                  } else {
                                    // Second click in Click-Move-Click mode!
                                    final drawing = ChartDrawing(
                                      id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
                                      tool: tool,
                                      points: [
                                        _drawingAnchorPoint!,
                                        snappedPoint,
                                      ],
                                      color: tool == DrawingTool.rectangle
                                          ? const Color(0xFFFFB300)
                                          : const Color(0xFF2962FF),
                                    );
                                    controller.addDrawing(drawing);
                                    controller.selectDrawing(drawing.id);
                                    setState(() {
                                      _drawingAnchorPoint = null;
                                      _hasDraggedDuringCreation = false;
                                    });
                                    controller.setPreviewDrawing(null);
                                    controller.activeDrawingTool =
                                        DrawingTool.pointer;
                                  }
                                }
                                return;
                              }
                            },
                            onTapUp: (details) {
                              final pos = details.localPosition;
                              // If in pointer mode, check if user tapped on a drawing or handle to select it
                              if (controller.activeDrawingTool ==
                                      DrawingTool.pointer &&
                                  pos.dx < priceAxisLeft &&
                                  pos.dy < timeAxisTop &&
                                  controller.candles.isNotEmpty) {
                                final chartWidth = priceAxisLeft;
                                final chartHeight = controller.mainPaneHeight;
                                final bounds = Rect.fromLTWH(
                                  0,
                                  0,
                                  chartWidth,
                                  chartHeight,
                                );
                                final converter = CoordinateConverter(
                                  viewport: controller.viewport,
                                  totalCandles: controller.candles.length,
                                );
                                final priceRange = controller.currentPriceRange;

                                ChartDrawing? tappedDrawing;
                                for (final d in controller.drawings.reversed) {
                                  if (d.hitTest(
                                    pos,
                                    bounds,
                                    priceRange,
                                    converter,
                                  )) {
                                    tappedDrawing = d;
                                    break;
                                  }
                                }
                                controller.selectDrawing(tappedDrawing?.id);
                              }
                            },
                            onScaleStart: (details) {
                              final start = details.localFocalPoint;
                              _lastFocalPoint = start;
                              _lastScale = 1.0;
                              _isPinching = false;

                              // If a drawing tool is currently active
                              if (controller.activeDrawingTool !=
                                  DrawingTool.pointer) {
                                _dragMode = _ChartDragMode.drawingCreation;
                                _drawingDragStartPos = start;
                                if (_drawingAnchorPoint == null &&
                                    start.dx < priceAxisLeft &&
                                    start.dy < timeAxisTop &&
                                    controller.candles.isNotEmpty) {
                                  final converter = CoordinateConverter(
                                    viewport: controller.viewport,
                                    totalCandles: controller.candles.length,
                                  );
                                  final clickedIndex = converter.xToIndex(
                                    start.dx,
                                  );
                                  final clickedPrice = double.parse(
                                    controller
                                        .priceAtY(start.dy)
                                        .toStringAsFixed(2),
                                  );
                                  _drawingAnchorPoint = DrawingPoint(
                                    candleIndex: clickedIndex,
                                    price: clickedPrice,
                                  );
                                  _hasDraggedDuringCreation = false;
                                }
                                return;
                              }

                              // Pointer tool active
                              if (start.dx >= priceAxisLeft &&
                                  start.dy < timeAxisTop) {
                                _dragMode = _ChartDragMode.priceAxis;
                              } else if (start.dy >= timeAxisTop &&
                                  start.dx < priceAxisLeft) {
                                _dragMode = _ChartDragMode.timeAxis;
                              } else if (start.dx >= priceAxisLeft &&
                                  start.dy >= timeAxisTop) {
                                _dragMode = _ChartDragMode.none;
                                controller.resetView();
                              } else {
                                // In main chart canvas
                                if (controller.candles.isNotEmpty) {
                                  final chartWidth = priceAxisLeft;
                                  final chartHeight = controller.mainPaneHeight;
                                  final bounds = Rect.fromLTWH(
                                    0,
                                    0,
                                    chartWidth,
                                    chartHeight,
                                  );
                                  final converter = CoordinateConverter(
                                    viewport: controller.viewport,
                                    totalCandles: controller.candles.length,
                                  );
                                  final priceRange =
                                      controller.currentPriceRange;

                                  // 1. Check if dragging a handle on the selected drawing
                                  final sel = controller.selectedDrawing;
                                  if (sel != null && !sel.isLocked) {
                                    final handle = sel.hitTestHandle(
                                          start,
                                          bounds,
                                          priceRange,
                                          converter,
                                        ) ??
                                        sel.hitTestHandle(
                                          _lastTapDownPosition,
                                          bounds,
                                          priceRange,
                                          converter,
                                        );
                                    if (handle != null) {
                                      controller.recordDrawingSnapshot();
                                      _draggingHandleIndex = handle;
                                      _draggingDrawingId = sel.id;
                                      if (sel.tool ==
                                              DrawingTool.horizontalLine ||
                                          sel.tool ==
                                              DrawingTool.horizontalRay) {
                                        _dragMode =
                                            _ChartDragMode.horizontalLineDrag;
                                      } else {
                                        _dragMode =
                                            _ChartDragMode.drawingHandle;
                                      }
                                      return;
                                    }
                                  }

                                  // 2. Check if clicking on any drawing to move it
                                  ChartDrawing? hitDrawing;
                                  for (final d
                                      in controller.drawings.reversed) {
                                    if (d.hitTest(
                                          start,
                                          bounds,
                                          priceRange,
                                          converter,
                                        ) ||
                                        d.hitTest(
                                          _lastTapDownPosition,
                                          bounds,
                                          priceRange,
                                          converter,
                                        )) {
                                      hitDrawing = d;
                                      break;
                                    }
                                  }

                                  if (hitDrawing != null) {
                                    controller.selectDrawing(hitDrawing.id);
                                    if (!hitDrawing.isLocked) {
                                      controller.recordDrawingSnapshot();
                                      _draggingDrawingId = hitDrawing.id;
                                      if (hitDrawing.tool ==
                                              DrawingTool.horizontalLine ||
                                          hitDrawing.tool ==
                                              DrawingTool.horizontalRay) {
                                        _dragMode =
                                            _ChartDragMode.horizontalLineDrag;
                                      } else {
                                        _dragMode = _ChartDragMode.drawingMove;
                                      }
                                      return;
                                    }
                                  }
                                }

                                _dragMode = _ChartDragMode.mainChart;
                              }
                            },
                            onScaleUpdate: (details) {
                              final deltaX = details.localFocalPoint.dx -
                                  _lastFocalPoint.dx;
                              final deltaY = details.localFocalPoint.dy -
                                  _lastFocalPoint.dy;

                              switch (_dragMode) {
                                case _ChartDragMode.drawingCreation:
                                  if (_drawingAnchorPoint != null &&
                                      controller.candles.isNotEmpty) {
                                    final dist = (details.localFocalPoint -
                                            (_drawingDragStartPos ??
                                                details.localFocalPoint))
                                        .distance;
                                    if (dist > 8.0) {
                                      _hasDraggedDuringCreation = true;
                                    }
                                    final converter = CoordinateConverter(
                                      viewport: controller.viewport,
                                      totalCandles: controller.candles.length,
                                    );
                                    final hoverIndex = converter.xToIndex(
                                      details.localFocalPoint.dx,
                                    );
                                    final hoverPrice = double.parse(
                                      controller
                                          .priceAtY(details.localFocalPoint.dy)
                                          .toStringAsFixed(2),
                                    );
                                    controller.setPreviewDrawing(
                                      ChartDrawing(
                                        id: 'preview',
                                        tool: controller.activeDrawingTool,
                                        points: [
                                          _drawingAnchorPoint!,
                                          DrawingPoint(
                                            candleIndex: hoverIndex,
                                            price: hoverPrice,
                                          ),
                                        ],
                                        color: controller.activeDrawingTool ==
                                                DrawingTool.rectangle
                                            ? const Color(
                                                0xFFFFB300,
                                              ).withValues(alpha: 0.8)
                                            : const Color(
                                                0xFF2962FF,
                                              ).withValues(alpha: 0.8),
                                      ),
                                    );
                                  }
                                  break;

                                case _ChartDragMode.horizontalLineDrag:
                                  if (_draggingDrawingId != null &&
                                      controller.candles.isNotEmpty) {
                                    final newPrice = double.parse(
                                      controller
                                          .priceAtY(details.localFocalPoint.dy)
                                          .toStringAsFixed(2),
                                    );
                                    final index =
                                        controller.drawings.indexWhere(
                                      (d) => d.id == _draggingDrawingId,
                                    );
                                    if (index >= 0) {
                                      final drawing =
                                          controller.drawings[index];
                                      final raw = DrawingPoint(
                                        candleIndex:
                                            drawing.points[0].candleIndex,
                                        price: newPrice,
                                      );
                                      final snapped =
                                          controller.snapPointToCandle(raw);
                                      controller.updateDrawing(
                                        drawing.copyWith(
                                          points: [snapped],
                                        ),
                                      );
                                    }
                                  }
                                  break;

                                case _ChartDragMode.drawingHandle:
                                  if (_draggingDrawingId != null &&
                                      _draggingHandleIndex != null &&
                                      controller.candles.isNotEmpty) {
                                    final converter = CoordinateConverter(
                                      viewport: controller.viewport,
                                      totalCandles: controller.candles.length,
                                    );
                                    final newIndex = converter.xToIndex(
                                      details.localFocalPoint.dx,
                                    );
                                    final newPrice = double.parse(
                                      controller
                                          .priceAtY(details.localFocalPoint.dy)
                                          .toStringAsFixed(2),
                                    );

                                    final index =
                                        controller.drawings.indexWhere(
                                      (d) => d.id == _draggingDrawingId,
                                    );
                                    if (index >= 0) {
                                      final drawing =
                                          controller.drawings[index];
                                      if (drawing.isLocked) break;

                                      if (drawing.tool ==
                                              DrawingTool.rectangle &&
                                          drawing.points.length >= 2) {
                                        final p0 = drawing.points[0];
                                        final p1 = drawing.points[1];

                                        // Canonical boundaries of the rectangle
                                        var minC = math.min(
                                          p0.candleIndex,
                                          p1.candleIndex,
                                        );
                                        var maxC = math.max(
                                          p0.candleIndex,
                                          p1.candleIndex,
                                        );
                                        var maxP = math.max(
                                          p0.price,
                                          p1.price,
                                        ); // Top price
                                        var minP = math.min(
                                          p0.price,
                                          p1.price,
                                        ); // Bottom price

                                        switch (_draggingHandleIndex) {
                                          case 0: // Top-Left corner
                                            minC = newIndex;
                                            maxP = newPrice;
                                            break;
                                          case 1: // Top-Right corner
                                            maxC = newIndex;
                                            maxP = newPrice;
                                            break;
                                          case 2: // Bottom-Right corner
                                            maxC = newIndex;
                                            minP = newPrice;
                                            break;
                                          case 3: // Bottom-Left corner
                                            minC = newIndex;
                                            minP = newPrice;
                                            break;
                                          case 4: // Top Edge
                                            maxP = newPrice;
                                            break;
                                          case 5: // Right Edge
                                            maxC = newIndex;
                                            break;
                                          case 6: // Bottom Edge
                                            minP = newPrice;
                                            break;
                                          case 7: // Left Edge
                                            minC = newIndex;
                                            break;
                                        }

                                        controller.updateDrawing(
                                          drawing.copyWith(
                                            points: [
                                              DrawingPoint(
                                                candleIndex: minC,
                                                price: maxP,
                                              ),
                                              DrawingPoint(
                                                candleIndex: maxC,
                                                price: minP,
                                              ),
                                            ],
                                          ),
                                        );
                                      } else if (drawing.tool ==
                                          DrawingTool.horizontalLine) {
                                        controller.updateDrawing(
                                          drawing.copyWith(
                                            points: [
                                              DrawingPoint(
                                                candleIndex: drawing
                                                    .points[0].candleIndex,
                                                price: newPrice,
                                              ),
                                            ],
                                          ),
                                        );
                                      } else if (drawing.tool ==
                                              DrawingTool.trendline ||
                                          drawing.tool == DrawingTool.ruler ||
                                          drawing.tool ==
                                              DrawingTool.fibonacci) {
                                        if (_draggingHandleIndex! <
                                            drawing.points.length) {
                                          final updatedPoints =
                                              List<DrawingPoint>.from(
                                            drawing.points,
                                          );
                                          updatedPoints[_draggingHandleIndex!] =
                                              DrawingPoint(
                                            candleIndex: newIndex,
                                            price: newPrice,
                                          );
                                          controller.updateDrawing(
                                            drawing.copyWith(
                                              points: updatedPoints,
                                            ),
                                          );
                                        }
                                      } else if (drawing.tool ==
                                              DrawingTool.longPosition ||
                                          drawing.tool ==
                                              DrawingTool.shortPosition) {
                                        final entryX = converter.indexToX(
                                          drawing.points[0].candleIndex,
                                        );
                                        if (_draggingHandleIndex == 0) {
                                          controller.updateDrawingProperties(
                                            drawing.id,
                                            {'targetPrice': newPrice},
                                          );
                                        } else if (_draggingHandleIndex == 1) {
                                          controller.updateDrawingProperties(
                                            drawing.id,
                                            {'stopPrice': newPrice},
                                          );
                                        } else if (_draggingHandleIndex == 2) {
                                          controller.updateDrawingPoint(
                                            drawing.id,
                                            0,
                                            DrawingPoint(
                                              candleIndex: newIndex,
                                              price: newPrice,
                                            ),
                                          );
                                        } else if (_draggingHandleIndex == 3) {
                                          final span =
                                              (details.localFocalPoint.dx -
                                                      entryX)
                                                  .clamp(50.0, 1500.0);
                                          controller.updateDrawingProperties(
                                            drawing.id,
                                            {'widthSpan': span},
                                          );
                                        }
                                      }
                                    }
                                  }
                                  break;

                                case _ChartDragMode.drawingMove:
                                  if (_draggingDrawingId != null &&
                                      controller.candles.isNotEmpty) {
                                    final converter = CoordinateConverter(
                                      viewport: controller.viewport,
                                      totalCandles: controller.candles.length,
                                    );
                                    final prevIndex = converter.xToIndex(
                                      _lastFocalPoint.dx,
                                    );
                                    final currIndex = converter.xToIndex(
                                      details.localFocalPoint.dx,
                                    );
                                    final deltaCandles = currIndex - prevIndex;

                                    final prevPrice = controller.priceAtY(
                                      _lastFocalPoint.dy,
                                    );
                                    final currPrice = controller.priceAtY(
                                      details.localFocalPoint.dy,
                                    );
                                    final deltaPrice = currPrice - prevPrice;

                                    if (deltaCandles != 0 ||
                                        deltaPrice.abs() > 0.001) {
                                      controller.translateDrawing(
                                        _draggingDrawingId!,
                                        deltaCandles,
                                        deltaPrice,
                                      );
                                    }
                                  }
                                  break;

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
                                  if (details.pointerCount >= 2 ||
                                      _isPinching ||
                                      (details.scale - 1.0).abs() > 0.01) {
                                    _isPinching = true;
                                    final scaleRatio =
                                        details.scale / _lastScale;
                                    controller.onZoom(
                                      scaleRatio,
                                      details.localFocalPoint,
                                    );
                                    _lastScale = details.scale;
                                  } else {
                                    if (deltaX.abs() > 0.1) {
                                      controller.onPan(deltaX);
                                    }
                                    if (controller.isManualPriceScale &&
                                        deltaY.abs() > 0.1) {
                                      controller.onVerticalPan(
                                        deltaY,
                                        timeAxisTop,
                                      );
                                    }
                                    if (details.localFocalPoint.dx <
                                            priceAxisLeft &&
                                        details.localFocalPoint.dy <
                                            timeAxisTop) {
                                      controller.setCrosshairPosition(
                                        details.localFocalPoint,
                                      );
                                    }
                                  }
                                  break;

                                case _ChartDragMode.none:
                                  break;
                              }

                              _lastFocalPoint = details.localFocalPoint;
                            },
                            onScaleEnd: (_) {
                              if (_dragMode == _ChartDragMode.drawingCreation) {
                                if (_hasDraggedDuringCreation &&
                                    _drawingAnchorPoint != null &&
                                    controller.previewDrawing != null) {
                                  final completed = ChartDrawing(
                                    id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
                                    tool: controller.activeDrawingTool,
                                    points: controller.previewDrawing!.points,
                                    color: controller.activeDrawingTool ==
                                            DrawingTool.rectangle
                                        ? const Color(0xFFFFB300)
                                        : const Color(0xFF2962FF),
                                  );
                                  controller.addDrawing(completed);
                                  controller.selectDrawing(completed.id);
                                  controller.setPreviewDrawing(null);
                                  setState(() {
                                    _drawingAnchorPoint = null;
                                    _hasDraggedDuringCreation = false;
                                  });
                                  controller.activeDrawingTool =
                                      DrawingTool.pointer;
                                }
                              }

                              _draggingHandleIndex = null;
                              _draggingDrawingId = null;
                              _dragMode = _ChartDragMode.none;
                              _isPinching = false;
                              _lastScale = 1.0;
                            },
                            onDoubleTap: () {
                              // Zone-aware double-tap reset (TradingView behavior)
                              if (_lastTapDownPosition.dx >= priceAxisLeft) {
                                // Double tap on price scale -> reset auto-scale
                                controller.resetPriceScale();
                              } else if (_lastTapDownPosition.dy >=
                                  timeAxisTop) {
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
                                controller.setCrosshairPosition(
                                  details.localPosition,
                                );
                              }
                            },
                            onLongPressMoveUpdate: (details) {
                              if (details.localPosition.dx < priceAxisLeft &&
                                  details.localPosition.dy < timeAxisTop) {
                                controller.setCrosshairPosition(
                                  details.localPosition,
                                );
                              }
                            },
                            onLongPressEnd: (_) {
                              controller.setCrosshairPosition(null);
                            },
                            child: RepaintBoundary(
                              key: widget.repaintBoundaryKey ??
                                  _defaultRepaintKey,
                              child: ClipRect(
                                child: CustomPaint(
                                  size: Size(width, height),
                                  painter: ChartPainter(
                                    candles: controller.candles,
                                    viewport: controller.viewport,
                                    theme: controller.theme,
                                    timeframe: controller.timeframe,
                                    candleStyle: controller.candleStyle,
                                    overlayIndicators:
                                        controller.overlayResults,
                                    subPaneIndicator: controller.subPaneResult,
                                    subPaneIndicators:
                                        controller.subPaneResults,
                                    orders: controller.orders,
                                    positions: controller.positions,
                                    drawings: controller.drawings,
                                    alerts: controller.alerts,
                                    previewDrawing: controller.previewDrawing,
                                    crosshairPosition:
                                        controller.crosshairPosition,
                                    showVolume: controller.showVolume,
                                    showVolumeProfile:
                                        controller.showVolumeProfile,
                                    volumeProfile: controller.volumeProfile,
                                    showGrid: controller.showGrid,
                                    showWatermark: widget.showWatermark &&
                                        controller.showWatermark,
                                    showCountdownTimer:
                                        widget.showCountdownTimer &&
                                            controller.showCountdownTimer,
                                    countdownText:
                                        controller.candleCountdownText,
                                    brandName: widget.brandName ??
                                        controller.brandName,
                                    symbol: controller.symbol,
                                    exchange: controller.exchange,
                                    verticalScale: controller.verticalScale,
                                    verticalPan: controller.verticalPan,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Interactive Order Badges & Hitboxes (Draggable & Cancel)
                      if (widget.enableChartTrading &&
                          controller.orders.isNotEmpty) ...[
                        for (final order in controller.orders)
                          ..._buildOrderInteractiveWidgets(
                            context,
                            controller,
                            order,
                            timeAxisTop,
                          ),
                      ],

                      // Interactive Position Badges & Close Hitboxes
                      if (widget.enableChartTrading &&
                          controller.positions.isNotEmpty) ...[
                        for (final position in controller.positions)
                          ..._buildPositionInteractiveWidgets(
                            context,
                            controller,
                            position,
                            timeAxisTop,
                          ),
                      ],

                      // Hover '+' button on the right side of the canvas (before vertical price axis)
                      if (widget.enableChartTrading &&
                          _hoverPosition != null &&
                          _hoverPosition!.dx < priceAxisLeft &&
                          _hoverPosition!.dy < timeAxisTop &&
                          _hoverPosition!.dy >= 0) ...[
                        Positioned(
                          right: _priceAxisWidth + 2,
                          top: (_hoverPosition!.dy - 11).clamp(
                            2.0,
                            timeAxisTop - 24.0,
                          ),
                          child: _buildPlusOrderButton(
                            context,
                            controller,
                            _hoverPosition!.dy,
                          ),
                        ),
                      ],

                      // Floating Replay Control Bar
                      if (controller.isReplayMode)
                        Positioned(
                          bottom: _timeAxisHeight + 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: ReplayControlBar(controller: controller),
                          ),
                        ),

                      // Floating Drawing Action Bar (when a drawing is selected)
                      if (controller.selectedDrawing != null)
                        Positioned(
                          top: 14,
                          left: 16,
                          child: _buildDrawingActionBar(
                            context,
                            controller,
                            controller.selectedDrawing!,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
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
                                  Icon(
                                    Icons.auto_mode,
                                    size: 10,
                                    color: Colors.white,
                                  ),
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
                                top: BorderSide(
                                  color: theme.gridColor,
                                  width: 0.8,
                                ),
                                left: BorderSide(
                                  color: theme.gridColor,
                                  width: 0.8,
                                ),
                              ),
                            ),
                            child: Text(
                              controller.isManualPriceScale ? 'RESET' : 'AUTO',
                              style: TextStyle(
                                color: controller.isManualPriceScale
                                    ? const Color(0xFF2962FF)
                                    : theme.axisTextColor.withValues(
                                        alpha: 0.6,
                                      ),
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
          ),
        );
      },
    );
  }

  Widget _buildPlusOrderButton(
    BuildContext context,
    TradingChartController controller,
    double y,
  ) {
    final price = controller.priceAtY(y);

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'Order @ ${price.toStringAsFixed(2)}',
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          key: const Key('chart_plus_order_button'),
          onTap: () => _openOrderMenu(context, controller, y, price),
          borderRadius: BorderRadius.circular(11),
          hoverColor: const Color(0xFF2962FF).withValues(alpha: 0.3),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFF2962FF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2962FF).withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  void _openOrderMenu(
    BuildContext context,
    TradingChartController controller,
    double y,
    double price,
  ) {
    final roundedPrice = double.parse(price.toStringAsFixed(2));

    if (widget.orderMenuBuilder != null) {
      showDialog(
        context: context,
        builder: (ctx) => widget.orderMenuBuilder!(
          ctx,
          roundedPrice,
          controller,
          () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    // Default institutional Order Dropdown Menu
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonPosition = renderBox.localToGlobal(
      Offset(renderBox.size.width - _priceAxisWidth - 10, y),
    );

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(buttonPosition.dx, buttonPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    );

    final messenger = ScaffoldMessenger.maybeOf(context);

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1E222D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2A2E39), width: 1),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'buy',
          height: 38,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Buy 100 Limit @ $roundedPrice',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sell',
          height: 38,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sell 100 Limit @ $roundedPrice',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'buy_bracket',
          height: 38,
          child: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 14,
                color: Color(0xFF00E5FF),
              ),
              const SizedBox(width: 8),
              Text(
                'Buy + TP (+1.5%) + SL (-1.0%)',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sell_bracket',
          height: 38,
          child: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 14,
                color: Color(0xFFFF9100),
              ),
              const SizedBox(width: 8),
              Text(
                'Sell + TP (-1.5%) + SL (+1.0%)',
                style: const TextStyle(
                  color: Color(0xFFFF9100),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'add_alert',
          height: 38,
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 14,
                color: Color(0xFFFFB300),
              ),
              const SizedBox(width: 8),
              Text(
                'Add Alert @ $roundedPrice',
                style: const TextStyle(
                  color: Color(0xFFFFB300),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (choice == null) return;

      if (choice == 'buy') {
        final order = ChartOrder(
          id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
          symbol: controller.symbol,
          side: OrderSide.buy,
          type: OrderType.limit,
          price: roundedPrice,
          quantity: 100,
        );
        controller.placeOrder(order);
        widget.onOrderPlaced?.call(order);
      } else if (choice == 'sell') {
        final order = ChartOrder(
          id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
          symbol: controller.symbol,
          side: OrderSide.sell,
          type: OrderType.limit,
          price: roundedPrice,
          quantity: 100,
        );
        controller.placeOrder(order);
        widget.onOrderPlaced?.call(order);
      } else if (choice == 'buy_bracket') {
        final tp = double.parse((roundedPrice * 1.015).toStringAsFixed(2));
        final sl = double.parse((roundedPrice * 0.990).toStringAsFixed(2));
        final order = ChartOrder(
          id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
          symbol: controller.symbol,
          side: OrderSide.buy,
          type: OrderType.limit,
          price: roundedPrice,
          quantity: 100,
          takeProfitPrice: tp,
          stopLossPrice: sl,
        );
        controller.placeOrder(order);
        widget.onOrderPlaced?.call(order);
      } else if (choice == 'sell_bracket') {
        final tp = double.parse((roundedPrice * 0.985).toStringAsFixed(2));
        final sl = double.parse((roundedPrice * 1.010).toStringAsFixed(2));
        final order = ChartOrder(
          id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
          symbol: controller.symbol,
          side: OrderSide.sell,
          type: OrderType.limit,
          price: roundedPrice,
          quantity: 100,
          takeProfitPrice: tp,
          stopLossPrice: sl,
        );
        controller.placeOrder(order);
        widget.onOrderPlaced?.call(order);
      } else if (choice == 'add_alert') {
        final alert = ChartAlert(
          id: 'alt_${DateTime.now().millisecondsSinceEpoch}',
          symbol: controller.symbol,
          price: roundedPrice,
          note: 'Crossing $roundedPrice',
          createdAt: DateTime.now(),
        );
        controller.addAlert(alert);
        messenger?.clearSnackBars();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              '🔔 Alert set at ₹$roundedPrice for ${controller.symbol}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: const Color(0xFF1E222D),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }
    });
  }

  List<Widget> _buildOrderInteractiveWidgets(
    BuildContext context,
    TradingChartController controller,
    ChartOrder order,
    double timeAxisTop,
  ) {
    final orderY = controller.yAtPrice(order.price);
    final tpY = order.hasTakeProfit
        ? controller.yAtPrice(order.takeProfitPrice!)
        : null;
    final slY =
        order.hasStopLoss ? controller.yAtPrice(order.stopLossPrice!) : null;

    final isThisOrderDragging = _draggingOrderId == order.id;

    return [
      // 1. Order Badge Interactive Hitbox (Draggable & Cancel)
      if (orderY >= 0 && orderY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 18,
          top: (orderY - 11).clamp(0.0, timeAxisTop - 22.0),
          child: SizedBox(
            width: 175,
            height: 22,
            child: Row(
              children: [
                // Quick bracket add button if no TP or SL
                if (!order.hasTakeProfit || !order.hasStopLoss)
                  GestureDetector(
                    key: Key('bracket_order_${order.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openBracketMenu(context, controller, order),
                    child: Container(
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2962FF).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        '+Bracket',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Draggable drag handle for adjusting limit price
                Expanded(
                  child: Tooltip(
                    message: 'Drag up/down to adjust limit price',
                    waitDuration: const Duration(milliseconds: 500),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (_) {
                          setState(() {
                            _draggingOrderId = order.id;
                            _draggingKind = 'order';
                            _draggingCurrentPrice = order.price;
                          });
                        },
                        onVerticalDragUpdate: (details) {
                          final currentY = controller.yAtPrice(order.price);
                          final newY = (currentY + details.delta.dy).clamp(
                            0.0,
                            timeAxisTop,
                          );
                          final newPrice = double.parse(
                            controller.priceAtY(newY).toStringAsFixed(2),
                          );
                          controller.updateOrderPrice(order.id, newPrice);
                          setState(() {
                            _draggingCurrentPrice = newPrice;
                          });
                        },
                        onVerticalDragEnd: (_) {
                          setState(() {
                            _draggingOrderId = null;
                            _draggingKind = null;
                            _draggingCurrentPrice = null;
                          });
                          final updated = controller.orders.firstWhere(
                            (o) => o.id == order.id,
                            orElse: () => order,
                          );
                          widget.onOrderModified?.call(updated);
                        },
                        onVerticalDragCancel: () {
                          setState(() {
                            _draggingOrderId = null;
                            _draggingKind = null;
                            _draggingCurrentPrice = null;
                          });
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                // Cancel order button (✖) at the right end of the badge
                Tooltip(
                  message: 'Cancel Order',
                  waitDuration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    key: Key('cancel_order_${order.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller.cancelOrder(order.id);
                      widget.onOrderCancelled?.call(order.id);
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

      // Floating Live Drag Telemetry Badge for Order Limit
      if (isThisOrderDragging && _draggingKind == 'order' && orderY >= 0 && orderY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 200,
          top: (orderY - 14).clamp(0.0, timeAxisTop - 28.0),
          child: _buildDragTelemetryChip(
            title: 'LIMIT ${order.isBuy ? 'BUY' : 'SELL'}',
            value: '₹${(_draggingCurrentPrice ?? order.price).toStringAsFixed(2)} (Qty: ${order.quantity.toStringAsFixed(order.quantity % 1 == 0 ? 0 : 2)})',
            accentColor: order.isBuy ? const Color(0xFF00E676) : const Color(0xFFFF3B30),
          ),
        ),

      // 2. Take Profit (TP) Interactive Hitbox (Draggable & Cancel)
      if (tpY != null && tpY >= 0 && tpY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 18,
          top: (tpY - 11).clamp(0.0, timeAxisTop - 22.0),
          child: SizedBox(
            width: 145,
            height: 22,
            child: Row(
              children: [
                // Draggable zone for Take Profit price
                Expanded(
                  child: Tooltip(
                    message: 'Drag up/down to adjust TP',
                    waitDuration: const Duration(milliseconds: 500),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (_) {
                          setState(() {
                            _draggingOrderId = order.id;
                            _draggingKind = 'tp';
                            _draggingCurrentPrice = order.takeProfitPrice;
                          });
                        },
                        onVerticalDragUpdate: (details) {
                          final currentY = controller.yAtPrice(
                            order.takeProfitPrice!,
                          );
                          final newY = (currentY + details.delta.dy).clamp(
                            0.0,
                            timeAxisTop,
                          );
                          final newPrice = double.parse(
                            controller.priceAtY(newY).toStringAsFixed(2),
                          );
                          controller.updateOrderBrackets(
                            order.id,
                            takeProfitPrice: newPrice,
                          );
                          setState(() {
                            _draggingCurrentPrice = newPrice;
                          });
                        },
                        onVerticalDragEnd: (_) {
                          setState(() {
                            _draggingOrderId = null;
                            _draggingKind = null;
                            _draggingCurrentPrice = null;
                          });
                          final updated = controller.orders.firstWhere(
                            (o) => o.id == order.id,
                            orElse: () => order,
                          );
                          widget.onOrderModified?.call(updated);
                        },
                        onVerticalDragCancel: () {
                          setState(() {
                            _draggingOrderId = null;
                            _draggingKind = null;
                            _draggingCurrentPrice = null;
                          });
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                // Cancel TP button
                Tooltip(
                  message: 'Remove Take Profit',
                  waitDuration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    key: Key('cancel_tp_${order.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller.updateOrderBrackets(
                        order.id,
                        clearTakeProfit: true,
                      );
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

      // Floating Live Drag Telemetry Badge for TP
      if (isThisOrderDragging && _draggingKind == 'tp' && tpY != null && tpY >= 0 && tpY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 170,
          top: (tpY - 14).clamp(0.0, timeAxisTop - 28.0),
          child: Builder(
            builder: (_) {
              final tpPrice = _draggingCurrentPrice ?? order.takeProfitPrice ?? 0.0;
              final diff = (tpPrice - order.price) * (order.isBuy ? 1 : -1);
              final estProfit = diff * order.quantity;
              final pct = order.price > 0 ? (diff / order.price) * 100 : 0.0;
              return _buildDragTelemetryChip(
                title: 'TAKE PROFIT',
                value: '₹${tpPrice.toStringAsFixed(2)} | +₹${estProfit.abs().toStringAsFixed(2)} (+${pct.toStringAsFixed(1)}%)',
                accentColor: const Color(0xFF00E5FF),
              );
            },
          ),
        ),

      // 3. Stop Loss (SL) Interactive Hitbox (Draggable & Cancel)
      if (slY != null && slY >= 0 && slY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 18,
          top: (slY - 11).clamp(0.0, timeAxisTop - 22.0),
          child: SizedBox(
            width: 145,
            height: 22,
            child: Row(
              children: [
                // Draggable zone for Stop Loss price
                Expanded(
                  child: Tooltip(
                    message: 'Drag up/down to adjust SL',
                    waitDuration: const Duration(milliseconds: 500),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (_) {
                          setState(() {
                            _draggingOrderId = order.id;
                            _draggingKind = 'sl';
                            _draggingCurrentPrice = order.stopLossPrice;
                          });
                        },
                        onVerticalDragUpdate: (details) {
                          final currentY = controller.yAtPrice(
                            order.stopLossPrice!,
                          );
                          final newY = (currentY + details.delta.dy).clamp(
                            0.0,
                            timeAxisTop,
                          );
                          final newPrice = double.parse(
                            controller.priceAtY(newY).toStringAsFixed(2),
                          );
                          controller.updateOrderBrackets(
                            order.id,
                            stopLossPrice: newPrice,
                          );
                          setState(() {
                            _draggingCurrentPrice = newPrice;
                          });
                        },
                        onVerticalDragEnd: (_) {
                          setState(() {
                            _draggingOrderId = null;
                            _draggingKind = null;
                            _draggingCurrentPrice = null;
                          });
                          final updated = controller.orders.firstWhere(
                            (o) => o.id == order.id,
                            orElse: () => order,
                          );
                          widget.onOrderModified?.call(updated);
                        },
                        onVerticalDragCancel: () {
                          setState(() {
                            _draggingOrderId = null;
                            _draggingKind = null;
                            _draggingCurrentPrice = null;
                          });
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                // Cancel SL button
                Tooltip(
                  message: 'Remove Stop Loss',
                  waitDuration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    key: Key('cancel_sl_${order.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      controller.updateOrderBrackets(
                        order.id,
                        clearStopLoss: true,
                      );
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

      // Floating Live Drag Telemetry Badge for SL
      if (isThisOrderDragging && _draggingKind == 'sl' && slY != null && slY >= 0 && slY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 170,
          top: (slY - 14).clamp(0.0, timeAxisTop - 28.0),
          child: Builder(
            builder: (_) {
              final slPrice = _draggingCurrentPrice ?? order.stopLossPrice ?? 0.0;
              final diff = (order.price - slPrice) * (order.isBuy ? 1 : -1);
              final estLoss = diff * order.quantity;
              final pct = order.price > 0 ? (diff / order.price) * 100 : 0.0;
              return _buildDragTelemetryChip(
                title: 'STOP LOSS',
                value: '₹${slPrice.toStringAsFixed(2)} | -₹${estLoss.abs().toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
                accentColor: const Color(0xFFFF9100),
              );
            },
          ),
        ),
    ];
  }

  Widget _buildDragTelemetryChip({
    required String title,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF131722).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: accentColor.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title  ',
            style: TextStyle(
              color: accentColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  void _openBracketMenu(
    BuildContext context,
    TradingChartController controller,
    ChartOrder order,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final orderY = controller.yAtPrice(order.price);
    final buttonPosition = renderBox.localToGlobal(
      Offset(renderBox.size.width - _priceAxisWidth - 60, orderY),
    );

    final position = RelativeRect.fromRect(
      Rect.fromLTWH(buttonPosition.dx, buttonPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1E222D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2A2E39), width: 1),
      ),
      items: [
        if (!order.hasTakeProfit)
          const PopupMenuItem<String>(
            value: 'add_tp',
            height: 36,
            child: Row(
              children: [
                Icon(Icons.trending_up, size: 14, color: Color(0xFF00E5FF)),
                SizedBox(width: 8),
                Text(
                  'Add Take Profit (+1.5%)',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        if (!order.hasStopLoss)
          const PopupMenuItem<String>(
            value: 'add_sl',
            height: 36,
            child: Row(
              children: [
                Icon(Icons.trending_down, size: 14, color: Color(0xFFFF9100)),
                SizedBox(width: 8),
                Text(
                  'Add Stop Loss (-1.0%)',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'cancel',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 14, color: Color(0xFFFF3B30)),
              SizedBox(width: 8),
              Text(
                'Cancel Order',
                style: TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'add_tp') {
        final mul = order.isBuy ? 1.015 : 0.985;
        final tp = double.parse((order.price * mul).toStringAsFixed(2));
        controller.updateOrderBrackets(order.id, takeProfitPrice: tp);
      } else if (choice == 'add_sl') {
        final mul = order.isBuy ? 0.990 : 1.010;
        final sl = double.parse((order.price * mul).toStringAsFixed(2));
        controller.updateOrderBrackets(order.id, stopLossPrice: sl);
      } else if (choice == 'cancel') {
        controller.cancelOrder(order.id);
        widget.onOrderCancelled?.call(order.id);
      }
    });
  }

  List<Widget> _buildPositionInteractiveWidgets(
    BuildContext context,
    TradingChartController controller,
    ChartPosition position,
    double timeAxisTop,
  ) {
    final posY = controller.yAtPrice(position.entryPrice);

    return [
      if (posY >= 0 && posY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 18,
          top: (posY - 12).clamp(0.0, timeAxisTop - 24.0),
          child: SizedBox(
            width: 80,
            height: 24,
            child: Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Close Position (Market Order)',
                waitDuration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  key: Key('close_position_${position.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    controller.closePosition(position.id);
                    widget.onPositionClosed?.call(position);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Position closed: ${position.side.label} ${position.quantity.toStringAsFixed(0)} @ ₹${position.entryPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: const Color(0xFF1E222D),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 12, color: Color(0xFFFF5252)),
                        SizedBox(width: 2),
                        Text(
                          'Close',
                          style: TextStyle(
                            color: Color(0xFFFF5252),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildDrawingActionBar(
    BuildContext context,
    TradingChartController controller,
    ChartDrawing drawing,
  ) {
    const swatches = [
      Color(0xFF2962FF), // Blue
      Color(0xFF00E676), // Emerald
      Color(0xFFFF3B30), // Crimson
      Color(0xFFFFB300), // Amber
      Color(0xFFAB47BC), // Purple
      Color(0xFFFFFFFF), // White
    ];

    const strokeWidths = [1.0, 2.0, 3.0, 4.0];

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE61E222D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2E39), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tool Icon & Title
            Icon(drawing.tool.icon, size: 16, color: drawing.color),
            const SizedBox(width: 6),
            Text(
              drawing.tool.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 18, color: const Color(0xFF363A45)),
            const SizedBox(width: 10),

            // Color Swatches
            for (final color in swatches) ...[
              GestureDetector(
                onTap: () => controller.setSelectedDrawingColor(color),
                child: Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: drawing.color == color
                          ? Colors.white
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Container(width: 1, height: 18, color: const Color(0xFF363A45)),
            const SizedBox(width: 8),

            // Stroke Width Selector
            for (final w in strokeWidths) ...[
              InkWell(
                onTap: () => controller.setSelectedDrawingStrokeWidth(w),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: drawing.strokeWidth == w
                        ? const Color(0xFF2962FF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${w.toInt()}px',
                    style: TextStyle(
                      color: drawing.strokeWidth == w
                          ? Colors.white
                          : const Color(0xFF868993),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Container(width: 1, height: 18, color: const Color(0xFF363A45)),
            const SizedBox(width: 6),

            // Lock Toggle
            IconButton(
              tooltip: drawing.isLocked ? 'Unlock Drawing' : 'Lock Drawing',
              icon: Icon(
                drawing.isLocked ? Icons.lock : Icons.lock_open_outlined,
                size: 16,
                color: drawing.isLocked
                    ? const Color(0xFFFFB300)
                    : const Color(0xFF868993),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: controller.toggleSelectedDrawingLocked,
            ),

            // Delete Button
            IconButton(
              key: Key('delete_drawing_${drawing.id}'),
              tooltip: 'Delete Drawing (Del)',
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Color(0xFFFF3B30),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: controller.deleteSelectedDrawing,
            ),

            // Close / Deselect
            IconButton(
              tooltip: 'Deselect (Esc)',
              icon: const Icon(Icons.close, size: 15, color: Color(0xFF868993)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 28),
              onPressed: () => controller.selectDrawing(null),
            ),
          ],
        ),
      ),
    );
  }
}
