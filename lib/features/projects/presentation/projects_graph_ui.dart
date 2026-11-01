import 'package:graph_ui/graph_ui.dart';
import '../../lifegraph/domain/graph_node.dart';
import '../../lifegraph/presentation/widgets/builtin_graph_forms.dart';

GraphNodeEditor projectsGraphEditor() =>
    builtinGraphEditor(GraphNodeType.project);
List<GraphChildAction> projectsGraphChildActions() => [
  GraphChildAction(
    id: 'projects.create',
    label: 'Новый проект',
    childKind: 'project',
    parentKinds: {'goal'},
    builder: (_, actions) =>
        builtinGraphChildForm(GraphNodeType.project, actions),
  ),
  GraphChildAction(
    id: 'projects.createChild',
    label: 'Новый подпроект',
    childKind: 'project',
    parentKinds: {'project'},
    order: 20,
    builder: (_, actions) =>
        builtinGraphChildForm(GraphNodeType.project, actions),
  ),
];
