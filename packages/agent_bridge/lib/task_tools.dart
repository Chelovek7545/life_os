import 'package:tasks_api/tasks_api.dart';

class ToolInputException implements Exception {
  const ToolInputException(this.message);
  final String message;
}

class TaskAgentTools {
  TaskAgentTools({required this.tasks, required this.completion});
  final TasksApi tasks;
  final TaskCompletionCommands completion;
  Future<void> _pending = Future.value();
  bool _accepting = true;
  Future<void>? _closing;

  static const definitions = [
    {
      'name': 'tasks_list',
      'description':
          'Find Life OS tasks. Results are paginated and ordered by id. Times are UTC; dueDate is a local calendar date.',
      'inputSchema': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'query': {'type': 'string', 'maxLength': 240},
          'completed': {'type': 'boolean'},
          'limit': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 100,
            'default': 25,
          },
          'offset': {
            'type': 'integer',
            'minimum': 0,
            'maximum': 1000000,
            'default': 0,
          },
        },
      },
      'annotations': {'readOnlyHint': true, 'openWorldHint': false},
    },
    {
      'name': 'tasks_create',
      'description':
          'Create an unassigned task. Do not retry a successful create: it creates a new task each time. Scheduled timestamps require Z or a UTC offset.',
      'inputSchema': {
        'type': 'object',
        'required': ['title'],
        'additionalProperties': false,
        'properties': {
          'title': {'type': 'string', 'minLength': 1, 'maxLength': 240},
          'description': {'type': 'string', 'maxLength': 10000},
          'dueDate': {
            'type': 'string',
            'format': 'date',
            'description':
                'Deadline only, when explicitly requested (deadline, due by, дедлайн, крайний срок). Do not use for a task scheduled on a day.',
          },
          'startsAt': {
            'type': 'string',
            'description':
                'Scheduled start (дата начала). Use this for on/tomorrow/на завтра. Without a time, send local YYYY-MM-DD; with a time, send RFC3339 with UTC offset.',
            'anyOf': [
              {'format': 'date'},
              {'format': 'date-time'},
            ],
          },
          'endsAt': {'type': 'string', 'format': 'date-time'},
        },
      },
      'annotations': {
        'readOnlyHint': false,
        'destructiveHint': false,
        'idempotentHint': false,
        'openWorldHint': false,
      },
    },
    {
      'name': 'tasks_complete',
      'description':
          'Mark an existing task done by id. Preserves its other fields and never recreates a deleted task. Safe to repeat.',
      'inputSchema': {
        'type': 'object',
        'required': ['id'],
        'additionalProperties': false,
        'properties': {
          'id': {'type': 'string', 'minLength': 1, 'maxLength': 200},
        },
      },
      'annotations': {
        'readOnlyHint': false,
        'destructiveHint': false,
        'idempotentHint': true,
        'openWorldHint': false,
      },
    },
  ];

  Future<Map<String, Object?>> call(String name, Map<String, Object?> args) {
    if (!_accepting) return Future.error(StateError('Agent tools are closed.'));
    // The same executor is usable by a future local assistant without MCP.
    final snapshot = Map<String, Object?>.of(args);
    final operation = _pending.then((_) => _execute(name, snapshot));
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<Map<String, Object?>> _execute(
    String name,
    Map<String, Object?> args,
  ) async {
    switch (name) {
      case 'tasks_list':
        _keys(args, {'query', 'completed', 'limit', 'offset'});
        final query = args.containsKey('query')
            ? _text(args, 'query', 240, empty: true).toLowerCase()
            : '';
        if (args.containsKey('completed') && args['completed'] is! bool) {
          throw const ToolInputException('completed must be a boolean.');
        }
        final limit = _integer(args, 'limit', 25, 1, 100);
        final offset = _integer(args, 'offset', 0, 0, 1000000);
        final all =
            (await tasks.getAllTasks())
                .where(
                  (task) =>
                      (!args.containsKey('completed') ||
                          task.isCompleted == args['completed']) &&
                      (query.isEmpty ||
                          task.title.toLowerCase().contains(query) ||
                          task.description.toLowerCase().contains(query)),
                )
                .toList()
              ..sort((a, b) => a.id.compareTo(b.id));
        final page = all.skip(offset).take(limit).map(taskJson).toList();
        return {
          'tasks': page,
          'total': all.length,
          'nextOffset': offset + page.length < all.length
              ? offset + page.length
              : null,
        };
      case 'tasks_create':
        _keys(args, {'title', 'description', 'dueDate', 'startsAt', 'endsAt'});
        final title = _text(args, 'title', 240);
        final description = args.containsKey('description')
            ? _text(args, 'description', 10000, empty: true)
            : '';
        final due = _date(args, 'dueDate', dateOnly: true);
        final startValue = args['startsAt'];
        final starts = _date(
          args,
          'startsAt',
          dateOnly:
              startValue is String &&
              RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(startValue),
        );
        final ends = _date(args, 'endsAt');
        if (ends != null && (starts == null || !ends.isAfter(starts))) {
          throw const ToolInputException(
            'endsAt requires startsAt and must be later.',
          );
        }
        final task = Task.blank().copyWith(
          title: title,
          description: description,
          dueDate: Wrapped(due),
          startsAt: Wrapped(starts),
          endsAt: Wrapped(ends),
        );
        await tasks.addTask(task);
        return {'task': taskJson(task)};
      case 'tasks_complete':
        _keys(args, {'id'});
        final id = _text(args, 'id', 200);
        final task = await completion.completeTask(id);
        if (task == null) {
          return {
            'error': 'task_not_found',
            'message': 'The task no longer exists.',
          };
        }
        return {'task': taskJson(task)};
      default:
        throw const ToolInputException('Unknown tool.');
    }
  }

  Future<void> close() => _closing ??= () async {
    _accepting = false;
    await _pending;
  }();
}

