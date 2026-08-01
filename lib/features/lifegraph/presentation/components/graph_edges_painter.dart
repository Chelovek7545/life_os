import 'package:flutter/material.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';

class GraphEdgesPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Matrix4 transformation;

  GraphEdgesPainter({
    required this.nodes,
    required this.edges,
    required this.transformation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final nodeMap = {for (final n in nodes) n.id: n};

    for (final edge in edges) {
      final from = nodeMap[edge.fromId];
      final to = nodeMap[edge.toId];
      if (from == null || to == null) continue;

      // Центр нод
      final fromCenter = Offset(from.x + _nodeWidth(from) / 2, from.y + _nodeHeight(from) / 2);
      final toCenter = Offset(to.x + _nodeWidth(to) / 2, to.y + _nodeHeight(to) / 2);

      canvas.drawLine(fromCenter, toCenter, paint);
    }
  }

  double _nodeWidth(GraphNode node) {
    switch (node.type) {
      case GraphNodeType.sphere:
        return 140;
      case GraphNodeType.goal:
        return 180;
      case GraphNodeType.project:
        return 180;
      case GraphNodeType.task:
        return 160;
    }
  }

  double _nodeHeight(GraphNode node) {
    switch (node.type) {
      case GraphNodeType.sphere:
        return 140;
      case GraphNodeType.goal:
        return 100;
      case GraphNodeType.project:
        return 100;
      case GraphNodeType.task:
        return 80;
    }
  }

  @override
  bool shouldRepaint(covariant GraphEdgesPainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges || oldDelegate.transformation != transformation;
  }
}