import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/app.dart';
import 'package:life_os/main_screen.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart' show PulsePanelSlots;
import 'package:life_os/features/habits/presentation/todays_habits_panel.dart';
import 'package:life_os/features/habits/presentation/habits_calendar_panel.dart';
import '../support/test_app.dart';

Future<void> pumpShell(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

class DraftPage extends StatefulWidget {
  const DraftPage({super.key});
  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(key: const ValueKey('plugin-draft'), controller: controller);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'registered destination appears in both layouts and retains its draft',
    (tester) async {
      final module = UiModuleSpec(
        id: 'extra.ui',
        screens: [
          PluginScreenContribution(
            id: 'extra',
            label: 'EXTRA',
            icon: Icons.extension,
            order: 40,
            builder: (_, _) => const DraftPage(),
          ),
        ],
      );
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false, uiModules: [module]),
      ))!;
      await tester.pumpWidget(MyApp(diContainer: app));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('navigation-rail:extra')));
      await pumpShell(tester);
      await tester.enterText(
        find.byKey(const ValueKey('plugin-draft')),
        'Keep this draft',
      );
      app.navigation.open('pulse');
      await pumpShell(tester);
      app.navigation.open('extra');
      await pumpShell(tester);
      expect(find.text('Keep this draft'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpShell(tester);
      expect(
        find.byKey(const ValueKey('navigation-bar:extra')),
        findsOneWidget,
      );
      expect(find.text('Keep this draft'), findsOneWidget);
      app.ui.unregister('extra.ui');
      await pumpShell(tester);
      expect(app.navigation.selectedId, 'pulse');
      expect(find.byKey(const ValueKey('plugin-draft')), findsNothing);
      await disposeTestApp(tester, app);
    },
  );

  test(
    'Pulse-to-Tasks navigation dispatches to the registered task editor',
    () async {
      final app = await createTestApp(enableObsidian: false);
      addTearDown(app.dispose);
      final task = Task.blank().copyWith(title: 'Open through navigation');
      await app.tasksRepository.addTask(task);
      final context = app.navigation.contextFor(
        app.ui.screens.firstWhere((screen) => screen.id == 'pulse'),
      );
      expect(context.openScreen('tasks', argument: task), isTrue);
      expect(app.navigation.selectedId, 'tasks');
      expect(app.tasksViewModel.activeTaskWithProject?.task.id, task.id);
      expect(app.tasksViewModel.currentUiFlags.isFormVisible, isTrue);
    },
  );

  testWidgets(
    'habits panels and calendar detach without removing Pulse or reviving stale callbacks',
    (tester) async {
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      await tester.pumpWidget(MyApp(diContainer: app));
      await tester.pump();
      expect(app.navigation.selectedId, 'pulse');
      expect(
        app.ui.panelsFor(PulsePanelSlots.center).single.id,
        'habits.today',
      );
      final open = tester
          .widget<TodaysHabitsPanel>(find.byType(TodaysHabitsPanel))
          .onOpenCalendar;
      open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HabitsCalendarPanel), findsOneWidget);
      app.ui.unregister('habits.ui');
      await pumpShell(tester);
      expect(find.byType(TodaysHabitsPanel), findsNothing);
      expect(find.byType(HabitsCalendarPanel), findsNothing);
      expect(find.byTooltip('Habits'), findsNothing);
      open();
      await tester.pump();
      expect(app.navigation.selectedId, 'pulse');
      expect(find.byType(HabitsCalendarPanel), findsNothing);
      await tester.runAsync(app.plugins.stop);
      await pumpShell(tester);
      expect(find.text('Нет доступных экранов'), findsOneWidget);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets('navigation handles a scrollable set of arbitrary destinations', (
    tester,
  ) async {
    var selected = -1;
    final screens = [
      for (var i = 0; i < 12; i++)
        PluginScreenContribution(
          id: 'screen$i',
          label: 'PAGE$i',
          icon: Icons.extension,
          builder: (_, _) => const SizedBox(),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 320,
              child: SlidingNavBar(
                destinations: screens,
                selectedIndex: 0,
                onTap: (index) => selected = index,
              ),
            ),
          ),
        ),
      ),
    );
    final scroll = find.byType(SingleChildScrollView);
    await tester.drag(scroll, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PAGE11'));
    await tester.pump();
    expect(selected, 11);
  });
}
