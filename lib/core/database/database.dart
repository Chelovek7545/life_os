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
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  //Если нужен Event
  DateTimeColumn get startsAt => dateTime().nullable()();
  DateTimeColumn get endsAt => dateTime().nullable()();


  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get space => text().nullable()();
  TextColumn get projectId => text().nullable()();
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

  //IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get goalId => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagModel')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  IntColumn get colorHex => integer()(); // Цвет тега
}

// Часть 2: Определение базы данных
@DriftDatabase(tables: [Tasks, Projects, Tags, TaskTagEntries])
class AppDatabase extends _$AppDatabase {
  // Конструктор
  AppDatabase() : super(_openConnection());


//Чтобы сохранялась 1 миллисекунда которую я добавляю
@override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);


  // Версия схемы базы данных
  @override
  int get schemaVersion => 1;

 
}

class TaskTagEntries extends Table {
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  
  @override
  Set<Column> get primaryKey => {taskId, tagId}; // Составной первичный ключ
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tasks.sqlite'));



    // //ТОЛЬКО В РАЗРАБОТКЕ
    // if (await file.exists()) {
    //   await file.delete();
    // }

    return NativeDatabase(file);
  });
}
