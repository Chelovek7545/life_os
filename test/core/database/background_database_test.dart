import 'dart:io';
import 'dart:isolate';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  test(
    'background SQLite preserves journal, streams, foreign keys and restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'life-os-background-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(p.join(directory.path, 'tasks.sqlite'));
      final started = ReceivePort();
      addTearDown(started.close);
      final sender = started.sendPort;
      final worker = started.first;
      final db = AppDatabase(
        NativeDatabase.createInBackground(
          file,
          isolateSetup: () => sender.send(Isolate.current.debugName),
        ),
      );
      final task = Task.blank();
      final log = WorkLog.blank(task.id);
      try {
        final journal = DriftSyncStore(db);
        await journal.initialize('background-test');
        expect(await worker, startsWith('Drift isolate worker'));
        final tasks = TasksRepository(TasksDao(db, journal: journal));
        final logs = WorkLogsRepository(WorkLogsDao(db, journal: journal));
        await tasks.addTask(task);
        await logs.addWorkLog(log);
        final changedTask = tasks.watchTasks().firstWhere(
          (items) => items.single.isCompleted,
        );
        final changedLog = logs
            .watchWorkLogsForTask(task.id)
            .firstWhere((items) => items.single.status == 1);
        await tasks.setTaskStatus(task.id, TaskStatus.done);
        await logs.setWorkLogStatus(log.id, 1);
        expect((await changedTask).single.storageRevision, isNotNull);
        expect((await changedLog).single.storageRevision, isNotNull);
        await expectLater(
          logs.addWorkLog(WorkLog.blank('missing')),
          throwsA(anything),
        );
        expect((await journal.readFeed()).entries, hasLength(4));
      } finally {
        await db.close();
      }
      final reopened = AppDatabase(NativeDatabase.createInBackground(file));
      try {
        final journal = DriftSyncStore(reopened);
        final tasks = TasksRepository(TasksDao(reopened, journal: journal));
        final logs = WorkLogsRepository(
          WorkLogsDao(reopened, journal: journal),
        );
        expect((await tasks.getById(task.id))!.status, TaskStatus.done);
        expect((await logs.getById(log.id))!.status, 1);
        expect((await journal.readFeed()).entries, hasLength(4));
        await tasks.deleteTask(task.id);
        expect(await reopened.select(reopened.workLogs).get(), isEmpty);
      } finally {
        await reopened.close();
      }
    },
  );
}
