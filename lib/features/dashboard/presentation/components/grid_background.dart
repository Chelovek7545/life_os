import 'package:flutter/material.dart';

class GridBackgroundPainter extends CustomPainter {
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double spacing;

  GridBackgroundPainter({
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..style = PaintingStyle.fill;

    for (int x = 0; x < columns; x++) {
      for (int y = 0; y < rows; y++) {
        final left = spacing + x * (cellWidth + spacing);
        final top = spacing + y * (cellHeight + spacing);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cellWidth, cellHeight),
          const Radius.circular(8),
        );
        canvas.drawRRect(rect, fillPaint);
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridBackgroundPainter oldDelegate) {
    return oldDelegate.cellWidth != cellWidth || oldDelegate.cellHeight != cellHeight;
  }
}

class GridBackground extends StatelessWidget {
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double spacing;

  const GridBackground({
    super.key,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(rows * columns, (index) {
        final int x = index % columns;
        final int y = index ~/ columns;

        return Positioned(
          left: spacing + x * (cellWidth + spacing),
          top: spacing + y * (cellHeight + spacing),
          width: cellWidth,
          height: cellHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
          ),
        );
      }),
    );
  }
}
