import 'package:graph_ui/graph_ui.dart';
import 'package:projects_plugin/projects_plugin.dart';
import '../../lifegraph/domain/graph_node.dart';
import '../../lifegraph/presentation/widgets/builtin_graph_forms.dart';

GraphNodeEditor projectsGraphEditor() =>
    builtinGraphEditor(GraphNodeType.project);
List<GraphChildAction> projectsGraphChildActions() => projectsChildActions(
  (_, actions) => builtinGraphChildForm(GraphNodeType.project, actions),
);
