import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/theme/app_theme.dart';
import 'package:life_os/features/tasks/presentation/components/pulse_quick_task.dart';
import 'package:projects_api/projects_api.dart';

import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

final _input = find.byKey(const ValueKey('pulse.quick-task.input'));
final _save = find.byKey(const ValueKey('pulse.quick-task.save'));
Finder _inline(String label) => find.descendant(
  of: find.descendant(of: _input, matching: find.byType(ActionChip)),
  matching: find.text(label),
);

void main() {
  testWidgets(
    'Pulse note previews, edits and saves two scheduled tasks',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final study = Project.create(name: 'Учёба');
      final filming = Project.create(name: 'Съёмка');
      final home = Project.create(name: 'Дом');
      final secondHome = Project.create(name: 'Дом', parentProjectId: home.id);
      await tester.runAsync(() async {
        for (final project in [study, filming, home, secondHome]) {
          await app.projectsRepository.addProject(project);
        }
      });
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('pulse');
      await pumpStorage(tester);
      await tester.tap(find.byType(PulseQuickTaskAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final panelEnteringTop = tester.getTopLeft(_input).dy;
      await pumpStorage(tester);
      expect(panelEnteringTop, lessThan(tester.getTopLeft(_input).dy));
      await tester.enterText(_input, 'Завтра');
      await tester.pump();
      expect(_inline('Завтра'), findsNothing);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Завтра ',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      await tester.pump();
      expect(_inline('Завтра'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Завтра ку',
          selection: TextSelection.collapsed(offset: 9),
          composing: TextRange(start: 7, end: 9),
        ),
      );
      await tester.pump();
      expect(_inline('Завтра'), findsOneWidget);
      final editor = tester.state<EditableTextState>(find.byType(EditableText));
      expect(editor.renderEditable.plainText.length, 9);
      expect(editor.widget.controller.text, 'Завтра ку');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Завтра ',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(editor.widget.controller.text, 'Завтра');
      expect(_inline('Завтра'), findsNothing);
      await tester.enterText(_input, 'Проверить отчёт, проект: Неизвестный ');
      await tester.pumpAndSettle();
      expect(
        find.text('Проект «Неизвестный» не найден. Выберите проект.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(_save).onPressed, isNull);
      await tester.enterText(
        _input,
        'Завтра в 7 утра сделать дз, приоритет обычный, проект: учёба, '
        'а с 8 до 9 в понедельник уборку в доме, проект: "Дом" ',
      );
      await tester.pumpAndSettle();
      expect(find.text('Черновики задач · 2'), findsOneWidget);
      expect(_inline('07:00'), findsOneWidget);
      expect(_inline('08:00–09:00'), findsOneWidget);
      expect(_inline('учёба'), findsOneWidget);
      expect(
        find.text('У нескольких проектов название «Дом». Выберите нужный.'),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(_save).onPressed, isNull);
      expect(await tester.runAsync(app.tasksRepository.getAllTasks), isEmpty);

      await tester.tap(_inline('Дом'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey(('pulse.quick-task.project', secondHome.id))),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(_save).onPressed, isNotNull);

      final studyChip = _inline('учёба');
      final chipBounds = tester.getRect(studyChip);
      await tester.tap(studyChip, kind: PointerDeviceKind.mouse);
      final currentOption = find.byKey(
        ValueKey(('pulse.quick-task.project', study.id)),
      );
      final replacement = find.byKey(
        ValueKey(('pulse.quick-task.project', filming.id)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(5));
      expect(
        find.ancestor(of: replacement, matching: find.byType(SlideTransition)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: currentOption,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.getTopLeft(replacement).dy, greaterThan(chipBounds.bottom));
      await tester.tap(replacement);
      await tester.pumpAndSettle();
      expect(_inline('Съёмка'), findsOneWidget);
      expect(_inline('учёба'), findsNothing);
      expect(find.byType(PopupMenuItem<String>), findsNothing);

      final dateChip = find.ancestor(
        of: _inline('Завтра'),
        matching: find.byType(ActionChip),
      );
      expect(tester.widget<ActionChip>(dateChip).avatar, isA<Icon>());
      expect(
        tester.widget<ActionChip>(dateChip).shape,
        isA<RoundedRectangleBorder>(),
      );
      await tester.tap(_inline('Завтра'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(_inline('Завтра'), findsNothing);

      await tester.tap(_inline('08:00–09:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Убрать окончание'));
      await tester.pump();
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(_inline('08:00'), findsOneWidget);

      await tester.tap(_inline('приоритет обычный'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Высокий'));
      await tester.pumpAndSettle();
      expect(_inline('приоритет высокий'), findsOneWidget);

      await tester.tap(_inline('сделать дз'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Сдать дз');
      await tester.tap(find.text('Применить'));
      await tester.pumpAndSettle();
      expect(_inline('Сдать дз'), findsOneWidget);
      final updatedText = tester.widget<TextField>(_input).controller!.text;
      expect(updatedText, startsWith('на '));
      expect(updatedText, contains('"Сдать дз"'));
      expect(updatedText, contains('в 08:00'));
      expect(updatedText, contains('приоритет высокий'));
      expect(updatedText, isNot(contains('\u2060')));
      await tester.tap(_save);
      await pumpStorage(tester);

      final tasks = (await tester.runAsync(app.tasksRepository.getAllTasks))!;
      final homework = tasks.singleWhere((task) => task.title == 'Сдать дз');
      final cleaning = tasks.singleWhere(
        (task) => task.title == 'уборку в доме',
      );
      expect(homework.startsAt!.hour, 7);
      expect(homework.priority, 2);
      expect(homework.projectId, filming.id);
      expect(homework.dueDate, isNull);
      expect(cleaning.startsAt!.weekday, DateTime.monday);
      expect(cleaning.startsAt!.hour, 8);
      expect(cleaning.endsAt, isNull);
      expect(cleaning.projectId, secondHome.id);
      expect(_input, findsNothing);
      expect(find.text('Добавлено задач: 2'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Добавлено задач: 2')).dy,
        lessThan(100),
      );
      app.navigation.open('tasks');
      await tester.pumpAndSettle();
      expect(find.byType(PulseQuickTaskAction), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await disposeTestApp(tester, app);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets('unsaved note survives closing and retry excludes saved tasks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final saved = <String>[];
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              PulseQuickTaskAction(
                isActive: () => true,
                watchProjects: () => Stream.value(const []),
                addTask: (task) async {
                  if (fail && task.title == 'Вторая задача') {
                    fail = false;
                    throw StateError('test write error');
                  }
                  saved.add(task.title);
                },
              ),
            ],
          ),
        ),
      ),
    );
    final action = find.byTooltip('Быстрый ввод');
    await tester.tap(action);
    await tester.pumpAndSettle();
    const note = 'Первая задача\nВторая задача';
    await tester.enterText(_input, note);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(_inline('Вторая')).top,
      greaterThan(tester.getRect(_inline('Первая задача')).bottom),
    );
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(_inline('Первая задача'), findsOneWidget);
    final controller = tester.widget<TextField>(_input).controller!;
    expect(controller.text, note);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(controller.text, 'Вторая задача');
    expect(saved, ['Первая задача']);
    expect(find.textContaining('Сохранено: 1.'), findsOneWidget);
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(saved, ['Первая задача', 'Вторая задача']);
    expect(_input, findsNothing);
    expect(tester.getTopLeft(find.text('Задача создана')).dy, lessThan(100));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
