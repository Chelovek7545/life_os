import 'package:flutter/material.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:goals_plugin/goals_plugin.dart' show goalsChildAction;

const goalGraphComponent = GraphNodeComponentSpec(
  kind: 'goal',
  label: 'ЦЕЛЬ',
  icon: Icons.flag_rounded,
  size: Size(180, 100),
  editTitle: 'Редактировать цель',
  createTitle: 'Добавить цель',
);
GraphNodeEditor goalsGraphEditor() => graphNodeEditor(goalGraphComponent);
GraphChildAction goalsGraphChildAction() => goalsChildAction(
  (_, actions) => graphChildForm(goalGraphComponent, actions),
);
