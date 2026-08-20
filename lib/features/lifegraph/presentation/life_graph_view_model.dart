import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/domain/graph_builder.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';import 'package:life_os/core/ui/graph/graph_view.dart' as gv;
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_sizes.dart';
import 'package:rxdart/rxdart.dart';

/// Состояние автосохранения позиций графа.
enum GraphSaveStatus { draft, saving, saved }

class LifeGraphViewModel {
  LifeGraphViewModel({
    required this.spheresRepository,
    required this.goalsRepository,
    required this.projectsRepository,
    required this.tasksRepository,
    required this.positionsRepository,
    required this.graphBuilder,
  });

  /// Координата центра мира: корень (сфера) размещается здесь, если нет сохранённой позиции.
  static const double worldCenter = 2000.0;

  final SpheresRepository spheresRepository;
  final GoalsRepository goalsRepository;
  final ProjectsRepository projectsRepository;
  final TasksRepository tasksRepository;
  final GraphPositionsRepository positionsRepository;
  final GraphBuilder graphBuilder;

  String? _currentSphereId;
  String? get currentSphereId => _currentSphereId;

  bool _initialized = false;

  /// true после первой эмиссии списка сфер — экран может сменить сплэш.
  bool get initialized => _initialized;

  /// Статус автосохранения позиций (для бейджа draft / saving… / saved).
  final ValueNotifier<GraphSaveStatus> saveStatus =
      ValueNotifier(GraphSaveStatus.draft);

  /// Стрим view-нод для [GraphView]. Полный список на каждую эмиссию.
  final BehaviorSubject<List<gv.GraphNode>> _graphSubject =
      BehaviorSubject.seeded(const <gv.GraphNode>[]);
  Stream<List<gv.GraphNode>> get graphStream => _graphSubject.stream;
  List<gv.GraphNode> get graph => _graphSubject.value;

  final BehaviorSubject<List<Sphere>> _spheresSubject = BehaviorSubject<List<Sphere>>.seeded([]);
  Stream<List<Sphere>> get spheresStream => _spheresSubject.stream;
  List<Sphere> get spheres => _spheresSubject.value;

  final BehaviorSubject<List<Goal>> _goalsSubject = BehaviorSubject<List<Goal>>.seeded([]);
  Stream<List<Goal>> get goalsStream => _goalsSubject.stream;
  List<Goal> get goals => _goalsSubject.value;

  final BehaviorSubject<List<Project>> _projectsSubject = BehaviorSubject<List<Project>>.seeded([]);
  Stream<List<Project>> get projectsStream => _projectsSubject.stream;
  List<Project> get projects => _projectsSubject.value;

  final BehaviorSubject<List<Task>> _tasksSubject = BehaviorSubject<List<Task>>.seeded([]);
  Stream<List<Task>> get tasksStream => _tasksSubject.stream;
  List<Task> get tasks => _tasksSubject.value;

  StreamSubscription? _projectsSubscription;

  /// Кэш доменных нод текущей сферы — нужен для CRUD (тип, цвет и т.п.).
  List<GraphNode> _domainNodes = const [];

  final Map<String, Offset> _positions = {};
  StreamSubscription? _graphSubscription;
  StreamSubscription? _spheresSubscription;
  StreamSubscription? _goalsSubscription;
  StreamSubscription? _tasksSubscription;
  Timer? _savePositionsTimer;
  String? _lastSphereId;
  bool _disposed = false;

  /// Инициализация: загружает список сфер и восстанавливает последнюю
  /// просматриваемую сферу (либо выбирает первую).
  Future<void> initialize() async {
    _lastSphereId = await positionsRepository.loadLastSphereId();
    _spheresSubscription = spheresRepository.watchAllSpheres().listen(
      (spheres) {
        _spheresSubject.add(spheres);
        _initialized = true;
        if (spheres.isNotEmpty && _currentSphereId == null) {
          final last = _lastSphereId;
          final target = (last != null && spheres.any((s) => s.id == last))
              ? last
              : spheres.first.id;
          _switchToSphere(target);
        }
      },
      onError: (e) => debugPrint('Spheres stream error: $e'),
    );
    _goalsSubscription = goalsRepository.watchAllGoals().listen(
      (goals) {
        _goalsSubject.add(goals);
      },
      onError: (e) => debugPrint('Goals stream error: $e'),
    );
    _tasksSubscription = tasksRepository.watchTasks().listen(
      (tasks) {
        _tasksSubject.add(tasks);
      },
      onError: (e) => debugPrint('Tasks stream error: $e'),
    );
    _projectsSubscription = projectsRepository.watchAllProjects().listen(
      (projects) {
        _projectsSubject.add(projects);
      },
      onError: (e) => debugPrint('Projects stream error: $e'),
    );
  }

