import 'package:uuid/uuid.dart';

String newRoutineId() => const Uuid().v4();
DateTime routineDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime shiftDay(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime mondayOf(DateTime d) => shiftDay(routineDay(d), 1 - d.weekday);
String clockLabel(int minute) =>
    '${(minute ~/ 60 % 24).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String minutesLabel(int m) =>
    m < 60 ? '$m мин' : '${m ~/ 60} ч${m % 60 == 0 ? '' : ' ${m % 60} мин'}';
const weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const monthLabels = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

/// Replace selected weekdays while preserving the identity of each activity.
List<RoutineItem> copyRoutineDay(
  List<RoutineItem> items,
  int source,
  Set<int> targets,
) {
  final destinations = targets.where((d) => d != source).toSet();
  return items
      .map((item) {
        final sourceSlots = item.slots.where((s) => s.days.contains(source));
        final slots = <RoutineSlot>[
          for (final slot in item.slots)
            if (slot.days.any((d) => !destinations.contains(d)))
              RoutineSlot(
                id: slot.id,
                days: slot.days
                    .where((d) => !destinations.contains(d))
                    .toList(),
                start: slot.start,
                end: slot.end,
              ),
          for (final slot in sourceSlots)
            if (destinations.isNotEmpty)
              RoutineSlot(
                id: newRoutineId(),
                days: destinations.toList()..sort(),
                start: slot.start,
                end: slot.end,
              ),
        ];
        return RoutineItem(
          id: item.id,
          title: item.title,
          slots: slots,
          sphereId: item.sphereId,
          sphere: item.sphere,
          color: item.color,
          note: item.note,
        );
      })
      .where((i) => i.slots.isNotEmpty)
      .toList();
}

class RoutineSlot {
  const RoutineSlot({
    required this.id,
    required this.days,
    this.start,
    this.end,
  });
  final String id;
  final List<int> days;
  final int? start;

  /// Minutes from the start of the owning day; > 1440 means overnight.
  final int? end;
  bool get timed => start != null;
  int get minutes => timed ? end! - start! : 0;
  String get timeLabel => timed
      ? '${clockLabel(start!)}–${clockLabel(end!)}${end! > 1440 ? ' +1' : ''}'
      : 'В течение дня';
  Map<String, dynamic> toJson() => {
    'id': id,
    'days': days,
    'start': start,
    'end': end,
  };
  factory RoutineSlot.fromJson(Map<String, dynamic> j) => RoutineSlot(
    id: j['id'],
    days: List<int>.from(j['days']),
    start: j['start'],
    end: j['end'],
  );
}

class RoutineItem {
  const RoutineItem({
    required this.id,
    required this.title,
    required this.slots,
    this.sphereId,
    this.sphere = 'Без сферы',
    this.color = 0xFF8B93A7,
    this.note = '',
  });
  final String id;
  final String title;
  final List<RoutineSlot> slots;
  final String? sphereId;
  final String sphere;
  final int color;
  final String note;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'slots': slots.map((s) => s.toJson()).toList(),
    'sphereId': sphereId,
    'sphere': sphere,
    'color': color,
    'note': note,
  };
  factory RoutineItem.fromJson(Map<String, dynamic> j) => RoutineItem(
    id: j['id'],
    title: j['title'],
    slots: (j['slots'] as List)
        .map((s) => RoutineSlot.fromJson(Map<String, dynamic>.from(s)))
        .toList(),
    sphereId: j['sphereId'],
    sphere: j['sphere'] ?? 'Без сферы',
    color: j['color'] ?? 0xFF8B93A7,
    note: j['note'] ?? '',
  );
  RoutineItem duplicate() => RoutineItem(
    id: newRoutineId(),
    title: title,
    sphereId: sphereId,
    sphere: sphere,
    color: color,
    note: note,
    slots: slots
        .map(
          (s) => RoutineSlot(
            id: newRoutineId(),
            days: [...s.days],
            start: s.start,
            end: s.end,
          ),
        )
        .toList(),
  );
}

class RoutineTemplate {
  const RoutineTemplate({
    required this.id,
    required this.name,
    required this.versionId,
    required this.items,
    this.archived = false,
  });
  final String id;
  final String name;
  final String versionId;
  final List<RoutineItem> items;
  final bool archived;
}

class RoutineActivation {
  const RoutineActivation({
    required this.id,
    required this.versionId,
    required this.templateId,
    required this.from,
  });
  final String id;
  final String versionId;
  final String templateId;
  final DateTime from;
}

