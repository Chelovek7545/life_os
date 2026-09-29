import 'dart:async';
import 'package:flutter/material.dart';

class TimeRange {
  final String start;
  final String? end;

  TimeRange({
    required this.start,
    this.end,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'start': start,
    };

    if (end != null) {
      map['end'] = end;
    }

    return map;
  }

  @override
  String toString() => 'TimeRange(start: $start, end: $end)';
}

class QuickTaskDraft {
  final String title;
  final TimeRange? time;
  final DateTime? deadline;
  final String? project;
  final List<String> tags;
  final List<String> warnings;
  final String raw;

  QuickTaskDraft({
    required this.title,
    this.time,
    this.deadline,
    this.project,
    required this.tags,
    required this.warnings,
    required this.raw,
  });

  String? get deadlineIso => deadline == null ? null : dateToIso(deadline!);

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'time': time?.toMap(),
      'deadline': deadlineIso,
      'project': project,
      'tags': tags,
      'warnings': warnings,
      'raw': raw,
    };
  }

  @override
  String toString() => 'QuickTaskDraft(${toMap()})';
}

QuickTaskDraft parseQuickTask(
  String rawInput, [
  DateTime? now,
]) {
  final baseNow = now ?? DateTime.now();

  final warnings = <String>[];
  final tags = <String>[];

  String? project;
  DateTime? deadline;
  TimeRange? time;

  var text = ' ${rawInput.trim()} ';

  // 1. Теги вида #анатомия #учёба
  final tagRe = RegExp(
    r'#([A-Za-zА-Яа-яЁё0-9_\-]+)',
    unicode: true,
  );

  text = text.replaceAllMapped(tagRe, (match) {
    final tag = match.group(1);
    if (tag != null && tag.isNotEmpty) {
      tags.add(tag);
    }
    return ' ';
  });

  // 2. Проект / предмет / курс / категория
  // Примеры:
  // проект анатомия
  // проект: анатомия
  // предмет анатомия
  // курс биология
  final projectRe = RegExp(
    r'[\s,;]+(?:проект|предмет|курс|категория|тег|тэг)\s*[:\-]?\s*([^,;.\n]+)',
    caseSensitive: false,
    unicode: true,
  );

  final projectMatch = projectRe.firstMatch(text);

  if (projectMatch != null) {
    final captured = projectMatch.group(1)?.trim();

    if (captured != null && captured.isNotEmpty) {
      project = captured.replaceAll(RegExp(r'\s+'), ' ');
      text = text.replaceFirst(projectMatch.group(0)!, ' ');
    }
  }

  // 3. Дедлайн с ключевым словом
  // Примеры:
  // дедлайн 12.08.2007
  // срок 12.08
  // до 12.08.2007
  // к 12.08
  final deadlineRe = RegExp(
    r'[\s,;]+(?:дедлайна|дедлайн|крайний срок|срок|до|к)\s*[:\-]?\s*(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?',
    caseSensitive: false,
    unicode: true,
  );

  final deadlineMatch = deadlineRe.firstMatch(text);

  if (deadlineMatch != null) {
    final day = int.tryParse(deadlineMatch.group(1) ?? '');
    final month = int.tryParse(deadlineMatch.group(2) ?? '');
    final year = normalizeYear(deadlineMatch.group(3));

    if (day != null && month != null) {
      final date = parseDate(day, month, year, baseNow);

      if (date != null) {
        deadline = date;
        text = text.replaceFirst(deadlineMatch.group(0)!, ' ');
      } else {
        warnings.add('Не удалось разобрать дату дедлайна');
      }
    }
  }

  // 4. Время вида:
  // с 8 до 9
  // с 08:30 до 10:00
  // с 14 до 16
  // с 8-9
  final timeRangeRe = RegExp(
    r'[\s,;]+с\s*(\d{1,2})(?::(\d{2}))?\s*(?:ч(?:ас(?:а|ов)?)?)?\s*(?:до|по|-|–|—)\s*(\d{1,2})(?::(\d{2}))?\s*(?:ч(?:ас(?:а|ов)?)?)?',
    caseSensitive: false,
    unicode: true,
  );

  final timeMatch = timeRangeRe.firstMatch(text);

  if (timeMatch != null) {
    final startHour = int.tryParse(timeMatch.group(1) ?? '') ?? -1;
    final endHour = int.tryParse(timeMatch.group(3) ?? '') ?? -1;

    final start = toTime(startHour, timeMatch.group(2));
    final end = toTime(endHour, timeMatch.group(4));

    if (start != null && end != null) {
      time = TimeRange(start: start, end: end);
      text = text.replaceFirst(timeMatch.group(0)!, ' ');

      if (end.compareTo(start) <= 0) {
        warnings.add('Время окончания раньше времени начала');
      }
    }
  }

  // 5. Если дедлайн не нашли с ключевым словом,
  // пробуем найти обычную дату в тексте:
  // 12.08.2007 или 12.08
  if (deadline == null) {
    final standaloneDateRe = RegExp(
      r'[\s,;]+(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?',
      unicode: true,
    );

    final dateMatch = standaloneDateRe.firstMatch(text);

    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1) ?? '');
      final month = int.tryParse(dateMatch.group(2) ?? '');
      final year = normalizeYear(dateMatch.group(3));

      if (day != null && month != null) {
        final date = parseDate(day, month, year, baseNow);

        if (date != null) {
          deadline = date;
          text = text.replaceFirst(dateMatch.group(0)!, ' ');
        }
      }
    }
  }

  // 6. То, что осталось, считаем названием задачи
  final title = text
      .replaceFirst(RegExp(r'^[\s,;.]+'), '')
      .replaceFirst(RegExp(r'[\s,;.]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (title.isEmpty) {
    warnings.add('Пустое название задачи');
  }

  return QuickTaskDraft(
    title: title,
    time: time,
    deadline: deadline,
    project: project,
    tags: tags,
    warnings: warnings,
    raw: rawInput,
  );
}

