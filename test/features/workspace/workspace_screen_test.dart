import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/glassPopUpMenuButton.dart';
import 'package:life_os/features/workspace/presentation/workspace_screen.dart';
import 'package:life_os/features/workspace/workspace_controller.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';

class _Counter extends StatefulWidget {
  const _Counter(this.id);
  final String id;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      key: ValueKey('counter:${widget.id}'),
      onPressed: () => setState(() => count++),
      child: Text('count:$count'),
    ),
  );
}

void main() {
  testWidgets(
    'edit toggle hides layout controls without recreating panel content',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = WorkspaceController(
        editorIds: const {'tasks', 'calendar'},
        save: (_) async {},
        onSaveError: (_, _) {},
      );
      final id = controller.selectedId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceScreen(
              controller: controller,
              editors: [
                WorkspaceEditor(
                  id: 'tasks',
                  label: 'Задачи',
                  icon: Icons.checklist,
                  builder: (_, id) => _Counter(id),
                ),
                WorkspaceEditor(
                  id: 'calendar',
                  label: 'Календарь',
                  icon: Icons.calendar_month,
                  builder: (_, _) => const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
      final counter = find.byKey(ValueKey('counter:$id'));
      await tester.tap(counter);
      await tester.pump();
      final state = tester.state<_CounterState>(find.byType(_Counter));
      final initialLayout = controller.layout.encode();
      expect(controller.isEditing, isFalse);
      expect(find.byKey(ValueKey('workspace-editor:$id')), findsNothing);
      expect(find.byKey(ValueKey('workspace-menu:$id')), findsNothing);
      expect(
        find.byKey(const ValueKey('workspace-divider:initial-split')),
        findsOneWidget,
      );
      final toggle = find.byKey(const ValueKey('workspace-edit-toggle'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(controller.isEditing, isTrue);
      expect(find.byKey(ValueKey('workspace-editor:$id')), findsOneWidget);
      expect(find.byKey(ValueKey('workspace-menu:$id')), findsOneWidget);
      final divider = find.byKey(
        const ValueKey('workspace-divider:initial-split'),
      );
      expect(divider, findsOneWidget);
      expect(tester.state<_CounterState>(find.byType(_Counter)), same(state));
      expect(find.text('count:1'), findsOneWidget);
      final dividerPosition = tester.getCenter(divider);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final pane = find.byKey(ValueKey('workspace-pane:$id'));
      final width = tester.getSize(pane).width;
      await tester.dragFrom(dividerPosition, const Offset(100, 0));
      await tester.pump();
      expect(controller.isEditing, isFalse);
      expect(find.byKey(ValueKey('workspace-menu:$id')), findsNothing);
      expect(divider, findsOneWidget);
      expect(tester.state<_CounterState>(find.byType(_Counter)), same(state));
      expect(controller.layout.encode(), isNot(initialLayout));
      expect(tester.getSize(pane).width, closeTo(width + 100, .01));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('workspace-area-selector')),
        findsOneWidget,
      );
      expect(toggle, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await controller.close();
      controller.dispose();
    },
  );

  for (final axis in WorkspaceAxis.values) {
    testWidgets(
      'moving the second $axis divider keeps the first divider fixed',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = WorkspaceController(
          editorIds: const {'tasks'},
          save: (_) async {},
          onSaveError: (_, _) {},
          initial: WorkspaceLayout(
            WorkspaceSplit(
              'outer',
              axis,
              .65,
              WorkspaceSplit(
                'inner',
                axis,
                .45,
                const WorkspacePane('a', 'tasks'),
                const WorkspacePane('b', 'tasks'),
              ),
              const WorkspacePane('c', 'tasks'),
            ),
          ),
        );
        controller.setEditing(true);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkspaceScreen(
                controller: controller,
                editors: [
                  WorkspaceEditor(
                    id: 'tasks',
                    label: 'Задачи',
                    icon: Icons.checklist,
                    builder: (_, id) => _Counter(id),
                  ),
                ],
              ),
            ),
          ),
        );
        Finder divider(String id) =>
            find.byKey(ValueKey('workspace-divider:$id'));
        Rect pane(String id) =>
            tester.getRect(find.byKey(ValueKey('workspace-pane:$id')));
        void expectSameRect(Rect actual, Rect expected) {
          expect(actual.left, closeTo(expected.left, .0001));
          expect(actual.top, closeTo(expected.top, .0001));
          expect(actual.width, closeTo(expected.width, .0001));
          expect(actual.height, closeTo(expected.height, .0001));
        }

        final firstDivider = tester.getRect(divider('inner'));
        final firstPane = pane('a');
        final middlePane = pane('b');
        final lastPane = pane('c');
        final horizontal = axis == WorkspaceAxis.horizontal;
        await tester.drag(
          divider('outer'),
          horizontal ? const Offset(120, 0) : const Offset(0, 120),
        );
        await tester.pump();
        expectSameRect(tester.getRect(divider('inner')), firstDivider);
        expectSameRect(pane('a'), firstPane);
        expect(
          horizontal ? pane('b').width : pane('b').height,
          closeTo(
            (horizontal ? middlePane.width : middlePane.height) + 120,
            .01,
          ),
        );
        expect(
          horizontal ? pane('c').width : pane('c').height,
          closeTo((horizontal ? lastPane.width : lastPane.height) - 120, .01),
        );
        final secondDivider = tester.getRect(divider('outer'));
        final unchangedLastPane = pane('c');
        await tester.drag(
          divider('inner'),
          horizontal ? const Offset(-60, 0) : const Offset(0, -60),
        );
        await tester.pump();
        expectSameRect(tester.getRect(divider('outer')), secondDivider);
        expectSameRect(pane('c'), unchangedLastPane);
        final anchoredFirstDivider = tester.getRect(divider('inner'));
        final anchoredFirstPane = pane('a');
        await tester.drag(
          divider('outer'),
          horizontal ? const Offset(-2000, 0) : const Offset(0, -2000),
        );
        await tester.pump();
        expectSameRect(tester.getRect(divider('inner')), anchoredFirstDivider);
        expectSameRect(pane('a'), anchoredFirstPane);
        expect(
          horizontal ? pane('b').width : pane('b').height,
          closeTo(260, .01),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await controller.close();
        controller.dispose();
      },
    );
  }

  testWidgets(
    'split menus, divider, editor selection and compact layout preserve pane state',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = WorkspaceController(
        editorIds: const {'tasks', 'calendar'},
        save: (_) async {},
        onSaveError: (_, _) {},
      );
      final first = controller.layout.root.panes.first.id;
      controller.setEditing(true);
      final second = controller.layout.root.panes.last.id;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkspaceScreen(
              controller: controller,
              editors: [
                WorkspaceEditor(
                  id: 'tasks',
                  label: 'Задачи',
                  icon: Icons.checklist,
                  builder: (_, id) => _Counter(id),
                ),
                WorkspaceEditor(
                  id: 'calendar',
                  label: 'Календарь',
                  icon: Icons.calendar_month,
                  builder: (_, _) =>
                      const Center(child: Text('calendar content')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(ValueKey('counter:$first')));
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);
      final before = tester
          .getSize(find.byKey(ValueKey('workspace-pane:$first')))
          .width;
      await tester.drag(
        find.byKey(const ValueKey('workspace-divider:initial-split')),
        const Offset(100, 0),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byKey(ValueKey('workspace-pane:$first'))).width,
        greaterThan(before),
      );

      await tester.tap(find.byKey(ValueKey('workspace-menu:$first')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Разделить вертикально'));
      await tester.pumpAndSettle();
      expect(controller.layout.root.panes.length, 3);
      expect(find.text('count:1'), findsOneWidget);
      final added = controller.selectedId;
      await tester.tap(find.byKey(ValueKey('workspace-editor:$added')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(MenuItemButton, 'Календарь').hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(
        controller.layout.root.panes
            .lastWhere((pane) => pane.id == added)
            .editorId,
        'calendar',
      );
      controller.closePane(added);
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);

      controller.toggleMaximize(first);
      await tester.pump();
      expect(find.text('calendar content'), findsNothing);
      controller.toggleMaximize(first);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspace-area-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Область 2 · Календарь').last);
      await tester.pumpAndSettle();
      expect(controller.selectedId, second);
      expect(find.text('calendar content'), findsOneWidget);
      tester.view.physicalSize = const Size(1400, 1000);
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);
      tester.view.physicalSize = const Size(390, 230);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(ValueKey('workspace-menu:$second')));
      await tester.pumpAndSettle();
      final horizontal = find.widgetWithText(
        PopupMenuItem<PopUpMenuAction>,
        'Разделить горизонтально',
      );
      expect(
        tester.widget<PopupMenuItem<PopUpMenuAction>>(horizontal).enabled,
        isFalse,
      );
      await tester.tap(horizontal);
      await tester.pump();
      expect(controller.layout.root.panes.length, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      controller.closePane(first);
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('workspace-menu:$second')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuItem<PopUpMenuAction>>(
              find.widgetWithText(
                PopupMenuItem<PopUpMenuAction>,
                'Закрыть область',
              ),
            )
            .enabled,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await controller.close();
      controller.dispose();
    },
  );
}
