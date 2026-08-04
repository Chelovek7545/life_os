import 'package:flutter/material.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/core/ui/graph/graph_view.dart';

/// Размер ноды в зависимости от её типа.
Size graphNodeSizeOf(GraphNodeType type) {
  switch (type) {
    case GraphNodeType.sphere:
      return const Size(140, 140);
    case GraphNodeType.goal:
      return const Size(180, 100);
    case GraphNodeType.project:
      return const Size(180, 100);
    case GraphNodeType.task:
      return const Size(160, 120);
  }
}

/// Размер по умолчанию — для ghost'ов GraphView и клампинга без известного типа.
const Size graphNodeSize = Size(176, 68);

/// Размер мирового канваса (ширина и высота).
const double graphWorldSize = 4200.0;

/// Отступ от края канваса при клампинге нод.
const double graphWorldMargin = 24.0;

/// Геометрия графа: размер узлов, зазоры, размер мира.
GraphLayout appGraphLayout() => const GraphLayout(
      nodeSize: graphNodeSize,
      levelGap: 236,
      siblingGap: 112,
      worldSize: Size.square(graphWorldSize),
    );
