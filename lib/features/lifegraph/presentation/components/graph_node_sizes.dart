import 'package:life_os/features/lifegraph/domain/graph_node.dart';

/// Размер мирового канваса (ширина и высота). Ноды клампаются внутрь,
/// чтобы не уходить в отрицательные координаты за границы канваса.
const double graphWorldSize = 4200.0;

/// Отступ от края канваса при клампинге нод.
const double graphWorldMargin = 24.0;

/// Ширина карточки ноды (нужна painter'у рёбер, экрану и карточке).
double graphNodeWidth(GraphNodeType type) {
  switch (type) {
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

/// Высота карточки ноды.
double graphNodeHeight(GraphNodeType type) {
  switch (type) {
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
