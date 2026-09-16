import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Utility class for capturing high-DPI snapshots of the chart canvas.
class ChartExporter {
  /// Captures the widget subtree wrapped in a [RepaintBoundary] as PNG byte data.
  /// [pixelRatio] controls the resolution multiplier (default: 2.0 for retina clarity).
  static Future<Uint8List?> capturePng(
    GlobalKey repaintBoundaryKey, {
    double pixelRatio = 2.0,
  }) async {
    try {
      final boundary =
          repaintBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('ChartExporter.capturePng error: $e');
      return null;
    }
  }

  /// Displays a modern, dark-themed preview modal of the captured chart snapshot.
  static Future<void> showSnapshotDialog({
    required BuildContext context,
    required Uint8List pngBytes,
    String symbol = 'Chart',
  }) async {
    final sizeKb = (pngBytes.lengthInBytes / 1024).toStringAsFixed(1);

    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1E222D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF2A2E39), width: 1),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 520),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            size: 18,
                            color: Color(0xFF2962FF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Chart Snapshot • $symbol ($sizeKb KB)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF787B86),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131722),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2A2E39)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Center(
                        child: Image.memory(pngBytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Snapshot captured successfully ($sizeKb KB)!',
                              ),
                              backgroundColor: const Color(0xFF1E222D),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.check,
                          size: 16,
                          color: Color(0xFF00C853),
                        ),
                        label: const Text(
                          'Done',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2A2E39)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
