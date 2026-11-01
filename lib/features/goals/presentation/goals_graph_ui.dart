import 'package:graph_ui/graph_ui.dart';
import '../../lifegraph/domain/graph_node.dart';
import '../../lifegraph/presentation/widgets/builtin_graph_forms.dart';

GraphNodeEditor goalsGraphEditor() => builtinGraphEditor(GraphNodeType.goal);
GraphChildAction goalsGraphChildAction() => GraphChildAction(
  id: 'goals.create',
  label: 'Новую цель',
  childKind: 'goal',
  parentKinds: {'sphere'},
  builder: (_, actions) => builtinGraphChildForm(GraphNodeType.goal, actions),
);
