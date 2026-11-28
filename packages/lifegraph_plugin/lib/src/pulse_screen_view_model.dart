import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:goals_api/goals_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:notes_api/notes_api.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import 'graph_builder.dart';
import 'life_graph_view_model.dart';
import 'canvas_catalog.dart';
import '../canvas_document.dart';

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
    this.canvasStore,
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
  final CanvasCatalogStore? canvasStore;
  final _canvases = BehaviorSubject<List<CanvasSummary>>.seeded(const []);
  Stream<List<CanvasSummary>> get canvasesStream => _canvases.stream;
  List<CanvasSummary> get canvases => _canvases.valueOrNull ?? const [];
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

  void _listen<T>(Stream<List<T>> source, BehaviorSubject<List<T>> target) {
    _subscriptions.add(
      source.listen((items) {
        if (_disposed) return;
        target.add(List.unmodifiable(items));
        if (identical(target, _spheres)) _initialized = true;
      }, onError: (Object error) => debugPrint('Pulse source error: $error')),
    );
  }

  Future<void> initialize() async {
    if (!_accepting) throw StateError('Pulse module is closed.');
    if (_started) return;
    _started = true;
    _listen(spheresRepository.watchAllSpheres(), _spheres);
    _listen(goalsRepository.watchAllGoals(), _goals);
    _listen(tasksRepository.watchTasks(), _tasks);
    _listen(projectsRepository.watchAllProjects(), _projects);
    if (canvasStore != null) {
      await _initializeCanvases().catchError(_reportCanvasCatalogError);
      if (obsidianRepository case final storage?) {
        _subscriptions.add(
          storage
              .watch()
              .map((state) => state.vaultPath)
              .distinct()
              .skip(1)
              .listen((_) {
                if (_accepting) {
                  unawaited(retryCanvasCatalog());
                }
              }),
        );
      }
    }
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

  Future<void> _initializeCanvases() async {
    final store = canvasStore!;
    final known = (await store.listCanvasIds()).toSet();
    for (final sphere in await spheresRepository.getAllSpheres()) {
      if (known.contains(sphere.id)) continue;
      if ((await positionsRepository.loadPositions(sphere.id))?.isNotEmpty !=
              true &&
          (await positionsRepository.loadStandalonePositions(
            sphere.id,
          )).isEmpty &&
          (await notesRepository.loadNotes(sphere.id))?.isNotEmpty != true &&
          (await positionsRepository.loadRemovedTaskIds(sphere.id)).isEmpty) {
        continue;
      }
      final model = _newGraph();
      try {
        await model.createMissingCanvasBoard(
          sphere.id,
          session: await store.openCatalogCanvas(sphere.id),
        );
      } finally {
        await model.dispose();
      }
    }
    await _loadCanvases();
  }

  Future<void> reloadCanvases() => _enqueue(_loadCanvases);

  Future<void> retryCanvasCatalog() =>
      _enqueue(_initializeCanvases).catchError(_reportCanvasCatalogError);

  void _reportCanvasCatalogError(Object error, StackTrace stack) {
    if (!_disposed) _canvases.addError(error, stack);
  }

  Future<void> _loadCanvases() async {
    final store = canvasStore;
    if (store == null) return;
    final sphereNames = {for (final sphere in spheres) sphere.id: sphere.name};
    final entries = <CanvasSummary>[];
    for (final id in await store.listCanvasIds()) {
      try {
        final session = await store.openCatalogCanvas(id);
        if (await session.read() case final raw?) {
          final canvas = CanvasSummary.read(
            id,
            raw,
            legacyTitle: sphereNames[id],
          );
          if (canvas != null) entries.add(canvas);
        }
      } on FormatException catch (error) {
        debugPrint('Invalid Canvas $id: $error');
      }
    }
    _canvases.add(List.unmodifiable(entries));
  }

  Future<List<GraphNodeData>> canvasSources() =>
      _enqueue(() => graphBuilder.watchCanvasEntities('catalog').first);

  Future<CanvasSummary> createCanvas({
    required String title,
    String? sourceId,
    Set<String> selectedIds = const {},
  }) => _enqueue(() async {
    final store = canvasStore ?? (throw StateError('Канвасы недоступны.'));
    final name = title.trim();
    if (name.isEmpty) throw ArgumentError('Укажите название канваса.');
    final id = 'board-${const Uuid().v4()}';
    GraphNodeData? source;
    final entities = <CanvasEntity>[];
    if (sourceId != null) {
      final available = await graphBuilder.watchCanvasEntities(id).first;
      final structure = CanvasStructure(available, sourceId);
      source = structure.root;
      if (source == null) throw StateError('Источник больше недоступен.');
      final nodes = structure.selected(selectedIds);
      if (nodes.isEmpty) throw StateError('Выберите карточки для добавления.');
      final depths = <String, int>{};
      final nextY = <int, double>{};
      final widths = <int, double>{};
      for (final node in nodes) {
        final depth = depths[node.parentId];
        final column = depth == null ? 0 : depth + 1;
        depths[node.id] = column;
        final width = nodePresentations.sizeFor(node.kind).width;
        if (width > (widths[column] ?? 0)) widths[column] = width;
      }
      final columns = <double>[LifeGraphViewModel.worldCenter];
      for (var depth = 0; depth < widths.length - 1; depth++) {
        columns.add(columns.last + widths[depth]! + 68);
      }
      for (final node in nodes) {
        final column = depths[node.id]!;
        final size = nodePresentations.sizeFor(node.kind);
        final y = nextY[column] ?? LifeGraphViewModel.worldCenter;
        entities.add(
          CanvasEntity(
            node: node,
            position: GraphPoint(columns[column], y),
            width: size.width,
            height: size.height,
          ),
        );
        nextY[column] = y + size.height + 28;
      }
    }
    final session = await store.openCatalogCanvas(id);
    final document = createCanvasDocument(
      entities: entities,
      notes: const [],
      filePath: session.notePath,
      metadata: {
        'version': 1,
        'canvasId': id,
        'title': name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'sourceId': ?source?.id,
        'sourceKind': ?source?.kind,
      },
    );
    final raw = const JsonEncoder.withIndent('  ').convert(document);
    await session.write(raw, expected: null);
    final canvas = CanvasSummary.read(id, raw)!;
    _canvases.add(List.unmodifiable([canvas, ...canvases]));
    return canvas;
  });

  Future<LifeGraphViewModel> openCanvas(CanvasSummary canvas) =>
      _enqueue(() async {
        final store = canvasStore ?? (throw StateError('Канвасы недоступны.'));
        if (_graphs.any((graph) => graph.currentCanvasId == canvas.id)) {
          throw StateError('Этот канвас уже открыт.');
        }
        final model = _newGraph();
        _graphs.add(model);
        try {
          await model.openCanvas(
            canvas,
            await store.openCatalogCanvas(canvas.id),
          );
          return model;
        } catch (error, stack) {
          try {
            await model.dispose();
          } catch (_) {}
          Error.throwWithStackTrace(error, stack);
        }
      });

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
    await _loadCanvases();
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
        _canvases.close(),
      ]),
    );
    if (failure case final error?) {
      Error.throwWithStackTrace(error.$1, error.$2);
    }
  }
}
