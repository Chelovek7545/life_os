import 'dart:async';
import 'package:test/test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import '../support/memory_tasks.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'calendar preloads the full three-week window without widening the Tasks list',
    () async {
      final tasks = MemoryTasks();
      final projects = MemoryProjectQueries();
      final dates = [
        DateTime(2026, 12, 20, 9),
        DateTime(2026, 12, 21, 9),
        DateTime(2026, 12, 28, 9),
        DateTime(2027, 1, 10, 23),
        DateTime(2027, 1, 11),
      ];
      final items = [
        for (final date in dates)
          Task.blank().copyWith(
            startsAt: Wrapped(date),
            projectId: const Wrapped('p'),
          ),
      ];
      for (final item in items) {
        tasks.items[item.id] = item;
      }
      final range = Task.blank().copyWith(
        startsAt: Wrapped(DateTime(2026, 12, 1)),
        endsAt: Wrapped(DateTime(2026, 12, 21)),
        projectId: const Wrapped('p'),
      );
      tasks.items[range.id] = range;
      final other = items[2].copyWith(
        id: 'other',
        projectId: const Wrapped('other'),
      );
      tasks.items[other.id] = other;
      final model =
          TasksViewModel(
              tasks,
              GetTasksWithProjectsUseCase(tasks, projects),
              projects,
            )
            ..updateFilter(
              (_) => TaskFilterConfig(
                anchorDate: DateTime(2027, 1, 3),
                period: DatePeriod.week,
                projectIds: ['p'],
              ),
            )
            ..initialize();
      addTearDown(model.dispose);
      final stream = model.watchCalendarTasks(bufferDays: 7);
      expect(
        identical(stream, model.watchCalendarTasks(bufferDays: 7)),
        isTrue,
      );
      expect((await stream.first).map((item) => item.task.id), [
        items[1].id,
        items[2].id,
        items[3].id,
        range.id,
      ]);
      final state =
          await model.state.firstWhere((state) => state is TasksLoaded)
              as TasksLoaded;
      expect(state.tasks.single.task.id, items[2].id);
      expect(
        (await model.watchCalendarTasks().first).single.task.id,
        items[2].id,
      );
      await model.updateTask(items[1].copyWith(title: 'Updated buffered task'));
      expect((await stream.first).first.task.title, 'Updated buffered task');
      expect(
        () => model.watchCalendarTasks(bufferDays: -1),
        throwsArgumentError,
      );
    },
  );

  test(
    'moving a panel task preserves date-only markers, range length and fresh fields',
    () async {
      final tasks = MemoryTasks();
      final projects = MemoryProjectQueries();
      final model = TasksViewModel(
        tasks,
        GetTasksWithProjectsUseCase(tasks, projects),
        projects,
      );
      addTearDown(model.dispose);
      final task = Task.blank().copyWith(
        title: 'Fresh title',
        startsAt: Wrapped(DateTime(2026, 12, 31, 0, 0, 0, 1)),
        endsAt: Wrapped(DateTime(2027, 1, 3, 0, 0, 0, 1)),
        tags: [const Tag(id: 1, name: 'Tag', colorHex: 0)],
      );
      tasks.items[task.id] = task;
      await model.moveTaskToDay(
        task.id,
        DateTime(2027, 1, 2),
        DateTime(2027, 1, 4),
      );
      final moved = tasks.items[task.id]!;
      expect(moved.startsAt, DateTime(2027, 1, 2, 0, 0, 0, 1));
      expect(moved.endsAt, DateTime(2027, 1, 5, 0, 0, 0, 1));
      expect(moved.title, task.title);
      expect(moved.tags, task.tags);
      final timed = task.copyWith(
        startsAt: Wrapped(DateTime(2026, 11, 3, 9)),
        endsAt: Wrapped(DateTime(2026, 11, 5, 18)),
      );
      tasks.items[task.id] = timed;
      await model.moveTaskToDay(
        task.id,
        DateTime(2026, 11, 4),
        DateTime(2026, 11, 6),
      );
      expect(tasks.items[task.id]!.startsAt, DateTime(2026, 11, 5, 9));
      expect(tasks.items[task.id]!.endsAt, DateTime(2026, 11, 7, 18));
      tasks.items[task.id] = task.copyWith(endsAt: const Wrapped(null));
      await model.moveTaskToDay(
        task.id,
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 1),
      );
      expect(tasks.items[task.id]!.endsAt, isNull);
    },
  );

  test('Tasks list includes every range day and overlapping periods', () async {
    final tasks = MemoryTasks();
    final projects = MemoryProjectQueries();
    final range = Task.blank().copyWith(
      startsAt: Wrapped(DateTime(2026, 12, 20, 9)),
      endsAt: Wrapped(DateTime(2027, 1, 3)),
    );
    final unscheduled = Task.blank();
    tasks.items.addAll({range.id: range, unscheduled.id: unscheduled});
    final model = TasksViewModel(
      tasks,
      GetTasksWithProjectsUseCase(tasks, projects),
      projects,
    )..initialize();
    addTearDown(model.dispose);
    for (final day in [
      DateTime(2026, 12, 19),
      DateTime(2026, 12, 20),
      DateTime(2026, 12, 31),
      DateTime(2027, 1, 3),
      DateTime(2027, 1, 4),
    ]) {
      model.updateFilter((_) => TaskFilterConfig(anchorDate: day));
      await tick();
      final state = await model.state.first as TasksLoaded;
      final included =
          !day.isBefore(DateTime(2026, 12, 20)) &&
          !day.isAfter(DateTime(2027, 1, 3));
      expect(
        state.tasks.map((item) => item.task.id),
        included ? [range.id] : isEmpty,
        reason: '$day',
      );
      expect(state.unscheduledTasks.single.task.id, unscheduled.id);
    }
    for (final period in [DatePeriod.week, DatePeriod.month, DatePeriod.year]) {
      model.updateFilter(
        (_) =>
            TaskFilterConfig(anchorDate: DateTime(2027, 1, 3), period: period),
      );
      await tick();
      expect(
        (await model.state.first as TasksLoaded).tasks.single.task.id,
        range.id,
      );
    }
    // Missing or invalid end dates remain single-day tasks.
    tasks.items[range.id] = range.copyWith(
      endsAt: Wrapped(DateTime(2026, 12, 1)),
    );
    tasks.emit();
    model.updateFilter(
      (_) => TaskFilterConfig(anchorDate: DateTime(2026, 12, 21)),
    );
    await tick();
    expect((await model.state.first as TasksLoaded).tasks, isEmpty);
  });

  test(
    'calendar includes overlapping ranges across years and respects filters',
    () async {
      final tasks = MemoryTasks();
      final projects = MemoryProjectQueries();
      final range = Task.blank().copyWith(
        projectId: const Wrapped('p'),
        startsAt: Wrapped(DateTime(2026, 12, 20, 9)),
        endsAt: Wrapped(DateTime(2027, 1, 3)),
      );
      final excluded = range.copyWith(
        id: 'other-project',
        projectId: const Wrapped('other'),
      );
      tasks.items.addAll({range.id: range, excluded.id: excluded});
      final model = TasksViewModel(
        tasks,
        GetTasksWithProjectsUseCase(tasks, projects),
        projects,
      )..initialize();
      addTearDown(model.dispose);
      final calendar = model.watchCalendarTasks();
      for (final period in DatePeriod.values) {
        model.updateFilter(
          (_) => TaskFilterConfig(
            anchorDate: DateTime(2027, 1, 3),
            period: period,
            projectIds: ['p'],
          ),
        );
        expect((await calendar.first).map((item) => item.task.id), [range.id]);
      }
      model.updateFilter(
        (_) => TaskFilterConfig(anchorDate: DateTime(2027, 1, 4)),
      );
      expect(await calendar.first, isEmpty);
      model.updateFilter(
        (_) => TaskFilterConfig(
          anchorDate: DateTime(2027, 1, 3),
          showCompleted: true,
        ),
      );
      expect(await calendar.first, isEmpty);
    },
  );

  test(
    'calendar updates preserve fresh fields and serialize move then resize',
    () async {
      final tasks = MemoryTasks();
      final projects = MemoryProjectQueries();
      final model = TasksViewModel(
        tasks,
        GetTasksWithProjectsUseCase(tasks, projects),
        projects,
      );
      addTearDown(model.dispose);
      final original = Task.blank().copyWith(
        startsAt: Wrapped(DateTime(2026, 11, 2, 8)),
        endsAt: Wrapped(DateTime(2026, 11, 2, 9)),
      );
      final latest = original.copyWith(
        title: 'Updated elsewhere',
        description: 'Keep me',
        tags: [const Tag(id: 1, name: 'Keep tag', colorHex: 0)],
        status: TaskStatus.done,
      );
      tasks.items[latest.id] = latest;
      await Future.wait([
        model.rescheduleTask(
          original.id,
          startMinutes: 600,
          newDate: DateTime(2026, 11, 3),
        ),
        model.rescheduleTask(original.id, durationMinutes: 90),
      ]);
      final moved = tasks.items[original.id]!;
      expect(moved.startsAt, DateTime(2026, 11, 3, 10));
      expect(moved.endsAt, DateTime(2026, 11, 3, 11, 30));
      expect(moved.title, latest.title);
      expect(moved.description, latest.description);
      expect(moved.tags, latest.tags);
      expect(moved.status, TaskStatus.done);
      await model.scheduleTask(
        original.id,
        DateTime(2026, 11, 4, 8),
        DateTime(2026, 11, 4, 10),
      );
      expect(tasks.items[original.id]!.title, latest.title);
      expect(tasks.items[original.id]!.tags, latest.tags);
      expect(tasks.items[original.id]!.endsAt, DateTime(2026, 11, 4, 10));
      tasks.items.clear();
      await model.rescheduleTask(original.id, startMinutes: 720);
      await model.scheduleTask(original.id, DateTime(2026), DateTime(2027));
      expect(tasks.items, isEmpty);
    },
  );

  test(
    'calendar writes finish before disposal and stale callbacks are rejected',
    () async {
      final tasks = MemoryTasks()
        ..writeGate = Completer<void>()
        ..entered = Completer<void>();
      final projects = MemoryProjectQueries();
      final model = TasksViewModel(
        tasks,
        GetTasksWithProjectsUseCase(tasks, projects),
        projects,
      );
      final task = Task.blank();
      tasks.items[task.id] = task;
      final write = model.scheduleTask(
        task.id,
        DateTime(2026, 11, 2, 8),
        DateTime(2026, 11, 2, 9),
      );
      await tasks.entered!.future;
      var closed = false;
      final closing = model.dispose().then((_) => closed = true);
      expect(closed, isFalse);
      await expectLater(
        model.rescheduleTask(task.id, startMinutes: 600),
        throwsStateError,
      );
      tasks.writeGate!.complete();
      await write;
      await closing;
      expect(tasks.items[task.id]!.startsAt, DateTime(2026, 11, 2, 8));
    },
  );

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
