enum QuickTaskField { title, date, time, deadline, priority }

typedef QuickTaskSpan = ({QuickTaskField field, int start, int end});

class QuickTaskDraft {
  const QuickTaskDraft._(
    this._connectorStart, {
    required this.start,
    required this.end,
    required this.title,
    required this.day,
    required this.startMinute,
    required this.endMinute,
    required this.deadline,
    required this.priority,
    required this.spans,
    required this.issues,
  });

  final int start;
  final int end;
  final String title;
  final DateTime? day;
  final int? startMinute;
  final int? endMinute;
  final DateTime? deadline;
  final int priority;
  final List<QuickTaskSpan> spans;
  final List<String> issues;
  final int? _connectorStart;

  DateTime? get startsAt => _atMinute(startMinute ?? 0);
  DateTime? get endsAt => endMinute == null ? null : _atMinute(endMinute!);

  DateTime? _atMinute(int minute) => switch (day) {
    final date? => DateTime(
      date.year,
      date.month,
      date.day,
      minute ~/ 60,
      minute % 60,
    ),
    null => null,
  };

  String replaceField(String text, QuickTaskField field, String value) {
    final ranges = spans.where((span) => span.field == field).toList();
    if (ranges.isEmpty) {
      if (value.isEmpty) return text;
      return text.replaceRange(end, end, ' $value');
    }
    final originalLength = text.length;
    for (final span in ranges.reversed) {
      text = text.replaceRange(
        span.start,
        span.end,
        span == ranges.first ? value : '',
      );
    }
    final connector = _connectorStart;
    if (connector != null) {
      final clause = text.substring(start, end + text.length - originalLength);
      final first = _fields.firstMatch(clause.trimLeft());
      if (first == null ||
          first.start != 0 ||
          first.namedGroup('literal') != null) {
        text = text.replaceRange(connector, start, '; ');
      }
    }
    return text;
  }
}

const _relative = r'послезавтра|завтра|сегодня';
const _weekdays =
    r'понедельник|вторник|сред[ау]|четверг|пятниц[ау]|суббот[ау]|воскресенье';
const _numericDate = r'\d{1,2}\.\d{1,2}(?:\.\d{4})?';
const _date = '(?:$_relative|$_weekdays|$_numericDate)';
const _partOfDay = r'утра|дня|вечера|ночи';
const _clock =
    r'\d{1,2}(?::\d{2})?'
    '(?:[ \t]+(?:$_partOfDay|час(?:а|ов)?|ч))?';
const _range =
    r'с[ \t]+'
    '$_clock'
    r'[ \t]*(?:до|по|[-–—])[ \t]*'
    '$_clock';
const _fieldPattern =
    r'(?<![\p{L}\p{N}_#])'
    r'(?:(?<deadline>дедлайн[ \t]*:?[ \t]+(?:до[ \t]+)?'
    '$_date)'
    '|(?<time>$_range'
    r'|в[ \t]+'
    '$_clock)'
    r'|(?<date>(?:(?:на|в|во)[ \t]+)?'
    '$_date)'
    r'|(?<priority>приоритет[ \t]*:?[ \t]+(?:высокий|обычный|средний|низкий)))'
    r'(?![\p{L}\p{N}_]|[.:]\d)';
const _literalTitle = r'"(?:\\[^\r\n]|[^"\\\r\n])*"';
final _fields = RegExp(
  '(?<literal>$_literalTitle)|$_fieldPattern',
  caseSensitive: false,
  unicode: true,
);
final _separator = RegExp(
  '(?<literal>$_literalTitle)|'
  r'[\r\n;]+|(?<connector>(?:[ \t]*,[ \t]*|[ \t]+)(?:а|затем|потом)[ \t]+'
  '(?=$_fieldPattern))',
  caseSensitive: false,
  unicode: true,
);
final _edgeSeparator = RegExp(r'^[\s,;:—–]+|[\s,;:—–]+$');
final _space = RegExp(r'\s+');
final _escape = RegExp(r'\\(["\\])');
final _timeParts = RegExp(
  r'(\d{1,2})(?::(\d{2}))?'
  '(?:[ \t]+($_partOfDay))?',
);

List<QuickTaskDraft> parseQuickTasks(String text, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final drafts = <QuickTaskDraft>[];
  var start = 0;
  int? connectorStart;
  for (final separator in _separator.allMatches(text)) {
    if (separator.namedGroup('literal') != null) continue;
    if (_parseDraft(text, start, separator.start, today, connectorStart)
        case final draft?) {
      drafts.add(draft);
    }
    start = separator.end;
    connectorStart = separator.namedGroup('connector') == null
        ? null
        : separator.start;
  }
  if (_parseDraft(text, start, text.length, today, connectorStart)
      case final draft?) {
    drafts.add(draft);
  }
  return drafts;
}

String quoteQuickTaskTitle(String title) =>
    '"${title.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

