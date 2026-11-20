import 'package:flutter/material.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:graph_api/graph_api.dart';

const sphereGraphComponent = GraphNodeComponentSpec(
  kind: 'sphere',
  label: 'СФЕРА',
  icon: Icons.public_rounded,
  size: Size(140, 140),
  round: true,
  editTitle: 'Редактировать сферу',
  createTitle: 'Добавить ',
  details: _sphereTaskCount,
);

Widget? _sphereTaskCount(
  BuildContext context,
  GraphNodeData node,
  GraphNodeInteraction state,
) {
  final count = state.descendantProgress?.total;
  if (count == null) return null;
  final word = count % 100 >= 11 && count % 100 <= 14
      ? 'задач'
      : switch (count % 10) {
          1 => 'задача',
          2 || 3 || 4 => 'задачи',
          _ => 'задач',
        };
  return Text(
    '$count $word',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: GraphComponentPalette.of(context).onSurfaceVariant,
      fontSize: 11,
    ),
  );
}

GraphNodeEditor spheresGraphEditor() => graphNodeEditor(sphereGraphComponent);
