import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';
import 'package:life_os/features/tasks/data/extensions/work_log_model_extension.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/extensions/project_model_extension.dart';
import 'package:life_os/features/goals/data/goals_dao.dart';
import 'package:life_os/features/goals/data/goal_model_extension.dart';
import 'package:life_os/features/spheres/data/spheres_dao.dart';
import 'package:life_os/features/spheres/data/sphere_model_extension.dart';
import 'package:projects_api/projects_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart';

class _CountingStore extends DriftSyncStore {
  _CountingStore(super.db);
  int projections = 0;
  @override
  Future<SyncGraph> state() {
    projections++;
    return super.state();
  }
}

void main() {
  test(
    'unenrolled lists retain local tags without decoding sync payloads',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = _CountingStore(db);
      final repo = TasksRepository(TasksDao(db, journal: store));
      await repo.addTask(
        Task.blank().copyWith(
          tags: [const Tag(id: 0, name: 'Local', colorHex: 1)],
        ),
      );
      final tasks = await repo.getAllTasks();
      expect(tasks.single.storageRevision, isNull);
      expect(tasks.single.tags.single.name, 'Local');
      expect(tasks.single.tags.single.syncId, isNull);
      expect(store.projections, 0);
      await store.initialize('enrolled');
      final enrolled = await repo.watchTasks().first;
      expect(enrolled.single.storageRevision, isNotNull);
      expect(enrolled.single.tags.single.name, 'Local');
      expect(enrolled.single.tags.single.syncId, isNotNull);
    },
  );

  test(
    'hierarchy, project task and work log lists use the persisted projection',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final spheres = List.generate(
        20,
        (i) => Sphere.create(name: 'Sphere $i'),
      );
      final goals = List.generate(
        20,
        (i) => Goal.create(name: 'Goal $i', sphereId: spheres.first.id),
      );
      final projects = List.generate(
        20,
        (i) => Project.create(name: 'Project $i', goalId: goals.first.id),
      );
      final tasks = List.generate(
        20,
        (i) => Task.blank().copyWith(projectId: Wrapped(projects.first.id)),
      );
      final logs = List.generate(20, (i) => WorkLog.blank(tasks.first.id));
      await db.batch((batch) {
        batch.insertAll(db.spheres, spheres.map((s) => s.toDrift()));
        batch.insertAll(db.goals, goals.map((g) => g.toDrift()));
        batch.insertAll(db.projects, projects.map((p) => p.toDrift()));
        batch.insertAll(db.tasks, tasks.map((t) => t.toDrift()));
        batch.insertAll(db.workLogs, logs.map((l) => l.toCompanion()));
      });
      final store = _CountingStore(db);
      await store.initialize('lists');
      final sphereDao = SpheresDao(db, journal: store);
      final goalDao = GoalsDao(db, journal: store);
      final projectDao = ProjectsDao(db, journal: store);
      final taskRepo = TasksRepository(TasksDao(db, journal: store));
      final logRepo = WorkLogsRepository(WorkLogsDao(db, journal: store));
      Future<void> check<T>(
        Future<List<T>> Function() read,
        String? Function(T) token,
      ) async {
        store.projections = 0;
        final items = await read();
        expect(items, hasLength(20));
        expect(items.every((item) => token(item) != null), isTrue);
        expect(store.projections, 0);
      }

      await check(sphereDao.getAllSpheres, (s) => s.storageRevision);
      await check(
        () => sphereDao.watchAllSpheres().first,
        (s) => s.storageRevision,
      );
      await check(goalDao.getAllGoals, (g) => g.storageRevision);
      await check(
        () => goalDao.watchAllGoals().first,
        (g) => g.storageRevision,
      );
      await check(
        () => goalDao.getGoalsBySphere(spheres.first.id),
        (g) => g.storageRevision,
      );
      await check(
        () => goalDao.watchGoalsBySphere(spheres.first.id).first,
        (g) => g.storageRevision,
      );
      await check(projectDao.getAllProjects, (p) => p.storageRevision);
      await check(
        () => projectDao.watchAllProjects().first,
        (p) => p.storageRevision,
      );
      await check(
        () => taskRepo.watchTasksForProject(projects.first.id).first,
        (t) => t.storageRevision,
      );
      await check(
        () => logRepo.getWorkLogsForTask(tasks.first.id),
        (l) => l.storageRevision,
      );
      await check(
        () => logRepo.getPageForTask(tasks.first.id, limit: 100, offset: 0),
        (l) => l.storageRevision,
      );
      await check(
        () => logRepo.watchWorkLogsForTask(tasks.first.id).first,
        (l) => l.storageRevision,
      );
    },
  );

  test('task list reads do not rebuild the causal graph', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tasks = List.generate(
      200,
      (i) => Task.blank().copyWith(title: 'Task $i'),
    );
    await db.batch(
      (batch) => batch.insertAll(db.tasks, tasks.map((t) => t.toDrift())),
    );
    final store = _CountingStore(db);
    await store.initialize('scaling');
    final repo = TasksRepository(TasksDao(db, journal: store));
    final elapsed = Stopwatch()..start();
    final loaded = await repo.getAllTasks();
    final listBuilds = store.projections;
    store.projections = 0;
    final streamed = await repo.watchTasks().first;
    final streamBuilds = store.projections;
    // ignore: avoid_print
    print(
      'SYNC READ: ${elapsed.elapsedMilliseconds}ms; '
      'list=$listBuilds, stream=$streamBuilds projections for ${tasks.length} tasks',
    );
    expect(loaded, hasLength(tasks.length));
    expect(streamed.every((task) => task.storageRevision != null), isTrue);
    expect(listBuilds, 0);
    expect(streamBuilds, 0);
    final stale = loaded.first;
    await repo.completeTask(stale.id);
    expect(
      await store.observe(stale),
      isA<Task>().having((t) => t.storageRevision, 'stale token', isNull),
    );
    expect((await repo.getById(stale.id))!.status, TaskStatus.done);
  });
}