int? normalizeYear(String? year) {
  if (year == null || year.isEmpty) return null;

  // 07 -> 2007
  // 26 -> 2026
  if (year.length == 2) {
    return int.tryParse('20$year');
  }

  return int.tryParse(year);
}

DateTime? parseDate(
  int day,
  int month,
  int? year,
  DateTime now,
) {
  if (month < 1 || month > 12) return null;

  final resolvedYear = year ?? now.year;

  if (day < 1 || day > daysInMonth(resolvedYear, month)) {
    return null;
  }

  final date = DateTime(resolvedYear, month, day);

  // Если год не указан и дата уже прошла в текущем году,
  // переносим её на следующий подходящий год.
  if (year == null) {
    final today = DateTime(now.year, now.month, now.day);

    if (date.isBefore(today)) {
      var nextYear = resolvedYear + 1;

      // На случай 29 февраля: ищем ближайший подходящий год.
      while (nextYear <= resolvedYear + 4 &&
          day > daysInMonth(nextYear, month)) {
        nextYear++;
      }

      if (day <= daysInMonth(nextYear, month)) {
        return DateTime(nextYear, month, day);
      }

      return null;
    }
  }

  return date;
}

int daysInMonth(int year, int month) {
  const monthDays = [
    31, // январь
    28, // февраль
    31, // март
    30, // апрель
    31, // май
    30, // июнь
    31, // июль
    31, // август
    30, // сентябрь
    31, // октябрь
    30, // ноябрь
    31, // декабрь
  ];

  if (month == 2 && _isLeapYear(year)) {
    return 29;
  }

  return monthDays[month - 1];
}

bool _isLeapYear(int year) {
  return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

String dateToIso(DateTime date) {
  final yyyy = date.year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');

  return '$yyyy-$mm-$dd';
}

String twoDigits(int n) {
  return n.toString().padLeft(2, '0');
}

String? toTime(int hour, String? minuteStr) {
  if (hour < 0 || hour > 24) return null;

  final minute = minuteStr == null ? 0 : int.tryParse(minuteStr);

  if (minute == null || minute < 0 || minute > 59) {
    return null;
  }

  // 24:00 можно считать концом дня,
  // но 24:30 уже некорректно.
  if (hour == 24 && minute != 0) return null;

  return '${twoDigits(hour)}:${twoDigits(minute)}';
}

// void main() {
//   const input =
//       'Посмотреть лекцию с 8 до 9 дедлайн 12.08.2007, проект анатомия';

//   final parsed = parseQuickTask(input);

//   print(parsed.toMap());
// }

// Сюда должен быть подключён код парсера выше.
// Например, если он лежит в отдельном файле:
// import 'quick_task_parser.dart';

class SmartTaskInput extends StatefulWidget {
  const SmartTaskInput({super.key});

  @override
  State<SmartTaskInput> createState() => _SmartTaskInputState();
}

class _SmartTaskInputState extends State<SmartTaskInput> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;
  QuickTaskDraft? _parsed;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 200),
      () {
        setState(() {
          if (value.trim().isEmpty) {
            _parsed = null;
          } else {
            _parsed = parseQuickTask(value);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              labelText: 'Быстрый ввод задачи',
              hintText:
                  'Посмотреть лекцию с 8 до 9 дедлайн 12.08.2007, проект анатомия',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          if (_parsed != null) ...[
            const Text(
              'Распознанная задача:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_parsed!.title.isNotEmpty)
                  Chip(
                    label: Text(_parsed!.title),
                    backgroundColor: Colors.blue.shade50,
                  ),
                if (_parsed!.time != null)
                  Chip(
                    label: Text(
                      '${_parsed!.time!.start}–${_parsed!.time!.end ?? ''}',
                    ),
                    backgroundColor: Colors.green.shade50,
                  ),
                if (_parsed!.deadlineIso != null)
                  Chip(
                    label: Text('Дедлайн: ${_parsed!.deadlineIso}'),
                    backgroundColor: Colors.red.shade50,
                  ),
                if (_parsed!.project != null)
                  Chip(
                    label: Text('Проект: ${_parsed!.project}'),
                    backgroundColor: Colors.purple.shade50,
                  ),
                for (final tag in _parsed!.tags)
                  Chip(
                    label: Text('#$tag'),
                    backgroundColor: Colors.orange.shade50,
                  ),
              ],
            ),
            if (_parsed!.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._parsed!.warnings.map(
                (warning) => Text(
                  warning,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}