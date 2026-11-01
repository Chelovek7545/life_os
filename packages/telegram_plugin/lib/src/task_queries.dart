import 'package:tasks_api/tasks_api.dart';

class BotTaskFilter {
  const BotTaskFilter({
    this.from,
    this.until,
    this.overdue = false,
    this.status,
    this.project,
    this.priority,
    this.search,
  });
  final DateTime? from;
  final DateTime? until;
  final bool overdue;
  final TaskStatus? status;
  final String? project;
  final int? priority;
  final String? search;
}

class BotTaskRow {
  const BotTaskRow(this.task, this.project);
  final Task task;
  final String? project;
}

class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.isArchived,
  });
  final String id;
  final String name;
  final bool isArchived;
}

abstract interface class TelegramTaskQueries {
  Future<List<BotTaskRow>> find(
    BotTaskFilter filter, {
    int page = 0,
    int pageSize = 10,
  });
  Future<List<ProjectSummary>> findProjects(String name);
  Future<List<ProjectSummary>> getProjectsPage({
    required int limit,
    required int offset,
  });
  Future<Task?> getTask(String id);
  Future<String?> getProjectName(String id);
}
