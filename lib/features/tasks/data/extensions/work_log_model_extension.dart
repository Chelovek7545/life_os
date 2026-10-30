import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/domain/work_log_model.dart';

extension WorkLogModelExtension on WorkLogModel {
  WorkLog toDomain() {
    return WorkLog(
      id: id,
      status: status,
      taskId: taskId,
      date: date,
      description: description,
    );
  }
}

extension WorkLogDomainExtension on WorkLog {
  WorkLogsCompanion toCompanion() {
    return WorkLogsCompanion.insert(
      id: id,
      status: status,
      taskId: taskId,
      date: date,
      description: description,
    );
  }
}