class RoutineOccurrence {
  const RoutineOccurrence({
    required this.id,
    required this.date,
    required this.templateId,
    required this.item,
    required this.slot,
    this.completed = false,
    this.cancelled = false,
    this.changed = false,
    this.added = false,
  });
  final String id;
  final DateTime date;
  final String templateId;
  final RoutineItem item;
  final RoutineSlot slot;
  final bool completed;
  final bool cancelled;
  final bool changed;
  final bool added;
  DateTime? get startsAt => slot.timed
      ? DateTime(date.year, date.month, date.day, 0, slot.start!)
      : null;
  DateTime? get endsAt => slot.timed
      ? DateTime(date.year, date.month, date.day, 0, slot.end!)
      : null;
  RoutineOccurrence copyWith({
    RoutineItem? item,
    RoutineSlot? slot,
    bool? completed,
    bool? cancelled,
    bool? changed,
  }) => RoutineOccurrence(
    id: id,
    date: date,
    templateId: templateId,
    item: item ?? this.item,
    slot: slot ?? this.slot,
    completed: completed ?? this.completed,
    cancelled: cancelled ?? this.cancelled,
    changed: changed ?? this.changed,
    added: added,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dayKey(date),
    'templateId': templateId,
    'item': item.toJson(),
    'slot': slot.toJson(),
    'cancelled': cancelled,
    'added': added,
  };
  factory RoutineOccurrence.fromJson(Map<String, dynamic> j) =>
      RoutineOccurrence(
        id: j['id'],
        date: DateTime.parse(j['date']),
        templateId: j['templateId'],
        item: RoutineItem.fromJson(Map<String, dynamic>.from(j['item'])),
        slot: RoutineSlot.fromJson(Map<String, dynamic>.from(j['slot'])),
        cancelled: j['cancelled'] ?? false,
        added: j['added'] ?? false,
        changed: true,
      );
}

class RoutineSnapshot {
  const RoutineSnapshot({
    this.templates = const [],
    this.versions = const {},
    this.activations = const [],
    this.overrides = const {},
    this.completedIds = const {},
  });
  final List<RoutineTemplate> templates;
  final Map<String, List<RoutineItem>> versions;
  final List<RoutineActivation> activations;
  final Map<String, RoutineOccurrence> overrides;
  final Set<String> completedIds;

  RoutineActivation? activeOn(DateTime date) {
    RoutineActivation? active;
    for (final a in activations) {
      if (!a.from.isAfter(routineDay(date)) &&
          (active == null || a.from.isAfter(active.from))) {
        active = a;
      }
    }
    return active;
  }

  List<RoutineOccurrence> resolve(DateTime from, DateTime to) {
    final result = <RoutineOccurrence>[];
    for (
      var date = routineDay(from);
      !date.isAfter(routineDay(to));
      date = shiftDay(date, 1)
    ) {
      final active = activeOn(date);
      if (active != null) {
        for (final item in versions[active.versionId] ?? <RoutineItem>[]) {
          for (final slot in item.slots.where(
            (s) => s.days.contains(date.weekday),
          )) {
            final id = '${active.id}/${slot.id}/${dayKey(date)}';
            final original = RoutineOccurrence(
              id: id,
              date: date,
              templateId: active.templateId,
              item: item,
              slot: slot,
            );
            result.add(
              (overrides[id] ?? original).copyWith(
                completed: completedIds.contains(id),
              ),
            );
          }
        }
      }
      for (final extra in overrides.values.where(
        (o) => o.added && dayKey(o.date) == dayKey(date),
      )) {
        result.add(extra.copyWith(completed: completedIds.contains(extra.id)));
      }
    }
    result.sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) {
        return date;
      }
      return (a.slot.start ?? 3000).compareTo(b.slot.start ?? 3000);
    });
    return result;
  }
}

