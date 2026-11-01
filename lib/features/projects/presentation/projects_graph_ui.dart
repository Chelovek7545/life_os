import 'package:flutter/material.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:projects_plugin/projects_plugin.dart';

const projectGraphComponent = GraphNodeComponentSpec(
  kind: 'project',
  label: 'ПРОЕКТ',
  icon: Icons.folder_rounded,
  size: Size(180, 100),
  editTitle: 'Редактировать проект',
  createTitle: 'Добавить проект',
);
GraphNodeEditor projectsGraphEditor() => graphNodeEditor(projectGraphComponent);
List<GraphChildAction> projectsGraphChildActions() => projectsChildActions(
  (_, actions) => graphChildForm(projectGraphComponent, actions),
);
