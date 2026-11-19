import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/theme/app_theme.dart';
import 'package:life_os/features/tasks/presentation/components/pulse_quick_task.dart';

import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

final _input = find.byKey(const ValueKey('pulse.quick-task.input'));
final _save = find.byKey(const ValueKey('pulse.quick-task.save'));
final _formatted = find.byKey(const ValueKey('pulse.quick-task.formatted'));

Finder _inline(String label) =>
    find.descendant(of: _formatted, matching: find.text(label));

void main() {
  testWidgets('Pulse note previews, edits and saves two scheduled tasks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(
      () => createTestApp(enableObsidian: false),
    ))!;
    await tester.pumpWidget(MyApp(diContainer: app));
    app.navigation.open('pulse');
    await pumpStorage(tester);
    await tester.tap(find.byType(PulseQuickTaskAction));
    await tester.pumpAndSettle();
    await tester.enterText(
      _input,
      'Завтра в 7 утра сделать дз, приоритет обычный, '
      'а с 8 до 9 в понедельник уборку в доме',
    );
    await tester.pumpAndSettle();
    expect(find.text('Черновики задач · 2'), findsOneWidget);
    expect(_inline('07:00'), findsOneWidget);
    expect(_inline('08:00–09:00'), findsOneWidget);
    expect(await tester.runAsync(app.tasksRepository.getAllTasks), isEmpty);

    final dateChip = find.ancestor(
      of: _inline('Завтра'),
      matching: find.byType(ActionChip),
    );
    expect(tester.widget<ActionChip>(dateChip).avatar, isA<Icon>());
    expect(
      tester.widget<ActionChip>(dateChip).shape,
      isA<RoundedRectangleBorder>(),
    );
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(_input, findsNothing);

    await tester.tap(_inline('Завтра'));
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
    await tester.enterText(find.byType(TextField), 'Сдать дз');
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(_inline('Сдать дз'), findsOneWidget);
    await tester.tap(find.text('Редактировать текст'));
    await tester.pumpAndSettle();
    final updatedText = tester.widget<TextField>(_input).controller!.text;
    expect(updatedText, startsWith('на '));
    expect(updatedText, contains('"Сдать дз"'));
    expect(updatedText, contains('в 08:00'));
    expect(updatedText, contains('приоритет высокий'));
    await tester.tap(_save);
    await pumpStorage(tester);

    final tasks = (await tester.runAsync(app.tasksRepository.getAllTasks))!;
    final homework = tasks.singleWhere((task) => task.title == 'Сдать дз');
    final cleaning = tasks.singleWhere((task) => task.title == 'уборку в доме');
    expect(homework.startsAt!.hour, 7);
    expect(homework.priority, 2);
    expect(homework.dueDate, isNull);
    expect(cleaning.startsAt!.weekday, DateTime.monday);
    expect(cleaning.startsAt!.hour, 8);
    expect(cleaning.endsAt, isNull);
    expect(_input, findsNothing);
    expect(find.text('Добавлено задач: 2'), findsOneWidget);
    app.navigation.open('tasks');
    await tester.pumpAndSettle();
    expect(find.byType(PulseQuickTaskAction), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await disposeTestApp(tester, app);
  });

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
                addTask: (task) async {
                  if (fail && task.title == 'Вторая задача') {
                    fail = false;
                    throw StateError('test write error');
                  }
                  saved.add(task.title);
                },
                onSaved: (_) {},
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
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(_inline('Первая задача'), findsOneWidget);
    await tester.tap(find.text('Редактировать текст'));
    await tester.pumpAndSettle();
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
    expect(tester.takeException(), isNull);
  });
}
