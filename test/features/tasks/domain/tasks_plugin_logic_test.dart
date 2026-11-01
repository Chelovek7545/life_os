import 'dart:async';
import 'package:test/test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import '../support/memory_tasks.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('filter contracts copy lists and hash equal values consistently', () {
    final projects = ['p'];
    final tags = [1];
    final filter = TaskFilterConfig(
      anchorDate: DateTime(2026, 12, 31),
      projectIds: projects,
      tagIds: tags,
    );
    projects.clear();
    tags.clear();
    expect(filter.projectIds, ['p']);
    expect(filter.tagIds, [1]);
    expect(() => filter.projectIds.clear(), throwsUnsupportedError);
    final same = filter.copyWith();
    expect(same, filter);
    expect(same.hashCode, filter.hashCode);
  });

  test(
    'pure model initializes once and closes owned auxiliary streams',
    () async {
      final tasks = MemoryTasks();
      final projects = MemoryProjectQueries();
      final model = TasksViewModel(
        tasks,
        GetTasksWithProjectsUseCase(tasks, projects),
        projects,
      )..initialize();
      model.initialize();
      final extra = model.watchAllTasks().listen((_) {});
      final projectExtra = model.watchProjects().listen((_) {});
      await model.state.firstWhere((state) => state is TasksEmpty);
      expect(tasks.listeners, hasLength(2));
      expect(projects.listeners, hasLength(2));
      await model.dispose();
      expect(tasks.listeners, isEmpty);
      expect(projects.listeners, isEmpty);
      expect(model.initialize, throwsStateError);
      expect(model.watchAllTasks, throwsStateError);
      await extra.cancel();
      await projectExtra.cancel();
    },
  );

  test(
    'week filter includes Sunday and excludes next Monday across year boundary',
    () async {
      final tasks = MemoryTasks();
      final projects = MemoryProjectQueries();
      for (final date in [
        DateTime(2026, 12, 28, 9),
        DateTime(2027, 1, 3, 23, 59),
        DateTime(2027, 1, 4),
      ]) {
        final task = Task.blank().copyWith(startsAt: Wrapped(date));
        tasks.items[task.id] = task;
      }
      final model = TasksViewModel(
        tasks,
        GetTasksWithProjectsUseCase(tasks, projects),
        projects,
      );
      addTearDown(model.dispose);
      model.updateFilter(
        (old) => old.copyWith(
          anchorDate: DateTime(2026, 12, 31),
          period: DatePeriod.week,
        ),
      );
      model.initialize();
      final state =
          await model.state.firstWhere((state) => state is TasksLoaded)
              as TasksLoaded;
      expect(state.tasks, hasLength(2));
      expect(() => state.tasks.clear(), throwsUnsupportedError);
      expect(() => state.selectedTasks.clear(), throwsUnsupportedError);
    },
  );

  test(
    'selection batch captures targets and finishes before disposal',
    () async {
      final tasks = MemoryTasks()
        ..writeGate = Completer<void>()
        ..entered = Completer<void>();
      final projects = MemoryProjectQueries();
      final model = TasksViewModel(
        tasks,
        GetTasksWithProjectsUseCase(tasks, projects),
        projects,
      )..initialize();
      final a = Task.blank();
      final b = Task.blank();
      model.toggleTaskSelection(a);
      model.toggleTaskSelection(b);
      final deleting = model.deleteSelectedTask();
      model.clearTaskSelection();
      await tasks.entered!.future;
      var disposed = false;
      final closing = model.dispose().then((_) => disposed = true);
      await expectLater(model.addTask(Task.blank()), throwsStateError);
      expect(disposed, isFalse);
      tasks.writeGate!.complete();
      await deleting;
      await closing;
      expect(tasks.writes, [a.id, b.id]);
    },
  );

  test('a failed task write does not poison the operation queue', () async {
    final tasks = MemoryTasks();
    final projects = MemoryProjectQueries();
    final model = TasksViewModel(
      tasks,
      GetTasksWithProjectsUseCase(tasks, projects),
      projects,
    )..initialize();
    addTearDown(model.dispose);
    tasks.failWrite = true;
    await expectLater(model.addTask(Task.blank()), throwsStateError);
    final next = Task.blank().copyWith(title: 'Retry');
    await model.addTask(next);
    expect(tasks.items[next.id]!.title, 'Retry');
  });

  test(
    'work log scope drains accepted writes and waits for source cancellation',
    () async {
      final store = MemoryWorkLogs()
        ..writeGate = Completer<void>()
        ..cancelGate = Completer<void>()
        ..entered = Completer<void>();
      final session = WorkLogsSession(store);
      final stream = session.watchWorkLogsForTask('task');
      final sub = stream.listen((_) {});
      await tick();
      final log = WorkLog(
        id: 'log',
        taskId: 'task',
        date: DateTime(2026),
        status: 0,
        description: 'Step',
      );
      final write = session.addWorkLog(log);
      await store.entered!.future;
      var closed = false;
      final closing = session.dispose().then((_) => closed = true);
      await expectLater(session.deleteWorkLog('log'), throwsStateError);
      expect(() => session.watchWorkLogsForTask('task'), throwsStateError);
      await expectLater(stream.toList(), throwsStateError);
      store.writeGate!.complete();
      await write;
      await tick();
      expect(closed, isFalse);
      store.cancelGate!.complete();
      await closing;
      expect(store.items['log'], same(log));
      expect(store.listeners, isEmpty);
      await sub.cancel();
    },
  );

  test(
    'work log scope preserves paging parameters, immutable results and retry',
    () async {
      final store = MemoryWorkLogs();
      final session = WorkLogsSession(store);
      addTearDown(session.dispose);
      final log = WorkLog(
        id: 'log',
        taskId: 'task',
        date: DateTime(2026),
        status: 0,
        description: 'Step',
      );
      store.failWrite = true;
      await expectLater(session.addWorkLog(log), throwsStateError);
      await session.addWorkLog(log);
      final from = DateTime(2026);
      final until = DateTime(2027);
      final page = await session.getPageForTask(
        'task',
        limit: 10,
        offset: 0,
        from: from,
        until: until,
        status: 0,
        search: 'Step',
      );
      expect(store.lastPage, ['task', 10, 0, from, until, 0, 'Step']);
      expect(page.single, same(log));
      expect(() => page.clear(), throwsUnsupportedError);
    },
  );

  test(
    'work log cancellation failure still releases every source and finishes streams',
    () async {
      final store = MemoryWorkLogs();
      final session = WorkLogsSession(store);
      final done = Completer<void>();
      session
          .watchWorkLogsForTask('first')
          .listen((_) {}, onDone: done.complete);
      session.watchWorkLogsForTask('second').listen((_) {});
      await tick();
      store.failCancel = true;
      await expectLater(session.dispose(), throwsStateError);
      await done.future;
      await tick();
      expect(store.listeners, isEmpty);
      await expectLater(session.deleteWorkLog('late'), throwsStateError);
    },
  );
}
