import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../core/coordinates/coordinate_converter.dart';
import '../core/models/chart_alert.dart';
import '../core/models/chart_drawing.dart';
import '../core/models/chart_layout_mode.dart';
import '../core/models/chart_order.dart';
import '../core/models/chart_position.dart';
import '../core/models/chart_theme.dart';
import '../engine/chart_controller.dart';
import '../renderer/chart_painter.dart';
import 'chart_toast.dart';
import 'replay_control_bar.dart';
import 'web_zoom_interop.dart';

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
  final bool enableContextMenu;
  final bool showWatermark;
  final bool showCountdownTimer;
  final ChartLayoutMode layoutMode;
  final double mobileBreakpoint;
  final String? brandName;
  final GlobalKey? repaintBoundaryKey;
  final Widget Function(
    BuildContext context,
    double price,
    TradingChartController controller,
    VoidCallback closeMenu,
  )? orderMenuBuilder;
  final Widget Function(
    BuildContext context,
    Offset position,
    double price,
    TradingChartController controller,
    VoidCallback closeMenu,
  )? contextMenuBuilder;
  final void Function(String action, Offset localPosition, double price)?
      onContextMenuAction;
  final void Function(ChartOrder order)? onOrderPlaced;
  final void Function(ChartOrder order)? onOrderModified;
  final void Function(String orderId)? onOrderCancelled;
  final void Function(ChartPosition position)? onPositionClosed;

  const TradingChart({
    super.key,
    required this.controller,
    this.enableChartTrading = true,
    this.enableContextMenu = true,
    this.showWatermark = true,
    this.showCountdownTimer = true,
    this.layoutMode = ChartLayoutMode.auto,
    this.mobileBreakpoint = 600.0,
    this.brandName,
    this.repaintBoundaryKey,
    this.orderMenuBuilder,
    this.contextMenuBuilder,
    this.onContextMenuAction,
    this.onOrderPlaced,
    this.onOrderModified,
    this.onOrderCancelled,
    this.onPositionClosed,
  });

  @override
  State<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends State<TradingChart>
    with TickerProviderStateMixin {
  bool _isMobile = false;
  double get _priceAxisWidth => _isMobile ? 44.0 : 65.0;
  double get _timeAxisHeight => _isMobile ? 22.0 : 24.0;
  double _cachedChartWidth = 400.0; // Updated in LayoutBuilder for use in sub-builders
  final GlobalKey _defaultRepaintKey = GlobalKey();

  double _lastScale = 1.0;
  double _lastTrackpadScale = 1.0;
  int _lastPointerCount = 0;
  bool _isTrackpadPanZoomActive = false;
  Offset _lastFocalPoint = Offset.zero;
  Offset _lastTapDownPosition = Offset.zero;
  _ChartDragMode _dragMode = _ChartDragMode.none;
  final FocusNode _focusNode = FocusNode();

  // Kinetic Inertia Scrolling State
  late final AnimationController _inertiaController;
  double _lastInertiaValue = 0.0;

  // Viewport Recenter Animation State
  late final AnimationController _recenterAnimController;
  Animation<double>? _recenterAnimation;

  // Mobile Inspection Mode State
  bool _isInspecting = false;
  int? _lastInspectedCandleIndex;
  double? _lastHapticDragPrice;

  // Multi-point tool creation state (click-move-click OR drag-release)
  DrawingPoint? _drawingAnchorPoint;
  bool _hasDraggedDuringCreation = false;
  Offset? _drawingDragStartPos;

  // Selected drawing handle dragging state
  int? _draggingHandleIndex;
  String? _draggingDrawingId;

  // Track hover position for dynamic cursor resolution
  Offset? _hoverPosition;

  // Active order and alert dragging state
  String? _draggingOrderId;
  String? _draggingKind; // 'order', 'tp', 'sl', 'alert'
  double? _draggingCurrentPrice;

  void _handleInertiaTick() {
    final current = _inertiaController.value;
    final delta = current - _lastInertiaValue;
    _lastInertiaValue = current;
    if (delta.abs() > 0.01) {
      widget.controller.onPan(delta);
    }
  }

  void _animateScrollTo(double targetOffset) {
    if (_inertiaController.isAnimating) {
      _inertiaController.stop();
    }
    final currentOffset = widget.controller.viewport.scrollOffset;
    if ((currentOffset - targetOffset).abs() < 1.0) {
      widget.controller.scrollToLatest();
      return;
    }
    _recenterAnimController.stop();
    _recenterAnimation = Tween<double>(
      begin: currentOffset,
      end: targetOffset,
    ).animate(
      CurvedAnimation(
        parent: _recenterAnimController,
        curve: Curves.easeOutCubic,
      ),
    )..addListener(() {
        widget.controller.setScrollOffset(_recenterAnimation!.value);
      });
    _recenterAnimController.forward(from: 0.0);
    HapticFeedback.lightImpact();
  }

  bool _computeIsMobile(BoxConstraints constraints, BuildContext context) {
    if (widget.layoutMode == ChartLayoutMode.mobile) return true;
    if (widget.layoutMode == ChartLayoutMode.desktop) return false;
    final screenWidth =
        MediaQuery.maybeOf(context)?.size.width ?? constraints.maxWidth;
    return constraints.maxWidth < widget.mobileBreakpoint ||
        screenWidth < widget.mobileBreakpoint;
  }

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

  static int _activeContextMenuCharts = 0;

  @override
  void initState() {
    super.initState();
    _inertiaController = AnimationController.unbounded(vsync: this)
      ..addListener(_handleInertiaTick);
    _recenterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    if (kIsWeb) {
      try {
        preventWebBrowserPinchZoom();
      } catch (_) {}
    }
    if (widget.enableContextMenu) {
      _activeContextMenuCharts++;
      if (kIsWeb && _activeContextMenuCharts == 1) {
        try {
          BrowserContextMenu.disableContextMenu();
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _inertiaController.dispose();
    _recenterAnimController.dispose();
    if (widget.enableContextMenu) {
      _activeContextMenuCharts--;
      if (kIsWeb && _activeContextMenuCharts <= 0) {
        _activeContextMenuCharts = 0;
        try {
          BrowserContextMenu.enableContextMenu();
        } catch (_) {}
      }
    }
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
        _isMobile = _computeIsMobile(constraints, context);
        final priceAxisLeft = width - _priceAxisWidth;
        final timeAxisTop = height - _timeAxisHeight;

        // Cache for use inside sub-builder methods (e.g. drag hitbox width)
        if (_cachedChartWidth != width) _cachedChartWidth = width;

        controller.updateDimensions(width, height, _priceAxisWidth);

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
                    _isTrackpadPanZoomActive = true;
                    _lastTrackpadScale = 1.0;
                  },
                  onPointerPanZoomUpdate: (event) {
                    final pos = event.localPosition;
                    final scaleRatio = event.scale / _lastTrackpadScale;
                    _lastTrackpadScale = event.scale;

                    // Native Trackpad pinch-to-zoom (macOS / Desktop precision trackpads)
                    if (scaleRatio.isFinite &&
                        scaleRatio > 0 &&
                        scaleRatio != 1.0) {
                      if (pos.dx >= priceAxisLeft) {
                        // Pinch over price axis: scale price vertically
                        if (scaleRatio > 1.0) {
                          controller.zoomInPrice();
                        } else {
                          controller.zoomOutPrice();
                        }
                      } else {
                        // Pinch over main chart canvas: horizontal focal zoom centered at trackpad pointer
                        controller.onPinchZoom(
                          scaleRatio,
                          pos,
                          event.panDelta.dx,
                        );
                      }
                    } else if (event.panDelta.dx.abs() > 0.05) {
                      controller.onPan(event.panDelta.dx);
                    }

                    if (controller.isManualPriceScale &&
                        event.panDelta.dy.abs() > 0.1) {
                      controller.onVerticalPan(
                        event.panDelta.dy,
                        timeAxisTop,
                      );
                    }
                  },
                  onPointerPanZoomEnd: (event) {
                    _isTrackpadPanZoomActive = false;
                    _lastTrackpadScale = 1.0;
                  },
                  onPointerSignal: (pointerSignal) {
                    // ── PointerScaleEvent: native macOS trackpad pinch signal ──
                    if (pointerSignal is PointerScaleEvent) {
                      final pos = pointerSignal.localPosition;
                      // scale > 1.0 = spread (zoom in), < 1.0 = pinch (zoom out)
                      final scaleFactor = pointerSignal.scale.clamp(0.5, 2.0);
                      if (pos.dx >= priceAxisLeft) {
                        if (scaleFactor > 1.0) {
                          controller.zoomInPrice();
                        } else {
                          controller.zoomOutPrice();
                        }
                      } else {
                        controller.onZoom(scaleFactor, pos);
                      }
                      return;
                    }

                    // ── PointerScrollEvent: mouse wheel & trackpad scroll ──
                    if (pointerSignal is PointerScrollEvent) {
                      final pos = pointerSignal.localPosition;
                      final dx = pointerSignal.scrollDelta.dx;
                      final dy = pointerSignal.scrollDelta.dy;
                      final isShift = HardwareKeyboard.instance.isShiftPressed;
                      // On Flutter Web, macOS trackpad pinch arrives as wheel+ctrlKey at the
                      // DOM level, but HardwareKeyboard.instance does NOT see this synthetic
                      // ctrlKey (it only tracks physical keys). We use isWebWheelCtrlKey()
                      // to read the DOM-level ctrlKey flag tracked by our JS listener.
                      final isCtrlOrMeta =
                          HardwareKeyboard.instance.isControlPressed ||
                          HardwareKeyboard.instance.isMetaPressed ||
                          (kIsWeb && isWebWheelCtrlKey());

                      // 1. Ctrl/Cmd + scroll OR browser-synthesised pinch-as-ctrl-wheel:
                      //    dy < 0 -> spread (zoom in)  |  dy > 0 -> pinch (zoom out)
                      if (isCtrlOrMeta) {
                        final zoomFactor =
                            math.exp(-dy * 0.03).clamp(0.5, 2.0);
                        if (pos.dx >= priceAxisLeft) {
                          if (zoomFactor > 1.0) {
                            controller.zoomInPrice();
                          } else {
                            controller.zoomOutPrice();
                          }
                        } else {
                          controller.onZoom(zoomFactor, pos);
                        }
                        return;
                      }

                      // 2. Zone-specific interactions (Price Axis & Time Axis)
                      if (pos.dx >= priceAxisLeft) {
                        // Wheel over price axis -> scale price vertically
                        if (dy < 0) {
                          controller.zoomInPrice();
                        } else if (dy > 0) {
                          controller.zoomOutPrice();
                        }
                      } else if (pos.dy >= timeAxisTop) {
                        // Wheel over time axis -> scale timeframe horizontally
                        final scrollDelta = dx.abs() > dy.abs() ? dx : dy;
                        if (scrollDelta < 0) {
                          controller.zoomIn();
                        } else if (scrollDelta > 0) {
                          controller.zoomOut();
                        }
                      } else {
                        // Main chart canvas:
                        if (isShift) {
                          // Shift + scroll -> pan horizontally
                          controller.onPan(-dy != 0 ? -dy : -dx);
                        } else if (dx.abs() > dy.abs() && dx.abs() > 0.5) {
                          // Horizontal 2-finger swipe on trackpad -> pan
                          controller.onPan(-dx);
                        } else if (dy.abs() > 0.0) {
                          // Standard mouse wheel / vertical trackpad scroll
                          // -> horizontal candle zoom centred at pointer
                          // Sensitivity 0.015 gives TradingView-like feel on both
                          // mouse (large dy steps) and trackpad (small dy steps).
                          final zoomFactor =
                              math.exp(-dy * 0.015).clamp(0.6, 1.5);
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
                            onSecondaryTapUp: (details) {
                              if (widget.enableContextMenu) {
                                _showContextMenu(
                                  details.globalPosition,
                                  details.localPosition,
                                );
                              }
                            },
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
                              if (_inertiaController.isAnimating) {
                                _inertiaController.stop();
                              }
                              if (_recenterAnimController.isAnimating) {
                                _recenterAnimController.stop();
                              }
                              if (_isTrackpadPanZoomActive) return;

                              if (_isInspecting) {
                                setState(() {
                                  _isInspecting = false;
                                  _lastInspectedCandleIndex = null;
                                });
                                controller.setCrosshairPosition(null);
                              }

                              final start = details.localFocalPoint;
                              _lastFocalPoint = start;
                              _lastScale = 1.0;
                              _lastPointerCount = details.pointerCount;

                              // If 2 or more fingers touch down immediately, prioritize horizontal candle pinch-zoom
                              if (details.pointerCount >= 2) {
                                _dragMode = _ChartDragMode.mainChart;
                                return;
                              }

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
                              if (_isTrackpadPanZoomActive) return;

                              // If 2 or more fingers are down, always switch to mainChart horizontal candle zoom
                              if (details.pointerCount >= 2 &&
                                  _dragMode != _ChartDragMode.mainChart) {
                                if (_dragMode ==
                                    _ChartDragMode.drawingCreation) {
                                  _drawingAnchorPoint = null;
                                  _hasDraggedDuringCreation = false;
                                  controller.setPreviewDrawing(null);
                                }
                                _draggingHandleIndex = null;
                                _draggingDrawingId = null;
                                _dragMode = _ChartDragMode.mainChart;
                                _lastPointerCount = details.pointerCount;
                                _lastFocalPoint = details.localFocalPoint;
                                _lastScale = details.scale;
                                return;
                              }

                              // If pointer count changed (finger added/lifted), synchronize focal point without jump
                              if (details.pointerCount != _lastPointerCount) {
                                _lastPointerCount = details.pointerCount;
                                _lastFocalPoint = details.localFocalPoint;
                                _lastScale = details.scale;
                                return;
                              }

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
                                      (details.scale - 1.0).abs() > 0.005) {
                                    final scaleRatio =
                                        details.scale / _lastScale;
                                    _lastScale = details.scale;

                                    final clampedFocal = Offset(
                                      _lastFocalPoint.dx
                                          .clamp(0.0, priceAxisLeft),
                                      _lastFocalPoint.dy
                                          .clamp(0.0, timeAxisTop),
                                    );

                                    if (scaleRatio.isFinite &&
                                        scaleRatio > 0 &&
                                        (scaleRatio - 1.0).abs() > 0.0005) {
                                      controller.onPinchZoom(
                                        scaleRatio,
                                        clampedFocal,
                                        deltaX,
                                      );
                                    } else if (deltaX.abs() > 0.05) {
                                      controller.onPan(deltaX);
                                    }

                                    if (controller.isManualPriceScale &&
                                        deltaY.abs() > 0.1) {
                                      controller.onVerticalPan(
                                        deltaY,
                                        timeAxisTop,
                                      );
                                    }
                                  } else {
                                    // 1-finger pan: reset scale baseline to avoid jump on next multi-touch
                                    _lastScale = 1.0;
                                    if (deltaX.abs() > 0.05) {
                                      controller.onPan(deltaX);
                                    }
                                    if (controller.isManualPriceScale &&
                                        deltaY.abs() > 0.1) {
                                      controller.onVerticalPan(
                                        deltaY,
                                        timeAxisTop,
                                      );
                                    }
                                    if (!_isMobile &&
                                        details.localFocalPoint.dx <
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
                            onScaleEnd: (details) {
                              _lastScale = 1.0;
                              _lastPointerCount = 0;
                              if (_isTrackpadPanZoomActive) return;

                              if (_dragMode == _ChartDragMode.mainChart) {
                                final vx = details.velocity.pixelsPerSecond.dx;
                                if (vx.abs() > 80.0) {
                                  final clampedVx = vx.clamp(-4000.0, 4000.0);
                                  _lastInertiaValue = 0.0;
                                  _inertiaController.value = 0.0;
                                  final simulation =
                                      FrictionSimulation(0.18, 0.0, clampedVx);
                                  _inertiaController.animateWith(simulation);
                                }
                              }

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
                            },
                            onDoubleTap: () {
                              HapticFeedback.lightImpact();
                              // Zone-aware double-tap reset (TradingView behavior)
                              if (_lastTapDownPosition.dx >= priceAxisLeft) {
                                // Double tap on price scale -> reset auto-scale
                                controller.resetPriceScale();
                              } else if (_lastTapDownPosition.dy >=
                                  timeAxisTop) {
                                // Double tap on time scale -> reset timeframe zoom
                                controller.resetTimeScale();
                              } else {
                                // Double tap on main chart -> reset complete view smoothly
                                _animateScrollTo(0.0);
                                controller.resetPriceScale();
                              }
                            },
                            onLongPressStart: (details) {
                              if (_inertiaController.isAnimating) {
                                _inertiaController.stop();
                              }
                              HapticFeedback.mediumImpact();
                              setState(() => _isInspecting = true);
                              if (details.localPosition.dx < priceAxisLeft &&
                                  details.localPosition.dy < timeAxisTop) {
                                controller.setCrosshairPosition(
                                  details.localPosition,
                                );
                                if (controller.candles.isNotEmpty) {
                                  final converter = CoordinateConverter(
                                    viewport: controller.viewport,
                                    totalCandles: controller.candles.length,
                                  );
                                  _lastInspectedCandleIndex =
                                      converter.xToIndex(details.localPosition.dx);
                                }
                              }
                            },
                            onLongPressMoveUpdate: (details) {
                              if (details.localPosition.dx < priceAxisLeft &&
                                  details.localPosition.dy < timeAxisTop) {
                                controller.setCrosshairPosition(
                                  details.localPosition,
                                );
                                if (controller.candles.isNotEmpty) {
                                  final converter = CoordinateConverter(
                                    viewport: controller.viewport,
                                    totalCandles: controller.candles.length,
                                  );
                                  final index = converter
                                      .xToIndex(details.localPosition.dx);
                                  if (index >= 0 &&
                                      index < controller.candles.length &&
                                      index != _lastInspectedCandleIndex) {
                                    _lastInspectedCandleIndex = index;
                                    HapticFeedback.selectionClick();
                                  }
                                }
                              }
                            },
                            onLongPressEnd: (_) {
                              setState(() {
                                _isInspecting = false;
                                _lastInspectedCandleIndex = null;
                              });
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
                                    showSMC: controller.showSMC,
                                    smc: controller.smc,
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
                                    priceAxisWidth: _priceAxisWidth,
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

                      // ── OHLCV Legend Panel (top-left, TradingView-style) ──
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildOHLCVPanel(controller, theme, priceAxisLeft),
                      ),

                      // Interactive Price Alert Badges & Hitboxes (Draggable & Cancel)
                      if (controller.alerts.isNotEmpty) ...[
                        for (final alert in controller.alerts)
                          ..._buildAlertInteractiveWidgets(
                            context,
                            controller,
                            alert,
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

                      // Floating "Jump to Real-Time" (Recenter) Pill when scrolled back in history
                      Positioned(
                        right: _priceAxisWidth + 12,
                        bottom: _timeAxisHeight + 10,
                        child: _buildJumpToRealtimeButton(
                          controller,
                          theme,
                          controller.isDarkTheme,
                        ),
                      ),

                      // Mobile Long-press Inspection Banner (at top of canvas)
                      if (_isMobile &&
                          _isInspecting &&
                          controller.hoveredCandle != null)
                        Positioned(
                          top: 10,
                          left: 12,
                          right: _priceAxisWidth + 12,
                          child: Center(
                            child: _buildMobileInspectionCard(
                              controller,
                              controller.isDarkTheme,
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
                      // ── Sub-pane Resize Drag Handle ──
                      if (controller.hasSubPane)
                        Positioned(
                          left: 0,
                          right: _priceAxisWidth,
                          top: controller.mainPaneHeight - 4,
                          height: 8,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: (details) {
                                final totalH = height - _timeAxisHeight;
                                final newMain = (controller.mainPaneHeight + details.delta.dy)
                                    .clamp(totalH * 0.4, totalH * 0.85);
                                final newSubRatio = (totalH - newMain) / totalH;
                                controller.subPaneRatio = newSubRatio;
                              },
                              child: Container(
                                color: Colors.transparent,
                                alignment: Alignment.center,
                                child: Container(
                                  height: 2,
                                  margin: const EdgeInsets.symmetric(horizontal: 40),
                                  decoration: BoxDecoration(
                                    color: theme.gridColor.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
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

  /// Builds the TradingView-style OHLCV data legend at the top-left of the chart.
  /// Shows O / H / L / C / Vol and Δ% for the hovered candle (or latest if no crosshair).
  Widget _buildOHLCVPanel(
    TradingChartController controller,
    ChartTheme theme,
    double priceAxisLeft,
  ) {
    final candle = controller.hoveredCandle ?? 
        (controller.candles.isNotEmpty ? controller.candles.last : null);
    if (candle == null) return const SizedBox.shrink();

    final isBull = candle.close >= candle.open;
    final delta = candle.close - candle.open;
    final pct = candle.open > 0 ? (delta / candle.open) * 100 : 0.0;
    final candleColor = isBull ? theme.bullishColor : theme.bearishColor;
    final isDark = theme.isDark;
    final bg = (isDark ? const Color(0xFF131722) : Colors.white)
        .withValues(alpha: 0.88);
    final labelColor = theme.axisTextColor;
    final valueStyle = TextStyle(
      color: isDark ? Colors.white : const Color(0xFF131722),
      fontSize: 10.5,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
    );
    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 9.5,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w500,
    );

    String fmt(double v) {
      if (v >= 1e7) return '${(v / 1e7).toStringAsFixed(2)}Cr';
      if (v >= 1e5) return '${(v / 1e5).toStringAsFixed(2)}L';
      if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
      return v.toStringAsFixed(2);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // O H L C
          _ohlcvItem('O', fmt(candle.open), valueStyle, labelStyle),
          const SizedBox(width: 10),
          _ohlcvItem('H', fmt(candle.high), valueStyle, labelStyle),
          const SizedBox(width: 10),
          _ohlcvItem('L', fmt(candle.low), valueStyle, labelStyle),
          const SizedBox(width: 10),
          _ohlcvItem('C', fmt(candle.close), valueStyle, labelStyle),
          const SizedBox(width: 10),
          // Volume
          _ohlcvItem('V', fmt(candle.volume), valueStyle, labelStyle),
          const SizedBox(width: 10),
          // Δ% coloured
          Text(
            '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} (${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%)',
            style: TextStyle(
              color: candleColor,
              fontSize: 10.5,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ohlcvItem(String label, String value, TextStyle valueStyle, TextStyle labelStyle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 3),
        Text(value, style: valueStyle),
      ],
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
  ) async {
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

    final isDark = controller.isDarkTheme;
    final itemTextColor = isDark ? Colors.white : const Color(0xFF131722);

    final choice = await showMenu<String>(
      context: context,
      position: position,
      color: isDark ? const Color(0xFF1E222D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB),
          width: 1,
        ),
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
                style: TextStyle(
                  color: itemTextColor,
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
                style: TextStyle(
                  color: itemTextColor,
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
    );

    if (choice == null || !mounted) return;

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
        if (!mounted || !context.mounted) return;
        ChartToast.alert(
          context,
          'Alert set at ₹$roundedPrice for ${controller.symbol}',
        );
      }
  }

  void _showContextMenu(Offset globalPosition, Offset localPosition) {
    final controller = widget.controller;

    // 1. Cancel in-progress drawing tool if active
    if (controller.activeDrawingTool != DrawingTool.pointer) {
      controller.cancelActiveDrawing();
      setState(() {
        _drawingAnchorPoint = null;
        _drawingDragStartPos = null;
        _hasDraggedDuringCreation = false;
      });
    }

    // 2. Compute clicked price at cursor position
    final clickedPrice = double.parse(
      controller.priceAtY(localPosition.dy).toStringAsFixed(2),
    );

    // 3. Optional custom context menu builder
    if (widget.contextMenuBuilder != null) {
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (ctx) => widget.contextMenuBuilder!(
          ctx,
          globalPosition,
          clickedPrice,
          controller,
          () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }

    // 4. Calculate relative position within Overlay
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
      Offset.zero & overlay.size,
    );

    final isDark = controller.isDarkTheme;
    final itemTextColor = isDark ? Colors.white : const Color(0xFF131722);
    final subTextColor =
        isDark ? const Color(0xFF787B86) : const Color(0xFF5D606B);
    final menuBg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB);

    final selectedDrawing = controller.selectedDrawing;
    final hasIndicators = controller.activeIndicators.isNotEmpty;
    final hasDrawings = controller.drawings.isNotEmpty;

    showMenu<String>(
      context: context,
      position: position,
      color: menuBg,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: 1),
      ),
      items: [
        // --- 1. Selected Drawing Actions ---
        if (selectedDrawing != null) ...[
          PopupMenuItem<String>(
            value: 'delete_drawing',
            height: 36,
            child: const Row(
              children: [
                Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF3B30)),
                SizedBox(width: 10),
                Text(
                  'Delete Selected Drawing',
                  style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'toggle_lock_drawing',
            height: 36,
            child: Row(
              children: [
                Icon(
                  selectedDrawing.isLocked ? Icons.lock_open : Icons.lock_outline,
                  size: 16,
                  color: subTextColor,
                ),
                const SizedBox(width: 10),
                Text(
                  selectedDrawing.isLocked ? 'Unlock Drawing' : 'Lock Drawing',
                  style: TextStyle(color: itemTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
        ],

        // --- 2. Price Actions & Quick Orders ---
        PopupMenuItem<String>(
          value: 'add_alert',
          height: 36,
          child: Row(
            children: [
              const Icon(
                Icons.add_alert_outlined,
                size: 16,
                color: Color(0xFFFFB74D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add Alert at ₹$clickedPrice',
                  style: TextStyle(
                    color: itemTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (widget.enableChartTrading) ...[
          PopupMenuItem<String>(
            value: 'buy_limit',
            height: 36,
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buy 100 Limit @ ₹$clickedPrice',
                    style: TextStyle(
                      color: itemTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'sell_limit',
            height: 36,
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sell 100 Limit @ ₹$clickedPrice',
                    style: TextStyle(
                      color: itemTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(height: 1),

        // --- 3. Indicators & Drawings Removal with Live Count ---
        PopupMenuItem<String>(
          value: 'remove_indicators',
          enabled: hasIndicators,
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.layers_clear_outlined,
                size: 16,
                color: hasIndicators
                    ? const Color(0xFF2962FF)
                    : subTextColor.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Remove Indicators (${controller.activeIndicators.length})',
                  style: TextStyle(
                    color: hasIndicators
                        ? itemTextColor
                        : subTextColor.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight:
                        hasIndicators ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'remove_drawings',
          enabled: hasDrawings,
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.delete_sweep_outlined,
                size: 16,
                color: hasDrawings
                    ? const Color(0xFFFF9100)
                    : subTextColor.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Remove Drawings (${controller.drawings.length})',
                  style: TextStyle(
                    color: hasDrawings
                        ? itemTextColor
                        : subTextColor.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight:
                        hasDrawings ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),

        // --- 4. Chart Reset & Auto Scale ---
        PopupMenuItem<String>(
          value: 'reset_chart',
          height: 36,
          child: Row(
            children: [
              const Icon(
                Icons.restart_alt,
                size: 16,
                color: Color(0xFF00E5FF),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reset Chart View',
                  style: TextStyle(
                    color: itemTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Alt+R',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        if (controller.isManualPriceScale)
          PopupMenuItem<String>(
            value: 'reset_price_scale',
            height: 36,
            child: Row(
              children: [
                const Icon(
                  Icons.height,
                  size: 16,
                  color: Color(0xFF2962FF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reset Price Scale (Auto)',
                    style: TextStyle(
                      color: itemTextColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(height: 1),

        // --- 5. Quick Terminal Toggles & Utility ---
        PopupMenuItem<String>(
          value: 'toggle_theme',
          height: 36,
          child: Row(
            children: [
              Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 16,
                color: subTextColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                  style: TextStyle(color: itemTextColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'toggle_magnet',
          height: 36,
          child: Row(
            children: [
              Icon(
                controller.magnetMode
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 16,
                color: controller.magnetMode
                    ? const Color(0xFF2962FF)
                    : subTextColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Magnet Mode (Snap to OHLC)',
                  style: TextStyle(color: itemTextColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'toggle_countdown',
          height: 36,
          child: Row(
            children: [
              Icon(
                controller.showCountdownTimer
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 16,
                color: controller.showCountdownTimer
                    ? const Color(0xFF2962FF)
                    : subTextColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bar Countdown Timer',
                  style: TextStyle(color: itemTextColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy_price',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 15, color: subTextColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Copy Price (₹$clickedPrice)',
                  style: TextStyle(color: itemTextColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((choice) {
      if (choice == null || !mounted) return;
      HapticFeedback.lightImpact();

      widget.onContextMenuAction?.call(choice, localPosition, clickedPrice);

      void showFeedback(String msg, Color col) {
        if (!mounted) return;
        ChartToast.show(context, message: msg, color: col);
      }

      switch (choice) {
        case 'delete_drawing':
          controller.deleteSelectedDrawing();
          showFeedback('Drawing deleted', const Color(0xFFFF3B30));
          break;

        case 'toggle_lock_drawing':
          controller.toggleSelectedDrawingLocked();
          showFeedback('Drawing lock toggled', const Color(0xFF2962FF));
          break;

        case 'add_alert':
          final alert = ChartAlert(
            id: 'alt_${DateTime.now().millisecondsSinceEpoch}',
            symbol: controller.symbol,
            price: clickedPrice,
            note: 'Crossing $clickedPrice',
            condition: AlertTriggerCondition.crossing,
            createdAt: DateTime.now(),
          );
          controller.addAlert(alert);
          showFeedback(
            '🔔 Alert set at ₹$clickedPrice for ${controller.symbol}',
            const Color(0xFFFFB74D),
          );
          break;

        case 'buy_limit':
          final order = ChartOrder(
            id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
            symbol: controller.symbol,
            side: OrderSide.buy,
            type: OrderType.limit,
            price: clickedPrice,
            quantity: 100,
          );
          controller.placeOrder(order);
          widget.onOrderPlaced?.call(order);
          showFeedback(
            'Buy 100 Limit placed at ₹$clickedPrice',
            const Color(0xFF00E676),
          );
          break;

        case 'sell_limit':
          final order = ChartOrder(
            id: 'ord_${DateTime.now().millisecondsSinceEpoch}',
            symbol: controller.symbol,
            side: OrderSide.sell,
            type: OrderType.limit,
            price: clickedPrice,
            quantity: 100,
          );
          controller.placeOrder(order);
          widget.onOrderPlaced?.call(order);
          showFeedback(
            'Sell 100 Limit placed at ₹$clickedPrice',
            const Color(0xFFFF3B30),
          );
          break;

        case 'remove_indicators':
          final count = controller.activeIndicators.length;
          controller.clearIndicators();
          showFeedback('Removed $count indicator(s)', const Color(0xFF2962FF));
          break;

        case 'remove_drawings':
          final count = controller.drawings.length;
          controller.clearDrawings();
          showFeedback('Removed $count drawing(s)', const Color(0xFFFF9100));
          break;

        case 'reset_chart':
          controller.resetView();
          showFeedback('Chart view reset', const Color(0xFF00E5FF));
          break;

        case 'reset_price_scale':
          controller.resetPriceScale();
          showFeedback('Price scale reset to auto', const Color(0xFF2962FF));
          break;

        case 'toggle_theme':
          controller.toggleTheme();
          break;

        case 'toggle_magnet':
          controller.toggleMagnetMode();
          showFeedback(
            controller.magnetMode
                ? 'Magnet mode enabled'
                : 'Magnet mode disabled',
            const Color(0xFF2962FF),
          );
          break;

        case 'toggle_countdown':
          controller.showCountdownTimer = !controller.showCountdownTimer;
          break;

        case 'copy_price':
          Clipboard.setData(ClipboardData(text: clickedPrice.toString()));
          showFeedback(
            'Copied ₹$clickedPrice to clipboard',
            const Color(0xFF00E5FF),
          );
          break;
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
    // Wider touch zone on mobile for easier dragging — full chart width
    final touchHeight = _isMobile ? 56.0 : 28.0;

    return [
      // 1. Order Badge Interactive Hitbox (Draggable & Cancel)
      if (orderY >= 0 && orderY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 18,
          top: (orderY - (touchHeight / 2)).clamp(0.0, timeAxisTop - touchHeight),
          child: SizedBox(
            // Full-width hitbox so finger doesn't slip off the line
            width: _isMobile ? _cachedChartWidth - _priceAxisWidth - 18 : 175,
            height: touchHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 22,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                            color:
                                const Color(0xFF2962FF).withValues(alpha: 0.8),
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
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (details) {
                              setState(() {
                                _draggingOrderId = order.id;
                                _draggingKind = 'order';
                                _draggingCurrentPrice = order.price;
                              });
                            },
                            onVerticalDragUpdate: (details) {
                              // Direct pointer-Y → price: no accumulation, no jumps
                              final newY = details.localPosition.dy
                                  .clamp(0.0, timeAxisTop);
                              final newPrice = double.parse(
                                controller.priceAtY(newY).toStringAsFixed(2),
                              );
                              if (newPrice != _draggingCurrentPrice) {
                                if (_lastHapticDragPrice == null ||
                                    (newPrice - _lastHapticDragPrice!).abs() >= 0.5) {
                                  _lastHapticDragPrice = newPrice;
                                  HapticFeedback.selectionClick();
                                }
                                _draggingCurrentPrice = newPrice;
                                controller.updateOrderPrice(order.id, newPrice);
                              }
                            },
                            onVerticalDragEnd: (_) {
                              HapticFeedback.lightImpact();
                              _lastHapticDragPrice = null;
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
                              _lastHapticDragPrice = null;
                              setState(() {
                                _draggingOrderId = null;
                                _draggingKind = null;
                                _draggingCurrentPrice = null;
                              });
                            },
                            child: Container(
                              color: Colors.transparent,
                              height: touchHeight,
                              child: const SizedBox.expand(),
                            ),
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
                          HapticFeedback.lightImpact();
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
          ),
        ),

      // Floating Live Drag Telemetry Badge for Order Limit
      if (isThisOrderDragging &&
          _draggingKind == 'order' &&
          orderY >= 0 &&
          orderY <= timeAxisTop)
        Positioned(
          right: _isMobile ? _priceAxisWidth + 10 : _priceAxisWidth + 200,
          top: (_isMobile ? orderY - 44 : orderY - 14)
              .clamp(8.0, timeAxisTop - 32.0),
          child: _buildDragTelemetryChip(
            title: 'LIMIT ${order.isBuy ? 'BUY' : 'SELL'}',
            value:
                '₹${(_draggingCurrentPrice ?? order.price).toStringAsFixed(2)} (Qty: ${order.quantity.toStringAsFixed(order.quantity % 1 == 0 ? 0 : 2)})',
            accentColor:
                order.isBuy ? const Color(0xFF00E676) : const Color(0xFFFF3B30),
          ),
        ),

      // 2. Take Profit (TP) Interactive Hitbox (Draggable & Cancel)
      if (tpY != null && tpY >= 0 && tpY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 18,
          top: (tpY - (touchHeight / 2)).clamp(0.0, timeAxisTop - touchHeight),
          child: SizedBox(
            width: _isMobile ? _cachedChartWidth - _priceAxisWidth - 18 : 145,
            height: touchHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 22,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Draggable zone for Take Profit price
                    Expanded(
                      child: Tooltip(
                        message: 'Drag up/down to adjust TP',
                        waitDuration: const Duration(milliseconds: 500),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpDown,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (details) {
                              setState(() {
                                _draggingOrderId = order.id;
                                _draggingKind = 'tp';
                                _draggingCurrentPrice = order.takeProfitPrice;
                              });
                            },
                            onVerticalDragUpdate: (details) {
                              final newY = details.localPosition.dy
                                  .clamp(0.0, timeAxisTop);
                              final newPrice = double.parse(
                                controller.priceAtY(newY).toStringAsFixed(2),
                              );
                              if (newPrice != _draggingCurrentPrice) {
                                if (_lastHapticDragPrice == null ||
                                    (newPrice - _lastHapticDragPrice!).abs() >= 0.5) {
                                  _lastHapticDragPrice = newPrice;
                                  HapticFeedback.selectionClick();
                                }
                                _draggingCurrentPrice = newPrice;
                                controller.updateOrderBrackets(
                                  order.id,
                                  takeProfitPrice: newPrice,
                                );
                              }
                            },
                            onVerticalDragEnd: (_) {
                              HapticFeedback.lightImpact();
                              _lastHapticDragPrice = null;
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
                              _lastHapticDragPrice = null;
                              setState(() {
                                _draggingOrderId = null;
                                _draggingKind = null;
                                _draggingCurrentPrice = null;
                              });
                            },
                            child: Container(
                              color: Colors.transparent,
                              height: touchHeight,
                              child: const SizedBox.expand(),
                            ),
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
                          HapticFeedback.lightImpact();
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
          ),
        ),

      // Floating Live Drag Telemetry Badge for TP
      if (isThisOrderDragging &&
          _draggingKind == 'tp' &&
          tpY != null &&
          tpY >= 0 &&
          tpY <= timeAxisTop)
        Positioned(
          right: _isMobile ? _priceAxisWidth + 10 : _priceAxisWidth + 170,
          top: (_isMobile ? tpY - 44 : tpY - 14)
              .clamp(8.0, timeAxisTop - 32.0),
          child: Builder(
            builder: (_) {
              final tpPrice =
                  _draggingCurrentPrice ?? order.takeProfitPrice ?? 0.0;
              final diff = (tpPrice - order.price) * (order.isBuy ? 1 : -1);
              final estProfit = diff * order.quantity;
              final pct = order.price > 0 ? (diff / order.price) * 100 : 0.0;
              return _buildDragTelemetryChip(
                title: 'TAKE PROFIT',
                value:
                    '₹${tpPrice.toStringAsFixed(2)} | +₹${estProfit.abs().toStringAsFixed(2)} (+${pct.toStringAsFixed(1)}%)',
                accentColor: const Color(0xFF00E5FF),
              );
            },
          ),
        ),

      // 3. Stop Loss (SL) Interactive Hitbox (Draggable & Cancel)
      if (slY != null && slY >= 0 && slY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 18,
          top: (slY - (touchHeight / 2)).clamp(0.0, timeAxisTop - touchHeight),
          child: SizedBox(
            width: _isMobile ? _cachedChartWidth - _priceAxisWidth - 18 : 145,
            height: touchHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 22,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Draggable zone for Stop Loss price
                    Expanded(
                      child: Tooltip(
                        message: 'Drag up/down to adjust SL',
                        waitDuration: const Duration(milliseconds: 500),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpDown,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragStart: (details) {
                              setState(() {
                                _draggingOrderId = order.id;
                                _draggingKind = 'sl';
                                _draggingCurrentPrice = order.stopLossPrice;
                              });
                            },
                            onVerticalDragUpdate: (details) {
                              final newY = details.localPosition.dy
                                  .clamp(0.0, timeAxisTop);
                              final newPrice = double.parse(
                                controller.priceAtY(newY).toStringAsFixed(2),
                              );
                              if (newPrice != _draggingCurrentPrice) {
                                if (_lastHapticDragPrice == null ||
                                    (newPrice - _lastHapticDragPrice!).abs() >= 0.5) {
                                  _lastHapticDragPrice = newPrice;
                                  HapticFeedback.selectionClick();
                                }
                                _draggingCurrentPrice = newPrice;
                                controller.updateOrderBrackets(
                                  order.id,
                                  stopLossPrice: newPrice,
                                );
                              }
                            },
                            onVerticalDragEnd: (_) {
                              HapticFeedback.lightImpact();
                              _lastHapticDragPrice = null;
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
                              _lastHapticDragPrice = null;
                              setState(() {
                                _draggingOrderId = null;
                                _draggingKind = null;
                                _draggingCurrentPrice = null;
                              });
                            },
                            child: Container(
                              color: Colors.transparent,
                              height: touchHeight,
                              child: const SizedBox.expand(),
                            ),
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
                          HapticFeedback.lightImpact();
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
          ),
        ),

      // Floating Live Drag Telemetry Badge for SL
      if (isThisOrderDragging &&
          _draggingKind == 'sl' &&
          slY != null &&
          slY >= 0 &&
          slY <= timeAxisTop)
        Positioned(
          right: _isMobile ? _priceAxisWidth + 10 : _priceAxisWidth + 170,
          top: (_isMobile ? slY - 44 : slY - 14)
              .clamp(8.0, timeAxisTop - 32.0),
          child: Builder(
            builder: (_) {
              final slPrice =
                  _draggingCurrentPrice ?? order.stopLossPrice ?? 0.0;
              final diff = (order.price - slPrice) * (order.isBuy ? 1 : -1);
              final estLoss = diff * order.quantity;
              final pct = order.price > 0 ? (diff / order.price) * 100 : 0.0;
              return _buildDragTelemetryChip(
                title: 'STOP LOSS',
                value:
                    '₹${slPrice.toStringAsFixed(2)} | -₹${estLoss.abs().toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
                accentColor: const Color(0xFFFF9100),
              );
            },
          ),
        ),
    ];
  }

  List<Widget> _buildAlertInteractiveWidgets(
    BuildContext context,
    TradingChartController controller,
    ChartAlert alert,
    double timeAxisTop,
  ) {
    if (!alert.isActive && !alert.isTriggered) return const [];
    final alertY = controller.yAtPrice(alert.price);
    if (alertY < 0 || alertY > timeAxisTop) return const [];

    final isThisAlertDragging =
        _draggingOrderId == alert.id && _draggingKind == 'alert';
    final touchHeight = _isMobile ? 56.0 : 28.0;
    final isTriggered = alert.isTriggered;
    final alertColor =
        isTriggered ? const Color(0xFF787B86) : const Color(0xFFFFB300);

    return [
      Positioned(
        right: _priceAxisWidth + 18,
        top: (alertY - (touchHeight / 2)).clamp(0.0, timeAxisTop - touchHeight),
        child: SizedBox(
          width: _isMobile ? _cachedChartWidth - _priceAxisWidth - 18 : 150,
          height: touchHeight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: controller.isDarkTheme
                    ? const Color(0xFF1E222D).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: alertColor.withValues(alpha: 0.8),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        key: Key('drag_alert_${alert.id}'),
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (details) {
                          setState(() {
                            _draggingOrderId = alert.id;
                            _draggingKind = 'alert';
                            _draggingCurrentPrice = alert.price;
                          });
                        },
                        onVerticalDragUpdate: (details) {
                          final newY = details.localPosition.dy
                              .clamp(0.0, timeAxisTop);
                          final newPrice = double.parse(
                            controller.priceAtY(newY).toStringAsFixed(2),
                          );
                          if (newPrice != _draggingCurrentPrice) {
                            if (_lastHapticDragPrice == null ||
                                (newPrice - _lastHapticDragPrice!).abs() >= 0.5) {
                              _lastHapticDragPrice = newPrice;
                              HapticFeedback.selectionClick();
                            }
                            _draggingCurrentPrice = newPrice;
                            controller.updateAlert(
                              alert.copyWith(price: newPrice),
                            );
                          }
                        },
                        onVerticalDragEnd: (_) {
                          HapticFeedback.lightImpact();
                          _lastHapticDragPrice = null;
                          setState(() {
                            _draggingOrderId = null;
                            _draggingKind = null;
                            _draggingCurrentPrice = null;
                          });
                        },
                        onVerticalDragCancel: () {
                          _lastHapticDragPrice = null;
                          setState(() {
                            _draggingOrderId = null;
                            _draggingKind = null;
                            _draggingCurrentPrice = null;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_active,
                              size: 11,
                              color: alertColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                alert.note.isNotEmpty
                                    ? alert.note
                                    : '₹${alert.price.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: alertColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    key: Key('cancel_alert_${alert.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      controller.removeAlert(alert.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: controller.isDarkTheme
                            ? const Color(0xFF787B86)
                            : const Color(0xFF9598A1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      if (isThisAlertDragging && alertY >= 0 && alertY <= timeAxisTop)
        Positioned(
          right: _isMobile ? _priceAxisWidth + 10 : _priceAxisWidth + 170,
          top: (_isMobile ? alertY - 44 : alertY - 14)
              .clamp(8.0, timeAxisTop - 32.0),
          child: _buildDragTelemetryChip(
            title: 'ALERT TRIGGER',
            value:
                '₹${(_draggingCurrentPrice ?? alert.price).toStringAsFixed(2)}',
            accentColor: alertColor,
          ),
        ),
    ];
  }

  Widget _buildDragTelemetryChip({
    required String title,
    required String value,
    required Color accentColor,
  }) {
    final isDark = widget.controller.isDarkTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF131722) : Colors.white)
            .withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.8), width: 1.2),
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
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF131722),
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

    final isDark = controller.isDarkTheme;
    final itemTextColor = isDark ? Colors.white : const Color(0xFF131722);

    showMenu<String>(
      context: context,
      position: position,
      color: isDark ? const Color(0xFF1E222D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB),
          width: 1,
        ),
      ),
      items: [
        if (!order.hasTakeProfit)
          PopupMenuItem<String>(
            value: 'add_tp',
            height: 36,
            child: Row(
              children: [
                const Icon(Icons.trending_up, size: 14, color: Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                Text(
                  'Add Take Profit (+1.5%)',
                  style: TextStyle(color: itemTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
        if (!order.hasStopLoss)
          PopupMenuItem<String>(
            value: 'add_sl',
            height: 36,
            child: Row(
              children: [
                const Icon(Icons.trending_down, size: 14, color: Color(0xFFFF9100)),
                const SizedBox(width: 8),
                Text(
                  'Add Stop Loss (-1.0%)',
                  style: TextStyle(color: itemTextColor, fontSize: 12),
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
    final touchHeight = _isMobile ? 56.0 : 28.0;

    return [
      if (posY >= 0 && posY <= timeAxisTop)
        Positioned(
          right: _priceAxisWidth + 18,
          top: (posY - (touchHeight / 2)).clamp(0.0, timeAxisTop - touchHeight),
          child: SizedBox(
            width: 80,
            height: touchHeight,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 24,
                child: Tooltip(
                message: 'Close Position (Market Order)',
                waitDuration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  key: Key('close_position_${position.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    controller.closePosition(position.id);
                    widget.onPositionClosed?.call(position);
                    if (context.mounted) {
                      ChartToast.info(
                        context,
                        'Position closed: ${position.side.label} ${position.quantity.toStringAsFixed(0)} @ ₹${position.entryPrice.toStringAsFixed(2)}',
                      );
                    }
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

  Widget _buildJumpToRealtimeButton(
    TradingChartController controller,
    ChartTheme theme,
    bool isDark,
  ) {
    final isScrolledAway = controller.viewport.scrollOffset > 50.0;

    return AnimatedOpacity(
      opacity: isScrolledAway ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: isScrolledAway ? 1.0 : 0.8,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !isScrolledAway,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('btn_jump_to_realtime'),
              onTap: () => _animateScrollTo(0.0),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xEE1E222D)
                      : const Color(0xEEFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2A2E39)
                        : const Color(0xFFE0E3EB),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6600E676),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Real-time',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF131722),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.keyboard_double_arrow_right,
                      size: 13,
                      color: Color(0xFF2962FF),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileInspectionCard(
    TradingChartController controller,
    bool isDark,
  ) {
    final candle = controller.hoveredCandle;
    if (candle == null) return const SizedBox.shrink();
    final isBullish = candle.isBullish;
    final color =
        isBullish ? const Color(0xFF089981) : const Color(0xFFF23645);
    final diff = candle.close - candle.open;
    final pct = candle.open > 0 ? (diff / candle.open) * 100 : 0.0;
    final sign = diff >= 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xEE1E222D) : const Color(0xEEFFFFFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2E39) : const Color(0xFFE0E3EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'O: ${candle.open.toStringAsFixed(1)} H: ${candle.high.toStringAsFixed(1)} L: ${candle.low.toStringAsFixed(1)} C: ${candle.close.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFD1D4DC) : const Color(0xFF131722),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$sign${diff.toStringAsFixed(1)} ($sign${pct.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
