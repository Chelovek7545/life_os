import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Точечная сетка фона канваса (тонкая + крупная) в палитре приложения.
class GraphGridPainter extends CustomPainter {
  const GraphGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const fine = 42.0;
    final fineDots = <Offset>[];
    for (var x = fine; x < size.width; x += fine) {
      for (var y = fine; y < size.height; y += fine) {
        fineDots.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      fineDots,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.7
        ..color = Colors.white.withValues(alpha: 0.035),
    );

    final coarseDots = <Offset>[];
    const coarse = fine * 4;
    for (var x = coarse; x < size.width; x += coarse) {
      for (var y = coarse; y < size.height; y += coarse) {
        coarseDots.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      coarseDots,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.06),
    );
  }

  @override
  bool shouldRepaint(covariant GraphGridPainter oldDelegate) => false;
}
