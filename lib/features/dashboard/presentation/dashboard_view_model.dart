import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_os/features/dashboard/domain/dashboard_card_item.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen_state.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:rxdart/rxdart.dart';

class DashboardViewModel {
  final TasksRepository _taskRepository;
  final ProjectsRepository _projectsRepository;

  DashboardViewModel(this._taskRepository, this._projectsRepository);

  StreamSubscription<dynamic>? _combineSubscription;

  final BehaviorSubject<DashboardScreenState> _uiStateController =
      BehaviorSubject<DashboardScreenState>.seeded(
        const DashboardScreenLoading(),
      );
  Stream<DashboardScreenState> get state => _uiStateController.stream;

  void initialize() {
    // Используем Rx.combineLatest2, чтобы пересчитывать отфильтрованный список задач
    // каждый раз, когда меняются либо данные в БД, либо пользователь переключает вкладку (день/неделя/месяц)
    _combineSubscription =
        Rx.combineLatest2<List<Task>, List<Project>, void>(
          _taskRepository.watchTasks(),
          _projectsRepository.watchAllProjects(),
          (tasks, projects) {
            _handleDataUpdate(tasks, projects);
          },
        ).listen(
          (_) {},
          onError: (Object error) {
            _uiStateController.add(DashboardScreenError(error.toString()));
          },
        );
  }

  void _handleDataUpdate(List<Task> tasks, List<Project> projects) {
    final tasksCount = tasks.length;
    final projectsCount = projects.length;
    _uiStateController.add(
      DashboardScreenLoaded([
        DashboardCardItem(
          icon: Icons.task_alt,
          title: 'Tasks',
          value: tasksCount.toString(),
        ),
        DashboardCardItem(
          icon: Icons.dashboard_customize,
          title: 'Projects',
          value: projectsCount.toString(),
        ),
      ]),
    );
  }

  void dispose() {
    _combineSubscription?.cancel();
    _uiStateController.close();
  }
}
