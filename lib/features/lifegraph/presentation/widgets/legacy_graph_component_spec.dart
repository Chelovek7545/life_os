import 'package:flutter/material.dart';
import 'package:graph_components/graph_components.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'package:life_os/features/goals/presentation/goals_graph_ui.dart';
import 'package:life_os/features/spheres/presentation/spheres_graph_ui.dart';
import 'package:life_os/features/projects/presentation/projects_graph_ui.dart';
import 'package:life_os/features/tasks/presentation/tasks_graph_components.dart';

GraphNodeComponentSpec legacyGraphComponentSpec(GraphNodeType type) =>
    switch (type) {
      GraphNodeType.sphere => sphereGraphComponent,
      GraphNodeType.goal => goalGraphComponent,
      GraphNodeType.project => projectGraphComponent,
      GraphNodeType.task => taskGraphComponent(),
      GraphNodeType.subTask => taskGraphComponent(subtask: true),
      GraphNodeType.external => const GraphNodeComponentSpec(
        kind: 'external',
        label: 'УЗЕЛ',
        icon: Icons.extension_outlined,
        size: Size(180, 100),
        editTitle: 'Узел',
        createTitle: 'Добавить узел',
      ),
    };
