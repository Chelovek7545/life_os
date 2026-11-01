import 'package:uuid/uuid.dart';
import 'canvas_note_mapper.dart';
import 'package:life_os/core/ui/hierarchy/build_note_hierarchy.dart';
import 'package:life_os/core/storage/debounced_writer.dart';
import '../domain/graph_deletion.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_os/core/utils/wrapped.dart';
import '../domain/canvas_note.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/projects/domain/projects_api.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:tasks_api/tasks_api.dart' show TasksApi;
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/domain/graph_builder.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:notes_api/notes_api.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_sizes.dart';
import 'package:rxdart/rxdart.dart';

/// Состояние автосохранения позиций графа.
enum GraphSaveStatus { draft, saving, saved, failed }

class LifeGraphViewModel {
  LifeGraphViewModel({
    required this.spheresRepository,
    required this.goalsRepository,
    required this.projectsRepository,
    required this.tasksRepository,
    required this.positionsRepository,
    required this.notesRepository,
    required this.graphBuilder,
    required this.deletion,
    required this.obsidianRepository,
    this.onDisposed,
    //required this._currentSphereId,
  });

  /// Координата центра мира: корень (сфера) размещается здесь, если нет сохранённой позиции.
  static const double worldCenter = 2000.0;

  final SpheresRepository spheresRepository;
  final GoalsRepository goalsRepository;
  final ProjectsApi projectsRepository;
  final TasksApi tasksRepository;
  final GraphPositionsRepository positionsRepository;
  final CanvasNotesStore notesRepository;
  final GraphBuilder graphBuilder;
  final GraphDeletion deletion;
  final VaultNotesApi? obsidianRepository;
  final void Function()? onDisposed;

  List<HierarchyNode> getObsidianHierarchy() =>
      buildVaultHierarchy(obsidianRepository?.state.notes ?? const []);

  String? _currentSphereId;
  String? get currentSphereId => _currentSphereId;

  Stream<List<Task>> get tasksStream => tasksRepository.watchTasks();

  Stream<List<Sphere>> get spheresStream => spheresRepository.watchAllSpheres();

  /// Статус автосохранения позиций (для бейджа draft / saving… / saved).
  final ValueNotifier<GraphSaveStatus> saveStatus = ValueNotifier(
    GraphSaveStatus.draft,
  );

  /// Стрим view-нод для [GraphView]. Полный список на каждую эмиссию.
  final BehaviorSubject<List<gv.GraphNode>> _graphSubject =
      BehaviorSubject.seeded(const <gv.GraphNode>[]);
  Stream<List<gv.GraphNode>> get graphStream => _graphSubject.stream;
  List<gv.GraphNode> get graph => _graphSubject.value;

  /// Стрим заметок для [GraphView].
  final BehaviorSubject<List<gv.GraphNote>> _notesSubject =
      BehaviorSubject.seeded(const <gv.GraphNote>[]);
  Stream<List<gv.GraphNote>> get notesStream => _notesSubject.stream;
  List<gv.GraphNote> get notes => _notesSubject.value;

  StreamSubscription? _notesSubscription;
  StreamSubscription? _graphSubscription;

  /// Кэш доменных нод текущей сферы — нужен для CRUD (тип, цвет и т.п.).
  List<GraphNode> _domainNodes = const [];

  final Map<String, Offset> _positions = {};

  late final _positionWriter = DebouncedWriter<(String, Map<String, Offset>)>(
    (snapshot) => positionsRepository.savePositions(snapshot.$1, snapshot.$2),
    onError: _onSaveError,
    onIdle: _onSaveIdle,
  );
  late final _noteWriter =
      DebouncedWriter<(String, List<gv.GraphNote>, Map<String, String>)>(
        _persistNotes,
        onError: _onSaveError,
        onIdle: _onSaveIdle,
      );
  Future<void> _switchQueue = Future.value();
  Future<void>? _closing;
  void _onSaveIdle() {
    if (!_disposed && _positionWriter.isIdle && _noteWriter.isIdle) {
      saveStatus.value = GraphSaveStatus.saved;
    }
  }

  void _onSaveError(Object error, StackTrace stack) {
    if (!_disposed) saveStatus.value = GraphSaveStatus.failed;
    debugPrint('Graph save failed: ' + error.toString());
  }

