import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

@DataClassName('TaskModel')
class Tasks extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get title => text()();
  TextColumn get description => text()();
  IntColumn get status => intEnum<TaskStatus>()(); // enum как int
  BoolColumn get isCompleted => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get space => text().nullable()();
  IntColumn get timerSeconds => integer()();
  RealColumn get effortWeight => real()();

  @override
  Set<Column> get primaryKey => {id};
}

// Часть 2: Определение базы данных
@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase {
  // Конструктор
  AppDatabase() : super(_openConnection());

  // Версия схемы базы данных
  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tasks.sqlite'));
    return NativeDatabase(file);
  });
}