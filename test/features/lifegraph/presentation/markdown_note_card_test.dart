import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_canvas/graph_canvas.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';

Widget noteCard({
  required String title,
  required bool editing,
  required Future<void> Function(String) onTitleSubmitted,
}) => DefaultNoteCard(
  title: title,
  onTitleSubmitted: onTitleSubmitted,
  theme: AppGraphThemes.dark,
  state: NoteState(
    note: GraphNote(
      id: 'md',
      index: 0,
      position: Offset.zero,
      text: 'Only body',
    ),
    size: const Size(180, 110),
    text: 'Only body',
    selected: false,
    editing: editing,
    canDelete: false,
    accent: Colors.amber,
    select: () {},
    beginEdit: () {},
    endEdit: () {},
    updateText: (_) {},
    remove: () {},
    dragStart: (_) {},
    dragUpdate: (_) {},
    dragEnd: (_) {},
  ),
);

Widget host(Widget card) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 180, height: 110, child: card),
          TextButton(onPressed: () {}, child: const Text('Снаружи')),
        ],
      ),
    ),
  ),
);

void main() {
  final titleField = find.byKey(const ValueKey('note-title-editor'));
  testWidgets(
    'title edits inline only in edit mode, Enter submits without changing body',
    (tester) async {
      const title = 'Очень длинное название Markdown-заметки с пробелами';
      final submitted = <String>[];
      Future<void> save(String title) async {
        submitted.add(title);
      }

      await tester.pumpWidget(
        host(noteCard(title: title, editing: false, onTitleSubmitted: save)),
      );
      final label = tester.widget<Text>(find.text(title));
      expect(label.overflow, TextOverflow.ellipsis);
      await tester.tap(find.text(title));
      await tester.pump(const Duration(milliseconds: 350));
      expect(titleField, findsNothing);
      await tester.pumpWidget(
        host(noteCard(title: title, editing: true, onTitleSubmitted: save)),
      );
      await tester.pump();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(titleField, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(titleField, 'Новое название');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(submitted, ['Новое название']);
      expect(titleField, findsNothing);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .single
            .controller!
            .text,
        'Only body',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Escape cancels, empty titles stay inline, blur saves a valid title',
    (tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        host(
          noteCard(
            title: 'Original',
            editing: true,
            onTitleSubmitted: (value) async {
              submitted.add(value);
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();
      await tester.enterText(titleField, 'Cancelled');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(submitted, isEmpty);
      expect(find.text('Original'), findsOneWidget);
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();
      await tester.enterText(titleField, '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Укажите название.'), findsOneWidget);
      expect(submitted, isEmpty);
      await tester.enterText(titleField, 'Blur saved');
      await tester.tap(find.text('Снаружи'));
      await tester.pumpAndSettle();
      expect(submitted, ['Blur saved']);
      expect(titleField, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'an async rename submits once, shows errors inline and supports retry',
    (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      var title = 'Original';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Center(
                child: SizedBox(
                  width: 180,
                  height: 110,
                  child: noteCard(
                    title: title,
                    editing: true,
                    onTitleSubmitted: (value) async {
                      calls++;
                      if (calls == 1) await gate.future;
                      setState(() => title = value);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();
      await tester.enterText(titleField, 'Occupied');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<TextField>(titleField).readOnly, isTrue);
      gate.completeError(StateError('Имя уже занято'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Имя уже занято'), findsOneWidget);
      expect(tester.widget<TextField>(titleField).controller!.text, 'Occupied');
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(titleField, 'Saved');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(title, 'Saved');
      expect(find.text('Saved'), findsOneWidget);
      expect(titleField, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
