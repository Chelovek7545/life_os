import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_canvas/graph_canvas.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  late BehaviorSubject<List<GraphNode>> nodes;
  late BehaviorSubject<List<GraphNote>> notes;
  late Map<String, NodeState> nodeStates;
  late Map<String, NoteState> noteStates;
  late List<GraphAction> actions;
  GraphSelection? menu;

  setUp(() {
    nodes = BehaviorSubject.seeded([
      GraphNode(
        id: 'a',
        label: 'A',
        index: 0,
        depth: 0,
        parentId: null,
        size: const Size(100, 60),
        position: const Offset(100, 100),
      ),
      GraphNode(
        id: 'b',
        label: 'B',
        index: 1,
        depth: 1,
        parentId: 'a',
        size: const Size(100, 60),
        position: const Offset(300, 100),
      ),
      GraphNode(
        id: 'c',
        label: 'C',
        index: 2,
        depth: 0,
        parentId: null,
        size: const Size(100, 60),
        position: const Offset(500, 400),
      ),
    ]);
    notes = BehaviorSubject.seeded([
      GraphNote(
        id: 'a',
        index: 0,
        position: const Offset(100, 240),
        size: const Size(120, 80),
        text: 'Note',
      ),
    ]);
    nodeStates = {};
    noteStates = {};
    actions = [];
    menu = null;
  });
  tearDown(() async {
    await nodes.close();
    await notes.close();
  });

  Future<void> mount(WidgetTester tester, {bool delayedTaps = false}) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphView(
            nodes: nodes,
            notes: notes,
            onAction: actions.add,
            onSelectionContextMenu: (selection, _) => menu = selection,
            layout: const GraphLayout(worldSize: Size(2000, 2000)),
            nodeBuilder: (context, state) {
              nodeStates[state.node.id] = state;
              return GestureDetector(
                key: ValueKey('hit:${state.node.id}'),
                onTap: state.select,
                onDoubleTap: delayedTaps ? state.toggleCollapse : null,
                dragStartBehavior: DragStartBehavior.down,
                onPanStart: state.dragStart,
                onPanUpdate: state.dragUpdate,
                onPanEnd: state.dragEnd,
                child: ColoredBox(
                  color: state.selected ? Colors.orange : Colors.grey,
                  child: Text(state.node.label),
                ),
              );
            },
            noteBuilder: (context, state) {
              noteStates[state.note.id] = state;
              return GestureDetector(
                key: ValueKey('note-hit:${state.note.id}'),
                onTap: state.select,
                onDoubleTap: delayedTaps ? state.beginEdit : null,
                dragStartBehavior: DragStartBehavior.down,
                onPanStart: state.dragStart,
                onPanUpdate: state.dragUpdate,
                onPanEnd: state.dragEnd,
                onSecondaryTapDown: (d) =>
                    state.onSelectionContextMenu?.call(d.globalPosition),
                child: ColoredBox(
                  color: state.selected ? Colors.orange : Colors.grey,
                  child: Text(state.text),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value =
        Matrix4.identity();
    await tester.pump();
  }

  Future<void> selectMixed(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('hit:a')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.byKey(const ValueKey('hit:b')));
    await tester.tap(find.byKey(const ValueKey('note-hit:a')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets(
    'modifier selection survives delayed taps after Ctrl is released',
    (tester) async {
      await mount(tester, delayedTaps: true);
      await tester.tap(find.byKey(const ValueKey('hit:a')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byKey(const ValueKey('hit:b')));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 500));
      expect(nodeStates['a']!.selected, isTrue);
      expect(nodeStates['b']!.selected, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byKey(const ValueKey('note-hit:a')));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 500));
      expect(noteStates['a']!.selected, isTrue);
      expect(nodeStates['a']!.selected, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byKey(const ValueKey('hit:a')));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 500));
      expect(nodeStates['a']!.selected, isFalse);
      expect(nodeStates['b']!.selected, isTrue);
      expect(noteStates['a']!.selected, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets(
    'Ctrl selection moves nodes and notes together and commits every position',
    (tester) async {
      await mount(tester);
      await selectMixed(tester);
      expect(nodeStates['a']!.selected, isTrue);
      expect(nodeStates['b']!.selected, isTrue);
      expect(noteStates['a']!.selected, isTrue);
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('hit:a'))),
      );
      await drag.moveBy(const Offset(60, 40));
      await tester.pump();
      final livePosition = nodeStates['a']!.node.position;
      nodes.add([
        for (final n in nodes.value)
          n.clone()
            ..position = (n.id == 'a'
                ? const Offset(100, 100)
                : n.id == 'b'
                ? const Offset(300, 100)
                : const Offset(500, 400)),
      ]);
      notes.add([
        notes.value.single.clone()..position = const Offset(100, 240),
      ]);
      await tester.pump();
      expect(nodeStates['a']!.node.position, livePosition);
      await drag.up();
      await tester.pump();
      final delta = nodeStates['a']!.node.position - const Offset(100, 100);
      expect(delta.distance, greaterThan(20));
      expect(nodeStates['b']!.node.position - const Offset(300, 100), delta);
      expect(noteStates['a']!.note.position - const Offset(100, 240), delta);
      expect(nodeStates['c']!.node.position, const Offset(500, 400));
      expect(actions.whereType<MoveEndAction>().map((a) => a.id).toSet(), {
        'a',
        'b',
      });
      expect(actions.whereType<MoveNoteEndAction>().single.id, 'a');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets(
    'Shift rectangle selects visible mixed objects and Escape clears selection',
    (tester) async {
      await mount(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final gesture = await tester.startGesture(const Offset(60, 50));
      await gesture.moveTo(const Offset(85, 75));
      await tester.pump();
      await gesture.moveTo(const Offset(440, 350));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('graph-selection-rectangle')),
        findsOneWidget,
      );
      await gesture.up();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(nodeStates['a']!.selected, isTrue);
      expect(nodeStates['b']!.selected, isTrue);
      expect(nodeStates['c']!.selected, isFalse);
      expect(noteStates['a']!.selected, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(nodeStates.values.any((s) => s.selected), isFalse);
      expect(noteStates['a']!.selected, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  for (final modifier in [
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.controlLeft,
  ]) {
    testWidgets(
      'releasing ${modifier.keyLabel} before the mouse keeps frame updates and clears it on release',
      (tester) async {
        await mount(tester);
        await tester.sendKeyDownEvent(modifier);
        await tester.pump();
        final gesture = await tester.startGesture(
          const Offset(60, 50),
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveTo(const Offset(440, 350));
        await tester.pump();
        expect(nodeStates['b']!.selected, isTrue);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
        expect(
          tester
              .widget<InteractiveViewer>(find.byType(InteractiveViewer))
              .panEnabled,
          isFalse,
        );
        await gesture.moveTo(const Offset(200, 200));
        await tester.pump();
        expect(nodeStates['a']!.selected, isTrue);
        expect(nodeStates['b']!.selected, isFalse);
        expect(noteStates['a']!.selected, isFalse);
        await gesture.up();
        await tester.pump();
        expect(
          find.byKey(const ValueKey('graph-selection-rectangle')),
          findsNothing,
        );
        expect(
          tester
              .widget<InteractiveViewer>(find.byType(InteractiveViewer))
              .panEnabled,
          isTrue,
        );
        await tester.dragFrom(const Offset(60, 50), const Offset(-30, -30));
        await tester.pump();
        expect(
          tester
              .widget<InteractiveViewer>(find.byType(InteractiveViewer))
              .transformationController!
              .value
              .getTranslation()
              .x,
          lessThan(0),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  }

  testWidgets('cancelled frame clears after its modifier was released', (
    tester,
  ) async {
    await mount(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final gesture = await tester.startGesture(
      const Offset(60, 50),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(const Offset(440, 350));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await gesture.cancel();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('graph-selection-rectangle')),
      findsNothing,
    );
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .panEnabled,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets(
    'group bounds preserve spacing, right click keeps the group and replaces it on another object',
    (tester) async {
      await mount(tester);
      await selectMixed(tester);
      await tester.drag(
        find.byKey(const ValueKey('note-hit:a')),
        const Offset(-500, 0),
      );
      await tester.pump();
      expect(nodeStates['a']!.node.position.dx, 24);
      expect(nodeStates['b']!.node.position.dx, 224);
      expect(noteStates['a']!.note.position.dx, 24);
      Future<void> rightClick(String key) async {
        final pointer = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey(key))),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await tester.pump(const Duration(milliseconds: 150));
        await pointer.up();
        await tester.pump();
      }

      await rightClick('hit:a');
      expect(menu!.nodeIds, {'a', 'b'});
      expect(menu!.noteIds, {'a'});
      await rightClick('note-hit:a');
      expect(menu!.length, 3);
      await rightClick('hit:c');
      expect(menu!.nodeIds, {'c'});
      expect(menu!.noteIds, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets(
    'selection mode works without modifiers and ignores collapsed descendants',
    (tester) async {
      await mount(tester);
      nodeStates['a']!.toggleCollapse();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Выделение рамкой (Ctrl + перетаскивание)'),
      );
      await tester.pump();
      await tester.dragFrom(const Offset(60, 50), const Offset(400, 310));
      await tester.pump();
      expect(nodeStates['a']!.selected, isTrue);
      expect(nodeStates['b']!.selected, isFalse);
      expect(noteStates['a']!.selected, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
