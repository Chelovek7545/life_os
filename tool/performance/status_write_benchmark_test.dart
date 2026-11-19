// Run separately from the test suite:
// flutter test --no-pub tool/performance/status_write_benchmark_test.dart --concurrency=1
// Uses temporary SQLite files; no application settings or user data are opened.
import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';
import 'package:life_os/features/tasks/data/extensions/work_log_model_extension.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  final extraRevisions = int.parse(
    Platform.environment['STATUS_BENCH_EXTRA_REVISIONS'] ?? '0',
  );
  test('SQLite event loop probe', () async {
    for (final background in [false, true]) {
      final directory = await Directory.systemTemp.createTemp(
        'life-os-sql-probe-',
      );
      final file = File(p.join(directory.path, 'tasks.sqlite'));
      final db = AppDatabase(
        background
            ? NativeDatabase.createInBackground(file)
            : NativeDatabase(file),
      );
      try {
        await db.customSelect('SELECT 1').getSingle();
        final clock = Stopwatch()..start();
        var previous = 0;
        var largestGap = 0;
        final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
          final current = clock.elapsedMicroseconds;
          final gap = current - previous;
          if (gap > largestGap) largestGap = gap;
          previous = current;
        });
        try {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          final result = await db
              .customSelect(
                'WITH RECURSIVE numbers(x) AS (VALUES(1) UNION ALL '
                'SELECT x+1 FROM numbers WHERE x<2000000) SELECT sum(x) AS total FROM numbers',
              )
              .getSingle();
          expect(result.read<int>('total'), 2000001000000);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        } finally {
          timer.cancel();
        }
        // ignore: avoid_print
        print(
          'SQL_PROBE background=$background max_timer_gap_ms=${(largestGap / 1000).toStringAsFixed(2)}',
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    }
  });
  for (final size in [200, 1000]) {
    for (final sync in [false, true]) {
      for (final background in [false, true]) {
        for (final narrow in [false, true]) {
          test(
            'size=$size sync=$sync background=$background narrow=$narrow',
            () async {
              final directory = await Directory.systemTemp.createTemp(
                'life-os-status-perf-',
              );
              final file = File(p.join(directory.path, 'tasks.sqlite'));
              final db = AppDatabase(
                background
                    ? NativeDatabase.createInBackground(file)
                    : NativeDatabase(file),
              );
              try {
                final tasks = List.generate(
                  size,
                  (i) => Task.blank().copyWith(title: 'Task $i'),
                );
                final workLogs = [
                  for (final task in tasks) WorkLog.blank(task.id),
                ];
                await db.batch((batch) {
                  batch.insertAll(
                    db.tasks,
                    tasks.map((task) => task.toDrift()),
                  );
                  batch.insertAll(
                    db.workLogs,
                    workLogs.map((log) => log.toCompanion()),
                  );
                });
                final journal = DriftSyncStore(db);
                if (sync) await journal.initialize('benchmark');
                final repo = TasksRepository(TasksDao(db, journal: journal));
                final logs = WorkLogsRepository(
                  WorkLogsDao(db, journal: journal),
                );
                if (sync) {
                  for (var index = 0; index < extraRevisions; index++) {
                    await repo.setTaskStatus(
                      tasks.last.id,
                      index.isEven ? TaskStatus.done : TaskStatus.inProgress,
                    );
                  }
                }
                final taskTimes = <int>[];
                final logTimes = <int>[];
                for (var i = 0; i < 7; i++) {
                  final target = i.isEven
                      ? TaskStatus.done
                      : TaskStatus.inProgress;
                  final taskTimer = Stopwatch()..start();
                  if (narrow) {
                    await repo.setTaskStatus(tasks.first.id, target);
                  } else {
                    final current = (await repo.getById(tasks.first.id))!;
                    await repo.updateTask(
                      current.copyWith(
                        status: target,
                        updatedAt: DateTime.now(),
                      ),
                    );
                  }
                  taskTimer.stop();
                  // The old checkbox already has a streamed snapshot before its click.
                  final log = (await logs.getById(workLogs.first.id))!;
                  final status = i.isEven ? 1 : 0;
                  final logTimer = Stopwatch()..start();
                  if (narrow) {
                    await logs.setWorkLogStatus(log.id, status);
                  } else {
                    await logs.updateWorkLog(log.copyWith(status: status));
                  }
                  logTimer.stop();
                  if (i > 0) {
                    taskTimes.add(taskTimer.elapsedMicroseconds);
                    logTimes.add(logTimer.elapsedMicroseconds);
                  }
                }
                double medianMs(List<int> values) {
                  values.sort();
                  return (values[2] + values[3]) / 2000;
                }

                // ignore: avoid_print
                print(
                  'STATUS_PERF size=$size sync=$sync background=$background narrow=$narrow '
                  'extra_revisions=${sync ? extraRevisions : 0} '
                  'task_ms=${medianMs(taskTimes).toStringAsFixed(2)} '
                  'log_ms=${medianMs(logTimes).toStringAsFixed(2)}',
                );
                expect(
                  (await repo.getById(tasks.first.id))!.status,
                  TaskStatus.done,
                );
                expect((await logs.getById(workLogs.first.id))!.status, 1);
              } finally {
                await db.close();
                await directory.delete(recursive: true);
              }
            },
            timeout: const Timeout(Duration(minutes: 3)),
          );
        }
      }
    }
  }
}
