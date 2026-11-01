import 'dart:convert';

import 'task_queries.dart';
import 'package:tasks_api/tasks_api.dart';

class BotTaskListFormatter {
  const BotTaskListFormatter._();

  static String format(
    List<BotTaskRow> rows, {
    required int page,
    required bool hasNext,
  }) {
    final visible = rows.take(10).toList();
    final heading = hasNext
        ? 'Задачи — страница $page'
        : 'Задачи — найдено ${(page - 1) * 10 + visible.length}'
              '${page == 1 ? '' : ' · страница $page'}';
    final lines = <String>[
      for (var i = 0; i < visible.length; i++)
        _formatTask(visible[i], (page - 1) * 10 + i + 1),
    ];
    return '$heading\n\n${lines.join('\n\n')}';
  }

  static String _formatTask(BotTaskRow row, int number) {
    final task = row.task;
    final status = switch (task.status) {
      TaskStatus.open => 'открыта',
      TaskStatus.notStarted => 'не начата',
      TaskStatus.inProgress => 'в работе',
      TaskStatus.done => 'завершена',
    };
    final planned = task.startsAt == null
        ? 'не запланирована'
        : 'план ${_date(task.startsAt!)}';
    final due = task.dueDate == null ? '' : ' · срок ${_date(task.dueDate!)}';
    final priority = task.priority == 2 ? ' · высокий' : '';
    return '$number. <b>${const HtmlEscape().convert(task.title)}</b>\n'
        '   <i>$status · $planned$due$priority</i>';
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}
