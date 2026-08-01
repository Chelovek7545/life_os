import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/presentation/components/graph_node_sizes.dart';

/// Безье-рёбра в стиле канваса v1: плавные дуги от правого края родителя
/// к левому краю ребёнка, градиент цвета родителя -> ребёнка, мягкое свечение
/// и опциональная reveal-анимация прорисовки (ключ 'parentId>childId').
class GraphEdgesPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, double> reveals;

  const GraphEdgesPainter({
    required this.nodes,
    required this.edges,
    this.reveals = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    for (final edge in edges) {
      final from = nodeMap[edge.fromId];
      final to = nodeMap[edge.toId];
      if (from == null || to == null) continue;

      final a = Offset(from.x + graphNodeWidth(from.type) + 18, from.y + graphNodeHeight(from.type) / 2);
      final b = Offset(to.x - 8, to.y + graphNodeHeight(to.type) / 2);

      final dx = math.max(56.0, (b.dx - a.dx) * 0.55);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);

      final reveal = reveals['${edge.fromId}>${edge.toId}'] ?? 1;
      Path drawn = path;
      ui.PathMetric? pm;
      if (reveal < 1) {
        pm = path.computeMetrics().first;
        drawn = pm.extractPath(0, pm.length * reveal);
      }

      final cFrom = _colorOf(from);
      final cTo = _colorOf(to);

      // Мягкое под-свечение.
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 8
          ..color = cTo.withValues(alpha: 0.10),
      );

      // Градиентная линия: цвет родителя -> цвет ребёнка.
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4
          ..shader = ui.Gradient.linear(a, b, [cFrom.withValues(alpha: 0.55), cTo]),
      );

      // Искра на кончике прорисовки.
      if (reveal < 1 && pm != null) {
        final tip = pm.getTangentForOffset(pm.length * reveal)?.position ?? b;
        canvas.drawCircle(tip, 7, Paint()..color = Colors.white.withValues(alpha: 0.18));
        canvas.drawCircle(tip, 3.2, Paint()..color = Colors.white);
      }
    }
  }

  Color _colorOf(GraphNode n) => Color(int.parse(n.color.replaceFirst('#', '0xFF')));

  @override
  bool shouldRepaint(covariant GraphEdgesPainter oldDelegate) =>
      !identical(oldDelegate.nodes, nodes) ||
      !identical(oldDelegate.edges, edges) ||
      !identical(oldDelegate.reveals, reveals);
}