  /// Переключает текущую сферу (граф).
  Future<void> switchSphere(String sphereId) async {
    await _switchToSphere(sphereId);
  }

  Future<void> _switchToSphere(String sphereId) async {
    _currentSphereId = sphereId;
    _cancelPendingSave();
    await positionsRepository.saveLastSphereId(sphereId);
    await _loadPositions(sphereId);
    saveStatus.value = GraphSaveStatus.saved;
    _domainNodes = const [];
    _graphSubject.add(const []); // сбрасываем устаревшие данные прошлой сферы
    _graphSubscription?.cancel();
    _graphSubscription = graphBuilder.watchGraph(sphereId).listen(
      (nodes) {
        _domainNodes = nodes;
        _graphSubject.add(_toViewNodes(nodes));
      },
      onError: (e) => debugPrint('Graph stream error: $e'),
    );
  }

  Future<void> _loadPositions(String sphereId) async {
    final loaded = await positionsRepository.loadPositions(sphereId);
    _positions.clear();
    if (loaded != null) {
      _positions.addAll(loaded);
    }
  }

  /// Создаёт новую сферу и переключается на неё.
  Future<void> createSphere({required String name, String color = '#FFB59C'}) async {
    final sphere = Sphere.create(name: name, color: color);
    await spheresRepository.addSphere(sphere);
    await _switchToSphere(sphere.id);
  }

