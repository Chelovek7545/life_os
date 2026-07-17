import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Widget createTestWidget({required Widget child}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.surfaceDim,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        onSurface: Colors.white,
      ),
    ),
    home: Scaffold(body: child),
  );
}

Task createMockTask({
  String? id,
  String? title,
  String? description,
  TaskStatus? status,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? dueDate,
  String? projectId,
  String? space,
  int? timerSeconds,
  double? effortWeight,
  List<Tag>? tags,
}) {
  final now = DateTime.now();
  return Task(
    id: id ?? _uuid.v4(),
    title: title ?? 'Test Task',
    description: description ?? '',
    status: status ?? TaskStatus.open,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    startsAt: startsAt,
    endsAt: endsAt,
    dueDate: dueDate,
    projectId: projectId,
    space: space,
    timerSeconds: timerSeconds ?? 0,
    effortWeight: effortWeight ?? 0.0,
    tags: tags ?? const [],
  );
}

Task createTaskWithTimes({
  required DateTime start,
  DateTime? end,
  String? id,
  String? title,
  TaskStatus? status,
  String? projectId,
  List<Tag>? tags,
}) {
  return createMockTask(
    id: id,
    title: title,
    status: status,
    startsAt: start,
    endsAt: end,
    projectId: projectId,
    tags: tags,
  );
}

TaskWithProject createMockTaskWithProject({Task? task, Project? project}) {
  return TaskWithProject(task: task ?? createMockTask(), project: project);
}

Project createMockProject({
  String? id,
  String? name,
  String? color,
  String? description,
  DateTime? createdAt,
}) {
  return Project(
    id: id ?? _uuid.v4(),
    name: name ?? 'Test Project',
    description: description ?? '',
    color: color ?? '#FF0000',
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Tag createMockTag({int? id, String? name, int? colorHex}) {
  return Tag(id: id ?? 1, name: name ?? 'test', colorHex: colorHex ?? 0xFF0000);
}

List<TaskWithProject> createMockTaskList(
  int count, {
  DateTime? anchorDate,
  DatePeriod? period,
}) {
  final baseDate = anchorDate ?? DateTime.now();
  return List.generate(count, (i) {
    final start = baseDate.add(Duration(hours: i * 2));
    final end = start.add(const Duration(hours: 1));
    return createMockTaskWithProject(
      task: createTaskWithTimes(start: start, end: end, title: 'Task ${i + 1}'),
      project: i % 2 == 0
          ? createMockProject(name: 'Project A')
          : createMockProject(name: 'Project B'),
    );
  });
}

extension TestDateTimeExtensions on DateTime {
  DateTime addDays(int days) => add(Duration(days: days));

  DateTime atTime(int hour, [int minute = 0]) =>
      DateTime(year, month, day, hour, minute);
}
