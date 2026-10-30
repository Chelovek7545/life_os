// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_logs_dao.dart';

// ignore_for_file: type=lint
mixin _$WorkLogsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TasksTable get tasks => attachedDatabase.tasks;
  $WorkLogsTable get workLogs => attachedDatabase.workLogs;
  WorkLogsDaoManager get managers => WorkLogsDaoManager(this);
}

class WorkLogsDaoManager {
  final _$WorkLogsDaoMixin _db;
  WorkLogsDaoManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$WorkLogsTableTableManager get workLogs =>
      $$WorkLogsTableTableManager(_db.attachedDatabase, _db.workLogs);
}
