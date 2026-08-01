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
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:rxdart/rxdart.dart';

class LifeGraphViewModel {
  LifeGraphViewModel({
    required this.spheresRepository,
    required this.goalsRepository,
    required this.projectsRepository,
    required this.tasksRepository,
    required this.positionsRepository,
    required this.graphBuilder,
  });

  final SpheresRepository spheresRepository;
  final GoalsRepository goalsRepository;
  final ProjectsRepository projectsRepository;
  final TasksRepository tasksRepository;
  final GraphPositionsRepository positionsRepository;
  final GraphBuilder graphBuilder;

  String? _currentSphereId;
  String? get currentSphereId => _currentSphereId;

  final BehaviorSubject<GraphData> _graphSubject = BehaviorSubject<GraphData>.seeded(GraphData.empty());
  Stream<GraphData> get graphStream => _graphSubject.stream;
  GraphData get graph => _graphSubject.value;

  final BehaviorSubject<List<Sphere>> _spheresSubject = BehaviorSubject<List<Sphere>>.seeded([]);
  Stream<List<Sphere>> get spheresStream => _spheresSubject.stream;
  List<Sphere> get spheres => _spheresSubject.value;

  final Map<String, Offset> _positions = {};
  StreamSubscription? _graphSubscription;
  StreamSubscription? _spheresSubscription;

  /// Инициализация: загружает список сфер и выбирает первую (или создаёт новую).
  Future<void> initialize() async {
    _spheresSubscription = spheresRepository.watchAllSpheres().listen(
      (spheres) {
        _spheresSubject.add(spheres);
        if (spheres.isNotEmpty && _currentSphereId == null) {
          _switchToSphere(spheres.first.id);
        }
      },
      onError: (e) => debugPrint('Spheres stream error: $e'),
    );
  }

  /// Переключает текущую сферу (граф).
  Future<void> switchSphere(String sphereId) async {
    await _switchToSphere(sphereId);
  }

