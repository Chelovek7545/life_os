import 'package:graph_ui/graph_ui.dart';
import 'package:graph_api/graph_api.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:goals_api/goals_api.dart';
import '../domain/canvas_note.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:life_os/features/lifegraph/domain/graph_builder.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:projects_api/projects_api.dart';
import 'package:notes_api/notes_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:rxdart/rxdart.dart';

class PulseScreenViewModel {
  final Set<LifeGraphViewModel> _graphs = {};
  final SpheresApi spheresRepository;
  final GoalsApi goalsRepository;
  final ProjectsQueries projectsRepository;
  final TasksApi tasksRepository;
  final GraphPositionsRepository positionsRepository;
  final CanvasNotesStore notesRepository;
  final GraphBuilder graphBuilder;
  final GraphNodePresentationRegistry nodePresentations;
  final GraphEditorRegistry nodeEditors;
  final GraphCommandRegistry commands;
  final VaultNotesApi? obsidianRepository;

  PulseScreenViewModel({
    required this.spheresRepository,
    required this.goalsRepository,
    required this.projectsRepository,
    required this.tasksRepository,
    required this.positionsRepository,
    required this.notesRepository,
    required this.graphBuilder,
    required this.nodePresentations,
    required this.nodeEditors,
    required this.commands,
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
  }

  Future<LifeGraphViewModel> openGraph(String sphereId) async {
    late final LifeGraphViewModel vm;
    vm = LifeGraphViewModel(
      onDisposed: () => _graphs.remove(vm),
      spheresRepository: spheresRepository,
      positionsRepository: positionsRepository,
      notesRepository: notesRepository,
      graphBuilder: graphBuilder,
      nodePresentations: nodePresentations,
      nodeEditors: nodeEditors,
      commands: commands,
      obsidianRepository: obsidianRepository,
    );
    _graphs.add(vm);
    await vm.switchSphere(sphereId);
    return vm;
  }

  Future<void> closeGraphs() =>
      Future.wait(_graphs.toList().map((graph) => graph.dispose()));

  Future<void> dispose() async {
    await closeGraphs();
    await _spheresSubscription?.cancel();
    await _goalsSubscription?.cancel();
    await _tasksSubscription?.cancel();
    await _projectsSubscription?.cancel();
    await Future.wait([
      _spheresSubject.close(),
      _goalsSubject.close(),
      _tasksSubject.close(),
      _projectsSubject.close(),
    ]);
  }
}