  bool _disposed = false;
  int _notesLoadGeneration = 0;

  /// Переключает текущую сферу (граф).
  Future<void> switchSphere(String sphereId) {
    final operation = _switchQueue.then((_) => _switchToSphere(sphereId));
    _switchQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> _loadPositions(String sphereId) async {
    final loaded = await positionsRepository.loadPositions(sphereId);
    _positions.clear();
    if (loaded != null) {
      _positions.addAll(loaded);
    }
  }

  // /// Создаёт новую сферу и переключается на неё.
  // Future<void> createSphere({
  //   required String name,
  //   String color = '#FFB59C',
  // }) async {
  //   final sphere = Sphere.create(name: name, color: color);
  //   await spheresRepository.addSphere(sphere);
  //   await _switchToSphere(sphere.id);
  // }

  /// Добавляет дочернюю ноду к указанному родителю (по иерархии сферы).
  Future<void> addChild({
    required String parentId,
    required String title,
    required GraphNodeType childNodeType,
    String description = '',
    String? color,
    DateTime? dueDate,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    if (_currentSphereId == null) return;
    final parentView = graph.firstWhere(
      (n) => n.id == parentId,
      orElse: () => throw StateError('Parent not found'),
    );
    // Свежайшая позиция родителя: во время драга не эмитим, поэтому берём из _positions.
    final parentPos = _positions[parentId] ?? parentView.position;
    final parentType = _domainNode(parentId).type;

    final newPos = _clampPosition(
      Offset(parentPos.dx + 280, parentPos.dy),
      graphNodeSizeOf(_childTypeOf(parentType)),
    );

    switch (childNodeType) {
      case GraphNodeType.goal:
        final goal = Goal.create(
          name: title,
          sphereId: _currentSphereId!,
          description: description,
          color: color ?? '#FF5C00',
        );
        await goalsRepository.addGoal(goal);
        _positions[goal.id] = newPos;
        await _scheduleSavePositions();
        break;

      case GraphNodeType.project:
        print(parentId);
        final project = parentType == GraphNodeType.project
            ? Project.create(
                name: title,
                description: description,
                color: color ?? '#4A90D9',
                parentProjectId: parentId,
              )
            : Project.create(
                name: title,
                description: description,
                color: color ?? '#4A90D9',
                goalId: parentId,
              );
        await projectsRepository.addProject(project);
        _positions[project.id] = newPos;
        await _scheduleSavePositions();
        break;

      case GraphNodeType.task:
        final task = Task.blank().copyWith(
          title: title,
          description: description,
          projectId: Wrapped(parentId),
          status: TaskStatus.notStarted,
          dueDate: Wrapped(dueDate),
          startsAt: Wrapped(startsAt),
          endsAt: Wrapped(endsAt),
        );
        await tasksRepository.addTask(task);
        _positions[task.id] = newPos;
        await _scheduleSavePositions();
        break;

      case GraphNodeType.subTask:
        final task = Task.blank().copyWith(
          title: title,
          description: description,
          parentTaskId: Wrapped(parentId),
          status: TaskStatus.notStarted,
          dueDate: Wrapped(dueDate),
          startsAt: Wrapped(startsAt),
          endsAt: Wrapped(endsAt),
        );
        await tasksRepository.addTask(task);
        _positions[task.id] = newPos;
        await _scheduleSavePositions();
        break;
      case GraphNodeType.sphere:
        return;
    }
  }

  /// Привязывает уже существующую задачу (без проекта) к проекту в графе.
  /// Задача появляется нодой под проектом после пересборки через стримы.
  Future<void> attachExistingTaskToProject({
    required String projectId,
    required String taskId,
  }) async {
    if (_currentSphereId == null) return;
    final existing = await tasksRepository.getById(taskId);
    if (existing == null) return;
    if (existing.projectId != null) return;

    await tasksRepository.updateTask(
      existing.copyWith(projectId: Wrapped(projectId)),
    );

    final parentView = graph.firstWhere(
      (n) => n.id == projectId,
      orElse: () => throw StateError('Parent not found'),
    );
    final parentPos = _positions[projectId] ?? parentView.position;
    final newPos = _clampPosition(
      Offset(parentPos.dx + 280, parentPos.dy),
      graphNodeSizeOf(GraphNodeType.task),
    );
    _positions[taskId] = newPos;
    await _scheduleSavePositions();
  }

  /// Привязывает уже существующую задачу к другой задаче как подзадачу.
  Future<void> attachExistingTaskToTask({
    required String parentTaskId,
    required String taskId,
  }) async {
    if (_currentSphereId == null) return;
    final existing = await tasksRepository.getById(taskId);
    if (existing == null || existing.id == parentTaskId) return;

    await tasksRepository.updateTask(
      existing.copyWith(parentTaskId: Wrapped(parentTaskId)),
    );

    final parentView = graph.firstWhere(
      (n) => n.id == parentTaskId,
      orElse: () => throw StateError('Parent not found'),
    );
    final parentPos = _positions[parentTaskId] ?? parentView.position;
    final newPos = _clampPosition(
      Offset(parentPos.dx + 280, parentPos.dy),
      graphNodeSizeOf(GraphNodeType.subTask),
    );
    _positions[taskId] = newPos;
    await _scheduleSavePositions();
  }

  /// Обновляет ноду (переименование, описание, цвет, статус задачи).
  Future<void> updateNode(GraphNode updated) async {
    final current = _domainNode(updated.id);

    switch (current.type) {
      case GraphNodeType.sphere:
        final sphere = Sphere(
          id: updated.id,
          name: updated.title,
          color: updated.color,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await spheresRepository.updateSphere(sphere);
        break;

      case GraphNodeType.goal:
        final goal = Goal(
          id: updated.id,
          name: updated.title,
          description: updated.subtitle,
          color: updated.color,
          sphereId: current.parentId!,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await goalsRepository.updateGoal(goal);
        break;

      case GraphNodeType.project:
        final project = Project(
          id: updated.id,
          name: updated.title,
          description: updated.subtitle,
          color: updated.color,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          goalId: current.parentId,
        );
        await projectsRepository.updateProject(project);
        break;

      case GraphNodeType.task:
        if (updated.taskStatus != null) {
          final existing = await tasksRepository.getById(updated.id);
          if (existing != null) {
            await tasksRepository.updateTask(
              existing.copyWith(status: updated.taskStatus!),
            );
          }
        }
        break;
      case GraphNodeType.subTask:
        if (updated.taskStatus != null) {
          final existing = await tasksRepository.getById(updated.id);
          if (existing != null) {
            await tasksRepository.updateTask(
              existing.copyWith(status: updated.taskStatus!),
            );
          }
        }
        break;
    }
    // Перестроение графа произойдёт автоматически через стримы
  }

  /// Live-курсор драга: обновляет позицию в памяти без эмиссии и записи —
  /// визуально ноду двигает сам [GraphView], запись — в [commitMove].
  void moveNode(String id, double x, double y) {
    if (_currentSphereId == null) return;
    Size size = graphNodeSize;
    for (final n in graph) {
      if (n.id == id) {
        size = n.size;
        break;
      }
    }
    _positions[id] = _clampPosition(Offset(x, y), size);
  }

  /// Точка коммита драга: сохраняем позицию (с debounce).
  void commitMove(String id, double x, double y) {
    if (_currentSphereId == null) return;
    moveNode(id, x, y);
    _scheduleSavePositions();
  }

  /// Клампит позицию внутрь мирового канваса с учётом размера ноды.
  Offset _clampPosition(Offset pos, Size size) {
    return Offset(
      pos.dx.clamp(
        graphWorldMargin,
        graphWorldSize - size.width - graphWorldMargin,
      ),
      pos.dy.clamp(
        graphWorldMargin,
        graphWorldSize - size.height - graphWorldMargin,
      ),
    );
  }

  Future<void> deleteNode(String id, {required bool keepChildren}) async {
    if (_currentSphereId == null) return;
    final node = _domainNode(id);
    await flush();
    final removed = await deletion.delete(
      node.type,
      id,
      keepChildren: keepChildren,
    );
    if (node.type == GraphNodeType.sphere) {
      await _graphSubscription?.cancel();
      await positionsRepository.deletePositions(id);
      await notesRepository.deleteNotes(id);
      _currentSphereId = null;
      _positions.clear();
      _domainNodes = const [];
      _notesSubject.add(const []);
      _graphSubject.add(const []);
      final spheres = await spheresRepository.getAllSpheres();
      if (spheres.isNotEmpty) await switchSphere(spheres.first.id);
    } else {
      _removePositions(removed);
      await flush();
    }
  }

  void _removePositions(Iterable<String> ids) {
    for (final id in ids) {
      _positions.remove(id);
    }
    _scheduleSavePositions();
  }

  // ── Маппинг доменных нод -> view-ноды GraphView ────────────────────────────

  GraphNode _domainNode(String id) {
    for (final n in _domainNodes) {
      if (n.id == id) return n;
    }
    throw StateError('Node not found: $id');
  }

  /// Доменная нода по id — для кастомного nodeBuilder экрана.
  GraphNode? nodeById(String id) {
    for (final n in _domainNodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Тип дочерней ноды следующего уровня иерархии (сфера → цель → проект → задача).
  GraphNodeType _childTypeOf(GraphNodeType parent) {
    switch (parent) {
      case GraphNodeType.sphere:
        return GraphNodeType.goal;
      case GraphNodeType.goal:
        return GraphNodeType.project;
      case GraphNodeType.project:
        return GraphNodeType.task;
      case GraphNodeType.task:
        return GraphNodeType.subTask;
      case GraphNodeType.subTask:
        return GraphNodeType.task;
    }
  }

  List<gv.GraphNode> _toViewNodes(List<GraphNode> nodes) {
    if (nodes.isEmpty) return const [];
    final depth = _depthsOf(nodes);
    final positions = _layoutPositions(nodes);
    final out = <gv.GraphNode>[];
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      out.add(
        gv.GraphNode(
          id: n.id,
          label: n.title,
          index: i,
          depth: depth[n.id] ?? 0,
          parentId: n.parentId,
          size: graphNodeSizeOf(n.type),
          position: _clampPosition(
            positions[n.id] ?? Offset.zero,
            graphNodeSizeOf(n.type),
          ),
        ),
      );
    }
    return out;
  }

  Map<String, int> _depthsOf(List<GraphNode> nodes) {
    final depth = <String, int>{};
    for (final n in nodes) {
      if (n.parentId == null) depth[n.id] = 0;
    }
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in nodes) {
        final p = n.parentId;
        if (p != null && depth.containsKey(p) && !depth.containsKey(n.id)) {
          depth[n.id] = depth[p]! + 1;
          grew = true;
        }
      }
    }
    return depth;
  }

  /// Накладывает финальные позиции: сохранённую из [_positions], либо
  /// автопозицию через BFS от корня (дети вправо, веером по Y).
  Map<String, Offset> _layoutPositions(List<GraphNode> nodes) {
    final positions = <String, Offset>{};
    GraphNode? root;
    for (final n in nodes) {
      if (n.parentId == null) {
        root = n;
        break;
      }
    }
    if (root == null) return positions;

    final childrenOf = <String, List<GraphNode>>{};
    for (final n in nodes) {
      if (n.parentId != null) {
        childrenOf.putIfAbsent(n.parentId!, () => []).add(n);
      }
    }

    positions[root.id] =
        _positions[root.id] ?? const Offset(worldCenter, worldCenter);
    final queue = <GraphNode>[root];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      final kids = childrenOf[parent.id] ?? const <GraphNode>[];
      final n = kids.length;
      final parentPos = positions[parent.id]!;
      for (var i = 0; i < n; i++) {
        final kid = kids[i];
        final pos =
            _positions[kid.id] ??
            Offset(parentPos.dx + 280, parentPos.dy + (i - (n - 1) / 2) * 160);
        positions[kid.id] = pos;
        queue.add(kid);
      }
    }
    return positions;
  }

  // ── Персистентность позиций (с debounce) ──────────────────────────────────

  Future<void> _scheduleSavePositions() async {
    final sphereId = _currentSphereId;
    if (sphereId == null || _disposed) return;
    saveStatus.value = GraphSaveStatus.saving;
    _positionWriter.schedule((sphereId, Map.of(_positions)));
  }

  Future<void> flush() async {
    try {
      await Future.wait([_positionWriter.flush(), _noteWriter.flush()]);
      if (!_disposed) saveStatus.value = GraphSaveStatus.saved;
    } catch (error, stack) {
      _onSaveError(error, stack);
      rethrow;
    }
  }

  Future<void> dispose() => _closing ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _switchQueue;
    await _graphSubscription?.cancel();
    await _notesSubscription?.cancel();
    try {
      await Future.wait([_positionWriter.close(), _noteWriter.close()]);
    } finally {
      saveStatus.dispose();
      await _graphSubject.close();
      await _notesSubject.close();
      onDisposed?.call();
    }
  }

  // ── Notes (стикеры) ────────────────────────────────────────────────────────────

  /// Создаёт новую заметку в центре видимой области.
  Future<void> createNote() async {
    if (_currentSphereId == null) return;
    final center = Offset(worldCenter, worldCenter);
    final note = gv.GraphNote(
      id: 'note_' + const Uuid().v4(),
      index: notes.length,
      size: const Size(212, 150),
      text: '',
      position: _clampPosition(center, const Size(212, 150)),
    );
    _notesSubject.add([...notes, note]);
    await _scheduleSaveNotes();
  }

  /// Создаёт заметку на графе на основе текста (например, из Obsidian).
  Future<void> createNoteWithText({
    required String title,
    required String text,
    String? obsidianPath,
  }) async {
    final sphereId = _currentSphereId;
    if (sphereId == null || _disposed) return;
    if (obsidianPath != null && obsidianRepository == null)
      throw StateError('Плагин заметок отключён.');
    final center = Offset(worldCenter, worldCenter);
    final noteText = obsidianPath != null
        ? await obsidianRepository!.readContent(obsidianPath)
        : (title.isNotEmpty ? '$title\n\n$text' : text);
    if (_disposed || _currentSphereId != sphereId) return;
    final note = gv.GraphNote(
      id: 'note_' + const Uuid().v4(),
      index: notes.length,
      size: const Size(250, 180),
      text: noteText,
      position: _clampPosition(center, const Size(250, 180)),
      source: obsidianPath == null
          ? null
          : NoteReference(sourceId: 'obsidian', path: obsidianPath),
    );
    _notesSubject.add([...notes, note]);
    await _scheduleSaveNotes();
  }

  /// Обновляет текст заметки.
  Future<void> updateNoteText(String id, String text) async {
    final original = notes.where((note) => note.id == id).firstOrNull;
    if (original == null) return;
    if (original.source != null &&
        (original.source!.sourceId != 'obsidian' ||
            obsidianRepository == null)) {
      throw StateError(
        'Плагин заметок отключён: внешняя заметка доступна только для чтения.',
      );
    }
    String? path;
    final updatedNotes = notes.map((n) {
      if (n.id != id) return n;
      final cloned = n.clone();
      cloned.text = text;
      path = cloned.source?.path;
      return cloned;
    }).toList();
    _notesSubject.add(updatedNotes);
    if (path != null) _externalWrites[path!] = text;
    await _scheduleSaveNotes();
  }

  /// Live-курсор драга заметки: обновляет позицию в памяти без эмиссии.
  void moveNote(String id, double x, double y) {
    if (_currentSphereId == null) return;
    Size size = const Size(212, 150);
    for (final n in notes) {
      if (n.id == id) {
        size = n.size;
        break;
      }
    }
    final updatedNotes = notes.map((n) {
      if (n.id != id) return n;
      final cloned = n.clone();
      cloned.position = _clampPosition(Offset(x, y), size);
      return cloned;
    }).toList();
    _notesSubject.add(updatedNotes);
  }

  /// Точка коммита драга заметки: сохраняет позицию (с debounce).
  void commitNoteMove(String id, double x, double y) {
    if (_currentSphereId == null) return;
    moveNote(id, x, y);
    _scheduleSaveNotes();
  }

  /// Live-курсор ресайза заметки: обновляет size в памяти без персиста.
  /// Границы синхронизированы с clamp в DefaultNoteCard (120..800 / 80..800).
  void resizeNote(String id, double width, double height) {
    if (_currentSphereId == null) return;
    final clampedWidth = width.clamp(120.0, 800.0);
    final clampedHeight = height.clamp(80.0, 800.0);
    final updatedNotes = notes.map((n) {
      if (n.id != id) return n;
      final cloned = n.clone();
      cloned.size = Size(clampedWidth, clampedHeight);
      return cloned;
    }).toList();
    _notesSubject.add(updatedNotes);
  }

  /// Точка коммита ресайза заметки: сохраняет размер (с debounce).
  void commitNoteResize(String id, double width, double height) {
    if (_currentSphereId == null) return;
    resizeNote(id, width, height);
    _scheduleSaveNotes();
  }

  /// Удаляет заметку.
  Future<void> removeNote(String id) async {
    final updatedNotes = notes.where((n) => n.id != id).toList();
    _notesSubject.add(updatedNotes);
    await _scheduleSaveNotes();
  }

  /// Перечитывает заметки текущей сферы из хранилища; текст заметок,
  /// привязанных к Obsidian, подтягивается заново из файлов по путям.
  /// Вызывается при каждом заходе на экран графа.
  Future<void> refreshNotes() async {
    final sphereId = _currentSphereId;
    if (sphereId == null) return;
    await flush();
    if (!_disposed && _currentSphereId == sphereId) await _loadNotes(sphereId);
  }

  /// Загружает заметки для текущей сферы. При каждом заходе в граф текст
  /// заметок, привязанных к Obsidian, подтягивается заново из файла по пути.
  Future<void> _loadNotes(String sphereId) async {
    final generation = ++_notesLoadGeneration;
    final loaded =
        await notesRepository.loadNotes(sphereId) ?? const <CanvasNote>[];
    final refreshed = <gv.GraphNote>[];
    var cacheChanged = false;
    for (final note in loaded) {
      var text = note.text;
      if (note.document.source case final source?) {
        final vault = obsidianRepository;
        if (vault != null && source.sourceId == 'obsidian') {
          try {
            text = await vault.readContent(source.path);
            cacheChanged = cacheChanged || text != note.text;
          } catch (error) {
            debugPrint('Could not refresh external note: ' + error.toString());
          }
        }
      }
      refreshed.add(
        note.toView(
          text: text,
          readOnly:
              note.document.source != null &&
              (note.document.source!.sourceId != 'obsidian' ||
                  obsidianRepository == null),
        ),
      );
    }
    if (!_disposed && generation == _notesLoadGeneration) {
      _notesSubject.add(refreshed);
      if (cacheChanged) {
        saveStatus.value = GraphSaveStatus.saving;
        _noteWriter.schedule((
          sphereId,
          refreshed.map((note) => note.clone()).toList(),
          {},
        ));
      }
    }
  }

  final Map<String, String> _externalWrites = {};
  Future<void> _persistNotes(
    (String, List<gv.GraphNote>, Map<String, String>) snapshot,
  ) async {
    if (snapshot.$3.isNotEmpty) {
      final vault = obsidianRepository;
      if (vault == null) throw StateError('Плагин заметок отключён.');
      for (final entry in snapshot.$3.entries) {
        await vault.writeContent(entry.key, entry.value);
        if (_externalWrites[entry.key] == entry.value)
          _externalWrites.remove(entry.key);
      }
    }
    await notesRepository.saveNotes(
      snapshot.$1,
      snapshot.$2.map((note) => note.toRecord()).toList(),
    );
  }

  Future<void> _scheduleSaveNotes() async {
    final sphereId = _currentSphereId;
    if (sphereId == null || _disposed) return;
    saveStatus.value = GraphSaveStatus.saving;
    _noteWriter.schedule((
      sphereId,
      notes.map((note) => note.clone()).toList(),
      Map.of(_externalWrites),
    ));
  }

  /// Переключает текущую сферу (граф) и загружает её позиции и заметки.
  Future<void> _switchToSphere(String sphereId) async {
    if (_disposed) return;
    await flush();
    await _graphSubscription?.cancel();
    if (_disposed) return;
    _currentSphereId = null;
    _graphSubject.add(const []);
    _notesSubject.add(const []);
    await positionsRepository.saveLastSphereId(sphereId);
    await _loadPositions(sphereId);
    await _loadNotes(sphereId);
    if (_disposed) return;
    _currentSphereId = sphereId;
    saveStatus.value = _positionWriter.isIdle && _noteWriter.isIdle
        ? GraphSaveStatus.saved
        : GraphSaveStatus.saving;
    _domainNodes = const [];
    _graphSubject.add(const []); // сбрасываем устаревшие данные прошлой сферы
    _graphSubscription?.cancel();
    _graphSubscription = graphBuilder.watchGraph(sphereId).listen((nodes) {
      _domainNodes = nodes;
      _graphSubject.add(_toViewNodes(nodes));
    }, onError: (e) => debugPrint('Graph stream error: $e'));
  }
}
