import 'dart:math' as math;
import 'dart:ui';
import '../../core/coordinates/coordinate_converter.dart';
import '../../core/coordinates/viewport.dart';
import '../../core/models/candle.dart';
import 'base_renderer.dart';

/// Renders a color-coded volume histogram at the lower section of the chart.
class VolumeRenderer extends BaseRenderer {
  VolumeRenderer(super.theme);

  void drawVolume({
    required Canvas canvas,
    required Rect bounds,
    required List<Candle> candles,
    required VisibleIndices visible,
    required CoordinateConverter converter,
    required double candleWidth,
    double volumeHeightRatio = 0.20, // 20% of pane height
  }) {
    if (candles.isEmpty || visible.count <= 0) return;

    // Find max volume in visible window
    double maxVolume = 0.0;
    for (int i = visible.start; i <= visible.end; i++) {
      if (i >= 0 && i < candles.length) {
        if (candles[i].volume > maxVolume) {
          maxVolume = candles[i].volume;
        }
      }
    }

    if (maxVolume <= 0) return;

    final maxPixelHeight = bounds.height * volumeHeightRatio;
    final halfWidth = math.max(0.5, candleWidth / 2.0);

    for (int i = visible.start; i <= visible.end; i++) {
      if (i < 0 || i >= candles.length) continue;
      final c = candles[i];
      final x = converter.indexToX(i);

      if (x + halfWidth < bounds.left || x - halfWidth > bounds.right) {
        continue;
      }

      final barHeight = (c.volume / maxVolume) * maxPixelHeight;
      final paint = c.isBullish ? bullVolumePaint : bearVolumePaint;

      canvas.drawRect(
        Rect.fromLTWH(
          x - halfWidth,
          bounds.bottom - barHeight,
          candleWidth,
          barHeight,
        ),
        paint,
      );
    }
  }
}