Map<String, Object?> taskJson(Task task) => {
  'id': task.id,
  'title': task.title,
  'description': task.description,
  'status': task.status.name,
  'projectId': task.projectId,
  'parentTaskId': task.parentTaskId,
  'dueDate': task.dueDate == null
      ? null
      : '${task.dueDate!.year.toString().padLeft(4, '0')}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}',
  'startsAt': task.startsAt?.toUtc().toIso8601String(),
  'endsAt': task.endsAt?.toUtc().toIso8601String(),
  'tags': task.tags.map((tag) => tag.name).toList(),
};

void _keys(Map<String, Object?> args, Set<String> allowed) {
  if (args.keys.any((key) => !allowed.contains(key))) {
    throw const ToolInputException('Unsupported argument.');
  }
}

String _text(
  Map<String, Object?> args,
  String key,
  int max, {
  bool empty = false,
}) {
  final value = args[key];
  if (value is! String ||
      value.trim().length > max ||
      (!empty && value.trim().isEmpty)) {
    throw ToolInputException(
      '$key must be a ${empty ? "possibly empty" : "nonempty"} string of at most $max characters.',
    );
  }
  return value.trim();
}

int _integer(
  Map<String, Object?> args,
  String key,
  int fallback,
  int min,
  int max,
) {
  if (!args.containsKey(key)) return fallback;
  final value = args[key];
  if (value is! int || value < min || value > max) {
    throw ToolInputException('$key must be an integer between $min and $max.');
  }
  return value;
}

DateTime? _date(
  Map<String, Object?> args,
  String key, {
  bool dateOnly = false,
}) {
  if (!args.containsKey(key)) return null;
  final value = args[key];
  final pattern = dateOnly
      ? RegExp(r'^\d{4}-\d{2}-\d{2}$')
      : RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$',
        );
  if (value is! String || !pattern.hasMatch(value)) {
    throw ToolInputException(
      '$key has an invalid date format. Use YYYY-MM-DD or a timestamp with seconds and UTC offset.',
    );
  }
  final calendar = DateTime.tryParse(value.substring(0, 10));
  if (calendar == null ||
      calendar.toIso8601String().substring(0, 10) != value.substring(0, 10)) {
    throw ToolInputException('$key has an invalid calendar date.');
  }
  if (!dateOnly &&
      (int.parse(value.substring(11, 13)) > 23 ||
          int.parse(value.substring(14, 16)) > 59 ||
          int.parse(value.substring(17, 19)) > 59)) {
    throw ToolInputException('$key has an invalid time.');
  }
  if (!dateOnly && !value.endsWith('Z')) {
    final offset = value.substring(value.length - 5);
    if (int.parse(offset.substring(0, 2)) > 23 ||
        int.parse(offset.substring(3)) > 59) {
      throw ToolInputException('$key has an invalid UTC offset.');
    }
  }
  final result = DateTime.tryParse(value);
  if (result == null) throw ToolInputException('$key has an invalid date.');
  return dateOnly ? result : result.toLocal();
}