/// Validates a repeating week, including the Sunday-to-Monday boundary.
void validateRoutineItems(List<RoutineItem> items) {
  final intervals = <(int, int, String)>[];
  final itemIds = <String>{};
  final slotIds = <String>{};
  for (final item in items) {
    if (!itemIds.add(item.id)) {
      throw const FormatException('Занятие продублировано.');
    }
    if (item.title.trim().isEmpty || item.title.trim().length > 120) {
      throw const FormatException('Название: от 1 до 120 символов.');
    }
    if (item.note.length > 2000) {
      throw const FormatException('Примечание: не более 2000 символов.');
    }
    if (item.slots.isEmpty) {
      throw const FormatException('Добавьте дни занятия.');
    }
    for (final slot in item.slots) {
      if (!slotIds.add(slot.id)) {
        throw const FormatException('Временной вариант продублирован.');
      }
      if (slot.days.isEmpty ||
          slot.days.any((d) => d < 1 || d > 7) ||
          slot.days.toSet().length != slot.days.length) {
        throw const FormatException('Выберите дни недели.');
      }
      if (!slot.timed && slot.end != null) {
        throw const FormatException('Укажите начало занятия.');
      }
      if (slot.timed) {
        if (slot.start! < 0 ||
            slot.start! >= 1440 ||
            slot.end == null ||
            slot.minutes <= 0 ||
            slot.minutes > 1440) {
          throw const FormatException(
            'Длительность должна быть от 1 минуты до 24 часов.',
          );
        }
        for (final day in slot.days) {
          final start = (day - 1) * 1440 + slot.start!;
          intervals.add((start, start + slot.minutes, item.title));
          if (start + slot.minutes > 10080) {
            intervals.add((
              start - 10080,
              start + slot.minutes - 10080,
              item.title,
            ));
          }
        }
      }
    }
  }
  intervals.sort((a, b) => a.$1.compareTo(b.$1));
  for (var i = 1; i < intervals.length; i++) {
    if (intervals[i].$1 < intervals[i - 1].$2) {
      throw FormatException(
        'Пересечение: «${intervals[i - 1].$3}» и «${intervals[i].$3}».',
      );
    }
  }
}

class RoutineStats {
  RoutineStats(Iterable<RoutineOccurrence> entries) : all = entries.toList();
  final List<RoutineOccurrence> all;
  List<RoutineOccurrence> get planned =>
      all.where((o) => !o.cancelled).toList();
  int get total => planned.length;
  int get done => planned.where((o) => o.completed).length;
  int get cancelled => all.where((o) => o.cancelled).length;
  double? get rate => total == 0 ? null : done / total;
  int get plannedMinutes => planned.fold(0, (sum, o) => sum + o.slot.minutes);
  int get doneMinutes => planned
      .where((o) => o.completed)
      .fold(0, (sum, o) => sum + o.slot.minutes);
  Map<String, RoutineStats> get days {
    final groups = <String, List<RoutineOccurrence>>{};
    for (final o in all) {
      (groups[dayKey(o.date)] ??= []).add(o);
    }
    return groups.map((key, value) => MapEntry(key, RoutineStats(value)));
  }

  int get fullDays =>
      days.values.where((s) => s.total > 0 && s.total == s.done).length;
  Map<String, RoutineStats> get spheres {
    final groups = <String, List<RoutineOccurrence>>{};
    for (final o in planned) {
      (groups[o.item.sphere] ??= []).add(o);
    }
    return groups.map((key, value) => MapEntry(key, RoutineStats(value)));
  }

  (int current, int best) streak(String itemId, DateTime today) {
    final grouped = RoutineStats(
      all.where(
        (o) => o.item.id == itemId && !o.date.isAfter(routineDay(today)),
      ),
    ).days;
    var current = 0;
    var best = 0;
    for (final key in grouped.keys.toList()..sort()) {
      final day = grouped[key]!;
      if (day.total == 0) {
        continue;
      }
      if (day.done == day.total) {
        current++;
        if (current > best) {
          best = current;
        }
      } else if (key != dayKey(today)) {
        current = 0;
      }
    }
    return (current, best);
  }
}

List<RoutineItem> exampleRoutineItems() {
  RoutineItem item(
    String title,
    String sphere,
    int color,
    int? start,
    int? end,
    List<int> days,
  ) => RoutineItem(
    id: newRoutineId(),
    title: title,
    sphere: sphere,
    color: color,
    slots: [
      RoutineSlot(id: newRoutineId(), days: days, start: start, end: end),
    ],
  );
  return [
    item('Спокойное утро', 'Личное', 0xFFBDA2EE, 420, 450, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]),
    item('Завтрак и планы на день', 'Отдых', 0xFFE3B26E, 450, 480, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]),
    item('Учёба', 'Образование', 0xFF7FA9ED, 540, 720, [1, 2, 4, 5]),
    item('Работа над проектом', 'Развитие', 0xFF85C8B0, 540, 690, [3, 6]),
    item('Обед и перерыв', 'Отдых', 0xFFE3B26E, 750, 810, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]),
    item('Тренировка', 'Здоровье', 0xFF9FCB83, 900, 960, [1, 3, 5]),
    item('Алгоритмы', 'Образование', 0xFF7FA9ED, 1050, 1140, [1, 2, 4]),
    item('Прогулка', 'Здоровье', 0xFF9FCB83, 1080, 1140, [3, 5, 6, 7]),
    item('Прочитать 20 страниц', 'Развитие', 0xFF85C8B0, null, null, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]),
    item('Подготовиться к завтра', 'Личное', 0xFFBDA2EE, null, null, [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]),
  ];
}
