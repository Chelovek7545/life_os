import 'package:flutter/material.dart';

/// Paints the time grid without allocating a widget for every time slot.
class CalendarGridPainter extends CustomPainter {
  const CalendarGridPainter({
    required this.hourHeight,
    required this.startHour,
    required this.endHour,
    required this.dayWidth,
    required this.dayCount,
    required this.lineColor,
    required this.todayIndex,
  });
  final double hourHeight;
  final int startHour;
  final int endHour;
  final double dayWidth;
  final int dayCount;
  final Color lineColor;
  final int todayIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var hour = 0; hour <= endHour - startHour; hour++) {
      final y = hour * hourHeight;
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    for (var day = 0; day <= dayCount; day++) {
      final x = day * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    if (todayIndex >= 0 && todayIndex < dayCount) {
      final rect = Rect.fromLTWH(
        todayIndex * dayWidth,
        0,
        dayWidth,
        size.height,
      );
      canvas.drawRect(rect, Paint()..color = const Color(0x0AFFFFFF));
    }
  }

  @override
  bool shouldRepaint(covariant CalendarGridPainter old) =>
      hourHeight != old.hourHeight ||
      dayWidth != old.dayWidth ||
      todayIndex != old.todayIndex ||
      lineColor != old.lineColor;
}
