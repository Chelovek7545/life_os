import 'package:resources_plugin/resources_plugin.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:notes_api/notes_api.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';

ResourcesPlugin createResourcesPlugin({
  required NotesCatalog notes,
  required PluginUiRegistry ui,
  VaultNotesApi? vault,
  Set<String> dependencies = const {},
}) => ResourcesPlugin(
  notes: notes,
  ui: ui,
  vault: vault,
  dependencies: dependencies,
  screen: (_, model) => ResourcesScreen(viewModel: model),
);
