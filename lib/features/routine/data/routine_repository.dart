import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:life_os/core/database/database.dart';
import '../domain/routine_models.dart';

/// Immutable version payloads keep the exact historical schedule. The indexed
/// journal is separate: checking a box never rewrites a template or the board.
Future<void> createRoutineSchema(AppDatabase db) async {
  for (final sql in routineSchema) {
    await db.customStatement(sql);
  }
}

const routineSchema = [
  'CREATE TABLE routine_templates (id TEXT PRIMARY KEY, name TEXT NOT NULL, archived INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE routine_versions (id TEXT PRIMARY KEY, template_id TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL)',
  'CREATE INDEX routine_versions_template ON routine_versions(template_id, created_at)',
  'CREATE TABLE routine_activations (id TEXT PRIMARY KEY, version_id TEXT NOT NULL, template_id TEXT NOT NULL, start_day TEXT NOT NULL UNIQUE)',
  'CREATE INDEX routine_activation_day ON routine_activations(start_day)',
  'CREATE TABLE routine_overrides (id TEXT PRIMARY KEY, day TEXT NOT NULL, payload TEXT NOT NULL)',
  'CREATE INDEX routine_override_day ON routine_overrides(day)',
  'CREATE TABLE routine_checks (id TEXT PRIMARY KEY, day TEXT NOT NULL, completed_at TEXT NOT NULL)',
  'CREATE INDEX routine_check_day ON routine_checks(day)',
  'CREATE TABLE routine_preferences (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
];

class RoutineRepository extends ChangeNotifier {
  RoutineRepository(this.db, {DateTime Function()? clock})
    : now = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() now;
  RoutineSnapshot snapshot = const RoutineSnapshot();
  bool loading = true;
  String? error;
  bool _disposed = false;
  Future<void> _queue = Future<void>.value();

