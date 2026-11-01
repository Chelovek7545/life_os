import 'package:uuid/uuid.dart';

class WorkLog {
  const WorkLog({
    required this.id,
    required this.status,
    required this.taskId,
    required this.date,
    required this.description,
  });

  final String id;
  final int status;
  final String taskId;
  final DateTime date;
  final String description;

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
  }) {
    return WorkLog(
      id: id ?? this.id,
      status: status ?? this.status,
      taskId: taskId ?? this.taskId,
      date: date ?? this.date,
      description: description ?? this.description,
    );
  }
}
