import 'dart:convert';
import 'package:tasks_api/tasks_api.dart';

class WorkLogSyncCodec {
  static String encode(WorkLog log) {
    if (log.id.isEmpty ||
        log.taskId.isEmpty ||
        (log.startedAt != null &&
            log.endedAt != null &&
            !log.endedAt!.isAfter(log.startedAt!))) {
      throw const FormatException('Invalid work log.');
    }
    return jsonEncode({
      'id': log.id,
      'taskId': log.taskId,
      'status': log.status,
      'date': log.date.toIso8601String(),
      'description': log.description,
      'startedAt': log.startedAt?.toIso8601String(),
      'endedAt': log.endedAt?.toIso8601String(),
    });
  }

  static WorkLog decode(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    DateTime? date(String key) =>
        map[key] == null ? null : DateTime.parse(map[key] as String);
    final log = WorkLog(
      id: map['id'] as String,
      taskId: map['taskId'] as String,
      status: map['status'] as int,
      date: date('date')!,
      description: map['description'] as String,
      startedAt: date('startedAt'),
      endedAt: date('endedAt'),
    );
    if (encode(log) != payload) {
      throw const FormatException('Noncanonical work log.');
    }
    return log;
  }
}
