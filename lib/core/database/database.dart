import 'package:drift/native.dart';
import 'package:habits_api/habits_api.dart';
import 'package:drift/drift.dart';
import 'package:tasks_api/tasks_api.dart' show TaskStatus;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'sync_tables.dart';

part 'database.g.dart';

@DataClassName('WorkLogModel')
class WorkLogs extends Table {
  TextColumn get id => text()(); // UUID
  IntColumn get status => integer()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TaskModel')
class Tasks extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get title => text()();
  TextColumn get description => text()();
  IntColumn get status => intEnum<TaskStatus>()(); // enum как int
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  //Если нужен Event
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();

  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get space => text().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get parentTaskId => text().nullable()();
  TextColumn get predecessorTaskId => text().nullable()();
  TextColumn get spaceId => text().nullable()();

  IntColumn get timerSeconds => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  RealColumn get effortWeight => real().withDefault(const Constant(1.0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProjectModel')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get color => text()(); // Hex color, например "#FF5733"
  //TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get parentProejectId => text().nullable()();

  //IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get goalId => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GoalModel')
class Goals extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()(); // используем name вместо title
  TextColumn get description => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get color => text()(); // Hex color, например "#FF5733"
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get sphereId => text().nullable()(); // FK к Spheres

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SphereModel')
class Spheres extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get color => text()(); // Hex color, например "#FF5733"
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagModel')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  IntColumn get colorHex => integer()(); // Цвет тега
}

@DataClassName('HabitModel')
class Habits extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get title => text()();
  TextColumn get icon => text().withDefault(const Constant('task_alt'))();
  TextColumn get color => text().withDefault(const Constant('#FF5C00'))();
  IntColumn get typeKind => intEnum<HabitTypeKind>()();
  TextColumn get timeOfDay => text().nullable()(); // "HH:mm" для TimeHabit
  IntColumn get daysOfWeek =>
      integer().withDefault(const Constant(254))(); // bitmask
  IntColumn get durationWeeks =>
      integer().nullable()(); // null = без ограничения
  TextColumn get reminderTime => text().nullable()(); // "HH:mm"
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('HabitEntryModel')
class HabitEntries extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get habitId =>
      text().references(Habits, #id, onDelete: KeyAction.cascade)();
  TextColumn get dateKey => text()(); // "YYYY-MM-DD"
  IntColumn get status => intEnum<HabitEntryStatus>()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, dateKey},
  ];
}

// Часть 2: Определение базы данных
@DriftDatabase(
  tables: [
    Tasks,
    Projects,
    Tags,
    TaskTagEntries,
    Goals,
    Spheres,
    Habits,
    HabitEntries,
    WorkLogs,
    SyncIdentities,
    SyncRevisions,
    SyncCursors,
    SyncEntityHeads,
    SyncNoteCheckpoints,
  ],
)
class AppDatabase extends _$AppDatabase {
  // Конструктор
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  //Чтобы сохранялась 1 миллисекунда которую я добавляю
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  // Версия схемы базы данных
  @override
  int get schemaVersion => 15;

  Future<void> _createSyncProjectionTriggers() async {
    for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
      await customStatement('''
        CREATE TRIGGER sync_entity_heads_after_${event.toLowerCase()}
        AFTER $event ON sync_revisions
        BEGIN
          DELETE FROM sync_entity_heads WHERE entity_key = '';
        END
      ''');
    }
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createSyncProjectionTriggers();
        await customStatement(
          'CREATE UNIQUE INDEX tags_sync_id_unique ON tags(sync_id)',
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 15) await m.createTable(syncNoteCheckpoints);
        if (from < 14) {
          // Миграция могла добавить колонку до обновления user_version.
          final columns = await customSelect('PRAGMA table_info(tasks)').get();
          final hasPredecessor = columns.any(
            (column) => column.read<String>('name') == 'predecessor_task_id',
          );
          if (!hasPredecessor)
            await m.addColumn(tasks, tasks.predecessorTaskId);
        }
        if (from < 12) {
          await m.addColumn(tags, tags.syncId);
          await customStatement(
            'CREATE UNIQUE INDEX tags_sync_id_unique ON tags(sync_id)',
          );
        }
        if (from < 11) {
          await m.createTable(syncIdentities);
          await m.createTable(syncRevisions);
          await m.createTable(syncCursors);
        }
        if (from < 13) {
          await m.createTable(syncEntityHeads);
          await _createSyncProjectionTriggers();
        }
        if (from <= 2) {
          await m.database.customStatement(
            'DROP TABLE IF EXISTS dashboard_widgets',
          );
        }
        if (from <= 4) {
          // Миграция v4 была сломана: зависела от несуществующей таблицы `spaces`
          // (в v3 её не было) и создавала таблицы с camelCase-колонками, тогда
          // как drift ожидает snake_case. Здесь делаем всё идемпотентно:
          // чистим мусор от сломанной миграции и создаём таблицы корректно.
          await m.database.customStatement('DROP TABLE IF EXISTS spheres_new');
          await m.database.customStatement('DROP TABLE IF EXISTS goals_new');
          await m.database.customStatement('DROP TABLE IF EXISTS spaces');
          await m.database.customStatement('''
            CREATE TABLE IF NOT EXISTS "spheres" (
              "id" TEXT NOT NULL,
              "name" TEXT NOT NULL,
              "color" TEXT NOT NULL,
              "created_at" TEXT NOT NULL,
              "updated_at" TEXT NOT NULL,
              PRIMARY KEY ("id")
            )
          ''');
          await m.database.customStatement('''
            CREATE TABLE IF NOT EXISTS "goals" (
              "id" TEXT NOT NULL,
              "name" TEXT NOT NULL,
              "description" TEXT NOT NULL,
              "created_at" TEXT NOT NULL,
              "updated_at" TEXT NOT NULL,
              "color" TEXT NOT NULL,
              "due_date" TEXT NULL,
              "sphere_id" TEXT NULL,
              PRIMARY KEY ("id")
            )
          ''');
        }
        if (from < 6) {
          await m.createTable(habits);
          await m.createTable(habitEntries);
        }
        if (from < 7) {
          await m.addColumn(tasks, tasks.parentTaskId);
        }
        if (from < 8) {
          await m.addColumn(projects, projects.parentProejectId);
        }
        if (from < 9) {
          await m.createTable(workLogs);
        } else if (from < 10) {
          await m.addColumn(workLogs, workLogs.startedAt);
          await m.addColumn(workLogs, workLogs.endedAt);
        }
      },
    );
  }
}

class TaskTagEntries extends Table {
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {taskId, tagId}; // Составной первичный ключ
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tasks.sqlite'));

    return NativeDatabase.createInBackground(file);
  });
}
