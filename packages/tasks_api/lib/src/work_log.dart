import 'package:uuid/uuid.dart';
import 'package:core_contracts/core_contracts.dart';

class WorkLog {
  const WorkLog({
    required this.id,
    required this.status,
    required this.taskId,
    required this.date,
    required this.description,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final int status;
  final String taskId;
  final DateTime date;
  final String description;
  final DateTime? startedAt;
  final DateTime? endedAt;
  Duration? get duration =>
      startedAt != null && endedAt != null && endedAt!.isAfter(startedAt!)
      ? endedAt!.difference(startedAt!)
      : null;

  factory WorkLog.blank(String taskId) {
    return WorkLog(
      id: const Uuid().v4(),
      status: 0,
      taskId: taskId,
      date: DateTime.now(),
      description: '',
    );
  }

  WorkLog copyWith({
    String? id,
    int? status,
    String? taskId,
    DateTime? date,
    String? description,
    Wrapped<DateTime?>? startedAt,
    Wrapped<DateTime?>? endedAt,
  }) {
    return WorkLog(
      id: id ?? this.id,
      status: status ?? this.status,
      taskId: taskId ?? this.taskId,
      date: date ?? this.date,
      description: description ?? this.description,
      startedAt: startedAt == null ? this.startedAt : startedAt.value,
      endedAt: endedAt == null ? this.endedAt : endedAt.value,
    );
  }
}
