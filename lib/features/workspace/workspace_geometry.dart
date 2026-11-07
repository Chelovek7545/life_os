import 'dart:math' as math;
import 'dart:ui';
import 'workspace_layout.dart';

class WorkspaceSplitBounds {
  const WorkspaceSplitBounds(
    this.split,
    this.bounds,
    this.first,
    this.divider,
    this.second,
  );
  final WorkspaceSplit split;
  final Rect bounds;
  final Rect first;
  final Rect divider;
  final Rect second;
  bool get horizontal => split.axis == WorkspaceAxis.horizontal;
  double get extent =>
      (horizontal ? bounds.width : bounds.height) - WorkspaceGeometry.gap;
  double get position => horizontal ? first.width : first.height;
}

class WorkspaceGeometry {
  WorkspaceGeometry(this.root, Size size) {
    final minimum = minimumSize(root);
    fits = size.width >= minimum.width && size.height >= minimum.height;
    if (fits) _place(root, Offset.zero & size);
  }

  static const gap = 8.0;
  static const paneSize = Size(260, 260);
  final WorkspaceNode root;
  late final bool fits;
  final panes = <String, Rect>{};
  final splits = <String, WorkspaceSplitBounds>{};

  static Size minimumSize(WorkspaceNode node) {
    if (node is! WorkspaceSplit) return paneSize;
    final a = minimumSize(node.first);
    final b = minimumSize(node.second);
    return node.axis == WorkspaceAxis.horizontal
        ? Size(a.width + b.width + gap, math.max(a.height, b.height))
        : Size(math.max(a.width, b.width), a.height + b.height + gap);
  }

  WorkspaceSplitBounds _divide(
    WorkspaceSplit split,
    Rect bounds,
    double position,
  ) {
    final horizontal = split.axis == WorkspaceAxis.horizontal;
    final first = horizontal
        ? Rect.fromLTWH(bounds.left, bounds.top, position, bounds.height)
        : Rect.fromLTWH(bounds.left, bounds.top, bounds.width, position);
    final divider = horizontal
        ? Rect.fromLTWH(first.right, bounds.top, gap, bounds.height)
        : Rect.fromLTWH(bounds.left, first.bottom, bounds.width, gap);
    final second = horizontal
        ? Rect.fromLTRB(divider.right, bounds.top, bounds.right, bounds.bottom)
        : Rect.fromLTRB(
            bounds.left,
            divider.bottom,
            bounds.right,
            bounds.bottom,
          );
    return WorkspaceSplitBounds(split, bounds, first, divider, second);
  }

  void _place(WorkspaceNode node, Rect bounds) {
    if (node is WorkspacePane) {
      panes[node.id] = bounds;
      return;
    }
    final split = node as WorkspaceSplit;
    final horizontal = split.axis == WorkspaceAxis.horizontal;
    final firstMin = minimumSize(split.first);
    final secondMin = minimumSize(split.second);
    final extent = (horizontal ? bounds.width : bounds.height) - gap;
    final position = (extent * split.ratio)
        .clamp(
          horizontal ? firstMin.width : firstMin.height,
          extent - (horizontal ? secondMin.width : secondMin.height),
        )
        .toDouble();
    final geometry = _divide(split, bounds, position);
    _place(split.first, geometry.first);
    _place(split.second, geometry.second);
    splits[node.id] = geometry;
  }

  WorkspaceNode moveDivider(String id, double delta) {
    final target = splits[id];
    if (target == null || !delta.isFinite) return root;
    final horizontal = target.horizontal;
    final origin = horizontal ? target.bounds.left : target.bounds.top;
    final edge = horizontal ? target.first.right : target.first.bottom;
    final otherEdge = edge + gap;
    var lower = 0.0;
    var upper = target.extent;
    // Only panes touching the dragged boundary may change size.
    for (final pane in target.split.first.panes) {
      final rect = panes[pane.id]!;
      if (((horizontal ? rect.right : rect.bottom) - edge).abs() < .001) {
        lower = math.max(
          lower,
          (horizontal
                  ? rect.left + paneSize.width
                  : rect.top + paneSize.height) -
              origin,
        );
      }
    }
    for (final pane in target.split.second.panes) {
      final rect = panes[pane.id]!;
      if (((horizontal ? rect.left : rect.top) - otherEdge).abs() < .001) {
        upper = math.min(
          upper,
          (horizontal
                  ? rect.right - paneSize.width
                  : rect.bottom - paneSize.height) -
              gap -
              origin,
        );
      }
    }
    final position = (target.position + delta).clamp(lower, upper).toDouble();
    if ((position - target.position).abs() < .000001) return root;

    WorkspaceNode reframe(WorkspaceNode node, Rect bounds) {
      if (node is WorkspacePane) return node;
      final split = node as WorkspaceSplit;
      final previous = splits[node.id]!;
      final start = previous.horizontal ? bounds.left : bounds.top;
      final coordinate = node.id == id
          ? origin + position
          : (previous.horizontal
                ? previous.divider.left
                : previous.divider.top);
      final offset = coordinate - start;
      final extent = (previous.horizontal ? bounds.width : bounds.height) - gap;
      final geometry = _divide(split, bounds, offset);
      return WorkspaceSplit(
        split.id,
        split.axis,
        offset / extent,
        reframe(split.first, geometry.first),
        reframe(split.second, geometry.second),
      );
    }

    return root.replace(id, reframe(target.split, target.bounds));
  }
}
