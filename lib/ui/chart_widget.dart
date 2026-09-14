import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/models/chart_drawing.dart';
import '../core/models/chart_order.dart';
import '../engine/chart_controller.dart';
import '../renderer/chart_painter.dart';

enum _ChartDragMode { none, priceAxis, timeAxis, mainChart }

/// Top-level chart presentation widget integrating the custom rendering pipeline,
/// multi-zone scale interactions (Price Axis drag, Time Axis drag, Pinch Zoom),
/// chart trading (hover '+' button, order lines, SL/TP brackets), and pointer tracking.
class TradingChart extends StatefulWidget {
  final TradingChartController controller;
  final bool enableChartTrading;
  final bool showWatermark;
  final bool showCountdownTimer;
  final Widget Function(BuildContext context, double price, TradingChartController controller, VoidCallback closeMenu)? orderMenuBuilder;
  final void Function(ChartOrder order)? onOrderPlaced;
  final void Function(String orderId)? onOrderCancelled;

  const TradingChart({
    super.key,
    required this.controller,
    this.enableChartTrading = true,
    this.showWatermark = true,
    this.showCountdownTimer = true,
    this.orderMenuBuilder,
    this.onOrderPlaced,
    this.onOrderCancelled,
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
  DrawingPoint? _drawingAnchorPoint;

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

                  // If actively drawing a multi-point tool, update preview
                  if (controller.activeDrawingTool != DrawingTool.pointer &&
                      _drawingAnchorPoint != null &&
                      controller.candles.isNotEmpty) {
                    final converter = CoordinateConverter(
                      viewport: controller.viewport,
                      totalCandles: controller.candles.length,
                    );
                    final hoverIndex = converter.xToIndex(pos.dx);
                    final hoverPrice = double.parse(controller.priceAtY(pos.dy).toStringAsFixed(2));
                    controller.setPreviewDrawing(ChartDrawing(
                      id: 'preview',
                      tool: controller.activeDrawingTool,
                      points: [
                        _drawingAnchorPoint!,
                        DrawingPoint(candleIndex: hoverIndex, price: hoverPrice),
                      ],
                      color: const Color(0xFF2962FF).withValues(alpha: 0.8),
                    ));
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
                          final pos = details.localPosition;

                          // Handle drawing tool interaction
                          if (controller.activeDrawingTool != DrawingTool.pointer &&
                              pos.dx < priceAxisLeft &&
                              pos.dy < timeAxisTop &&
                              controller.candles.isNotEmpty) {
                            final converter = CoordinateConverter(
                              viewport: controller.viewport,
                              totalCandles: controller.candles.length,
                            );
                            final clickedIndex = converter.xToIndex(pos.dx);
                            final clickedPrice = double.parse(controller.priceAtY(pos.dy).toStringAsFixed(2));
                            final tool = controller.activeDrawingTool;

                            if (tool == DrawingTool.horizontalLine) {
                              controller.addDrawing(ChartDrawing(
                                id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
                                tool: DrawingTool.horizontalLine,
                                points: [DrawingPoint(candleIndex: clickedIndex, price: clickedPrice)],
                                color: const Color(0xFF00E5FF),
                              ));
                              controller.activeDrawingTool = DrawingTool.pointer;
                            } else if (tool == DrawingTool.longPosition || tool == DrawingTool.shortPosition) {
                              final isLong = tool == DrawingTool.longPosition;
                              controller.addDrawing(ChartDrawing(
                                id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
                                tool: tool,
                                points: [DrawingPoint(candleIndex: clickedIndex, price: clickedPrice)],
                                properties: {
                                  'targetPrice': double.parse((isLong ? clickedPrice * 1.015 : clickedPrice * 0.985).toStringAsFixed(2)),
                                  'stopPrice': double.parse((isLong ? clickedPrice * 0.9925 : clickedPrice * 1.0075).toStringAsFixed(2)),
                                },
                              ));
                              controller.activeDrawingTool = DrawingTool.pointer;
                            } else {
                              // Multi-point tools (trendline, fibonacci, ruler)
                              if (_drawingAnchorPoint == null) {
                                setState(() {
                                  _drawingAnchorPoint = DrawingPoint(candleIndex: clickedIndex, price: clickedPrice);
                                });
                              } else {
                                controller.addDrawing(ChartDrawing(
                                  id: 'draw_${DateTime.now().millisecondsSinceEpoch}',
                                  tool: tool,
                                  points: [
                                    _drawingAnchorPoint!,
                                    DrawingPoint(candleIndex: clickedIndex, price: clickedPrice),
                                  ],
                                ));
                                setState(() => _drawingAnchorPoint = null);
                                controller.setPreviewDrawing(null);
                                controller.activeDrawingTool = DrawingTool.pointer;
                              }
                            }
                            return;
                          }
                        },
                        onScaleStart: (details) {
                          if (controller.activeDrawingTool != DrawingTool.pointer) {
                            _dragMode = _ChartDragMode.none;
                            return;
                          }
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
                              orders: controller.orders,
                              drawings: controller.drawings,
                              previewDrawing: controller.previewDrawing,
                              crosshairPosition: controller.crosshairPosition,
                              showVolume: controller.showVolume,
                              showGrid: controller.showGrid,
                              showWatermark: widget.showWatermark && controller.showWatermark,
                              showCountdownTimer: widget.showCountdownTimer && controller.showCountdownTimer,
                              countdownText: controller.candleCountdownText,
                              symbol: controller.symbol,
                              exchange: controller.exchange,
                              verticalScale: controller.verticalScale,
                              verticalPan: controller.verticalPan,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Interactive Order Badges & Hitboxes (Draggable & Cancel)
                    if (widget.enableChartTrading && controller.orders.isNotEmpty) ...[
                      for (final order in controller.orders)
                        ..._buildOrderInteractiveWidgets(context, controller, order, timeAxisTop),
                    ],

                    // Hover '+' button on the right side of the canvas (before vertical price axis)
                    if (widget.enableChartTrading &&
                        _hoverPosition != null &&
                        _hoverPosition!.dx < priceAxisLeft &&
                        _hoverPosition!.dy < timeAxisTop &&
                        _hoverPosition!.dy >= 0) ...[
                      Positioned(
                        right: _priceAxisWidth + 2,
                        top: (_hoverPosition!.dy - 11).clamp(2.0, timeAxisTop - 24.0),
                        child: _buildPlusOrderButton(context, controller, _hoverPosition!.dy),
                      ),
                    ],

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

  Widget _buildPlusOrderButton(BuildContext context, TradingChartController controller, double y) {
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
              child: Icon(
                Icons.add,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openOrderMenu(BuildContext context, TradingChartController controller, double y, double price) {
    final roundedPrice = double.parse(price.toStringAsFixed(2));

    if (widget.orderMenuBuilder != null) {
      showDialog(
        context: context,
        builder: (ctx) => widget.orderMenuBuilder!(ctx, roundedPrice, controller, () => Navigator.of(ctx).pop()),
      );
      return;
    }

    // Default institutional Order Dropdown Menu
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final buttonPosition = renderBox.localToGlobal(Offset(renderBox.size.width - _priceAxisWidth - 10, y));

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
        PopupMenuItem<String>(
          value: 'buy',
          height: 38,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF00E676), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Buy 100 Limit @ $roundedPrice',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
                decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Sell 100 Limit @ $roundedPrice',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
              const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text(
                'Buy + TP (+1.5%) + SL (-1.0%)',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sell_bracket',
          height: 38,
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFFF9100)),
              const SizedBox(width: 8),
              Text(
                'Sell + TP (-1.5%) + SL (+1.0%)',
                style: const TextStyle(color: Color(0xFFFF9100), fontSize: 12, fontWeight: FontWeight.w600),
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
    final tpY = order.hasTakeProfit ? controller.yAtPrice(order.takeProfitPrice!) : null;
    final slY = order.hasStopLoss ? controller.yAtPrice(order.stopLossPrice!) : null;

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
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2962FF).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        '+Bracket',
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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
                        onVerticalDragUpdate: (details) {
                          final currentY = controller.yAtPrice(order.price);
                          final newY = (currentY + details.delta.dy).clamp(0.0, timeAxisTop);
                          final newPrice = double.parse(controller.priceAtY(newY).toStringAsFixed(2));
                          controller.updateOrderPrice(order.id, newPrice);
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
                        onVerticalDragUpdate: (details) {
                          final currentY = controller.yAtPrice(order.takeProfitPrice!);
                          final newY = (currentY + details.delta.dy).clamp(0.0, timeAxisTop);
                          final newPrice = double.parse(controller.priceAtY(newY).toStringAsFixed(2));
                          controller.updateOrderBrackets(order.id, takeProfitPrice: newPrice);
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
                      controller.updateOrderBrackets(order.id, clearTakeProfit: true);
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
                        onVerticalDragUpdate: (details) {
                          final currentY = controller.yAtPrice(order.stopLossPrice!);
                          final newY = (currentY + details.delta.dy).clamp(0.0, timeAxisTop);
                          final newPrice = double.parse(controller.priceAtY(newY).toStringAsFixed(2));
                          controller.updateOrderBrackets(order.id, stopLossPrice: newPrice);
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
                      controller.updateOrderBrackets(order.id, clearStopLoss: true);
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
    ];
  }

  void _openBracketMenu(BuildContext context, TradingChartController controller, ChartOrder order) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final orderY = controller.yAtPrice(order.price);
    final buttonPosition = renderBox.localToGlobal(Offset(renderBox.size.width - _priceAxisWidth - 60, orderY));

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
                Text('Add Take Profit (+1.5%)', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                Text('Add Stop Loss (-1.0%)', style: TextStyle(color: Colors.white, fontSize: 12)),
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
              Text('Cancel Order', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
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
}