QuickTaskDraft? _parseDraft(
  String text,
  int start,
  int end,
  DateTime today,
  int? connectorStart,
) {
  final clause = text.substring(start, end);
  if (clause.trim().isEmpty) return null;

  final spans = <QuickTaskSpan>[];
  final issues = <String>[];
  final titleParts = <String>[];
  final seen = <QuickTaskField>{};
  DateTime? day;
  DateTime? deadline;
  int? startMinute;
  int? endMinute;
  var priority = 0;
  var cursor = 0;

  void readTitle(int until) {
    final piece = clause.substring(cursor, until);
    final title = piece.replaceAll(_edgeSeparator, '');
    if (title.isEmpty) return;
    final offset = start + cursor + piece.indexOf(title);
    titleParts.add(title);
    spans.add((
      field: QuickTaskField.title,
      start: offset,
      end: offset + title.length,
    ));
  }

  for (final match in _fields.allMatches(clause)) {
    readTitle(match.start);
    cursor = match.end;
    if (match.namedGroup('literal') case final literal?) {
      final content = literal.substring(1, literal.length - 1);
      titleParts.add(content.replaceAllMapped(_escape, (m) => m.group(1)!));
      spans.add((
        field: QuickTaskField.title,
        start: start + match.start,
        end: start + match.end,
      ));
      continue;
    }
    final field = QuickTaskField.values.firstWhere(
      (field) =>
          field != QuickTaskField.title && match.namedGroup(field.name) != null,
    );
    spans.add((
      field: field,
      start: start + match.start,
      end: start + match.end,
    ));
    final value = match.group(0)!.toLowerCase();
    if (!seen.add(field)) {
      issues.add('Для задачи указан один и тот же параметр несколько раз.');
      continue;
    }
    switch (field) {
      case QuickTaskField.title:
        break;
      case QuickTaskField.date:
        day = _resolveDate(value, today);
        if (day == null) issues.add('Уточните дату задачи.');
      case QuickTaskField.deadline:
        deadline = _resolveDate(value, today);
        if (deadline == null) issues.add('Уточните дату дедлайна.');
      case QuickTaskField.time:
        final times = _timeParts.allMatches(value).toList();
        final lastPart = times.length == 2 ? times.last.group(3) : null;
        startMinute = _minutes(times.first, otherPartOfDay: lastPart);
        endMinute = times.length == 2 ? _minutes(times.last) : null;
        if (startMinute == null || (times.length == 2 && endMinute == null)) {
          issues.add('Уточните время задачи.');
        } else if (endMinute != null && endMinute <= startMinute) {
          issues.add('Время окончания должно быть позже начала.');
        }
      case QuickTaskField.priority:
        priority = switch (value.split(_space).last) {
          'высокий' => 2,
          'обычный' || 'средний' => 1,
          _ => 0,
        };
    }
  }
  readTitle(clause.length);
  final title = titleParts.join(' ').replaceAll(_space, ' ').trim();
  if (title.isEmpty) issues.add('Добавьте название задачи.');
  return QuickTaskDraft._(
    connectorStart,
    start: start,
    end: end,
    title: title,
    day: day ?? (startMinute == null ? null : today),
    startMinute: startMinute,
    endMinute: endMinute,
    deadline: deadline,
    priority: priority,
    spans: List.unmodifiable(spans),
    issues: List.unmodifiable(issues),
  );
}

DateTime? _resolveDate(String value, DateTime today) {
  final word = value.split(_space).last;
  final offset = switch (word) {
    'сегодня' => 0,
    'завтра' => 1,
    'послезавтра' => 2,
    _ => null,
  };
  if (offset != null) {
    return DateTime(today.year, today.month, today.day + offset);
  }
  final weekday = switch (word) {
    'понедельник' => DateTime.monday,
    'вторник' => DateTime.tuesday,
    'среда' || 'среду' => DateTime.wednesday,
    'четверг' => DateTime.thursday,
    'пятница' || 'пятницу' => DateTime.friday,
    'суббота' || 'субботу' => DateTime.saturday,
    'воскресенье' => DateTime.sunday,
    _ => null,
  };
  if (weekday != null) {
    return DateTime(
      today.year,
      today.month,
      today.day + (weekday - today.weekday) % 7,
    );
  }
  final numbers = word.split('.').map(int.parse).toList();
  final [day, month, ...years] = numbers;
  if (day < 1 || day > 31 || month < 1 || month > 12) return null;
  if (years.isNotEmpty) {
    final year = years.single;
    final date = DateTime(year, month, day);
    return year > 0 && date.month == month ? date : null;
  }
  for (var year = today.year; year <= today.year + 8; year++) {
    final date = DateTime(year, month, day);
    if (date.month == month && !date.isBefore(today)) return date;
  }
  return null;
}

int? _minutes(RegExpMatch match, {String? otherPartOfDay}) {
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2) ?? '0');
  final part = match.group(3) ?? (hour <= 12 ? otherPartOfDay : null);
  if (minute > 59 || hour > 23) return null;
  if (part != null) {
    if (hour == 0 || hour > 12) return null;
    hour = hour % 12 + (part == 'дня' || part == 'вечера' ? 12 : 0);
  }
  return hour * 60 + minute;
}
