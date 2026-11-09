import 'dart:async';
import 'package:agent_bridge/task_tools.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:test/test.dart';
import '../tasks/support/memory_tasks.dart';
import 'support/agent_harness.dart';

void main() {
  late MemoryTasks store;
  late TaskAgentTools tools;
  setUp(() {
    store = MemoryTasks();
    tools = TaskAgentTools(tasks: store, completion: Completion(store));
  });
  tearDown(() => tools.close());

  test(
    'strict tool arguments and invalid calendar values never write data',
    () async {
      for (final args in <Map<String, Object?>>[
        {},
        {'title': ' '},
        {'title': 'Task', 'projectId': 'missing'},
        {'title': 'Task', 'dueDate': '2027-02-30'},
        {'title': 'Task', 'startsAt': '2027-02-03T25:00:00Z'},
        {'title': 'Task', 'startsAt': '2027-02-03T09:00:00'},
        {'title': 'Task', 'endsAt': '2027-02-03T09:00:00Z'},
        {'title': 'Task', 'startsAt': '2027-02-03T09:00:00+99:00'},
      ]) {
        await expectLater(
          tools.call('tasks_create', args),
          throwsA(isA<ToolInputException>()),
        );
      }
      await expectLater(
        tools.call('tasks_list', {'completed': 'false'}),
        throwsA(isA<ToolInputException>()),
      );
      await expectLater(
        tools.call('tasks_list', {'limit': 101}),
        throwsA(isA<ToolInputException>()),
      );
      expect(store.writes, isEmpty);
    },
  );

  test(
    'creation and paginated search use shared task data and explicit timestamps',
    () async {
      for (final title in ['Читать книгу', 'Читать статью', 'Другое']) {
        await tools.call('tasks_create', {'title': title});
      }
      final page = await tools.call('tasks_list', {
        'query': 'ЧИТАТЬ',
        'limit': 1,
      });
      expect(page['total'], 2);
      expect(page['nextOffset'], 1);
      final second = await tools.call('tasks_list', {
        'query': 'читать',
        'offset': 1,
      });
      expect(second['nextOffset'], isNull);
      final created = await tools.call('tasks_create', {
        'title': 'Timed',
        'startsAt': '2027-02-03T12:00:00+03:00',
        'endsAt': '2027-02-03T13:00:00+03:00',
        'dueDate': '2027-02-04',
      });
      final task = created['task'] as Map;
      expect(task['startsAt'], '2027-02-03T09:00:00.000Z');
      expect(task['dueDate'], '2027-02-04');
    },
  );

  test(
    'completion is idempotent and deleted tasks are never recreated',
    () async {
      final task = Task.blank().copyWith(
        title: 'Preserved',
        description: 'Details',
      );
      store.items[task.id] = task;
      await tools.call('tasks_complete', {'id': task.id});
      await tools.call('tasks_complete', {'id': task.id});
      expect(store.writes, hasLength(1));
      expect(store.items[task.id]!.description, 'Details');
      store.items.clear();
      expect(
        (await tools.call('tasks_complete', {'id': task.id}))['error'],
        'task_not_found',
      );
      expect(store.items, isEmpty);
    },
  );

  test('a start day does not set a deadline or invent a duration', () async {
    await tools.call('tasks_create', {
      'title': 'Read',
      'startsAt': '2027-01-01',
    });
    final task = store.items.values.single;
    expect(task.startsAt, DateTime(2027, 1, 1));
    expect(task.dueDate, isNull);
    expect(task.endsAt, isNull);
    await tools.call('tasks_create', {
      'title': 'Deadline',
      'dueDate': '2027-01-02',
    });
    final deadline = store.items.values.singleWhere(
      (item) => item.title == 'Deadline',
    );
    expect(deadline.dueDate, DateTime(2027, 1, 2));
    expect(deadline.startsAt, isNull);
    await expectLater(
      tools.call('tasks_create', {
        'title': 'Invalid',
        'startsAt': '2027-02-30',
      }),
      throwsA(isA<ToolInputException>()),
    );
    expect(store.items, hasLength(2));
  });

  test(
    'queued arguments are captured and close drains accepted work',
    () async {
      store.writeGate = Completer<void>();
      store.entered = Completer<void>();
      final first = tools.call('tasks_create', {'title': 'First'});
      await store.entered!.future;
      final args = <String, Object?>{'title': 'Captured'};
      final next = tools.call('tasks_create', args);
      args['title'] = 'Changed';
      var done = false;
      final closing = tools.close().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      await expectLater(tools.call('tasks_list', {}), throwsStateError);
      store.writeGate!.complete();
      await Future.wait([first, next]);
      await closing;
      expect(store.items.values.map((task) => task.title), [
        'First',
        'Captured',
      ]);
    },
  );

  test('a failed write does not poison subsequent tool calls', () async {
    store.failWrite = true;
    await expectLater(
      tools.call('tasks_create', {'title': 'Failed'}),
      throwsStateError,
    );
    await tools.call('tasks_create', {'title': 'Retry'});
    expect(store.items.values.single.title, 'Retry');
  });
}
