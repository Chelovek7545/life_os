import 'package:graph_ui/graph_ui.dart';
import 'package:uuid/uuid.dart';
import 'canvas_note_mapper.dart';
import '../canvas_document.dart';
import '../canvas_board.dart';
import 'dart:convert';
import 'package:plugin_runtime/debounced_writer.dart';
import 'package:plugin_runtime/owned_streams.dart';
import 'package:graph_api/graph_api.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spheres_api/spheres_api.dart';
import 'graph_node.dart';
import 'graph_builder.dart';
import 'package:notes_api/notes_api.dart';
import 'package:graph_canvas/graph_canvas.dart' as gv;
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
    this.worldSize = 4200,
    this.worldMargin = 24,
  }) {
    nodePresentations.addListener(_onPresentationsChanged);
    final files = obsidianRepository;
    if (files is MarkdownNoteRenameApi) {
      _noteRenames = (files as MarkdownNoteRenameApi).watchNoteRenames().listen(
        (_) {
          if (_accepting) {
            unawaited(
              _enqueue(_applyRenamedNotePaths).catchError((
                Object error,
                StackTrace stack,
              ) {
                _onSaveError(error, stack);
              }),
            );
          }
        },
      );
    }
  }

  /// Координата центра мира: корень (сфера) размещается здесь, если нет сохранённой позиции.
  static const double worldCenter = 2000.0;
  final double worldSize;
  final double worldMargin;

  final SpheresQueries spheresRepository;
  final GraphPositionsStore positionsRepository;
  final CanvasNotesStore notesRepository;
  final GraphBuilder graphBuilder;
  final GraphNodePresentationRegistry nodePresentations;
  final GraphEditorRegistry nodeEditors;
  final GraphCommandRegistry commands;
  final VaultNotesApi? obsidianRepository;
  final void Function()? onDisposed;
  StreamSubscription<NotePathChange>? _noteRenames;

  _CanvasBoardState? _board;
  Offset _boardOrigin = Offset.zero;
  double _boardWorldSize = 4200;
  final Map<String, Size> _boardSizes = {};
  bool _discardBoardWrite = false;
  (Object, StackTrace)? _boardBuildFailure;
  bool get hasCanvasBoard => _board != null;
  double get canvasWorldSize => hasCanvasBoard ? _boardWorldSize : worldSize;
  String? get canvasBoardPath => _board?.session.path;
  late final _boardWriter = DebouncedWriter<_CanvasBoardWrite>(
    _persistBoard,
    onError: _onSaveError,
    onIdle: _onSaveIdle,
  );

  Map<String, Object?> _canvasSnapshot(String Function(String) filePath) =>
      createSphereCanvas(
        sphereId: _scope().rootId,
        entities: [
          for (final view in graph)
            CanvasEntity(
              node: _domainNode(view.id).toData(),
              position: GraphPoint(
                (_positions[view.id] ?? view.position).dx + _boardOrigin.dx,
                (_positions[view.id] ?? view.position).dy + _boardOrigin.dy,
              ),
              width: view.size.width,
              height: view.size.height,
            ),
        ],
        notes: _canvasNotes(),
        filePath: filePath,
      );

  List<CanvasNote> _canvasNotes() => [
    for (final note in notes)
      CanvasNote(
        document: note.toRecord().document,
        x: note.position.dx + _boardOrigin.dx,
        y: note.position.dy + _boardOrigin.dy,
        width: note.size.width,
        height: note.size.height,
        index: note.index,
      ),
  ];

  void _scheduleBoard() {
    final board = _board;
    final sphereId = _currentSphereId;
    if (board == null || sphereId == null || graph.isEmpty || _disposed) return;
    saveStatus.value = GraphSaveStatus.saving;
    _boardWriter.schedule(
      _CanvasBoardWrite(
        board,
        sphereId,
        _canvasSnapshot(board.session.notePath),
        _canvasNotes(),
        Map.of(_externalWrites),
      ),
    );
    _boardBuildFailure = null;
  }

  Future<void> _persistBoard(_CanvasBoardWrite snapshot) async {
    if (_discardBoardWrite) return;
    final document = snapshot.board.document.merge(snapshot.generated);
    final content = const JsonEncoder.withIndent('  ').convert(document);
    await snapshot.board.session.write(content, expected: snapshot.board.raw);
    snapshot.board.raw = content;
    snapshot.board.document = CanvasBoardDocument(content);
    final vault = obsidianRepository;
    for (final entry in snapshot.externalWrites.entries) {
      if (vault == null) throw StateError('Плагин заметок отключён.');
      await vault.writeContent(entry.key, entry.value);
      if (_externalWrites[entry.key] == entry.value) {
        _externalWrites.remove(entry.key);
      }
    }
    // Offline mirror and Resources catalog; the Canvas remains authoritative.
    await notesRepository.saveNotes(snapshot.sphereId, snapshot.notes);
  }

  Future<void> _openBoard(String sphereId) async {
    _board = null;
    _boardBuildFailure = null;
    _boardOrigin = Offset.zero;
    _boardWorldSize = worldSize;
    _boardSizes.clear();
    final vault = obsidianRepository;
    if (vault is! VaultCanvasBoardsApi ||
        (vault?.state.vaultPath.isEmpty ?? true)) {
      return;
    }
    final session = await (vault as VaultCanvasBoardsApi).openCanvasBoard(
      sphereId,
    );
    final raw = await session.read();
    final document = CanvasBoardDocument(raw ?? '{"nodes":[],"edges":[]}');
    document.validateScope(sphereId);
    _board = _CanvasBoardState(session, raw, document);
    if (raw != null) _readBoardLayout(document);
  }

  void _readBoardLayout(CanvasBoardDocument document) {
    double minX = 0, minY = 0, maxX = worldSize, maxY = worldSize;
    for (final node in document.nodes) {
      final x = (node['x'] as num).toDouble(),
          y = (node['y'] as num).toDouble();
      if (x - worldMargin < minX) minX = x - worldMargin;
      if (y - worldMargin < minY) minY = y - worldMargin;
      final right = x + (node['width'] as num).toDouble() + worldMargin;
      final bottom = y + (node['height'] as num).toDouble() + worldMargin;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }
    _boardOrigin = Offset(minX, minY);
    _boardWorldSize = (maxX - minX) > (maxY - minY) ? maxX - minX : maxY - minY;
    _positions.clear();
    _boardSizes.clear();
    for (final node in document.nodes) {
      final id = document.entityId(node);
      if (id == null) continue;
      _positions[id] =
          Offset((node['x'] as num).toDouble(), (node['y'] as num).toDouble()) -
          _boardOrigin;
      _boardSizes[id] = Size(
        (node['width'] as num).toDouble(),
        (node['height'] as num).toDouble(),
      );
    }
  }

  Future<void> reloadCanvasBoard() => _enqueue(() async {
    final sphereId = _currentSphereId;
    if (sphereId == null || _board == null) return;
    try {
      await _flush();
    } on CanvasBoardConflict {
      // A recovery document was written before the conflict was reported.
      _discardBoardWrite = true;
      try {
        await _boardWriter.flush();
      } finally {
        _discardBoardWrite = false;
      }
      _externalWrites.clear();
    }
    final previous = _board!;
    final raw = await previous.session.read();
    if (raw == null) throw StateError('Файл Canvas удалён.');
    final document = CanvasBoardDocument(raw);
    document.validateScope(sphereId);
    _board = _CanvasBoardState(previous.session, raw, document);
    _readBoardLayout(document);
    await _loadNotes(sphereId);
    _graphSubject.add(_toViewNodes(_domainNodes));
    saveStatus.value = GraphSaveStatus.saved;
  });

  List<VaultNote> get vaultNotes => obsidianRepository?.state.notes ?? const [];
  List<VaultNote> get markdownLibraryNotes {
    final files = obsidianRepository;
    return files is NotesLibrarySourcesApi
        ? (files as NotesLibrarySourcesApi).graphMarkdownState.notes
        : const [];
  }

  List<VaultNote> get obsidianLibraryNotes {
    final files = obsidianRepository;
    return files is NotesLibrarySourcesApi
        ? (files as NotesLibrarySourcesApi).obsidianState?.notes ?? const []
        : files?.state.notes ?? const [];
  }

  bool canRenameNote(gv.GraphNote note) =>
      obsidianRepository is MarkdownNoteRenameApi &&
      note.source?.sourceId == 'obsidian' &&
      !note.isReadOnly;

  Future<void> _applyRenamedNotePaths() async {
    final files = obsidianRepository;
    if (files is! MarkdownNoteRenameApi) return;
    final renamer = files as MarkdownNoteRenameApi;
    await _flush();
    var changed = false;
    final updated = [
      for (final note in notes)
        () {
          final source = note.source;
          if (source == null || source.sourceId != 'obsidian') return note;
          final path = renamer.resolveNotePath(source.path);
          if (path == source.path) return note;
          changed = true;
          return note.clone()
            ..source = NoteReference(sourceId: source.sourceId, path: path);
        }(),
    ];
    if (!changed) return;
    _notesSubject.add(updated);
    await _scheduleSaveNotes();
    await _flush();
  }

  Future<String> renameNote(String id, String title) => _enqueue(() async {
    final note = notes.where((note) => note.id == id).firstOrNull;
    if (note == null || !canRenameNote(note)) {
      throw StateError('Переименование этой заметки недоступно.');
    }
    await _flush();
    final path = await (obsidianRepository as MarkdownNoteRenameApi)
        .renameMarkdownNote(note.source!.path, title);
    await _applyRenamedNotePaths();
    return path;
  });
  bool get canCreateMarkdown =>
      obsidianRepository != null &&
      obsidianRepository!.state.vaultPath.isNotEmpty;
  bool get canSaveMarkdownCopy => obsidianRepository is MarkdownNoteSaveApi;
  bool get isClosing => !_accepting;
  Future<String> saveNoteMarkdownCopy(
    String id, {
    required String directory,
    required String title,
  }) => _enqueue(() async {
    final files = obsidianRepository;
    if (files is! MarkdownNoteSaveApi) {
      throw StateError('Сохранение копии недоступно.');
    }
    final note = notes.where((note) => note.id == id).firstOrNull;
    if (note == null) throw StateError('Заметка не найдена.');
    return (files as MarkdownNoteSaveApi).saveMarkdownCopy(
      directory,
      title,
      note.text,
    );
  });

  Future<String> createMarkdownNote({
    required String title,
    String text = '',
  }) => _enqueue(() async {
    if (_currentSphereId == null || !canCreateMarkdown) {
      throw StateError('Откройте граф и подключите vault.');
    }
    await _flush();
    final file = await obsidianRepository!.createNote(title, text);
    await _createNoteWithText(
      title: title,
      text: text,
      obsidianPath: file.absolutePath,
    );
    await _flush();
    return file.absolutePath;
  });

  Future<String> convertNoteToMarkdown(String id, {required String title}) =>
      _enqueue(() async {
        if (!canCreateMarkdown) throw StateError('Подключите vault.');
        await _flush();
        final original = notes.where((note) => note.id == id).firstOrNull;
        if (original == null || original.source != null) {
          throw StateError('Выберите обычный стикер.');
        }
        final file = await obsidianRepository!.createNote(title, original.text);
        final converted = original.clone()
          ..source = NoteReference(
            sourceId: 'obsidian',
            path: file.absolutePath,
          );
        _notesSubject.add([
          for (final note in notes)
            if (note.id == id) converted else note,
        ]);
        await _scheduleSaveNotes();
        await _flush();
        return file.absolutePath;
      });

  bool get canExportCanvas =>
      obsidianRepository is VaultCanvasApi &&
      (obsidianRepository?.state.vaultPath.isNotEmpty ?? false);

  Future<String> exportCanvas() => _enqueue(() async {
    final vault = obsidianRepository;
    if (vault is! VaultCanvasApi) {
      throw StateError('Экспорт Canvas недоступен: подключите Obsidian.');
    }
    final canvas = vault as VaultCanvasApi;
    final scope = _scope();
    if (graph.isEmpty) throw StateError('Граф ещё загружается.');
    await _flush();
    final generated = _canvasSnapshot(canvas.canvasNotePath);
    final document = _board?.document.merge(generated) ?? generated;
    return canvas.createCanvas(scope.rootId, document);
  });

  String? _currentSphereId;
  String? get currentSphereId => _currentSphereId;

  final _sourceStreams = OwnedStreams();
  Stream<List<Sphere>> get spheresStream => _accepting
      ? _sourceStreams.watch(spheresRepository.watchAllSpheres)
      : Stream.value(const []);

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
    (snapshot) => positionsRepository.savePositions(snapshot.$1, {
      for (final entry in snapshot.$2.entries)
        entry.key: GraphPoint(entry.value.dx, entry.value.dy),
    }),
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
    if (!_disposed &&
        _positionWriter.isIdle &&
        _noteWriter.isIdle &&
        _boardWriter.isIdle) {
      saveStatus.value = GraphSaveStatus.saved;
    }
  }

  void _onSaveError(Object error, StackTrace stack) {
    if (!_disposed) saveStatus.value = GraphSaveStatus.failed;
    debugPrint('Graph save failed: $error');
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
      _positions.addAll(
        loaded.map((id, point) => MapEntry(id, Offset(point.x, point.y))),
      );
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
    if (!_accepting) return;
    if (_currentSphereId == null) return;
    Size size = const Size(176, 68);
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
    if (!_accepting) return;
    if (_currentSphereId == null) return;
    moveNode(id, x, y);
    _scheduleSavePositions();
  }

  /// Клампит позицию внутрь мирового канваса с учётом размера ноды.
  Offset _clampPosition(Offset pos, Size size) {
    return Offset(
      pos.dx.clamp(worldMargin, canvasWorldSize - size.width - worldMargin),
      pos.dy.clamp(worldMargin, canvasWorldSize - size.height - worldMargin),
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
    await _flush();
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
      await _flush();
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
          size: _boardSizes[n.id] ?? nodePresentations.sizeFor(n.kind),
          position: _clampPosition(
            positions[n.id] ?? Offset.zero,
            _boardSizes[n.id] ?? nodePresentations.sizeFor(n.kind),
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
    if (_board != null) {
      _scheduleBoard();
      return;
    }
    saveStatus.value = GraphSaveStatus.saving;
    _positionWriter.schedule((sphereId, Map.of(_positions)));
  }

  Future<void> flush() => _enqueue(_flush);

  Future<void> _flush() async {
    try {
      await Future.wait([
        _positionWriter.flush(),
        _noteWriter.flush(),
        _boardWriter.flush(),
      ]);
      if (_boardBuildFailure case final failure?) {
        Error.throwWithStackTrace(failure.$1, failure.$2);
      }
      if (!_disposed) saveStatus.value = GraphSaveStatus.saved;
    } catch (error, stack) {
      _onSaveError(error, stack);
      rethrow;
    }
  }

  void stopAccepting() {
    _accepting = false;
    _sourceStreams.stopAccepting();
  }

  Future<void> dispose() => _closing ??= _dispose();

  Future<void> _dispose() async {
    stopAccepting();
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
    await release(() async => _noteRenames?.cancel());
    await release(_sourceStreams.close);
    await release(_positionWriter.close);
    await release(_noteWriter.close);
    await release(_boardWriter.close);
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
  Future<void> createNote() => _enqueue(() => _createNote());

  Future<void> _createNote() async {
    if (_currentSphereId == null) return;
    final center = Offset(worldCenter, worldCenter);
    final note = gv.GraphNote(
      id: 'note_${const Uuid().v4()}',
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
  }) => _enqueue(
    () => _createNoteWithText(
      title: title,
      text: text,
      obsidianPath: obsidianPath,
    ),
  );

  Future<void> _createNoteWithText({
    required String title,
    required String text,
    String? obsidianPath,
  }) async {
    final sphereId = _currentSphereId;
    if (sphereId == null || _disposed) return;
    if (obsidianPath != null && obsidianRepository == null) {
      throw StateError('Плагин заметок отключён.');
    }
    final center = Offset(worldCenter, worldCenter);
    final noteText = obsidianPath != null
        ? await obsidianRepository!.readContent(obsidianPath)
        : (title.isNotEmpty ? '$title\n\n$text' : text);
    if (_disposed || _currentSphereId != sphereId) return;
    final note = gv.GraphNote(
      id: 'note_${const Uuid().v4()}',
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
  Future<void> updateNoteText(String id, String text) =>
      _enqueue(() => _updateNoteText(id, text));

  Future<void> _updateNoteText(String id, String text) async {
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
    if (!_accepting) return;
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
    if (!_accepting) return;
    if (_currentSphereId == null) return;
    moveNote(id, x, y);
    _scheduleSaveNotes();
  }

  /// Live-курсор ресайза заметки: обновляет size в памяти без персиста.
  /// Границы синхронизированы с clamp в DefaultNoteCard (120..800 / 80..800).
  void resizeNote(String id, double width, double height) {
    if (!_accepting) return;
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
    if (!_accepting) return;
    if (_currentSphereId == null) return;
    resizeNote(id, width, height);
    _scheduleSaveNotes();
  }

  /// Удаляет заметку.
  Future<void> removeNote(String id) => _enqueue(() => _removeNote(id));

  Future<void> _removeNote(String id) async {
    final updatedNotes = notes.where((n) => n.id != id).toList();
    _notesSubject.add(updatedNotes);
    await _scheduleSaveNotes();
  }

  /// Перечитывает заметки текущей сферы из хранилища; текст заметок,
  /// привязанных к Obsidian, подтягивается заново из файлов по путям.
  /// Вызывается при каждом заходе на экран графа.
  Future<void> refreshNotes() => _enqueue(() => _refreshNotes());

  Future<void> _refreshNotes() async {
    final sphereId = _currentSphereId;
    if (sphereId == null) return;
    await _flush();
    if (!_disposed && _currentSphereId == sphereId) await _loadNotes(sphereId);
  }

  /// Загружает заметки для текущей сферы. При каждом заходе в граф текст
  /// заметок, привязанных к Obsidian, подтягивается заново из файла по пути.
  Future<void> _loadNotes(String sphereId) async {
    final generation = ++_notesLoadGeneration;
    final board = _board;
    final loaded = board != null && board.raw != null
        ? board.document.notes(board.session.resolveNote)
        : await notesRepository.loadNotes(sphereId) ?? const <CanvasNote>[];
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
            debugPrint('Could not refresh external note: $error');
          }
        }
      }
      final view = note.toView(
        text: text,
        readOnly:
            note.document.source != null &&
            (note.document.source!.sourceId != 'obsidian' ||
                obsidianRepository == null),
      );
      final files = obsidianRepository;
      if (view.source != null && files is MarkdownNoteRenameApi) {
        view.source = NoteReference(
          sourceId: view.source!.sourceId,
          path: (files as MarkdownNoteRenameApi).resolveNotePath(
            view.source!.path,
          ),
        );
      }
      if (board != null && board.raw != null) view.position -= _boardOrigin;
      refreshed.add(view);
    }
    if (!_disposed && generation == _notesLoadGeneration) {
      _notesSubject.add(refreshed);
      if (cacheChanged && _board == null) {
        saveStatus.value = GraphSaveStatus.saving;
        _noteWriter.schedule((
          sphereId,
          refreshed.map((note) => note.clone()).toList(),
          {},
        ));
      }
      if (cacheChanged && _board != null) _scheduleBoard();
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
        if (_externalWrites[entry.key] == entry.value) {
          _externalWrites.remove(entry.key);
        }
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
    if (_board != null) {
      _scheduleBoard();
      return;
    }
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
    await _flush();
    await _graphSubscription?.cancel();
    if (_disposed) return;
    _currentSphereId = null;
    _graphSubject.add(const []);
    _notesSubject.add(const []);
    await positionsRepository.saveLastSphereId(sphereId);
    await _loadPositions(sphereId);
    await _openBoard(sphereId);
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
      try {
        _scheduleBoard();
      } catch (error, stack) {
        _boardBuildFailure = (error, stack);
        _onSaveError(error, stack);
      }
    }, onError: (e) => debugPrint('Graph stream error: $e'));
  }
}

class _CanvasBoardState {
  _CanvasBoardState(this.session, this.raw, this.document);
  final CanvasBoardSession session;
  String? raw;
  CanvasBoardDocument document;
}

class _CanvasBoardWrite {
  _CanvasBoardWrite(
    this.board,
    this.sphereId,
    this.generated,
    this.notes,
    this.externalWrites,
  );
  final _CanvasBoardState board;
  final String sphereId;
  final Map<String, Object?> generated;
  final List<CanvasNote> notes;
  final Map<String, String> externalWrites;
}
