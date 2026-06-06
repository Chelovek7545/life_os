// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_dao.dart';

// ignore_for_file: type=lint
mixin _$TasksDaoMixin on DatabaseAccessor<AppDatabase> {
  $TasksTable get tasks => attachedDatabase.tasks;
  $TagsTable get tags => attachedDatabase.tags;
  $TaskTagEntriesTable get taskTagEntries => attachedDatabase.taskTagEntries;
  TasksDaoManager get managers => TasksDaoManager(this);
}

class TasksDaoManager {
  final _$TasksDaoMixin _db;
  TasksDaoManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$TaskTagEntriesTableTableManager get taskTagEntries =>
      $$TaskTagEntriesTableTableManager(
        _db.attachedDatabase,
        _db.taskTagEntries,
      );
}
