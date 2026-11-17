import 'package:test/test.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  test(
    'a typed entity key cannot be smuggled into a task-parent reference',
    () {
      expect(() => SyncPayload.key('unknown', 'id'), throwsFormatException);
      final task = Task.blank().copyWith(
        parentTaskId: const Wrapped('project/not-a-task'),
      );
      final revision = SyncRevision(
        id: 'bad-parent',
        deviceId: 'peer',
        entityId: task.id,
        parents: [],
        payload: TaskSyncCodec.encode(task),
        schemaVersion: 3,
      );
      expect(() => SyncGraph([revision]), throwsFormatException);
    },
  );
  test(
    'reusing one transaction ID with disjoint manifests cannot complete a group',
    () {
      final one = Task.blank();
      final two = Task.blank();
      SyncRevision r(String id, Task task, List<String> members) =>
          SyncRevision(
            id: id,
            deviceId: 'peer',
            entityId: task.id,
            parents: [],
            payload: TaskSyncCodec.encode(task),
            schemaVersion: 2,
            groupId: 'same',
            groupMembers: members,
          );
      expect(
        () => SyncGraph([
          r('one', one, ['one', 'missing1']),
          r('two', two, ['two', 'missing2']),
        ]),
        throwsFormatException,
      );
    },
  );
  test(
    'causal heads do not depend on delivery order or redundant ancestors',
    () {
      final task = Task.blank();
      SyncRevision r(String id, List<String> parents) => SyncRevision(
        id: id,
        deviceId: 'peer',
        entityId: task.id,
        parents: parents,
        payload: TaskSyncCodec.encode(task.copyWith(title: id)),
      );
      final root = r('root', []);
      final a = r('a', ['root']);
      final b = r('b', ['root']);
      final joined = r('joined', ['a', 'b', 'root']);
      for (final revisions in [
        [root, a, b, joined],
        [joined, b, a, root],
        [b, root, joined, a],
      ]) {
        final graph = SyncGraph(revisions);
        expect(graph.heads[task.id]!.map((r) => r.id), ['joined']);
        expect(graph.pending, isEmpty);
      }
    },
  );

  test('unknown fields and invalid status cannot be silently discarded', () {
    final payload = TaskSyncCodec.encode(Task.blank());
    expect(
      () => TaskSyncCodec.decode(payload.replaceFirst('{', '{"unknown":1,')),
      throwsFormatException,
    );
    expect(
      () => TaskSyncCodec.decode(payload.replaceFirst('"open"', '"unknown"')),
      throwsArgumentError,
    );
  });

  test('deleted ancestors cannot have upsert descendants', () {
    final task = Task.blank();
    final deleted = SyncRevision(
      id: 'delete',
      deviceId: 'peer',
      entityId: task.id,
      parents: [],
      payload: null,
    );
    final revived = SyncRevision(
      id: 'revive',
      deviceId: 'peer',
      entityId: task.id,
      parents: ['delete'],
      payload: TaskSyncCodec.encode(task),
    );
    expect(() => SyncGraph([revived, deleted]), throwsFormatException);
  });
}
