import 'package:core_contracts/core_contracts.dart' show StorageException;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/goals/data/goals_dao.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/spheres/data/spheres_dao.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';
import 'package:life_os/features/lifegraph/data/drift_graph_deletion.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'package:projects_api/projects_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:graph_api/graph_api.dart';
import 'package:projects_plugin/projects_logic.dart';
import 'package:goals_plugin/goals_logic.dart';
import 'package:spheres_plugin/spheres_logic.dart';
import 'package:tasks_plugin/tasks_logic.dart';

void main() {
  late AppDatabase aDb, bDb;
  late DriftSyncStore a, b;
  late ProjectsDao projectDao;
  late ProjectsRepository projects;
  late GoalsRepository goals;
  late SpheresRepository spheres;
  late TasksRepository tasks, otherTasks;
  late WorkLogsRepository logs;
  Future<Set<String>> versions(DriftSyncStore store, String key) async =>
      (await store.heads(key)).map((r) => r.id).toSet();
  Future<Map<String, String?>> projection(DriftSyncStore store) async {
    final graph = await store.state();
    return {
      for (final key in graph.heads.keys) key: graph.winner(key)?.payload,
    };
  }

  Future<
    ({
      Sphere sphere,
      Goal goal,
      Project project,
      Project nested,
      Task root,
      Task child,
    })
  >
  seed() async {
    final sphere = Sphere.create(name: 'Life');
    await spheres.addSphere(sphere);
    final goal = Goal.create(name: 'Goal', sphereId: sphere.id);
    await goals.addGoal(goal);
    final project = Project.create(name: 'Project', goalId: goal.id);
    await projects.addProject(project);
    final nested = Project.create(name: 'Nested', parentProjectId: project.id);
    await projects.addProject(nested);
    final root = Task.blank().copyWith(
      title: 'Root',
      projectId: Wrapped(project.id),
      spaceId: const Wrapped('legacy-space'),
      tags: [const Tag(id: 0, name: 'Focus', colorHex: 0xFF112233)],
    );
    await tasks.addTask(root);
    final child = Task.blank().copyWith(
      title: 'Child',
      projectId: Wrapped(nested.id),
      parentTaskId: Wrapped(root.id),
    );
    await tasks.addTask(child);
    await logs.addWorkLog(WorkLog.blank(child.id));
    return (
      sphere: sphere,
      goal: goal,
      project: project,
      nested: nested,
      root: root,
      child: child,
    );
  }

  final engine = SyncEngine();
  test(
    'graph editors keep the version of the opened node for all business kinds',
    () async {
      final data = await seed();
      final scope = GraphScope(rootId: data.sphere.id, rootKind: 'sphere');
      final specs =
          <
            ({
              GraphContributor contributor,
              GraphNodeCommands commands,
              String id,
            })
          >[
            (
              contributor: ProjectsGraphContributor(projects),
              commands: projectsGraphCommands(
                projects,
                delete: (_) => Future.value({}),
              ),
              id: data.project.id,
            ),
            (
              contributor: GoalsGraphContributor(goals),
              commands: goalsGraphCommands(
                goals,
                delete: (_) => Future.value({}),
              ),
              id: data.goal.id,
            ),
            (
              contributor: SpheresGraphContributor(spheres),
              commands: spheresGraphCommands(
                spheres,
                delete: (_) => Future.value({}),
              ),
              id: data.sphere.id,
            ),
            (
              contributor: TasksGraphContributor(tasks),
              commands: tasksGraphCommands(
                tasks,
                delete: (_) => Future.value({}),
              ).first,
              id: data.root.id,
            ),
          ];
      for (final spec in specs) {
        final node = (await spec.contributor.watch(scope).first).firstWhere(
          (n) => n.id == spec.id,
        );
        expect(node.attributes['storageRevision'], isNotNull);
        final request = GraphUpdateRequest(
          scope: scope,
          current: node,
          updated: GraphNodeData(
            id: node.id,
            kind: node.kind,
            title: 'Updated',
            subtitle: node.subtitle,
            color: node.color,
            attributes: node.attributes,
          ),
        );
        await spec.commands.update!(request);
        await expectLater(spec.commands.update!(request), throwsStateError);
      }
    },
  );
  test(
    'project cycles created offline are pending and repairable without losing either branch',
    () async {
      final first = Project.create(name: 'First');
      final second = Project.create(name: 'Second');
      await projects.addProject(first);
      await projects.addProject(second);
      await engine.exchange(a, b);
      final otherProjects = ProjectsRepository(ProjectsDao(bDb, journal: b));
      final localFirst = (await projects.getProjectById(first.id))!;
      final remoteSecond = (await otherProjects.getProjectById(second.id))!;
      await projects.updateProject(
        localFirst.copyWith(parentProejectId: Wrapped(second.id)),
      );
      await otherProjects.updateProject(
        remoteSecond.copyWith(parentProejectId: Wrapped(first.id)),
      );
      await engine.exchange(a, b);
      expect(await a.readPending(), hasLength(2));
      final basis = {
        ...await versions(a, 'project/${first.id}'),
        ...(await a.readPending())
            .where((r) => r.key == 'project/${first.id}')
            .map((r) => r.id),
      };
      await a.repairPendingEntity(
        'project',
        HierarchySyncCodec.project(first),
        expectedRevisions: basis,
      );
      await engine.exchange(a, b);
      expect(await b.readPending(), isEmpty);
      expect(
        (await otherProjects.getProjectById(second.id))!.parentProejectId,
        first.id,
      );
    },
  );
  test(
    'deleting a tag atomically detaches it and invalidates a previously opened task',
    () async {
      final task = Task.blank().copyWith(
        tags: [const Tag(id: 0, name: 'Remove', colorHex: 1)],
      );
      await tasks.addTask(task);
      final old = (await tasks.getById(task.id))!;
      final tag = old.tags.single;
      await a.deleteEntity(
        'tag',
        tag.syncId!,
        expectedHeads: await versions(a, 'tag/${tag.syncId}'),
      );
      expect((await tasks.getById(task.id))!.tags, isEmpty);
      await expectLater(
        tasks.updateTask(old.copyWith(title: 'Stale')),
        throwsA(isA<StorageException>()),
      );
      await engine.exchange(a, b);
      expect((await otherTasks.getById(task.id))!.tags, isEmpty);
      expect(await bDb.select(bDb.tags).get(), isEmpty);
    },
  );
  setUp(() async {
    aDb = AppDatabase(NativeDatabase.memory());
    bDb = AppDatabase(NativeDatabase.memory());
    a = DriftSyncStore(aDb);
    b = DriftSyncStore(bDb);
    await a.initialize('dataset');
    await b.initialize('dataset');
    projectDao = ProjectsDao(aDb, journal: a);
    projects = ProjectsRepository(projectDao);
    goals = GoalsRepository(GoalsDao(aDb, journal: a));
    spheres = SpheresRepository(SpheresDao(aDb, journal: a));
    tasks = TasksRepository(TasksDao(aDb, journal: a));
    otherTasks = TasksRepository(TasksDao(bDb, journal: b));
    logs = WorkLogsRepository(WorkLogsDao(aDb, journal: a));
  });
  tearDown(() async {
    await aDb.close();
    await bDb.close();
  });

  test(
    'full dependency chain converges while local tag integers differ',
    () async {
      await b.saveEntity(
        'tag',
        HierarchySyncCodec.tag(
          const Tag(id: 0, syncId: 'seed', name: 'Other', colorHex: 1),
        ),
        expectedHeads: {},
      );
      final data = await seed();
      await engine.exchange(a, b);
      final local = (await tasks.getById(data.root.id))!;
      final remote = (await otherTasks.getById(data.root.id))!;
      expect(remote.projectId, data.project.id);
      expect(remote.spaceId, 'legacy-space');
      expect(remote.tags.single.id, isNot(local.tags.single.id));
      expect(remote.tags.single.syncId, local.tags.single.syncId);
      expect(remote.tags.single.colorHex, 0xFF112233);
      expect(await projection(b), await projection(a));
      expect(await bDb.select(bDb.workLogs).get(), hasLength(1));
      expect((await b.state()).pending, isEmpty);
      expect(await bDb.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  for (final type in [
    GraphNodeType.sphere,
    GraphNodeType.goal,
    GraphNodeType.project,
  ]) {
    for (final keep in [true, false]) {
      test(
        '${type.name} graph deletion keepChildren=$keep transfers one atomic group',
        () async {
          final data = await seed();
          await engine.exchange(a, b);
          final cursor = await b.receivedCursor((await a.identity()).deviceId);
          final id = type == GraphNodeType.sphere
              ? data.sphere.id
              : type == GraphNodeType.goal
              ? data.goal.id
              : data.project.id;
          // Legacy spaceId is opaque; graph deletion must retain its existing semantics.
          await DriftGraphDeletion(
            aDb,
            journal: a,
          ).delete(type, id, keepChildren: keep);
          final entries = (await a.readFeed(after: cursor)).entries;
          expect(entries.length, greaterThan(1));
          expect(entries.map((e) => e.revision.groupId).toSet(), hasLength(1));
          final old = await projection(b);
          await b.receive(
            SyncBatch(await a.identity(), cursor, entries.take(1)),
          );
          expect(await projection(b), old);
          await b.receive(
            SyncBatch(await a.identity(), cursor + 1, entries.skip(1)),
          );
          expect(await projection(b), await projection(a));
          expect((await b.state()).pending, isEmpty);
          if (keep) {
            expect(await bDb.select(bDb.tasks).get(), hasLength(2));
            if (type == GraphNodeType.sphere) {
              expect(
                (await bDb.select(bDb.goals).get()).single.sphereId,
                isNull,
              );
            }
            if (type == GraphNodeType.goal) {
              expect(
                (await bDb.select(bDb.projects).get())
                    .firstWhere((p) => p.id == data.project.id)
                    .goalId,
                isNull,
              );
            }
            if (type == GraphNodeType.project) {
              expect(
                (await otherTasks.getById(data.root.id))!.projectId,
                isNull,
              );
            }
          } else {
            expect(await bDb.select(bDb.tasks).get(), isEmpty);
            expect(await bDb.select(bDb.workLogs).get(), isEmpty);
          }
        },
      );
    }
  }

  test(
    'project goal and sphere snapshots reject stale saves and preserve tokens in copyWith',
    () async {
      final data = await seed();
      final p = (await projects.getProjectById(data.project.id))!;
      final g = (await goals.getGoal(data.goal.id))!;
      final s = (await spheres.getSphere(data.sphere.id))!;
      expect(p.storageRevision, isNotNull);
      expect(g.storageRevision, isNotNull);
      expect(s.storageRevision, isNotNull);
      expect(
        (await projects.watchAllProjects().first).first.storageRevision,
        isNotNull,
      );
      expect(
        (await goals.watchGoalsBySphere(s.id).first).single.storageRevision,
        isNotNull,
      );
      expect(
        (await spheres.watchAllSpheres().first).single.storageRevision,
        isNotNull,
      );
      await projects.updateProject(p.copyWith(name: 'New project'));
      await goals.updateGoal(g.copyWith(name: 'New goal'));
      await spheres.updateSphere(s.copyWith(name: 'New sphere'));
      for (final action in [
        () => projects.updateProject(p),
        () => goals.updateGoal(g),
        () => spheres.updateSphere(s),
      ]) {
        await expectLater(action(), throwsA(isA<StorageException>()));
      }
      await engine.exchange(a, b);
      expect(await projection(a), await projection(b));
    },
  );

  test(
    'narrow project commands journal current state without replacing dependencies',
    () async {
      final data = await seed();
      await projectDao.archiveProject(data.project.id);
      await projectDao.unarchiveProject(data.project.id);
      await projectDao.updateProjectName(data.project.id, 'Narrow');
      await engine.exchange(a, b);
      final row = (await bDb.select(bDb.projects).get()).firstWhere(
        (p) => p.id == data.project.id,
      );
      expect(row.name, 'Narrow');
      expect(row.isArchived, isFalse);
      expect(row.goalId, data.goal.id);
      expect(await bDb.select(bDb.workLogs).get(), hasLength(1));
    },
  );

  test(
    'renaming a portable tag does not turn an older task snapshot into a new tag',
    () async {
      final task = Task.blank().copyWith(
        tags: [const Tag(id: 0, name: 'Old', colorHex: 123)],
      );
      await tasks.addTask(task);
      final stale = (await tasks.getById(task.id))!;
      final tag = stale.tags.single;
      await a.saveEntity(
        'tag',
        HierarchySyncCodec.tag(tag.copyWith(name: 'Renamed')),
        expectedHeads: await versions(a, 'tag/${tag.syncId}'),
      );
      await tasks.updateTask(stale.copyWith(title: 'Edited'));
      final current = (await tasks.getById(task.id))!;
      expect(current.tags.single.name, 'Renamed');
      expect(current.tags.single.syncId, tag.syncId);
      expect(await aDb.select(aDb.tags).get(), hasLength(1));
      await engine.exchange(a, b);
      expect((await otherTasks.getById(task.id))!.tags.single.name, 'Renamed');
    },
  );

  test(
    'same-name offline tags stay pending and can be explicitly renamed without discarding tasks',
    () async {
      final first = Task.blank().copyWith(
        tags: [const Tag(id: 0, name: 'Same', colorHex: 1)],
      );
      final second = Task.blank().copyWith(
        tags: [const Tag(id: 0, name: 'Same', colorHex: 2)],
      );
      await tasks.addTask(first);
      await otherTasks.addTask(second);
      await engine.exchange(a, b);
      expect((await a.readPending()).length, 4);
      expect(await aDb.select(aDb.tasks).get(), isEmpty);
      final pending = (await a.readPending()).firstWhere(
        (r) => r.entityType == 'tag',
      );
      final tag = HierarchySyncCodec.decodeTag(pending.payload!);
      await a.repairPendingEntity(
        'tag',
        HierarchySyncCodec.tag(tag.copyWith(name: 'Different')),
        expectedRevisions: {pending.id},
      );
      await engine.exchange(a, b);
      expect(await a.readPending(), isEmpty);
      expect(await b.readPending(), isEmpty);
      expect(await bDb.select(bDb.tasks).get(), hasLength(2));
      expect((await bDb.select(bDb.tags).get()).map((t) => t.name).toSet(), {
        'Same',
        'Different',
      });
    },
  );

  test(
    'task with a not-yet-received project remains pending until project arrives',
    () async {
      final project = Project.create(name: 'Later');
      final task = Task.blank().copyWith(projectId: Wrapped(project.id));
      final r = SyncRevision(
        id: 'task',
        deviceId: 'peer',
        entityId: task.id,
        parents: [],
        payload: TaskSyncCodec.encode(task),
        schemaVersion: 3,
      );
      await b.receive(
        SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [SyncEntry(1, r)]),
      );
      expect(await bDb.select(bDb.tasks).get(), isEmpty);
      final p = SyncRevision(
        id: 'project',
        deviceId: 'peer',
        entityId: project.id,
        entityType: 'project',
        parents: [],
        payload: HierarchySyncCodec.project(project),
        schemaVersion: 3,
      );
      await b.receive(
        SyncBatch(const SyncIdentity('dataset', 'peer'), 1, [SyncEntry(2, p)]),
      );
      expect((await otherTasks.getById(task.id))!.projectId, project.id);
    },
  );

  test(
    'full hierarchy rollback restores all tables when journal fails midway',
    () async {
      final data = await seed();
      final before = await projection(a);
      final count = (await a.readFeed()).entries.length;
      await aDb.customStatement(
        "CREATE TRIGGER reject_hierarchy BEFORE INSERT ON sync_revisions WHEN (SELECT count(*) FROM sync_revisions)>$count BEGIN SELECT RAISE(ABORT,'test'); END",
      );
      await expectLater(
        DriftGraphDeletion(
          aDb,
          journal: a,
        ).delete(GraphNodeType.sphere, data.sphere.id, keepChildren: false),
        throwsA(anything),
      );
      expect(await projection(a), before);
      expect(await aDb.select(aDb.tasks).get(), hasLength(2));
      expect(await aDb.select(aDb.workLogs).get(), hasLength(1));
      expect(await aDb.select(aDb.spheres).get(), hasLength(1));
    },
  );
}
