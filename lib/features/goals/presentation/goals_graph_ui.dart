import 'package:flutter/material.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:goals_plugin/goals_plugin.dart' show goalsChildAction;
import 'package:graph_api/graph_api.dart';

const goalGraphComponent = GraphNodeComponentSpec(
  kind: 'goal',
  label: 'ЦЕЛЬ',
  icon: Icons.flag_rounded,
  size: Size(180, 100),
  editTitle: 'Редактировать цель',
  createTitle: 'Добавить цель',
  details: _goalProgress,
);

Widget? _goalProgress(
  BuildContext context,
  GraphNodeData node,
  GraphNodeInteraction state,
) {
  final progress = state.descendantProgress;
  if (progress == null) return null;
  final palette = GraphComponentPalette.of(context);
  return Row(
    children: [
      Expanded(
        child: LinearProgressIndicator(
          value: progress.total == 0 ? 0 : progress.completed / progress.total,
          minHeight: 5,
          borderRadius: BorderRadius.circular(8),
          color: graphColor(node.color, fallback: state.accent),
          backgroundColor: palette.surfaceContainerHigh,
          semanticsLabel:
              'Выполнено задач: ${progress.completed} из ${progress.total}',
        ),
      ),
      const SizedBox(width: 6),
      Text(
        '${progress.completed}/${progress.total}',
        maxLines: 1,
        style: TextStyle(color: palette.onSurfaceVariant, fontSize: 10),
      ),
    ],
  );
}

GraphNodeEditor goalsGraphEditor() => graphNodeEditor(goalGraphComponent);
GraphChildAction goalsGraphChildAction() => goalsChildAction(
  (_, actions) => graphChildForm(goalGraphComponent, actions),
);
