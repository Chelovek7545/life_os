import 'package:graph_ui/graph_ui.dart';
import 'package:uuid/uuid.dart';
import 'canvas_note_mapper.dart';
import 'package:life_os/core/ui/hierarchy/build_note_hierarchy.dart';
import 'package:life_os/core/storage/debounced_writer.dart';
import 'package:graph_api/graph_api.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../domain/canvas_note.dart';
import 'package:spheres_api/spheres_api.dart';
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
    required this.positionsRepository,
    required this.notesRepository,
    required this.graphBuilder,
    required this.nodePresentations,
    required this.nodeEditors,
    required this.commands,
    required this.obsidianRepository,
    this.onDisposed,
  }) {
    nodePresentations.addListener(_onPresentationsChanged);
  }

  /// Координата центра мира: корень (сфера) размещается здесь, если нет сохранённой позиции.
  static const double worldCenter = 2000.0;

  final SpheresQueries spheresRepository;
  final GraphPositionsRepository positionsRepository;
  final CanvasNotesStore notesRepository;
  final GraphBuilder graphBuilder;
  final GraphNodePresentationRegistry nodePresentations;
  final GraphEditorRegistry nodeEditors;
  final GraphCommandRegistry commands;
  final VaultNotesApi? obsidianRepository;
  final void Function()? onDisposed;

  List<HierarchyNode> getObsidianHierarchy() =>
      buildVaultHierarchy(obsidianRepository?.state.notes ?? const []);

  String? _currentSphereId;
  String? get currentSphereId => _currentSphereId;

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
  Future<void> _operationQueue = Future.value();
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

  bool _accepting = true;
  bool _disposed = false;
  int _notesLoadGeneration = 0;
  int _scopeGeneration = 0;

  /// Переключает текущую сферу (граф).
  Future<void> switchSphere(String sphereId) =>
      _enqueue(() => _switchToSphere(sphereId));

  Future<T> _enqueue<T>(
    Future<T> Function() operation, {
    bool Function()? isAvailable,
  }) {
    if (!_accepting) return Future.error(StateError('Graph is closing.'));
    final result = _operationQueue.then((_) {
      if (isAvailable != null && !isAvailable()) {
        throw StateError('The graph form is no longer current.');
      }
      return operation();
    });
    _operationQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _loadPositions(String sphereId) async {
    final loaded = await positionsRepository.loadPositions(sphereId);
    _positions.clear();
    if (loaded != null) {
      _positions.addAll(loaded);
    }
  }

  Future<String> createChild(
    String parentId,
    GraphNodeDraft draft, {
    bool Function()? isAvailable,
  }) => _enqueue(() async {
    final scope = _scope();
    final parent = _domainNode(parentId).toData();
    final position = _childPosition(parentId, draft.kind);
    final id = await commands.create(
      GraphCreateRequest(scope: scope, parent: parent, draft: draft),
    );
    _positions[id] = position;
    await _scheduleSavePositions();
    return id;
  }, isAvailable: isAvailable);

  Future<void> attachNode({
    required String parentId,
    required String kind,
    required String id,
    bool Function()? isAvailable,
  }) => _enqueue(() async {
    if (_currentSphereId == null) return;
    final parent = _domainNode(parentId).toData();
    final position = _childPosition(parentId, kind);
    final attached = await commands.attach(
      GraphAttachRequest(scope: _scope(), parent: parent, kind: kind, id: id),
    );
    if (attached == null) return;
    _positions[attached] = position;
    await _scheduleSavePositions();
  }, isAvailable: isAvailable);

  Future<void> updateNode(GraphNode updated) =>
      updateGraphNode(updated.toData());

  Future<void> updateGraphNode(
    GraphNodeData updated, {
    bool Function()? isAvailable,
  }) => _enqueue(() async {
    final current = _domainNode(updated.id).toData();
    await commands.update(
      GraphUpdateRequest(scope: _scope(), current: current, updated: updated),
    );
  }, isAvailable: isAvailable);

  Offset _childPosition(String parentId, String kind) {
    final parentView = graph.firstWhere((node) => node.id == parentId);
    final parentPos = _positions[parentId] ?? parentView.position;
    return _clampPosition(
      Offset(parentPos.dx + 280, parentPos.dy),
      nodePresentations.sizeFor(kind),
    );
  }

  GraphScope _scope() {
    final rootId = _currentSphereId;
    if (rootId == null) throw StateError('No graph is open.');
    return GraphScope(rootId: rootId, rootKind: graphBuilder.rootKind);
  }

  GraphNodeActionContext actionsFor(String id) {
    final scope = _scope();
    final generation = _scopeGeneration;
    return GraphNodeActionContext(
      scope: scope,
      node: _domainNode(id).toData(),
      isAvailable: () =>
          !_disposed &&
          _scopeGeneration == generation &&
          _currentSphereId == scope.rootId,
      createChild: (draft, active) =>
          createChild(id, draft, isAvailable: active),
      updateNode: (updated, active) =>
          updateGraphNode(updated, isAvailable: active),
      deleteNode: (keepChildren, active) =>
          deleteNode(id, keepChildren: keepChildren, isAvailable: active),
      attachNode: (kind, entityId, active) => attachNode(
        parentId: id,
        kind: kind,
        id: entityId,
        isAvailable: active,
      ),
    );
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

  Future<void> deleteNode(
    String id, {
    required bool keepChildren,
    bool Function()? isAvailable,
  }) => _enqueue(() async {
    if (_currentSphereId == null) return;
    final scope = _scope();
    final node = _domainNode(id).toData();
    await flush();
    final removed = await commands.delete(
      GraphDeleteRequest(scope: scope, node: node, keepChildren: keepChildren),
    );
    if (id == scope.rootId) {
      await _graphSubscription?.cancel();
      await positionsRepository.deletePositions(id);
      await notesRepository.deleteNotes(id);
      _currentSphereId = null;
      _positions.clear();
      _domainNodes = const [];
      _notesSubject.add(const []);
      _graphSubject.add(const []);
      final spheres = await spheresRepository.getAllSpheres();
      if (spheres.isNotEmpty) await _switchToSphere(spheres.first.id);
    } else {
      _removePositions(removed);
      await flush();
    }
  }, isAvailable: isAvailable);

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

  void _onPresentationsChanged() {
    if (!_disposed) _graphSubject.add(_toViewNodes(_domainNodes));
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
          size: nodePresentations.sizeFor(n.kind),
          position: _clampPosition(
            positions[n.id] ?? Offset.zero,
            nodePresentations.sizeFor(n.kind),
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
    _accepting = false;
    (Object, StackTrace)? failure;
    Future<void> release(FutureOr<void> Function() action) async {
      try {
        await action();
      } catch (error, stack) {
        failure ??= (error, stack);
      }
    }

    // A source can fail during cancellation; pending writes still need flushing.
    await release(() => _operationQueue);
    _disposed = true;
    nodePresentations.removeListener(_onPresentationsChanged);
    await release(() async => _graphSubscription?.cancel());
    await release(() async => _notesSubscription?.cancel());
    await release(_positionWriter.close);
    await release(_noteWriter.close);
    await release(saveStatus.dispose);
    await release(_graphSubject.close);
    await release(_notesSubject.close);
    await release(() => onDisposed?.call());
    if (failure case final error?) {
      Error.throwWithStackTrace(error.$1, error.$2);
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
    _scopeGeneration++;
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
    _graphSubscription = graphBuilder.watchGraph(sphereId).listen((nodes) {
      _domainNodes = nodes.map(GraphNode.fromData).toList(growable: false);
      _graphSubject.add(_toViewNodes(_domainNodes));
    }, onError: (e) => debugPrint('Graph stream error: $e'));
  }
}
