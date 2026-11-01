/// Small, local interpreter for messages that create one task.
/// It deliberately rejects uncertain dates instead of guessing silently.
class TaskDraft {
  const TaskDraft(this.title, {this.scheduledAt, this.projectName});

  final String title;
  final DateTime? scheduledAt;
  final String? projectName;
}

class TaskMessageParser {
  const TaskMessageParser();

  TaskDraft? parse(String input, DateTime now) {
    var text = input.trim();
    text = text
        .replaceFirst(
          RegExp(
            r'^(?:/add(?:@\w+)?\s+|(?:добавь|создай|запиши)\s+(?:задачу\s+)?|задача\s*:\s*)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (text.isEmpty || text.length > 300 || text.contains('\n')) return null;

    DateTime? scheduledAt;
    void extractDate() {
      final match = RegExp(
        r'\s+(?:на\s+)?(сегодня|завтра)$',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) return;
      final day = DateTime(now.year, now.month, now.day);
      scheduledAt = day.add(
        Duration(days: match.group(1)!.toLowerCase() == 'завтра' ? 1 : 0),
      );
      text = text.substring(0, match.start).trim();
    }

    extractDate();
    String? project;
    final projectMatch = RegExp(
      r'\s+(?:в проект|project:)\s*(?:"([^"]+)"|([^,]+))$',
      caseSensitive: false,
    ).firstMatch(text);
    if (projectMatch != null) {
      project = (projectMatch.group(1) ?? projectMatch.group(2))?.trim();
      text = text.substring(0, projectMatch.start).trim();
    }

    if (scheduledAt == null) extractDate();
    if (text.isEmpty ||
        text.startsWith('/') ||
        RegExp(
          r'(^|\s)(послезавтра|понедельник|вторник|среду|четверг|пятницу|субботу|воскресенье|сегодня|завтра)(\s|$)',
          caseSensitive: false,
        ).hasMatch(text) ||
        RegExp(r'\b\d{1,2}[./]\d{1,2}(?:[./]\d{2,4})?\b').hasMatch(text) ||
        RegExp(
          r'(^|\s)(удали|удалить|перенеси|измени)($|\s)',
          caseSensitive: false,
        ).hasMatch(text)) {
      return null;
    }
    return TaskDraft(text, scheduledAt: scheduledAt, projectName: project);
  }
}
