import 'package:uuid/uuid.dart';
import 'tag.dart';
import 'package:core_contracts/core_contracts.dart' show Wrapped;

enum TaskStatus { open, notStarted, inProgress, done }

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,

    required this.updatedAt,

    this.startsAt,
    this.endsAt,
    required this.timerSeconds,
    required this.effortWeight,
    required this.tags,
    this.dueDate,
    this.projectId,
    this.parentTaskId,
    this.predecessorTaskId,
    this.additionalPredecessorTaskIds = const [],
    this.space,
    this.spaceId,
    this.priority = 0,
    this.storageRevision,
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  final DateTime? startsAt;
  final DateTime? endsAt;

  final DateTime? dueDate;
  final String? projectId;
  final String? parentTaskId;
  final String? predecessorTaskId;
  final List<String> additionalPredecessorTaskIds;
  List<String> get predecessorTaskIds => [
    ?predecessorTaskId,
    ...additionalPredecessorTaskIds,
  ];
  final String? space;
  final String? spaceId;
  final int priority;
  final int timerSeconds;
  final double effortWeight;
  final List<Tag> tags;

  /// Opaque storage token captured when this snapshot was read.
  final String? storageRevision;

  bool get isCompleted => status == TaskStatus.done;

  Duration get duration {
    if (startsAt != null && endsAt != null) {
      return endsAt!.difference(startsAt!);
    }
    return const Duration(minutes: 15);
  }

  factory Task.blank() {
    return Task(
      id: const Uuid().v4(), // или можно генирировать UUID
      title: 'Untitled',
      description: '',
      status: TaskStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),

      timerSeconds: 0,
      effortWeight: 0.0,
      tags: const [],
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Wrapped<DateTime?>? startsAt,
    Wrapped<DateTime?>? endsAt,

    Wrapped<DateTime?>? dueDate,
    Wrapped<String?>? projectId,
    Wrapped<String?>? parentTaskId,
    Wrapped<String?>? predecessorTaskId,
    List<String>? predecessorTaskIds,
    Wrapped<String?>? space,
    Wrapped<String?>? spaceId,
    int? priority,
    int? timerSeconds,
    double? effortWeight,
    List<Tag>? tags,
  }) {
    final predecessors =
        predecessorTaskIds ??
        (predecessorTaskId == null
            ? this.predecessorTaskIds
            : [?predecessorTaskId.value]);
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate != null ? dueDate.value : this.dueDate,
      startsAt: startsAt != null ? startsAt.value : this.startsAt,
      endsAt: endsAt != null ? endsAt.value : this.endsAt,

      projectId: projectId != null ? projectId.value : this.projectId,
      predecessorTaskId: predecessors.firstOrNull,
      additionalPredecessorTaskIds: List.unmodifiable(predecessors.skip(1)),
      parentTaskId: parentTaskId != null
          ? parentTaskId.value
          : this.parentTaskId,
      space: space != null ? space.value : this.space,
      spaceId: spaceId != null ? spaceId.value : this.spaceId,
      priority: priority ?? this.priority,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      effortWeight: effortWeight ?? this.effortWeight,
      tags: tags ?? this.tags,
      storageRevision: storageRevision,
    );
  }
}

TaskStatus taskStatusFromStorage(String value) {
  return TaskStatus.values.firstWhere(
    (TaskStatus status) => status.name == value,
    orElse: () => TaskStatus.open,
  );
}

bool wouldCreateSequenceCycle(
  String sourceId,
  String targetId,
  Iterable<String> Function(String id) predecessorsOf,
) {
  final visited = <String>{};
  final pending = [sourceId];
  while (pending.isNotEmpty) {
    final id = pending.removeLast();
    if (id == targetId) return true;
    if (visited.add(id)) pending.addAll(predecessorsOf(id));
  }
  return false;
}
