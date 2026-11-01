import 'package:flutter/material.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';

const sphereGraphComponent = GraphNodeComponentSpec(
  kind: 'sphere',
  label: 'СФЕРА',
  icon: Icons.public_rounded,
  size: Size(140, 140),
  round: true,
  editTitle: 'Редактировать сферу',
  createTitle: 'Добавить ',
);
GraphNodeEditor spheresGraphEditor() => graphNodeEditor(sphereGraphComponent);
