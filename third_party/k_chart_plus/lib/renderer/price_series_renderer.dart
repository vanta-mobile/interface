import 'package:flutter/material.dart';
import '../styles/chart_options.dart';
import '../styles/k_chart_style.dart';
import '../entity/candle_entity.dart';

/// Additional time-based chart styles share the same prices and viewport.
void drawPriceSeries({
  required Canvas canvas,
  required CandleEntity last,
  required CandleEntity point,
  required double lastX,
  required double x,
  required double Function(double) getY,
  required Rect rect,
  required KChartType type,
  required KChartColors colors,
  required double width,
  required double scaleX,
  required double baseline,
}) {
  final paint = Paint()
    ..isAntiAlias = true
    ..strokeWidth = 1 / scaleX;
  final color = point.close >= last.close ? colors.upColor : colors.dnColor;
  if (type == KChartType.bars || type == KChartType.highLow) {
    paint.color = color;
    canvas.drawLine(Offset(x, getY(point.high)), Offset(x, getY(point.low)), paint);
    if (type == KChartType.bars) {
      canvas.drawLine(Offset(x - width / 2, getY(point.open)), Offset(x, getY(point.open)), paint);
      canvas.drawLine(
          Offset(x, getY(point.close)), Offset(x + width / 2, getY(point.close)), paint);
    } else {
      for (final price in [point.high, point.low]) {
        canvas.drawLine(
            Offset(x - width / 2, getY(price)), Offset(x + width / 2, getY(price)), paint);
      }
    }
    return;
  }
  if (type == KChartType.columns) {
    canvas.drawRect(Rect.fromLTRB(x - width / 2, getY(point.close), x + width / 2, rect.bottom),
        paint..color = color);
    return;
  }
  final from = Offset(lastX, getY(last.close));
  final to = Offset(x, getY(point.close));
  final path = Path()..moveTo(from.dx, from.dy);
  if (type == KChartType.stepLine) path.lineTo(to.dx, from.dy);
  path.lineTo(to.dx, to.dy);
  if (type == KChartType.area || type == KChartType.baseline) {
    final fill = Path.from(path)
      ..lineTo(to.dx, rect.bottom)
      ..lineTo(from.dx, rect.bottom)
      ..close();
    if (type == KChartType.baseline) {
      final split = getY(baseline).clamp(rect.top, rect.bottom).toDouble();
      final baseFill = Path.from(path)
        ..lineTo(to.dx, split)
        ..lineTo(from.dx, split)
        ..close();
      for (final above in [true, false]) {
        canvas.save();
        canvas.clipRect(
            Rect.fromLTRB(-1e15, above ? rect.top : split, 1e15, above ? split : rect.bottom));
        canvas.drawPath(
            baseFill,
            paint
              ..style = PaintingStyle.fill
              ..color = (above ? colors.upColor : colors.dnColor).withValues(alpha: .18));
        canvas.drawPath(
            path,
            paint
              ..style = PaintingStyle.stroke
              ..color = above ? colors.upColor : colors.dnColor);
        canvas.restore();
      }
      return;
    }
    canvas.drawPath(
        fill,
        paint
          ..style = PaintingStyle.fill
          ..color = colors.kLineColor.withValues(alpha: .15));
  }
  canvas.drawPath(
      path,
      paint
        ..style = PaintingStyle.stroke
        ..color = colors.kLineColor);
  if (type == KChartType.lineWithMarkers) {
    canvas.drawOval(Rect.fromCenter(center: to, width: 4 / scaleX, height: 4),
        paint..style = PaintingStyle.fill);
  }
}
