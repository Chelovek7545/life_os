import 'package:flutter/material.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'package:graph_canvas/graph_canvas.dart';
import 'legacy_graph_component_spec.dart';

/// Размер ноды в зависимости от её типа.
Size graphNodeSizeOf(GraphNodeType type) => legacyGraphComponentSpec(type).size;

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
