import 'package:flutter/material.dart';
import 'package:life_os/features/lifegraph/graph_view.dart';

/// Единый размер карточки ноды. [GraphView] использует один размер на все узлы
/// (позиционирование, рёбра, зона тапа) — карточки вписывают контент внутрь.
const Size graphNodeSize = Size(180, 140);

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
