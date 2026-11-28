import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/canvas_add_dialog.dart';

void main() {
  final taskEditor = _editor('task', 'Создать задачу');
  final projectEditor = _editor('project', 'Создать проект');

  Future<void> open(
    WidgetTester tester, {
    required Size viewport,
    double textScale = 1,
    required ValueChanged<Object?> onSelect,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onSelect(
                await showCanvasAddDialog(
                  context,
                  editors: [taskEditor, projectEditor],
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
  }

  testWidgets('lays out paired actions on a wide canvas', (tester) async {
    Object? selected;
    await open(
      tester,
      viewport: const Size(1000, 720),
      onSelect: (value) => selected = value,
    );

    final task = tester.getTopLeft(find.text('Создать задачу'));
    final project = tester.getTopLeft(find.text('Создать проект'));
    expect(task.dy, project.dy);
    expect(task.dx, lessThan(project.dx));
    await tester.tap(find.text('Создать проект'));
    await tester.pumpAndSettle();
    expect(selected, same(projectEditor));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps actions reachable with large text on a narrow canvas', (
    tester,
  ) async {
    Object? selected;
    await open(
      tester,
      viewport: const Size(360, 460),
      textScale: 1.5,
      onSelect: (value) => selected = value,
    );

    final task = tester.getTopLeft(find.text('Создать задачу'));
    final project = tester.getTopLeft(find.text('Создать проект'));
    expect(task.dx, project.dx);
    expect(task.dy, lessThan(project.dy));
    final note = find.text('Добавить заметку');
    await tester.ensureVisible(note);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Закрыть').hitTestable(), findsOneWidget);
    await tester.tap(note);
    await tester.pumpAndSettle();
    expect(selected, CanvasAddAction.note);
    expect(tester.takeException(), isNull);
  });
}

GraphNodeEditor _editor(String kind, String label) => GraphNodeEditor(
  kind: kind,
  builder: (_, _) => const SizedBox.shrink(),
  standaloneForm: GraphStandaloneForm(
    label: label,
    builder: (_, _) => const SizedBox.shrink(),
  ),
);