  Future<void> load() async {
    try {
      // Serialize reads on the Drift executor; publish only a complete snapshot.
      final templates = await db
          .customSelect('SELECT * FROM routine_templates ORDER BY rowid')
          .get();
      final versions = await db
          .customSelect('SELECT * FROM routine_versions ORDER BY rowid')
          .get();
      final activations = await db
          .customSelect('SELECT * FROM routine_activations ORDER BY start_day')
          .get();
      final overrides = await db
          .customSelect('SELECT * FROM routine_overrides')
          .get();
      final checks = await db
          .customSelect('SELECT id FROM routine_checks')
          .get();
      final versionMap = <String, List<RoutineItem>>{};
      for (final v in versions) {
        versionMap[v.read<String>(
          'id',
        )] = (jsonDecode(v.read<String>('payload')) as List)
            .map((j) => RoutineItem.fromJson(Map<String, dynamic>.from(j)))
            .toList();
      }
      snapshot = RoutineSnapshot(
        templates: templates.map((t) {
          final id = t.read<String>('id');
          final latest = versions.lastWhere(
            (v) => v.read<String>('template_id') == id,
          );
          final version = latest.read<String>('id');
          return RoutineTemplate(
            id: id,
            name: t.read<String>('name'),
            versionId: version,
            items: versionMap[version]!,
            archived: t.read<int>('archived') != 0,
          );
        }).toList(),
        versions: versionMap,
        activations: activations
            .map(
              (a) => RoutineActivation(
                id: a.read<String>('id'),
                versionId: a.read<String>('version_id'),
                templateId: a.read<String>('template_id'),
                from: DateTime.parse(a.read<String>('start_day')),
              ),
            )
            .toList(),
        overrides: {
          for (final o in overrides)
            o.read<String>('id'): RoutineOccurrence.fromJson(
              Map<String, dynamic>.from(jsonDecode(o.read<String>('payload'))),
            ),
        },
        completedIds: checks.map((c) => c.read<String>('id')).toSet(),
      );
      error = null;
    } catch (e) {
      error = 'Не удалось загрузить распорядок: $e';
      rethrow;
    } finally {
      loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<T> _mutate<T>(Future<T> Function() work) {
    final result = _queue.then((_) async {
      try {
        final value = await db.transaction(work);
        await load();
        return value;
      } catch (e) {
        error = e is FormatException ? e.message : 'Не удалось сохранить: $e';
        _notify();
        rethrow;
      }
    });
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<String> saveTemplate({
    String? id,
    required String name,
    required List<RoutineItem> items,
    DateTime? applyFrom,
  }) => _mutate(() async {
    validateRoutineItems(items);
    final title = name.trim();
    if (title.isEmpty || title.length > 80) {
      throw const FormatException('Название шаблона: от 1 до 80 символов.');
    }
    final templateId = id ?? newRoutineId();
    final versionId = newRoutineId();
    await db.customStatement(
      'INSERT INTO routine_templates(id,name) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name',
      [templateId, title],
    );
    await db.customStatement(
      'INSERT INTO routine_versions(id,template_id,payload,created_at) VALUES (?,?,?,?)',
      [
        versionId,
        templateId,
        jsonEncode(items.map((i) => i.toJson()).toList()),
        now().toUtc().toIso8601String(),
      ],
    );
    if (applyFrom != null) {
      await _activate(versionId, templateId, applyFrom, items);
    }
    return templateId;
  });

  Future<void> activate(RoutineTemplate template, DateTime from) => _mutate(
    () => _activate(template.versionId, template.id, from, template.items),
  );

  Future<void> _activate(
    String versionId,
    String templateId,
    DateTime from,
    List<RoutineItem> items,
  ) async {
    final today = routineDay(now());
    if (routineDay(from).isBefore(today)) {
      throw const FormatException('Нельзя менять расписание прошлых дней.');
    }
    if (dayKey(from) == dayKey(today) && snapshot.activeOn(today) != null) {
      throw const FormatException(
        'Сегодня уже есть расписание. Примените с завтра, а сегодня измените отдельные пункты.',
      );
    }
    // Reject an overlap with an overnight occurrence from the previous template.
    final previous = snapshot
        .resolve(shiftDay(from, -1), shiftDay(from, -1))
        .where((o) => !o.cancelled && o.slot.timed);
    final starts = [
      for (final i in items)
        for (final s in i.slots)
          if (s.days.contains(from.weekday) && s.timed) s.start!,
    ];
    for (final o in previous) {
      if (o.slot.end! > 1440 && starts.any((s) => s < o.slot.end! - 1440)) {
        throw FormatException(
          'Пересечение с ночным занятием «${o.item.title}» предыдущего дня.',
        );
      }
    }
    // Also check the far boundary against an already scheduled activation.
    final future =
        snapshot.activations
            .where((a) => a.from.isAfter(routineDay(from)))
            .toList()
          ..sort((a, b) => a.from.compareTo(b.from));
    if (future.isNotEmpty) {
      final next = future.first;
      final prevWeekday = shiftDay(next.from, -1).weekday;
      final nextStarts = [
        for (final i in snapshot.versions[next.versionId] ?? <RoutineItem>[])
          for (final s in i.slots)
            if (s.timed && s.days.contains(next.from.weekday)) s.start!,
      ];
      for (final i in items) {
        for (final s in i.slots) {
          if (s.timed &&
              s.days.contains(prevWeekday) &&
              s.end! > 1440 &&
              nextStarts.any((n) => n < s.end! - 1440)) {
            throw const FormatException(
              'Ночной блок пересекается со следующим запланированным шаблоном.',
            );
          }
        }
      }
    }
    await db.customStatement(
      'INSERT INTO routine_activations(id,version_id,template_id,start_day) VALUES (?,?,?,?) ON CONFLICT(start_day) DO UPDATE SET id=excluded.id,version_id=excluded.version_id,template_id=excluded.template_id',
      [newRoutineId(), versionId, templateId, dayKey(from)],
    );
  }

  Future<void> archive(String id, bool archived) => _mutate(
    () => db.customStatement(
      'UPDATE routine_templates SET archived=? WHERE id=?',
      [archived ? 1 : 0, id],
    ),
  );

  Future<void> setCompleted(
    RoutineOccurrence occurrence,
    bool completed,
  ) => _mutate(() async {
    if (occurrence.date.isAfter(routineDay(now()))) {
      throw const FormatException('Будущие дни пока нельзя отмечать.');
    }
    final current = snapshot
        .resolve(occurrence.date, occurrence.date)
        .where((o) => o.id == occurrence.id)
        .firstOrNull;
    if (current == null || current.cancelled) {
      throw const FormatException('Этот пункт исключён из расписания.');
    }
    if (completed) {
      await db.customStatement(
        'INSERT INTO routine_checks(id,day,completed_at) VALUES (?,?,?) ON CONFLICT(id) DO NOTHING',
        [
          occurrence.id,
          dayKey(occurrence.date),
          now().toUtc().toIso8601String(),
        ],
      );
    } else {
      await db.customStatement('DELETE FROM routine_checks WHERE id=?', [
        occurrence.id,
      ]);
    }
  });

  void _validateOccurrence(RoutineOccurrence o) {
    validateRoutineItems([o.itemWithSingleSlot]);
    if (o.cancelled || !o.slot.timed) {
      return;
    }
    for (final other in snapshot.resolve(
      shiftDay(o.date, -1),
      shiftDay(o.date, 1),
    )) {
      if (other.id != o.id &&
          !other.cancelled &&
          other.slot.timed &&
          o.startsAt!.isBefore(other.endsAt!) &&
          other.startsAt!.isBefore(o.endsAt!)) {
        throw FormatException(
          'Пересечение с «${other.item.title}» (${other.slot.timeLabel}).',
        );
      }
    }
  }

  Future<void> saveOverride(RoutineOccurrence occurrence) => _mutate(() async {
    _validateOccurrence(occurrence);
    await db.customStatement(
      'INSERT INTO routine_overrides(id,day,payload) VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
      [occurrence.id, dayKey(occurrence.date), jsonEncode(occurrence.toJson())],
    );
    if (occurrence.cancelled) {
      await db.customStatement('DELETE FROM routine_checks WHERE id=?', [
        occurrence.id,
      ]);
    }
  });

  Future<void> restore(RoutineOccurrence o) => _mutate(() async {
    final original = RoutineSnapshot(
      templates: snapshot.templates,
      versions: snapshot.versions,
      activations: snapshot.activations,
    ).resolve(o.date, o.date).where((v) => v.id == o.id).firstOrNull;
    if (original != null) {
      _validateOccurrence(original);
    }
    await db.customStatement('DELETE FROM routine_overrides WHERE id=?', [
      o.id,
    ]);
    if (o.added) {
      await db.customStatement('DELETE FROM routine_checks WHERE id=?', [o.id]);
    }
  });

  Future<void> cancelDay(DateTime date) => _mutate(() async {
    for (final o in snapshot.resolve(date, date).where((o) => !o.cancelled)) {
      await db.customStatement(
        'INSERT INTO routine_overrides(id,day,payload) VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
        [o.id, dayKey(date), jsonEncode(o.copyWith(cancelled: true).toJson())],
      );
      await db.customStatement('DELETE FROM routine_checks WHERE id=?', [o.id]);
    }
  });

  Future<Map<String, dynamic>?> readBoard() async {
    final row = await db
        .customSelect(
          'SELECT payload FROM routine_preferences WHERE id=?',
          variables: [const Variable('board')],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(row.read<String>('payload')));
  }

  Future<void> saveBoard(Map<String, dynamic> board) => db.customStatement(
    'INSERT INTO routine_preferences(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
    ['board', jsonEncode(board)],
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

extension on RoutineOccurrence {
  RoutineItem get itemWithSingleSlot => RoutineItem(
    id: item.id,
    title: item.title,
    slots: [slot],
    sphereId: item.sphereId,
    sphere: item.sphere,
    color: item.color,
    note: item.note,
  );
}
