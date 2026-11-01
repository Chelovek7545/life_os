import 'package:graph_ui/graph_ui.dart';
import '../../lifegraph/domain/graph_node.dart';
import '../../lifegraph/presentation/widgets/builtin_graph_forms.dart';

GraphNodeEditor spheresGraphEditor() =>
    builtinGraphEditor(GraphNodeType.sphere);
