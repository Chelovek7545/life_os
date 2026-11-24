import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:goals_api/goals_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:notes_api/notes_api.dart';
import 'package:rxdart/rxdart.dart';
import 'graph_builder.dart';
import 'life_graph_view_model.dart';

class PulseScreenViewModel {
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
    this.ensureAllBoards = false,
  });
  final SpheresApi spheresRepository;
  final GoalsQueries goalsRepository;
  final ProjectsQueries projectsRepository;
  final TaskQueries tasksRepository;
  final GraphPositionsStore positionsRepository;
  final CanvasNotesStore notesRepository;
  final GraphBuilder graphBuilder;
  final GraphNodePresentationRegistry nodePresentations;
  final GraphEditorRegistry nodeEditors;
  final GraphCommandRegistry commands;
  final VaultNotesApi? obsidianRepository;
  final bool ensureAllBoards;
  final _ensuredBoards = <String>{};
  String? _ensuredRoot;
  final _graphs = <LifeGraphViewModel>{};
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _spheres = BehaviorSubject<List<Sphere>>.seeded(const []);
  final _goals = BehaviorSubject<List<Goal>>.seeded(const []);
  final _projects = BehaviorSubject<List<Project>>.seeded(const []);
  final _tasks = BehaviorSubject<List<Task>>.seeded(const []);
  Stream<List<Sphere>> get spheresStream => _spheres.stream;
  List<Sphere> get spheres => _spheres.value;
  Stream<List<Goal>> get goalsStream => _goals.stream;
  List<Goal> get goals => _goals.value;
  Stream<List<Project>> get projectsStream => _projects.stream;
  List<Project> get projects => _projects.value;
  Stream<List<Task>> get tasksStream => _tasks.stream;
  List<Task> get tasks => _tasks.value;
  bool _initialized = false;
  bool get initialized => _initialized;
  bool _started = false;
  bool _accepting = true;
  bool _disposed = false;
  Future<void> _operations = Future.value();
  Future<void>? _closing;

  void _listen<T>(
    Stream<List<T>> source,
    BehaviorSubject<List<T>> target, {
    void Function(List<T>)? onItems,
  }) {
    _subscriptions.add(
      source.listen((items) {
        if (_disposed) return;
        target.add(List.unmodifiable(items));
        if (identical(target, _spheres)) _initialized = true;
        onItems?.call(items);
      }, onError: (Object error) => debugPrint('Pulse source error: $error')),
    );
  }

  Future<void> initialize() async {
    if (!_accepting) throw StateError('Pulse module is closed.');
    if (_started) return;
    _started = true;
    if (ensureAllBoards) {
      await _ensureBoards(await spheresRepository.getAllSpheres());
    }
    _listen(
      spheresRepository.watchAllSpheres(),
      _spheres,
      onItems: (items) {
        if (ensureAllBoards && _accepting) {
          unawaited(
            _enqueue(() => _ensureBoards(items)).catchError(
              (Object error) =>
                  debugPrint('Canvas initialization failed: $error'),
            ),
          );
        }
      },
    );
    _listen(goalsRepository.watchAllGoals(), _goals);
    _listen(tasksRepository.watchTasks(), _tasks);
    _listen(projectsRepository.watchAllProjects(), _projects);
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (!_accepting) return Future.error(StateError('Pulse module is closed.'));
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> createSphere({required String name, String color = '#FFB59C'}) =>
      _enqueue(() async {
        final sphere = Sphere.create(name: name, color: color);
        await spheresRepository.addSphere(sphere);
        if (ensureAllBoards) await _ensureBoards([sphere]);
      });

  LifeGraphViewModel _newGraph() {
    late final LifeGraphViewModel model;
    model = LifeGraphViewModel(
      onDisposed: () => _graphs.remove(model),
      spheresRepository: spheresRepository,
      positionsRepository: positionsRepository,
      notesRepository: notesRepository,
      graphBuilder: graphBuilder,
      nodePresentations: nodePresentations,
      nodeEditors: nodeEditors,
      commands: commands,
      obsidianRepository: obsidianRepository,
    );
    return model;
  }

  Future<void> ensureCanvasBoards() => _enqueue(() async {
    if (ensureAllBoards) {
      await _ensureBoards(await spheresRepository.getAllSpheres());
    }
  });

  Future<void> _ensureBoards(Iterable<Sphere> spheres) async {
    final vault = obsidianRepository;
    if (vault is! VaultCanvasBoardsApi ||
        vault == null ||
        vault.state.vaultPath.isEmpty ||
        vault.state.error != null) {
      return;
    }
    final root = vault.state.vaultPath;
    if (_ensuredRoot != root) {
      _ensuredRoot = root;
      _ensuredBoards.clear();
    }
    for (final sphere in spheres) {
      if (!_accepting || vault.state.vaultPath != root) return;
      if (_ensuredBoards.contains(sphere.id)) continue;
      final model = _newGraph();
      try {
        await model.createMissingCanvasBoard(sphere.id);
        _ensuredBoards.add(sphere.id);
      } finally {
        await model.dispose();
      }
    }
  }

  Future<LifeGraphViewModel> openGraph(String sphereId) => _enqueue(() async {
    final model = _newGraph();
    _graphs.add(model);
    try {
      await model.switchSphere(sphereId);
      return model;
    } catch (error, stack) {
      try {
        await model.dispose();
      } catch (_) {}
      Error.throwWithStackTrace(error, stack);
    }
  });

  Future<void> closeGraphs() =>
      Future.wait([for (final graph in _graphs.toList()) graph.dispose()]);

  Future<void> flushGraphs() => _enqueue(() async {
    await Future.wait([for (final graph in _graphs.toList()) graph.flush()]);
  });

  Future<void> refreshSyncedCanvas(Set<String> sphereIds) => _enqueue(() async {
    await Future.wait([
      for (final graph in _graphs.toList())
        graph.refreshSyncedCanvas(sphereIds),
    ]);
  });
  Future<void> dispose() => _closing ??= _dispose();
  Future<void> _dispose() async {
    _accepting = false;
    for (final graph in _graphs) {
      graph.stopAccepting();
    }
    await _operations;
    (Object, StackTrace)? failure;
    Future<void> release(FutureOr<void> Function() action) async {
      try {
        await action();
      } catch (error, stack) {
        failure ??= (error, stack);
      }
    }

    await release(closeGraphs);
    _disposed = true;
    for (final sub in _subscriptions) {
      await release(sub.cancel);
    }
    await release(
      () => Future.wait([
        _spheres.close(),
        _goals.close(),
        _projects.close(),
        _tasks.close(),
      ]),
    );
    if (failure case final error?) {
      Error.throwWithStackTrace(error.$1, error.$2);
    }
  }
}
