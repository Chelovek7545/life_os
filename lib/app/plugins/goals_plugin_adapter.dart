import 'package:goals_plugin/goals_plugin.dart';
import 'package:goals_api/goals_api.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:graph_components/graph_components.dart';
import 'package:life_os/features/goals/presentation/goals_graph_ui.dart';

GoalsUiBindings goalsUiBindings() {
  final card = graphNodePresentation(goalGraphComponent);
  return GoalsUiBindings(
    nodeCard: card.builder,
    nodeSize: card.size,
    editor: graphNodeEditor(goalGraphComponent).builder,
    createForm: (_, actions) => graphChildForm(goalGraphComponent, actions),
  );
}

GoalsPlugin createGoalsPlugin({
  required GoalsApi goals,
  required GraphContributorRegistry contributors,
  required GraphNodePresentationRegistry presentations,
  required GraphEditorRegistry editors,
  required GraphCommandRegistry commands,
  required GraphDeleteHandler delete,
}) => GoalsPlugin(
  goals: goals,
  contributors: contributors,
  presentations: presentations,
  editors: editors,
  commands: commands,
  visuals: goalsUiBindings(),
  delete: delete,
);
