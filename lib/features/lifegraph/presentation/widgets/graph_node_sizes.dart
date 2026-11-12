import 'package:flutter/material.dart';
import 'package:graph_canvas/graph_canvas.dart';

/// Размер по умолчанию — для ghost'ов GraphView и клампинга без известного типа.
const Size graphNodeSize = Size(176, 68);

/// Размер мирового канваса (ширина и высота).
const double graphWorldSize = 4200.0;

/// Отступ от края канваса при клампинге нод.
const double graphWorldMargin = 24.0;

/// Геометрия графа: размер узлов, зазоры, размер мира.
GraphLayout appGraphLayout({double worldSize = graphWorldSize}) => GraphLayout(
  nodeSize: graphNodeSize,
  levelGap: 236,
  siblingGap: 112,
  worldSize: Size.square(worldSize),
);
