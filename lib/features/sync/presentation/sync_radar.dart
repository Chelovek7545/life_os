import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

class SyncRadar extends StatefulWidget {
  const SyncRadar({
    super.key,
    required this.receiving,
    this.deviceIds = const [],
  });

  final bool receiving;
  final List<String> deviceIds;

  @override
  State<SyncRadar> createState() => _SyncRadarState();
}

class _SyncRadarState extends State<SyncRadar>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
    value: 1,
  );
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _sweep.value = 1;
    } else {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 112,
      child: CustomPaint(
        painter: _RadarPainter(
          _sweep,
          receiving: widget.receiving,
          deviceIds: widget.deviceIds,
        ),
      ),
    ),
  );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.sweep, {required this.receiving, required this.deviceIds})
    : super(repaint: sweep);

  final Animation<double> sweep;
  final bool receiving;
  final List<String> deviceIds;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final tint = AppColors.primary;
    final grid = Paint()
      ..color = tint.withValues(alpha: receiving ? .27 : .19)
      ..style = PaintingStyle.stroke;
    for (final ratio in [.36, .68, 1.0]) {
      canvas.drawCircle(center, radius * ratio, grid);
    }

    final progress = sweep.value;
    final bearing = -math.pi / 3 + progress * 2 * math.pi;
    final glow = math.sin(progress * math.pi);
    const tail = math.pi / 2.4;
    final shade = SweepGradient(
      endAngle: tail,
      colors: [
        tint.withValues(alpha: 0),
        tint.withValues(alpha: .10 + glow * .25),
      ],
      transform: GradientRotation(bearing - tail),
    );
    canvas.drawArc(
      rect,
      bearing - tail,
      tail,
      true,
      Paint()..shader = shade.createShader(rect),
    );
    canvas.drawLine(
      center,
      center + Offset(math.cos(bearing), math.sin(bearing)) * radius,
      Paint()
        ..color = tint.withValues(alpha: .28 + glow * .48)
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(center, 4, Paint()..color = tint);
    for (final id in deviceIds.take(12)) {
      final hash = id.hashCode;
      final angle = (hash % 360) * math.pi / 180;
      final distance = radius * (.42 + ((hash >> 9) % 42) / 100);
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final gap = (bearing - angle) % (2 * math.pi);
      final highlight = 1 - (gap / tail).clamp(0, 1);
      canvas.drawCircle(
        position,
        3.5 + highlight * 4,
        Paint()..color = tint.withValues(alpha: .14 + highlight * .14),
      );
      canvas.drawCircle(position, 2.8, Paint()..color = tint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      sweep != oldDelegate.sweep ||
      receiving != oldDelegate.receiving ||
      !listEquals(deviceIds, oldDelegate.deviceIds);
}
