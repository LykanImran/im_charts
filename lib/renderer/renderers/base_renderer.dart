import 'package:flutter/material.dart';
import '../../core/models/chart_theme.dart';

/// Base class for modular sub-renderers offering reusable pre-configured Paint instances.
abstract class BaseRenderer {
  final ChartTheme theme;

  late final Paint bullWickPaint;
  late final Paint bearWickPaint;
  late final Paint bullBodyPaint;
  late final Paint bearBodyPaint;
  late final Paint bullVolumePaint;
  late final Paint bearVolumePaint;
  late final Paint gridPaint;
  late final Paint crosshairPaint;
  late final Paint currentPriceLinePaint;
  late final Paint badgeBackgroundPaint;

  BaseRenderer(this.theme) {
    bullWickPaint = Paint()
      ..color = theme.bullishColor
      ..strokeWidth = 1.0
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke;

    bearWickPaint = Paint()
      ..color = theme.bearishColor
      ..strokeWidth = 1.0
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke;

    bullBodyPaint = Paint()
      ..color = theme.bullishColor
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    bearBodyPaint = Paint()
      ..color = theme.bearishColor
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    bullVolumePaint = Paint()
      ..color = theme.bullishTransparent
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    bearVolumePaint = Paint()
      ..color = theme.bearishTransparent
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    gridPaint = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 0.8
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke;

    crosshairPaint = Paint()
      ..color = theme.crosshairColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    currentPriceLinePaint = Paint()
      ..color = theme.currentPriceLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    badgeBackgroundPaint = Paint()
      ..color = theme.crosshairBadgeBackground
      ..style = PaintingStyle.fill;
  }
}
