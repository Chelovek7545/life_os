import 'package:flutter/material.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'resources_screen.dart';
import 'package:resources_plugin/resources_plugin.dart' show ResourcesViewModel;

UiModuleSpec resourcesScreenModule(ResourcesViewModel viewModel) =>
    UiModuleSpec(
      id: 'resources.screen',
      screens: [
        PluginScreenContribution(
          id: 'resources',
          label: 'LIBRARY',
          icon: Icons.menu_book_rounded,
          order: 30,
          builder: (_, _) => ResourcesScreen(viewModel: viewModel),
        ),
      ],
    );
