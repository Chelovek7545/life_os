import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/routine/data/routine_repository.dart';
import 'package:life_os/features/routine/domain/routine_models.dart';

RoutineItem activity({
  String id = 'reading',
  String title = 'Чтение',
  int? start = 540,
  int? end = 600,
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
}) => RoutineItem(
  id: id,
  title: title,
  slots: [RoutineSlot(id: '$id-slot', days: days, start: start, end: end)],
  sphere: 'Развитие',
);

void main() {
  late AppDatabase db;
  late RoutineRepository repo;
  var today = DateTime(2026, 9, 7, 12);
  setUp(() async {
    today = DateTime(2026, 9, 7, 12);
    db = AppDatabase(NativeDatabase.memory());
    repo = RoutineRepository(db, clock: () => today);
    await repo.load();
  });
  tearDown(() async {
    repo.dispose();
    await db.close();
  });

  test('creates an independent, initially empty module', () async {
    expect(repo.snapshot.templates, isEmpty);
    expect(repo.snapshot.resolve(today, shiftDay(today, 30)), isEmpty);
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    expect(
      tables.map((t) => t.read<String>('name')),
      containsAll(['tasks', 'habits', 'routine_templates', 'routine_checks']),
    );
  });
  test(
    'versions preserve history and skipped app launches do not lose days',
    () async {
      final id = await repo.saveTemplate(
        name: 'Неделя',
        items: [activity()],
        applyFrom: today,
      );
      final before = repo.snapshot.resolve(today, today).single;
      await repo.setCompleted(before, true);
      await repo.saveTemplate(
        id: id,
        name: 'Новая неделя',
        items: [activity(title: 'Другое чтение', start: 600, end: 660)],
        applyFrom: shiftDay(today, 1),
      );
      expect(repo.snapshot.resolve(today, today).single.item.title, 'Чтение');
      expect(repo.snapshot.resolve(today, today).single.completed, isTrue);
      final future = repo.snapshot.resolve(
        shiftDay(today, 1),
        shiftDay(today, 90),
      );
      expect(future.length, 90);
      expect(future.first.item.title, 'Другое чтение');
      expect(future.first.slot.start, 600);
    },
  );
  test(
    'idempotent check, uncheck and concurrent writes use one journal row',
    () async {
      await repo.saveTemplate(
        name: 'Неделя',
        items: [activity()],
        applyFrom: today,
      );
      final o = repo.snapshot.resolve(today, today).single;
      await Future.wait([
        repo.setCompleted(o, true),
        repo.setCompleted(o, true),
      ]);
      expect(
        (await db.customSelect('SELECT * FROM routine_checks').get()).length,
        1,
      );
      await repo.setCompleted(o, false);
      expect(
        await db.customSelect('SELECT * FROM routine_checks').get(),
        isEmpty,
      );
    },
  );
  test('future completion and historical activation are rejected', () async {
    await repo.saveTemplate(
      name: 'Неделя',
      items: [activity()],
      applyFrom: today,
    );
    final o = repo.snapshot
        .resolve(shiftDay(today, 1), shiftDay(today, 1))
        .single;
    await expectLater(repo.setCompleted(o, true), throwsFormatException);
    await expectLater(
      repo.activate(repo.snapshot.templates.single, shiftDay(today, -1)),
      throwsFormatException,
    );
    expect(repo.snapshot.completedIds, isEmpty);
  });
  test(
    'cancellation removes check; restoration preserves original schedule',
    () async {
      await repo.saveTemplate(
        name: 'Неделя',
        items: [activity()],
        applyFrom: today,
      );
      final o = repo.snapshot.resolve(today, today).single;
      await repo.setCompleted(o, true);
      await repo.saveOverride(o.copyWith(cancelled: true));
      var day = repo.snapshot.resolve(today, today);
      expect(day.single.cancelled, isTrue);
      expect(day.single.completed, isFalse);
      expect(RoutineStats(day).total, 0);
      await repo.restore(day.single);
      day = repo.snapshot.resolve(today, today);
      expect(day.single.cancelled, isFalse);
      expect(day.single.slot.start, 540);
    },
  );
  test('single-date override does not alter tomorrow or its version', () async {
    await repo.saveTemplate(
      name: 'Неделя',
      items: [activity()],
      applyFrom: today,
    );
    final o = repo.snapshot.resolve(today, today).single;
    await repo.saveOverride(
      o.copyWith(
        slot: RoutineSlot(id: o.slot.id, days: [1], start: 700, end: 760),
      ),
    );
    expect(repo.snapshot.resolve(today, today).single.slot.start, 700);
    expect(
      repo.snapshot
          .resolve(shiftDay(today, 1), shiftDay(today, 1))
          .single
          .slot
          .start,
      540,
    );
    expect(repo.snapshot.templates.single.items.single.slots.single.start, 540);
  });
  test(
    'overlap exceptions and Sunday overnight conflicts are rejected',
    () async {
      expect(
        () => validateRoutineItems([
          activity(start: 1380, end: 1500, days: [7]),
          activity(id: 'morning', start: 30, end: 90, days: [1]),
        ]),
        throwsFormatException,
      );
      await repo.saveTemplate(
        name: 'Неделя',
        items: [
          activity(),
          activity(id: 'study', start: 660, end: 720),
        ],
        applyFrom: today,
      );
      final first = repo.snapshot.resolve(today, today).first;
      await expectLater(
        repo.saveOverride(
          first.copyWith(
            slot: RoutineSlot(
              id: first.slot.id,
              days: [1],
              start: 650,
              end: 700,
            ),
          ),
        ),
        throwsFormatException,
      );
      expect(repo.snapshot.overrides, isEmpty);
    },
  );
  test('template activation respects previous overnight activity', () async {
    await repo.saveTemplate(
      name: 'Ночь',
      items: [activity(start: 1380, end: 1500)],
      applyFrom: today,
    );
    await repo.saveTemplate(
      name: 'Утро',
      items: [activity(start: 30, end: 90)],
    );
    await expectLater(
      repo.activate(repo.snapshot.templates.last, shiftDay(today, 1)),
      throwsFormatException,
    );
  });
  test(
    'archiving and reopening repository preserves history and layout',
    () async {
      final id = await repo.saveTemplate(
        name: 'Неделя',
        items: [activity()],
        applyFrom: today,
      );
      await repo.setCompleted(repo.snapshot.resolve(today, today).single, true);
      await repo.saveBoard({
        'dark': false,
        'panels': [
          {'x': 120.0, 'type': 'week'},
        ],
      });
      await repo.archive(id, true);
      final reopened = RoutineRepository(db, clock: () => today);
      await reopened.load();
      expect(reopened.snapshot.templates.single.archived, isTrue);
      expect(reopened.snapshot.resolve(today, today).single.completed, isTrue);
      expect((await reopened.readBoard())!['dark'], isFalse);
      reopened.dispose();
    },
  );
  test(
    'one-off untimed item works without any template and can be removed',
    () async {
      final item = activity(start: null, end: null);
      final o = RoutineOccurrence(
        id: 'one',
        date: routineDay(today),
        templateId: 'one-off',
        item: item,
        slot: item.slots.single,
        added: true,
      );
      await repo.saveOverride(o);
      await repo.setCompleted(o, true);
      final stats = RoutineStats(repo.snapshot.resolve(today, today));
      expect(stats.done, 1);
      expect(stats.doneMinutes, 0);
      await repo.restore(o);
      expect(repo.snapshot.resolve(today, today), isEmpty);
    },
  );
  test('cancel whole day excludes every item and clears its checks', () async {
    await repo.saveTemplate(
      name: 'Неделя',
      items: [
        activity(),
        activity(id: 'walk', start: 700, end: 720),
      ],
      applyFrom: today,
    );
    await repo.setCompleted(repo.snapshot.resolve(today, today).first, true);
    await repo.cancelDay(today);
    final stats = RoutineStats(repo.snapshot.resolve(today, today));
    expect(stats.cancelled, 2);
    expect(stats.total, 0);
    expect(stats.done, 0);
  });
  test('invalid save rolls back new template and version', () async {
    await expectLater(
      repo.saveTemplate(name: '', items: [activity()], applyFrom: today),
      throwsFormatException,
    );
    expect(
      await db.customSelect('SELECT * FROM routine_versions').get(),
      isEmpty,
    );
  });

  test('v8 migration keeps existing tasks and habits', () async {
    final temp = await Directory.systemTemp.createTemp(
      'pulse-routine-migration-',
    );
    final file = File('${temp.path}/test.sqlite');
    final first = AppDatabase(NativeDatabase(file));
    await first.customSelect('SELECT * FROM tasks').get();
    await first.customStatement(
      "INSERT INTO tasks(id,title,description,status,created_at,updated_at) VALUES ('kept','Existing task','',0,'2026-09-01','2026-09-01')",
    );
    await first.customStatement(
      "INSERT INTO habits(id,title,icon,color,type_kind,created_at,updated_at) VALUES ('habit','Existing habit','task_alt','#FFFFFF',0,'2026-09-01','2026-09-01')",
    );
    for (final table in [
      'routine_preferences',
      'routine_checks',
      'routine_overrides',
      'routine_activations',
      'routine_versions',
      'routine_templates',
    ]) {
      await first.customStatement('DROP TABLE $table');
    }
    await first.customStatement('PRAGMA user_version=8');
    await first.close();
    final migrated = AppDatabase(openPulseDatabaseFile(file));
    final migrationRepo = RoutineRepository(migrated);
    try {
      await migrationRepo.load();
      final backups = temp
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.bak'))
          .toList();
      expect(backups, hasLength(1));
      final backup = sqlite.sqlite3.open(
        backups.single.path,
        mode: sqlite.OpenMode.readOnly,
      );
      expect(backup.select('PRAGMA user_version').single['user_version'], 8);
      expect(
        backup.select('SELECT title FROM tasks').single['title'],
        'Existing task',
      );
      backup.close();
      expect(
        (await migrated.customSelect('SELECT title FROM tasks').getSingle())
            .read<String>('title'),
        'Existing task',
      );
      expect(
        (await migrated.customSelect('SELECT title FROM habits').getSingle())
            .read<String>('title'),
        'Existing habit',
      );
      expect(
        (await migrated.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        9,
      );
    } finally {
      migrationRepo.dispose();
      await migrated.close();
      await temp.delete(recursive: true);
    }
  });
}