  /// Добавляет дочернюю ноду к указанному родителю (по иерархии сферы).
  Future<void> addChild({
    required String parentId,
    required String title,
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

    switch (parentType) {
      case GraphNodeType.sphere:
        // Сфера -> Цель
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

      case GraphNodeType.goal:
        // Цель -> Проект
        final project = Project.create(
          name: title,
          description: description,
          color: color ?? '#4A90D9',
          goalId: parentId,
        );
        await projectsRepository.addProject(project);
        _positions[project.id] = newPos;
        await _scheduleSavePositions();
        break;

      case GraphNodeType.project:
        // Проект -> Задача
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

      case GraphNodeType.task:
        // Задача — лист, детей не добавляем
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

    await tasksRepository.updateTask(existing.copyWith(projectId: Wrapped(projectId)));

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
            await tasksRepository.updateTask(existing.copyWith(status: updated.taskStatus!));
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
      pos.dx.clamp(graphWorldMargin, graphWorldSize - size.width - graphWorldMargin),
      pos.dy.clamp(graphWorldMargin, graphWorldSize - size.height - graphWorldMargin),
    );
  }

  /// Удаляет ноду с выбором: каскадно (поддерево) или только ноду (дети становятся осиротевшими).
  Future<void> deleteNode(String id, {required bool keepChildren}) async {
    if (_currentSphereId == null) return;

    if (!keepChildren) {
      await _deleteSubtree(id);
    } else {
      await _deleteNodeOnly(id);
    }
  }

  Future<void> _deleteSubtree(String id) async {
    final node = _domainNode(id);
    final descendantIds = _getDescendantIds(id);

    switch (node.type) {
      case GraphNodeType.sphere:
        await goalsRepository.deleteGoalsBySphere(id);
        await spheresRepository.deleteSphere(id);
        await positionsRepository.deletePositions(id);
        _currentSphereId = null;
        _cancelPendingSave();
        _positions.clear();
        _domainNodes = const [];
        final spheres = await spheresRepository.getAllSpheres();
        if (spheres.isNotEmpty) {
          await _switchToSphere(spheres.first.id);
        } else {
          _graphSubject.add(const []);
        }
        break;

      case GraphNodeType.goal:
        final goalProjects = _domainNodes
            .where((n) => n.type == GraphNodeType.project && n.parentId == id)
            .map((p) => p.id)
            .toList();
        for (final pid in goalProjects) {
          await projectsRepository.deleteProject(pid);
        }
        await goalsRepository.deleteGoal(id);
        _removePositions(descendantIds);
        break;

      case GraphNodeType.project:
        final projectTasks = _domainNodes
            .where((n) => n.type == GraphNodeType.task && n.parentId == id)
            .map((t) => t.id)
            .toList();
        for (final tid in projectTasks) {
          await tasksRepository.deleteTask(tid);
        }
        await projectsRepository.deleteProject(id);
        _removePositions(descendantIds);
        break;

      case GraphNodeType.task:
        await tasksRepository.deleteTask(id);
        _positions.remove(id);
        await _scheduleSavePositions();
        break;
    }
  }

  Future<void> _deleteNodeOnly(String id) async {
    final node = _domainNode(id);

    switch (node.type) {
      case GraphNodeType.sphere:
        await spheresRepository.deleteSphere(id);
        await positionsRepository.deletePositions(id);
        _currentSphereId = null;
        _cancelPendingSave();
        _positions.clear();
        _domainNodes = const [];
        final spheres = await spheresRepository.getAllSpheres();
        if (spheres.isNotEmpty) {
          await _switchToSphere(spheres.first.id);
        } else {
          _graphSubject.add(const []);
        }
        break;

      case GraphNodeType.goal:
        await goalsRepository.deleteGoal(id);
        _removePositions([id]);
        break;

      case GraphNodeType.project:
        await projectsRepository.deleteProject(id);
        _removePositions([id]);
        break;

      case GraphNodeType.task:
        await tasksRepository.deleteTask(id);
        _positions.remove(id);
        await _scheduleSavePositions();
        break;
    }
  }

  List<String> _getDescendantIds(String id) {
    final result = <String>[];
    void collect(String parentId) {
      final children = _domainNodes.where((n) => n.parentId == parentId).toList();
      for (final child in children) {
        result.add(child.id);
        collect(child.id);
      }
    }

    collect(id);
    return result;
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
      out.add(gv.GraphNode(
        id: n.id,
        label: n.title,
        index: i,
        depth: depth[n.id] ?? 0,
        parentId: n.parentId,
        size: graphNodeSizeOf(n.type),
        position: _clampPosition(positions[n.id] ?? Offset.zero, graphNodeSizeOf(n.type)),
      ));
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

    positions[root.id] = _positions[root.id] ?? const Offset(worldCenter, worldCenter);
    final queue = <GraphNode>[root];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      final kids = childrenOf[parent.id] ?? const <GraphNode>[];
      final n = kids.length;
      final parentPos = positions[parent.id]!;
      for (var i = 0; i < n; i++) {
        final kid = kids[i];
        final pos = _positions[kid.id] ??
            Offset(parentPos.dx + 280, parentPos.dy + (i - (n - 1) / 2) * 160);
        positions[kid.id] = pos;
        queue.add(kid);
      }
    }
    return positions;
  }

  // ── Персистентность позиций (с debounce) ──────────────────────────────────

  void _cancelPendingSave() {
    _savePositionsTimer?.cancel();
    _savePositionsTimer = null;
  }

  /// Откладывает сохранение позиций на ~400 мс, чтобы не писать в
  /// хранилище каждый кадр перетаскивания. Бейдж: saving… → saved.
  Future<void> _scheduleSavePositions() async {
    _cancelPendingSave();
    saveStatus.value = GraphSaveStatus.saving;
    _savePositionsTimer = Timer(const Duration(milliseconds: 400), () async {
      final sphereId = _currentSphereId;
      if (sphereId == null) return;
      await positionsRepository.savePositions(sphereId, Map.of(_positions));
      if (!_disposed) saveStatus.value = GraphSaveStatus.saved;
    });
  }

  void dispose() {
    _disposed = true;
    _cancelPendingSave();
    _graphSubscription?.cancel();
    _spheresSubscription?.cancel();
    _goalsSubscription?.cancel();
    _tasksSubscription?.cancel();
    _projectsSubscription?.cancel();
    saveStatus.dispose();
    _graphSubject.close();
    _spheresSubject.close();
    _goalsSubject.close();
    _tasksSubject.close();
    _projectsSubject.close();
  }
}
