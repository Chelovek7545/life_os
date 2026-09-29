import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:life_os/features/lifegraph/domain/graph_builder.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/resources/data/obsidian_repository.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:rxdart/rxdart.dart';

class PulseScreenViewModel {
  final SpheresRepository spheresRepository;
  final GoalsRepository goalsRepository;
  final ProjectsRepository projectsRepository;
  final TasksRepository tasksRepository;
  final GraphPositionsRepository positionsRepository;
  final GraphNotesRepository notesRepository;
  final GraphBuilder graphBuilder;
  final ObsidianRepository obsidianRepository;

  PulseScreenViewModel({
    required this.spheresRepository,
    required this.goalsRepository,
    required this.projectsRepository,
    required this.tasksRepository,
    required this.positionsRepository,
    required this.notesRepository,
    required this.graphBuilder,
    required this.obsidianRepository,
  });

  StreamSubscription? _spheresSubscription;
  StreamSubscription? _goalsSubscription;
  StreamSubscription? _tasksSubscription;
  StreamSubscription? _projectsSubscription;

  final BehaviorSubject<List<Sphere>> _spheresSubject =
      BehaviorSubject<List<Sphere>>.seeded([]);
  Stream<List<Sphere>> get spheresStream => _spheresSubject.stream;
  List<Sphere> get spheres => _spheresSubject.value;

  final BehaviorSubject<List<Goal>> _goalsSubject =
      BehaviorSubject<List<Goal>>.seeded([]);
  Stream<List<Goal>> get goalsStream => _goalsSubject.stream;
  List<Goal> get goals => _goalsSubject.value;

  final BehaviorSubject<List<Project>> _projectsSubject =
      BehaviorSubject<List<Project>>.seeded([]);
  Stream<List<Project>> get projectsStream => _projectsSubject.stream;
  List<Project> get projects => _projectsSubject.value;

  final BehaviorSubject<List<Task>> _tasksSubject =
      BehaviorSubject<List<Task>>.seeded([]);
  Stream<List<Task>> get tasksStream => _tasksSubject.stream;
  List<Task> get tasks => _tasksSubject.value;

  //String? _lastSphereId;

  bool _initialized = false;

  /// true после первой эмиссии списка сфер — экран может сменить сплэш.
  bool get initialized => _initialized;

  /// Инициализация: загружает список сфер и восстанавливает последнюю
  /// просматриваемую сферу (либо выбирает первую).
  Future<void> initialize() async {
    //_lastSphereId = await positionsRepository.loadLastSphereId();
    _spheresSubscription = spheresRepository.watchAllSpheres().listen((
      spheres,
    ) {
      _spheresSubject.add(spheres);
      _initialized = true;
      // if (spheres.isNotEmpty && _currentSphereId == null) {
      //   final last = _lastSphereId;
      //   final target = (last != null && spheres.any((s) => s.id == last))
      //       ? last
      //       : spheres.first.id;
      //   _switchToSphere(target);
      // }
    }, onError: (e) => debugPrint('Spheres stream error: $e'));
    _goalsSubscription = goalsRepository.watchAllGoals().listen((goals) {
      _goalsSubject.add(goals);
    }, onError: (e) => debugPrint('Goals stream error: $e'));
    _tasksSubscription = tasksRepository.watchTasks().listen((tasks) {
      _tasksSubject.add(tasks);
    }, onError: (e) => debugPrint('Tasks stream error: $e'));
    //obsidianRepository.addListener(_onObsidianChanged);
    _projectsSubscription = projectsRepository.watchAllProjects().listen((
      projects,
    ) {
      _projectsSubject.add(projects);
    }, onError: (e) => debugPrint('Projects stream error: $e'));
  }

  /// Создаёт новую сферу и переключается на неё.
  Future<void> createSphere({
    required String name,
    String color = '#FFB59C',
  }) async {
    final sphere = Sphere.create(name: name, color: color);
    await spheresRepository.addSphere(sphere);
    //await _switchToSphere(sphere.id);
    openGraph(sphere.id);
  }

  LifeGraphViewModel openGraph(String sphereId) {
    final vm = LifeGraphViewModel(
      spheresRepository: spheresRepository,
      goalsRepository: goalsRepository,
      projectsRepository: projectsRepository,
      tasksRepository: tasksRepository,
      positionsRepository: positionsRepository,
      notesRepository: notesRepository,
      graphBuilder: graphBuilder,
      obsidianRepository: obsidianRepository,
    );
    vm.switchSphere(sphereId);
    return vm;
  }

  void dispose() {
    _spheresSubscription?.cancel();
    _goalsSubscription?.cancel();
    _tasksSubscription?.cancel();
    _projectsSubscription?.cancel();
    _spheresSubject.close();
    _goalsSubject.close();
    _tasksSubject.close();
    _projectsSubject.close();
  }
}
