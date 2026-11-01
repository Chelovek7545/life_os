import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/lifegraph/data/drift_graph_deletion.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  late AppDatabase db;
  late DriftGraphDeletion deletion;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    deletion = DriftGraphDeletion(db);
    final now = DateTime(2026, 10, 31);
    await db
        .into(db.spheres)
        .insert(
          SpheresCompanion.insert(
            id: 'sphere',
            name: 'Life',
            color: '#123456',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal',
            name: 'Goal',
            description: '',
            color: '#123456',
            createdAt: now,
            updatedAt: now,
            sphereId: const Value('sphere'),
          ),
        );
    for (final id in ['root', 'child', 'grandchild']) {
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: id,
              name: id,
              description: '',
              color: '#123456',
              createdAt: now,
              updatedAt: now,
              goalId: id == 'root' ? const Value('goal') : const Value(null),
              parentProejectId: Value(switch (id) {
                'child' => 'root',
                'grandchild' => 'child',
                _ => null,
              }),
            ),
          );
    }
    for (final id in ['task', 'subtask', 'nested', 'unrelated']) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: id,
              title: id,
              description: '',
              status: TaskStatus.open,
              createdAt: now,
              updatedAt: now,
              projectId: id == 'task'
                  ? const Value('grandchild')
                  : const Value(null),
              parentTaskId: Value(switch (id) {
                'subtask' => 'task',
                'nested' => 'subtask',
                _ => null,
              }),
            ),
          );
    }
    await db
        .into(db.workLogs)
        .insert(
          WorkLogsCompanion.insert(
            id: 'log',
            status: 0,
            taskId: 'nested',
            date: now,
            description: 'keep consistent',
          ),
        );
  });
  tearDown(() => db.close());
  test(
    'sphere deletion includes descendants absent from a UI projection',
    () async {
      final deleted = await deletion.delete(
        GraphNodeType.sphere,
        'sphere',
        keepChildren: false,
      );
      expect(
        deleted,
        containsAll([
          'sphere',
          'goal',
          'root',
          'child',
          'grandchild',
          'task',
          'subtask',
          'nested',
        ]),
      );
      expect(await db.select(db.projects).get(), isEmpty);
      expect((await db.select(db.tasks).get()).map((t) => t.id), ['unrelated']);
      expect(await db.select(db.workLogs).get(), isEmpty);
    },
  );
  test('keeping project children removes dangling parent references', () async {
    await deletion.delete(
      GraphNodeType.project,
      'grandchild',
      keepChildren: true,
    );
    final task = await (db.select(
      db.tasks,
    )..where((t) => t.id.equals('task'))).getSingle();
    expect(task.projectId, isNull);
    expect(await db.select(db.tasks).get(), hasLength(4));
    expect(await db.select(db.workLogs).get(), hasLength(1));
  });
  test(
    'deleting a task subtree includes arbitrarily nested subtasks',
    () async {
      await deletion.delete(GraphNodeType.task, 'task', keepChildren: false);
      expect((await db.select(db.tasks).get()).map((t) => t.id), ['unrelated']);
      expect(await db.select(db.projects).get(), hasLength(3));
    },
  );
  test('a failed root delete rolls back every descendant deletion', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_goal BEFORE DELETE ON goals BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      deletion.delete(GraphNodeType.sphere, 'sphere', keepChildren: false),
      throwsA(anything),
    );
    expect(await db.select(db.tasks).get(), hasLength(4));
    expect(await db.select(db.projects).get(), hasLength(3));
    expect(await db.select(db.workLogs).get(), hasLength(1));
    expect(await db.select(db.goals).get(), hasLength(1));
  });
}
