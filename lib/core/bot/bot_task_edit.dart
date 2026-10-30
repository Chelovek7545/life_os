import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

enum BotTaskEditField { title, description, scheduledAt, dueDate, project }

class BotTaskEdit {
  const BotTaskEdit._();

  static Task? applyText(
    Task task,
    BotTaskEditField field,
    String input,
    DateTime now, {
    String? projectId,
  }) {
    final value = input.trim();
    switch (field) {
      case BotTaskEditField.title:
        if (value.isEmpty || value.length > 300 || value.contains('\n')) {
          return null;
        }
        return task.copyWith(title: value);
      case BotTaskEditField.description:
        if (value.length > 2000) return null;
        return task.copyWith(
          description: value.toLowerCase() == 'пусто' ? '' : value,
        );
      case BotTaskEditField.scheduledAt:
        if (value.toLowerCase() == 'без плана') {
          return task.copyWith(
            startsAt: const Wrapped(null),
            endsAt: const Wrapped(null),
          );
        }
        final day = _parseDate(value, now);
        if (day == null) return null;
        final previousStart = task.startsAt;
        final start = previousStart == null
            ? day
            : DateTime(
                day.year,
                day.month,
                day.day,
                previousStart.hour,
                previousStart.minute,
                previousStart.second,
                previousStart.millisecond,
                previousStart.microsecond,
              );
        final end = previousStart == null || task.endsAt == null
            ? null
            : start.add(task.endsAt!.difference(previousStart));
        return task.copyWith(startsAt: Wrapped(start), endsAt: Wrapped(end));
      case BotTaskEditField.dueDate:
        if (value.toLowerCase() == 'без срока') {
          return task.copyWith(dueDate: const Wrapped(null));
        }
        final dueDate = _parseDate(value, now);
        return dueDate == null
            ? null
            : task.copyWith(dueDate: Wrapped(dueDate));
      case BotTaskEditField.project:
        if (value.toLowerCase() == 'без проекта') {
          return task.copyWith(projectId: const Wrapped(null));
        }
        if (value.isEmpty || value.length > 100 || projectId == null) {
          return null;
        }
        return task.copyWith(projectId: Wrapped(projectId));
    }
  }

  static DateTime? _parseDate(String input, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (input.toLowerCase()) {
      case 'сегодня':
        return today;
      case 'завтра':
        return today.add(const Duration(days: 1));
    }
    final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(input);
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    if (year < 1900 || year > 2100) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
}