  Future<void> _switchToSphere(String sphereId) async {
    _currentSphereId = sphereId;
    await _loadPositions(sphereId);
    _graphSubscription?.cancel();
    _graphSubscription = graphBuilder.watchGraph(sphereId).listen(
      (data) {
        // Накладываем сохранённые позиции
        final positionedNodes = data.nodes.map((node) {
          final pos = _positions[node.id];
          return pos != null ? node.copyWith(x: pos.dx, y: pos.dy) : node;
        }).toList();
        _graphSubject.add(GraphData(nodes: positionedNodes, edges: data.edges));
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
  Future<void> createSphere({required String name, String color = '#4A90D9'}) async {
    final sphere = Sphere.create(name: name, color: color);
    await spheresRepository.addSphere(sphere);
    await _switchToSphere(sphere.id);
  }

  /// Добавляет дочернюю ноду к указанному родителю.
  Future<void> addChild({
    required String parentId,
    required String title,
    String description = '',
    String? color,
    DateTime? dueDate,
  }) async {
    if (_currentSphereId == null) return;
    final parentNode = graph.nodes.firstWhere((n) => n.id == parentId, orElse: () => throw StateError('Parent not found'));
    final parentPos = _positions[parentId] ?? Offset.zero;

    switch (parentNode.type) {
      case GraphNodeType.sphere:
        // Сфера -> Цель
        final goal = Goal.create(
          name: title,
          sphereId: _currentSphereId!,
          description: description,
          color: color ?? '#E8A838',
        );
        await goalsRepository.addGoal(goal);
        // Авто-позиция: справа от сферы
        final newPos = Offset(parentPos.dx + 280, parentPos.dy);
        _positions[goal.id] = newPos;
        await positionsRepository.savePositions(_currentSphereId!, _positions);
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
        final newPos = Offset(parentPos.dx + 280, parentPos.dy);
        _positions[project.id] = newPos;
        await positionsRepository.savePositions(_currentSphereId!, _positions);
        break;

      case GraphNodeType.project:
        // Проект -> Задача
        final task = Task.blank().copyWith(
          title: title,
          description: description,
          projectId: Wrapped(parentId),
          status: TaskStatus.notStarted,
        );
        await tasksRepository.addTask(task);
        final newPos = Offset(parentPos.dx + 280, parentPos.dy);
        _positions[task.id] = newPos;
        await positionsRepository.savePositions(_currentSphereId!, _positions);
        break;

      case GraphNodeType.task:
        // Задача — лист, детей не добавляем
        return;
    }
  }

  /// Обновляет ноду (переименование, описание, цвет, статус задачи).
  Future<void> updateNode(GraphNode updated) async {
    final current = graph.nodes.firstWhere((n) => n.id == updated.id, orElse: () => throw StateError('Node not found'));

    switch (current.type) {
      case GraphNodeType.sphere:
        final sphere = Sphere(
          id: updated.id,
          name: updated.title,
          color: updated.color,
          createdAt: DateTime.now(), // TODO: keep original
          updatedAt: DateTime.now(),
        ).copyWith(name: updated.title, color: updated.color);
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
        ).copyWith(name: updated.title, description: updated.subtitle, color: updated.color);
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
        ).copyWith(name: updated.title, description: updated.subtitle, color: updated.color);
        await projectsRepository.updateProject(project);
        break;

      case GraphNodeType.task:
        if (updated.taskStatus != null) {
          // Нужно получить полную задачу из репозитория, чтобы обновить только статус
          // Для простоты: используем TasksRepository.getById
          final existing = await tasksRepository.getById(updated.id);
          if (existing != null) {
            await tasksRepository.updateTask(existing.copyWith(status: updated.taskStatus!));
          }
        }
        break;
    }
    // Перестроение графа произойдёт автоматически через стримы
  }

  /// Перемещает ноду (drag end) — сохраняет позицию.
  Future<void> moveNode(String id, double x, double y) async {
    if (_currentSphereId == null) return;
    _positions[id] = Offset(x, y);
    await positionsRepository.savePositions(_currentSphereId!, _positions);
    // Локально обновляем граф для мгновенного отклика
    _emitUpdatedGraph();
  }

  void _emitUpdatedGraph() {
    final data = graph;
    final positionedNodes = data.nodes.map((node) {
      final pos = _positions[node.id];
      return pos != null ? node.copyWith(x: pos.dx, y: pos.dy) : node;
    }).toList();
    _graphSubject.add(GraphData(nodes: positionedNodes, edges: data.edges));
  }

  /// Удаляет ноду с выбором: каскадно (поддерево) или только ноду (дети становятся осиротевшими).
  Future<void> deleteNode(String id, {required bool keepChildren}) async {
    if (_currentSphereId == null) return;

    if (!keepChildren) {
      // Каскадное удаление поддерева
      await _deleteSubtree(id);
    } else {
      // Удаляем только ноду, детей оставляем (становятся осиротевшими — скрываются)
      await _deleteNodeOnly(id);
    }
  }

  Future<void> _deleteSubtree(String id) async {
    final node = graph.nodes.firstWhere((n) => n.id == id);
    final descendantIds = _getDescendantIds(id);

    switch (node.type) {
      case GraphNodeType.sphere:
        await goalsRepository.deleteGoalsBySphere(id);
        // Проекты и задачи удалятся каскадно через deleteGoalsBySphere -> projects -> tasks
        await spheresRepository.deleteSphere(id);
        // Удаляем позиции графа
        await positionsRepository.deletePositions(id);
        // Сбрасываем текущую сферу
        _currentSphereId = null;
        _positions.clear();
        final spheres = await spheresRepository.getAllSpheres();
        if (spheres.isNotEmpty) {
          await _switchToSphere(spheres.first.id);
        } else {
          _graphSubject.add(GraphData.empty());
        }
        break;

      case GraphNodeType.goal:
        // Удаляем проекты этой цели -> удалятся задачи
        final goalProjects = graph.nodes.where((n) => n.type == GraphNodeType.project && n.parentId == id).map((p) => p.id).toList();
        for (final pid in goalProjects) {
          await projectsRepository.deleteProject(pid);
        }
        await goalsRepository.deleteGoal(id);
        _removePositions(descendantIds);
        break;

      case GraphNodeType.project:
        final projectTasks = graph.nodes.where((n) => n.type == GraphNodeType.task && n.parentId == id).map((t) => t.id).toList();
        for (final tid in projectTasks) {
          await tasksRepository.deleteTask(tid);
        }
        await projectsRepository.deleteProject(id);
        _removePositions(descendantIds);
        break;

      case GraphNodeType.task:
        await tasksRepository.deleteTask(id);
        _positions.remove(id);
        await positionsRepository.savePositions(_currentSphereId!, _positions);
        break;
    }
  }

  Future<void> _deleteNodeOnly(String id) async {
    final node = graph.nodes.firstWhere((n) => n.id == id);

    switch (node.type) {
      case GraphNodeType.sphere:
        // Сфера без детей — просто удаляем сферу, цели остаются (станут осиротевшими)
        await spheresRepository.deleteSphere(id);
        await positionsRepository.deletePositions(id);
        _currentSphereId = null;
        _positions.clear();
        final spheres = await spheresRepository.getAllSpheres();
        if (spheres.isNotEmpty) {
          await _switchToSphere(spheres.first.id);
        } else {
          _graphSubject.add(GraphData.empty());
        }
        break;

      case GraphNodeType.goal:
        await goalsRepository.deleteGoal(id);
        // Дети (проекты) останутся с goalId = deleted_id -> станут осиротевшими (скроются)
        _removePositions([id]);
        break;

      case GraphNodeType.project:
        await projectsRepository.deleteProject(id);
        // Дети (задачи) останутся с projectId = deleted_id -> осиротевшие (скроются)
        _removePositions([id]);
        break;

      case GraphNodeType.task:
        await tasksRepository.deleteTask(id);
        _positions.remove(id);
        await positionsRepository.savePositions(_currentSphereId!, _positions);
        break;
    }
  }

  List<String> _getDescendantIds(String id) {
    final result = <String>[];
    void collect(String parentId) {
      final children = graph.nodes.where((n) => n.parentId == parentId).toList();
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
    if (_currentSphereId != null) {
      positionsRepository.savePositions(_currentSphereId!, _positions);
    }
  }

  void dispose() {
    _graphSubscription?.cancel();
    _spheresSubscription?.cancel();
    _graphSubject.close();
    _spheresSubject.close();
  }
}