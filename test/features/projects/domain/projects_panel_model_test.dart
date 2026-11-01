import 'package:test/test.dart';
import 'package:projects_api/projects_api.dart';
import 'package:projects_plugin/projects_logic.dart';
import 'package:tasks_api/tasks_api.dart';
import '../../tasks/support/memory_tasks.dart';

void main() {
  test(
    'project panel filters by date, excludes archived projects and publishes immutable progress',
    () async {
      final tasks = MemoryTasks();
      final projects = MemoryProjectQueries();
      final active = Project.create(name: 'Active');
      final empty = Project.create(name: 'Empty');
      final archived = Project.create(
        name: 'Archived',
      ).copyWith(isArchived: true);
      for (final project in [active, empty, archived]) {
        projects.items[project.id] = project;
      }
      final day = DateTime(2026, 11, 2);
      final task = Task.blank().copyWith(
        projectId: Wrapped(active.id),
        startsAt: Wrapped(day),
        status: TaskStatus.done,
      );
      tasks.items[task.id] = task;
      final model = ProjectsPanelModel(
        projects: projects,
        tasks: tasks,
        date: day,
      )..initialize();
      addTearDown(model.dispose);
      model.initialize();
      final initial = await model.state.firstWhere((state) => !state.isLoading);
      expect(initial.projects.map((item) => item.project.id), [
        active.id,
        empty.id,
      ]);
      expect(initial.projects.first.progress, 1);
      expect(initial.projects.last.progress, 0);
      expect(() => initial.projects.clear(), throwsUnsupportedError);
      model.setOnlyForDate(true);
      expect(model.currentState.projects.single.project.id, active.id);
      model.selectDate(DateTime(2026, 11, 3));
      expect(model.currentState.projects, isEmpty);
      expect(tasks.listeners, hasLength(1));
      expect(projects.listeners, hasLength(1));
    },
  );
}
