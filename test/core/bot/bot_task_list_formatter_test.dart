import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/bot/bot_task_list_formatter.dart';
import 'package:life_os/core/bot/bot_task_store.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

void main() {
  BotTaskRow row(String title, {int priority = 0}) {
    final now = DateTime(2026, 10, 30);
    return BotTaskRow(
      Task(
        tags: const [],
        id: title,
        title: title,
        description: '',
        status: TaskStatus.notStarted,
        createdAt: now,
        updatedAt: now,
        startsAt: now,
        dueDate: now,
        timerSeconds: 0,
        priority: priority,
        effortWeight: 0,
      ),
      null,
    );
  }

  test('formats numbered tasks with escaped titles and matching metadata', () {
    final text = BotTaskListFormatter.format(
      [row('Справка <важная>', priority: 2), row('ДЗ по анатомии')],
      page: 1,
      hasNext: false,
    );
    expect(text, contains('Задачи — найдено 2'));
    expect(text, contains('1. <b>Справка &lt;важная&gt;</b>'));
    expect(
      text,
      contains(
        '<i>не начата · план 30.10.2026 · срок 30.10.2026 · высокий</i>',
      ),
    );
    expect(text, contains('2. <b>ДЗ по анатомии</b>'));
    expect(text, isNot(contains('ID:')));
  });

  test('continues numbering and total on the last page', () {
    final text = BotTaskListFormatter.format(
      [row('Следующая задача')],
      page: 2,
      hasNext: false,
    );
    expect(text, contains('Задачи — найдено 11 · страница 2'));
    expect(text, contains('11. <b>Следующая задача</b>'));
  });
}
