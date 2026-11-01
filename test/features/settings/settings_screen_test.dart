import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:life_os/app/plugins/obsidian_ui.dart';
import 'package:life_os/features/settings/vault_settings_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/settings/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    late PluginUiRegistry ui;
    late ObsidianVault vault;
    late AppPlugin plugin;
    setUp(() async {
      ui = PluginUiRegistry();
      vault = ObsidianVault();
      plugin = registerObsidianUi(vault, AppVaultSettings(), ui);
      await plugin.start();
    });
    tearDown(() async {
      await plugin.stop();
      await vault.dispose();
      ui.dispose();
    });
    Widget app() => MaterialApp(
      builder: (_, child) => PluginUiScope(registry: ui, child: child!),
      home: const SettingsScreen(),
    );
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('renders section headers', (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('ОСНОВНЫЕ'), findsOneWidget);
      expect(find.text('ПРЕДПОЧТЕНИЯ'), findsOneWidget);
      expect(find.text('OBSIDIAN INTEGRATION'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('О СИСТЕМЕ'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('О СИСТЕМЕ'), findsOneWidget);
    });

    testWidgets('renders theme toggle', (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('Тёмная тема'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    });

    testWidgets('renders notifications toggle', (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('Уведомления'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
    });

    testWidgets('renders language selector', (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('Язык приложения'), findsOneWidget);
      expect(find.byIcon(Icons.language_outlined), findsOneWidget);
    });

    testWidgets('renders blur toggle', (tester) async {
      await tester.pumpWidget(app());

      await tester.scrollUntilVisible(
        find.text('Эффект размытия (Blur)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Эффект размытия (Blur)'), findsOneWidget);
      expect(find.byIcon(Icons.blur_on), findsOneWidget);
    });

    testWidgets('renders obsidian vault path row', (tester) async {
      await tester.pumpWidget(app());

      expect(find.text('Путь к хранилищу Obsidian (Vault)'), findsOneWidget);
      final row = find.ancestor(
        of: find.text('Путь к хранилищу Obsidian (Vault)'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: row, matching: find.text('Не указан')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.edit_outlined)),
        findsOneWidget,
      );
    });

    testWidgets('renders about section', (tester) async {
      await tester.pumpWidget(app());

      // 'О программе' уходит за экран после добавления секции Obsidian.
      await tester.scrollUntilVisible(
        find.text('О программе'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('О программе'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}
