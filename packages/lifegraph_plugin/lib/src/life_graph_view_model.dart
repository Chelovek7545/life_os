import 'package:graph_ui/graph_ui.dart';
import 'package:uuid/uuid.dart';
import 'canvas_note_mapper.dart';
import '../canvas_document.dart';
import '../canvas_board.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:plugin_runtime/debounced_writer.dart';
import 'package:plugin_runtime/owned_streams.dart';
import 'package:graph_api/graph_api.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart' show TaskStatus;
import 'graph_node.dart';
import 'graph_builder.dart';
import 'canvas_catalog.dart';
import 'package:notes_api/notes_api.dart';
import 'package:graph_canvas/graph_canvas.dart' as gv;
import 'package:rxdart/rxdart.dart';

/// Состояние автосохранения позиций графа.
enum GraphSaveStatus { draft, saving, saved, failed }

typedef GraphDisconnection = ({
  GraphDetachRequest link,
  Future<void> Function() apply,
});

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
  CanvasSummary? _canvas;
  CanvasCards? _canvasCards;
  Map<String, GraphNodeData> _liveCanvasEntities = const {};
  String? get canvasTitle => _canvas?.title;
  bool get isIndependentCanvas => _canvas != null;
  List<GraphNodeData> get availableCanvasEntities => [
    for (final entry in _liveCanvasEntities.entries)
      if (!(_canvasCards?.snapshots.containsKey(entry.key) ?? false))
        entry.value,
  ];

  GraphNodeData? canvasEntityData(String id) {
    final snapshot = _canvasCards?.snapshots[id];
    return snapshot == null ? null : _liveCanvasEntities[id] ?? snapshot;
  }

  GraphNodeData? canvasProjectFor(String id) {
    final visited = <String>{};
    for (String? current = id; current != null && visited.add(current);) {
      final entity = _liveCanvasEntities[current];
      if (entity == null) break;
      if (entity.kind == 'project') return entity;
      current = entity.attributes['projectId'] as String? ?? entity.parentId;
    }
    return null;
  }

  Offset _boardOrigin = Offset.zero;
  double _boardWorldSize = 4200;
  final Map<String, Size> _boardSizes = {};
  bool _discardBoardWrite = false;
  (Object, StackTrace)? _boardBuildFailure;
  bool get hasCanvasBoard => _board != null;
  double _layoutWorldSize = 0;
  double get canvasWorldSize =>
      math.max(hasCanvasBoard ? _boardWorldSize : worldSize, _layoutWorldSize);
  String? get canvasBoardPath => _board?.session.path;
  late final _boardWriter = DebouncedWriter<_CanvasBoardWrite>(
    _persistBoard,
    onError: _onSaveError,
    onIdle: _onSaveIdle,
  );

  Map<String, Object?> _canvasSnapshot(String Function(String) filePath) {
    final metadata = switch (_canvas) {
      final canvas? => <String, Object?>{
        'version': 1,
        'canvasId': canvas.id,
        'title': canvas.title,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'sourceId': ?canvas.sourceId,
        'sourceKind': ?canvas.sourceKind,
      },
      null => <String, Object?>{
        'version': 1,
        'sphereId': _scope().rootId,
        if (_removedTaskIds.isNotEmpty)
          'removedTaskIds': _removedTaskIds.toList()..sort(),
      },
    };
    return createCanvasDocument(
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
            standalone: _standalonePositions.value.containsKey(view.id),
          ),
      ],
      notes: _canvasNotes(),
      filePath: filePath,
      metadata: metadata,
    );
  }

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
    final sphereId = _graphId;
    if (board == null ||
        sphereId == null ||
        (graph.isEmpty && !isIndependentCanvas) ||
        _disposed) {
      return;
    }
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

  Future<void> _openBoard(String sphereId, {bool onlyIfMissing = false}) async {
    _board = null;
    _boardBuildFailure = null;
    _boardOrigin = Offset.zero;
    _boardWorldSize = worldSize;
    _layoutWorldSize = 0;
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
    if (onlyIfMissing && raw != null) return;
    final document = CanvasBoardDocument(raw ?? '{"nodes":[],"edges":[]}');
    document.validateScope(sphereId);
    _board = _CanvasBoardState(session, raw, document);
    if (raw != null) _readBoardLayout(document);
  }

  void _readBoardLayout(CanvasBoardDocument document) {
    double minX = 0, minY = 0, maxX = worldSize, maxY = worldSize;
    final removed = document.removedTaskIds;
    final removalChanged =
        removed.length != _removedTaskIds.length ||
        !_removedTaskIds.containsAll(removed);
    _removedTaskIds
      ..clear()
      ..addAll(removed);
    final geometry = document.entityGeometry
      ..removeWhere((id, _) => removed.contains(id));
    for (final (x: x, y: y, width: width, height: height) in [
      ...geometry.values,
      for (final node in document.nodes)
        if (document.entityId(node) == null)
          (
            x: (node['x'] as num).toDouble(),
            y: (node['y'] as num).toDouble(),
            width: (node['width'] as num).toDouble(),
            height: (node['height'] as num).toDouble(),
          ),
    ]) {
      if (x - worldMargin < minX) minX = x - worldMargin;
      if (y - worldMargin < minY) minY = y - worldMargin;
      final right = x + width + worldMargin;
      final bottom = y + height + worldMargin;
      if (right > maxX) maxX = right;
      if (bottom > maxY) maxY = bottom;
    }
    _boardOrigin = Offset(minX, minY);
    _boardWorldSize = (maxX - minX) > (maxY - minY) ? maxX - minX : maxY - minY;
    _positions.clear();
    _restoreStandalonePositions();
    _boardSizes.clear();
    for (final entry in geometry.entries) {
      final value = entry.value;
      _positions[entry.key] = Offset(value.x, value.y) - _boardOrigin;
      _boardSizes[entry.key] = Size(value.width, value.height);
    }
    final standalone = _standalonePositions.value;
    final standaloneIds = document.standaloneEntityIds.difference(removed);
    if (removalChanged ||
        standalone.keys.any(removed.contains) ||
        standaloneIds.any((id) => !standalone.containsKey(id))) {
      _standalonePositions.add({
        for (final entry in standalone.entries)
          if (!removed.contains(entry.key)) entry.key: entry.value,
        for (final id in standaloneIds)
          if (_positions[id] case final position?)
            id: GraphPoint(position.dx, position.dy),
      });
    }
    _positions.removeWhere((id, _) => removed.contains(id));
  }

  Future<void> reloadCanvasBoard() => _enqueue(() async {
    final sphereId = _graphId;
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
    await _useCanvasBoard(sphereId, previous.session, raw);
  });

  Future<void> _useCanvasBoard(
    String sphereId,
    CanvasBoardSession session,
    String raw,
  ) async {
    final document = CanvasBoardDocument(raw);
    document.validateScope(sphereId);
    _board = _CanvasBoardState(session, raw, document);
    _readBoardLayout(document);
    if (isIndependentCanvas) {
      _canvas =
          CanvasSummary.read(sphereId, raw, legacyTitle: canvasTitle) ??
          _canvas;
      _canvasCards = CanvasCards.fromDocument(document);
      _removedTaskIds.clear();
    }
    await _loadNotes(sphereId);
    if (isIndependentCanvas) {
      _projectCanvas();
    } else {
      _graphSubject.add(_toViewNodes(_domainNodes));
    }
    saveStatus.value = GraphSaveStatus.saved;
  }

  Future<void> refreshSyncedCanvas(Set<String> sphereIds) => _enqueue(() async {
    final sphereId = _graphId;
    final board = _board;
    if (sphereId == null || !sphereIds.contains(sphereId) || board == null) {
      return;
    }
    await _flush();
    final raw = await board.session.read();
    if (raw != null && raw != board.raw) {
      await _useCanvasBoard(sphereId, board.session, raw);
    }
  });

  Future<void> createMissingCanvasBoard(
    String sphereId, {
    CanvasBoardSession? session,
  }) async {
    if (_graphId != null) {
      throw StateError('Для создания Canvas нужна отдельная модель графа.');
    }
    if (session == null) {
      await _openBoard(sphereId, onlyIfMissing: true);
    } else {
      if (await session.read() != null) return;
      _board = _CanvasBoardState(session, null, CanvasBoardDocument('{}'));
    }
    if (_board == null) return;
    await _loadPositions(sphereId);
    await _loadNotes(sphereId);
    final nodes = await graphBuilder
        .watchGraph(
          sphereId,
          standaloneIds: Stream.value({
            ..._standalonePositions.value.keys,
            ..._removedTaskIds,
          }),
        )
        .first;
    if (nodes.isEmpty) return;
    _graphId = sphereId;
    _domainNodes = nodes.map(GraphNode.fromData).toList(growable: false);
    _graphSubject.add(_toViewNodes(_domainNodes));
    _scheduleBoard();
    await _flush();
  }

  Future<void> openCanvas(CanvasSummary canvas, CanvasBoardSession session) =>
      _enqueue(() async {
        if (_graphId != null) throw StateError('Граф уже открыт.');
        final raw = await session.read();
        if (raw == null) throw StateError('Файл канваса отсутствует.');
        final live = await graphBuilder.watchCanvasEntities(canvas.id).first;
        _liveCanvasEntities = {for (final node in live) node.id: node};
        _canvas = canvas;
        _graphId = canvas.id;
        await _useCanvasBoard(canvas.id, session, raw);
        _graphSubscription = graphBuilder.watchCanvasEntities(canvas.id).listen(
          (nodes) {
            _liveCanvasEntities = {for (final node in nodes) node.id: node};
            _projectCanvas();
          },
          onError: (Object error) => debugPrint('Canvas source error: $error'),
        );
      });

  void _projectCanvas() {
    final nodes = _canvasCards!.project(_liveCanvasEntities);
    _domainNodes = nodes.map(GraphNode.fromData).toList(growable: false);
    _graphSubject.add(_toViewNodes(_domainNodes));
  }

  Future<void> addCanvasEntity(String id, Offset point) => _enqueue(() async {
    if (_canvasCards!.snapshots.containsKey(id)) return;
    final node = _liveCanvasEntities[id];
    if (node == null) throw StateError('Объект больше недоступен.');
    _placeCanvasEntity(node, point);
  });

  void _placeCanvasEntity(GraphNodeData node, Offset point) {
    _canvasCards!.snapshots[node.id] = node;
    _positions[node.id] = _clampPosition(
      point,
      nodePresentations.sizeFor(node.kind),
    );
    _projectCanvas();
    _scheduleBoard();
  }

  bool canEditCanvasEntity(String id) =>
      !isIndependentCanvas || _liveCanvasEntities.containsKey(id);

  bool canConnectCanvasCards(String from, String to) =>
      _canvasCards?.canConnect(from, to) ?? false;

  Future<void> connectCanvasCards(String from, String to) => _enqueue(() async {
    final cards = _canvasCards!;
    if (!cards.canConnect(from, to)) return;
    _rememberCanvasPositions();
    cards.parents[to] = from;
    _projectCanvas();
    _scheduleBoard();
  });

  void _rememberCanvasPositions() {
    for (final view in graph) {
      _positions.putIfAbsent(view.id, () => view.position);
    }
  }

  Future<void> removeCanvasSelection(
    Iterable<String> ids,
    Iterable<String> noteIds, {
    bool Function()? isAvailable,
  }) => _enqueue(() async {
    final cards = _canvasCards!;
    _rememberCanvasPositions();
    for (final id in ids) {
      cards.remove(id);
      _positions.remove(id);
      _boardSizes.remove(id);
    }
    _projectCanvas();
    for (final id in noteIds) {
      await _removeNote(id);
    }
    _scheduleBoard();
  }, isAvailable: isAvailable);

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

  Future<bool> markdownNoteTitleExists(String title) =>
      obsidianRepository!.noteTitleExists(title);

  Future<String> createMarkdownNote({
    required String title,
    String text = '',
  }) => _enqueue(() async {
    if (_graphId == null || !canCreateMarkdown) {
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

  Future<Map<String, Object?>> snapshotCanvas() => _enqueue(() async {
    if (!isIndependentCanvas) throw StateError('Откройте канвас.');
    await _flush();
    final board = _board!;
    return board.document.merge(_canvasSnapshot(board.session.notePath));
  });

  Future<String> exportCanvas() => _enqueue(() async {
    final vault = obsidianRepository;
    if (vault is! VaultCanvasApi) {
      throw StateError('Экспорт Canvas недоступен: подключите Obsidian.');
    }
    final canvas = vault as VaultCanvasApi;
    final scope = _scope();
    if (graph.isEmpty && !isIndependentCanvas) {
      throw StateError('Граф ещё загружается.');
    }
    await _flush();
    final generated = _canvasSnapshot(canvas.canvasNotePath);
    final document = _board?.document.merge(generated) ?? generated;
    return canvas.createCanvas(scope.rootId, document);
  });

  String? _graphId;
  String? get currentGraphId => _graphId;
  String? get currentCanvasId => _canvas?.id;
  String? get currentSphereId => isIndependentCanvas ? null : _graphId;

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
  final Set<String> _removedTaskIds = {};
  final _standalonePositions = BehaviorSubject<Map<String, GraphPoint>>.seeded(
    const {},
  );
  late final _standaloneWriter =
      DebouncedWriter<(String, Map<String, GraphPoint>)>(
        (snapshot) => positionsRepository.saveStandalonePositions(
          snapshot.$1,
          snapshot.$2,
        ),
        onError: _onSaveError,
        onIdle: _onSaveIdle,
      );

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
        _standaloneWriter.isIdle &&
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
  Future<void> switchSphere(String sphereId) => _enqueue(() {
    if (isIndependentCanvas) throw StateError('Открыт самостоятельный канвас.');
    return _switchToSphere(sphereId);
  });

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
    _removedTaskIds
      ..clear()
      ..addAll(await positionsRepository.loadRemovedTaskIds(sphereId));
    final standalone = await positionsRepository.loadStandalonePositions(
      sphereId,
    );
    _standalonePositions.add({
      for (final entry in standalone.entries)
        if (!_removedTaskIds.contains(entry.key)) entry.key: entry.value,
    });
    _positions.clear();
    _restoreStandalonePositions();
    if (loaded != null) {
      _positions.addAll(
        loaded.map((id, point) => MapEntry(id, Offset(point.x, point.y))),
      );
    }
    _positions.removeWhere((id, _) => _removedTaskIds.contains(id));
  }

  void _restoreStandalonePositions() {
    for (final entry in _standalonePositions.value.entries) {
      _positions[entry.key] = Offset(entry.value.x, entry.value.y);
    }
  }

  Future<String> Function(GraphNodeDraft, bool Function()) standaloneCreationAt(
    Offset point,
  ) {
    final scope = _scope();
    final generation = _scopeGeneration;
    return (draft, isAvailable) => _enqueue(
      () async {
        final position = _clampPosition(
          point,
          nodePresentations.sizeFor(draft.kind),
        );
        final id = await commands.createStandalone(draft);
        if (scope.isCanvas) {
          // The command may finish before the contributor emits the new row.
          final node =
              _liveCanvasEntities[id] ??
              GraphNodeData(
                id: id,
                kind: draft.kind,
                title: draft.title,
                subtitle: draft.subtitle,
                color: draft.color ?? '#E5E2E1',
                attributes: draft.attributes,
              );
          _placeCanvasEntity(node, position);
          return id;
        }
        _positions[id] = position;
        _saveStandalonePositions(scope.rootId, {
          ..._standalonePositions.value,
          id: GraphPoint(position.dx, position.dy),
        });
        return id;
      },
      isAvailable: () =>
          generation == _scopeGeneration &&
          scope.rootId == _graphId &&
          isAvailable(),
    );
  }

  void _saveStandalonePositions(
    String scopeId,
    Map<String, GraphPoint> positions,
  ) {
    _standalonePositions.add(positions);
    saveStatus.value = GraphSaveStatus.saving;
    _standaloneWriter.schedule((scopeId, positions));
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
    if (_graphId == null) return;
    final parent = _domainNode(parentId).toData();
    final position = _childPosition(parentId, kind);
    await _attachNode(parent, kind, id, position);
  }, isAvailable: isAvailable);

  bool Function() connectionGuard(String kind) {
    final generation = _scopeGeneration;
    final active = commands.guardFor(kind);
    return () => _accepting && generation == _scopeGeneration && active();
  }

  List<GraphDisconnection> disconnectionsFor(String id) {
    if (_graphId == null || nodeById(id) == null) return const [];
    final scope = _scope();
    final byId = {for (final node in _domainNodes) node.id: node};
    final options = <GraphDisconnection>[];
    for (final target in _domainNodes) {
      if (_removedTaskIds.contains(target.id) ||
          (!isIndependentCanvas && !commands.canDetach(target.kind))) {
        continue;
      }
      for (final (sourceId, type) in [
        (target.parentId, GraphLinkType.hierarchy),
        for (final predecessor in graphPredecessorIds(target.attributes))
          (predecessor, GraphLinkType.sequence),
      ]) {
        final source = byId[sourceId];
        if (source == null ||
            _removedTaskIds.contains(source.id) ||
            (source.id != id && target.id != id)) {
          continue;
        }
        final link = GraphDetachRequest(
          scope: scope,
          source: source.toData(),
          target: target.toData(),
          linkType: type,
        );
        final active = isIndependentCanvas
            ? () => _accepting
            : connectionGuard(target.kind);
        options.add((
          link: link,
          apply: () =>
              _enqueue(() => _disconnect(link, active), isAvailable: active),
        ));
      }
    }
    return options;
  }

  Future<void> _disconnect(
    GraphDetachRequest link,
    bool Function() isAvailable,
  ) async {
    final target = nodeById(link.target.id);
    final stillLinked =
        target != null &&
        (link.linkType == GraphLinkType.hierarchy
            ? target.parentId == link.source.id
            : graphPredecessorIds(target.attributes).contains(link.source.id));
    if (target?.kind != link.target.kind || !stillLinked) {
      throw StateError('Связь уже изменилась.');
    }
    if (_canvasCards case final cards?) {
      _rememberCanvasPositions();
      if (link.linkType == GraphLinkType.hierarchy) {
        cards.parents.remove(link.target.id);
      } else {
        cards.predecessors[link.target.id]?.remove(link.source.id);
      }
      _projectCanvas();
      _scheduleBoard();
      return;
    }
    if (link.linkType == GraphLinkType.sequence) {
      await commands.detach(link);
      return;
    }

    // Keep auto-positioned cards in place when the branch becomes a root.
    for (final view in graph) {
      _positions.putIfAbsent(view.id, () => view.position);
    }
    final scopeId = link.scope.rootId;
    final id = link.target.id;
    final standalone = _standalonePositions.value;
    final position = _positions[id]!;
    _saveStandalonePositions(scopeId, {
      ...standalone,
      id: GraphPoint(position.dx, position.dy),
    });
    try {
      await _standaloneWriter.flush();
      if (!isAvailable()) throw StateError('Действие больше недоступно.');
      await commands.detach(link);
    } catch (_) {
      _saveStandalonePositions(scopeId, standalone);
      rethrow;
    }
    if (_board == null) await _scheduleSavePositions();
  }

  Future<void> connectNodes(
    String parentId,
    String id, {
    String? attachmentKind,
    GraphLinkType linkType = GraphLinkType.hierarchy,
    bool Function()? isAvailable,
  }) {
    final generation = _scopeGeneration;
    return _enqueue(
      () async {
        final parent = nodeById(parentId);
        final child = nodeById(id);
        if (_graphId == null ||
            parentId == id ||
            parent == null ||
            child == null ||
            (attachmentKind == null && child.parentId != null) ||
            !commands.canAttach(attachmentKind ?? child.kind, parent.kind)) {
          return;
        }
        final position =
            _positions[id] ??
            graph.firstWhere((node) => node.id == id).position;
        await _attachNode(
          parent.toData(),
          attachmentKind ?? child.kind,
          id,
          position,
          linkType,
        );
      },
      isAvailable: () =>
          generation == _scopeGeneration && (isAvailable?.call() ?? true),
    );
  }

  Future<void> _attachNode(
    GraphNodeData parent,
    String kind,
    String id,
    Offset position, [
    GraphLinkType linkType = GraphLinkType.hierarchy,
  ]) async {
    final attached = await commands.attach(
      GraphAttachRequest(
        scope: _scope(),
        parent: parent,
        kind: kind,
        id: id,
        linkType: linkType,
      ),
    );
    if (attached == null) return;
    _positions[attached] = position;
    await _scheduleSavePositions();
  }

  Future<void> updateNode(GraphNode updated) =>
      updateGraphNode(updated.toData());

  Future<void> updateGraphNode(
    GraphNodeData updated, {
    bool Function()? isAvailable,
  }) => _enqueue(() async {
    final current = isIndependentCanvas
        ? _liveCanvasEntities[updated.id] ??
              (throw StateError('Объект больше недоступен.'))
        : _domainNode(updated.id).toData();
    await commands.update(
      GraphUpdateRequest(scope: _scope(), current: current, updated: updated),
    );
  }, isAvailable: isAvailable);

  Offset _childPosition(String parentId, String kind) {
    final parent = graph.firstWhere((node) => node.id == parentId);
    final size = nodePresentations.sizeFor(kind);
    final siblings = graph.where((node) => node.parentId == parentId);
    final y = siblings.fold<double>(
      parent.position.dy + (parent.size.height - size.height) / 2,
      (top, node) => math.max(top, node.position.dy + node.size.height + 28),
    );
    return Offset(
      parent.position.dx + parent.size.width + 68,
      math.max(y, worldMargin),
    );
  }

  GraphScope _scope() {
    final rootId = _graphId;
    if (rootId == null) throw StateError('No graph is open.');
    return isIndependentCanvas
        ? GraphScope.canvas(rootId)
        : GraphScope(rootId: rootId, rootKind: graphBuilder.rootKind);
  }

  GraphNodeActionContext actionsFor(String id) {
    final scope = _scope();
    final generation = _scopeGeneration;
    final snapshot = _liveCanvasEntities[id] ?? _domainNode(id).toData();
    bool canUpdateSnapshot() {
      if (!scope.isCanvas) return true;
      final live = _liveCanvasEntities[id];
      return live?.kind == snapshot.kind &&
          live?.attributes['storageRevision'] ==
              snapshot.attributes['storageRevision'];
    }

    return GraphNodeActionContext(
      scope: scope,
      node: snapshot,
      isAvailable: () =>
          !_disposed &&
          _scopeGeneration == generation &&
          _graphId == scope.rootId &&
          (_canvasCards?.snapshots.containsKey(id) ?? true) &&
          !_removedTaskIds.contains(id),
      createChild: (draft, active) =>
          createChild(id, draft, isAvailable: active),
      updateNode: (updated, active) => updateGraphNode(
        updated,
        isAvailable: () => active() && canUpdateSnapshot(),
      ),
      deleteNode: (keepChildren, active) => isIndependentCanvas
          ? removeCanvasSelection([id], const [], isAvailable: active)
          : deleteNode(id, keepChildren: keepChildren, isAvailable: active),
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
    if (_graphId == null) return;
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
    if (_graphId == null) return;
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
  }) => _enqueue(
    () => _deleteNodeNow(id, keepChildren: keepChildren),
    isAvailable: isAvailable,
  );

  /// Captures the originating board so a delayed menu cannot delete another scope.
  Future<void> Function(bool keepChildren) deletionForSelection({
    required Set<String> nodeIds,
    required Set<String> noteIds,
  }) {
    final scope = _scope();
    final generation = _scopeGeneration;
    final selectedNodes = Set<String>.of(nodeIds);
    final selectedNotes = Set<String>.of(noteIds);
    return (keepChildren) => _enqueue(
      () async {
        final nodes = [
          for (final n in _domainNodes)
            if (selectedNodes.contains(n.id) && !_removedTaskIds.contains(n.id))
              n,
        ];
        if (nodes.length != selectedNodes.length ||
            nodes.any((n) => !commands.canDelete(n.kind)) ||
            selectedNotes.any((id) => !notes.any((n) => n.id == id))) {
          throw StateError(
            'Часть выбранных объектов больше недоступна. Выделите их заново.',
          );
        }
        final depths = _depthsOf(_domainNodes);
        final targets =
            nodes.where((node) {
              if (keepChildren) return true;
              var parent = node.parentId;
              final seen = <String>{};
              while (parent != null && seen.add(parent)) {
                if (selectedNodes.contains(parent)) return false;
                parent = _domainNodes
                    .where((n) => n.id == parent)
                    .firstOrNull
                    ?.parentId;
              }
              return true;
            }).toList()..sort(
              (a, b) => (depths[b.id] ?? 0).compareTo(depths[a.id] ?? 0),
            );
        for (final node in targets.where((n) => n.id != scope.rootId)) {
          await _deleteNodeNow(node.id, keepChildren: keepChildren);
        }
        if (selectedNotes.isNotEmpty) {
          _notesSubject.add(
            notes.where((n) => !selectedNotes.contains(n.id)).toList(),
          );
          await _scheduleSaveNotes();
          await _flush();
        }
        if (targets.any((n) => n.id == scope.rootId)) {
          await _deleteNodeNow(scope.rootId, keepChildren: keepChildren);
        }
      },
      isAvailable: () =>
          !_disposed &&
          generation == _scopeGeneration &&
          scope.rootId == _graphId,
    );
  }

  Future<void> _deleteNodeNow(String id, {required bool keepChildren}) async {
    if (_graphId == null) return;
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
      _graphId = null;
      _positions.clear();
      _domainNodes = const [];
      _notesSubject.add(const []);
      _graphSubject.add(const []);
      final spheres = await spheresRepository.getAllSpheres();
      if (spheres.isNotEmpty) await _switchToSphere(spheres.first.id);
    } else {
      _removePositions(removed);
      final standalone = _standalonePositions.value;
      if (removed.any(standalone.containsKey)) {
        _saveStandalonePositions(
          scope.rootId,
          Map.of(standalone)..removeWhere((id, _) => removed.contains(id)),
        );
      }
      await _flush();
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
    if (_removedTaskIds.contains(id)) return null;
    for (final n in _domainNodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  List<GraphNode> get tasksRemovedFromBoard => [
    for (final node in _domainNodes)
      if (_removedTaskIds.contains(node.id)) node,
  ];

  bool canRemoveTaskFromBoard(String id) =>
      nodeById(id)?.attributes[GraphNodeData.removeFromBoardAttribute] == true;

  Iterable<String> sequencePredecessorsFor(String id) {
    final node = _domainNodes.where((node) => node.id == id).firstOrNull;
    return node == null ? const [] : graphPredecessorIds(node.attributes);
  }

  Future<void> Function() removeTaskFromBoard(String id) {
    final generation = _scopeGeneration;
    return () => _enqueue(() async {
      if (!canRemoveTaskFromBoard(id)) return;
      final scopeId = _scope().rootId;
      final ids = {..._removedTaskIds, id};
      if (_board == null) {
        await positionsRepository.saveRemovedTaskIds(scopeId, ids);
      }
      for (final node in graph) {
        if (node.id != id) _positions.putIfAbsent(node.id, () => node.position);
      }
      _removedTaskIds.add(id);
      _positions.remove(id);
      _boardSizes.remove(id);
      _saveStandalonePositions(
        scopeId,
        Map.of(_standalonePositions.value)..remove(id),
      );
      _graphSubject.add(_toViewNodes(_domainNodes));
      await _scheduleSavePositions();
    }, isAvailable: () => generation == _scopeGeneration);
  }

  Future<void> Function(String) placeRemovedTaskAt(Offset point) {
    final generation = _scopeGeneration;
    return (id) => _enqueue(() async {
      if (!_removedTaskIds.contains(id)) return;
      final task = tasksRemovedFromBoard
          .where((node) => node.id == id)
          .firstOrNull;
      if (task == null) throw StateError('Задача больше недоступна.');
      final scopeId = _scope().rootId;
      final position = _clampPosition(
        point,
        nodePresentations.sizeFor(task.kind),
      );
      final standalone = {
        ..._standalonePositions.value,
        id: GraphPoint(position.dx, position.dy),
      };
      final ids = Set<String>.of(_removedTaskIds)..remove(id);
      if (_board == null) {
        await _standaloneWriter.flush();
        await positionsRepository.saveStandalonePositions(scopeId, standalone);
        await positionsRepository.saveRemovedTaskIds(scopeId, ids);
      }
      _removedTaskIds.remove(id);
      _positions[id] = position;
      if (_board == null) {
        _standalonePositions.add(standalone);
      } else {
        _saveStandalonePositions(scopeId, standalone);
      }
      _graphSubject.add(_toViewNodes(_domainNodes));
      await _scheduleSavePositions();
    }, isAvailable: () => generation == _scopeGeneration);
  }

  void _onPresentationsChanged() {
    if (!_disposed) _graphSubject.add(_toViewNodes(_domainNodes));
  }

  final _taskProgress = <String, ({int total, int completed})>{};

  ({int total, int completed}) taskProgressFor(String id) =>
      _taskProgress[id] ?? (total: 0, completed: 0);

  void _countDescendantTasks(List<GraphNode> nodes) {
    _taskProgress.clear();
    // The projection is breadth-first, so children accumulate before parents.
    for (final node in nodes.reversed) {
      final parent = node.parentId;
      if (parent == null) continue;
      final nested = taskProgressFor(node.id);
      final parentProgress = taskProgressFor(parent);
      final isTask = node.taskStatus != null;
      _taskProgress[parent] = (
        total: parentProgress.total + nested.total + (isTask ? 1 : 0),
        completed:
            parentProgress.completed +
            nested.completed +
            (node.taskStatus == TaskStatus.done ? 1 : 0),
      );
    }
  }

  List<gv.GraphNode> _toViewNodes(List<GraphNode> nodes) {
    _countDescendantTasks(nodes);
    if (nodes.isEmpty) return const [];
    final depth = _depthsOf(nodes);
    final positions = _layoutPositions(nodes);
    _fitLayoutExtent(nodes, positions);
    final out = <gv.GraphNode>[];
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      if (_removedTaskIds.contains(n.id)) continue;
      out.add(
        gv.GraphNode(
          id: n.id,
          label: n.title,
          index: i,
          depth: depth[n.id] ?? 0,
          parentId: _removedTaskIds.contains(n.parentId) ? null : n.parentId,
          predecessorIds: graphPredecessorIds(
            n.attributes,
          ).where((id) => !_removedTaskIds.contains(id)),
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

  /// Places whole branches in separate bands, centered around their parent.
  Map<String, Offset> _layoutPositions(
    List<GraphNode> nodes, {
    bool keepSaved = true,
  }) {
    if (nodes.isEmpty) return {};
    const rowGap = 28.0;
    const columnGap = 68.0;
    final root = nodes.first;
    final children = <String, List<GraphNode>>{};
    final sizes = {
      for (final node in nodes)
        node.id: _boardSizes[node.id] ?? nodePresentations.sizeFor(node.kind),
    };
    final depths = _depthsOf(nodes);
    final widths = <int, double>{};
    for (final node in nodes) {
      final depth = depths[node.id] ?? 0;
      widths[depth] = math.max(widths[depth] ?? 0, sizes[node.id]!.width);
      if (node.parentId case final parent?) {
        (children[parent] ??= []).add(node);
      }
    }
    final bands = <String, double>{};
    double childBand(List<GraphNode> kids) => kids.isEmpty
        ? 0
        : kids.fold<double>(0, (height, child) => height + bands[child.id]!) +
              (kids.length - 1) * rowGap;
    for (final node in nodes.reversed) {
      bands[node.id] = math.max(
        sizes[node.id]!.height,
        childBand(children[node.id] ?? const []),
      );
    }
    final rootOffset =
        _positions[root.id] ?? const Offset(worldCenter, worldCenter);
    final topSafeRoot = Offset(
      rootOffset.dx,
      math.max(
        rootOffset.dy,
        worldMargin + (bands[root.id]! - sizes[root.id]!.height) / 2,
      ),
    );
    final positions = {
      root.id: keepSaved ? _positions[root.id] ?? topSafeRoot : topSafeRoot,
      for (final node in nodes.skip(1))
        if (node.parentId == null) node.id: _positions[node.id] ?? topSafeRoot,
    };
    for (final parent in nodes) {
      final kids = children[parent.id] ?? const [];
      if (kids.isEmpty) continue;
      final parentPosition = positions[parent.id]!;
      var top =
          parentPosition.dy +
          sizes[parent.id]!.height / 2 -
          childBand(kids) / 2;
      final x = parentPosition.dx + widths[depths[parent.id] ?? 0]! + columnGap;
      for (final child in kids) {
        final band = bands[child.id]!;
        positions[child.id] =
            (keepSaved ? _positions[child.id] : null) ??
            Offset(x, top + (band - sizes[child.id]!.height) / 2);
        top += band + rowGap;
      }
    }
    return positions;
  }

  void _fitLayoutExtent(List<GraphNode> nodes, Map<String, Offset> layout) {
    for (final node in nodes) {
      final size = _boardSizes[node.id] ?? nodePresentations.sizeFor(node.kind);
      final point = layout[node.id]!;
      _layoutWorldSize = math.max(
        _layoutWorldSize,
        math.max(point.dx + size.width, point.dy + size.height) + worldMargin,
      );
    }
  }

  Future<void> arrangeNodes() {
    final generation = _scopeGeneration;
    return _enqueue(() async {
      if (_domainNodes.isEmpty) return;
      final layout = _layoutPositions(_domainNodes, keepSaved: false);
      _fitLayoutExtent(_domainNodes, layout);
      for (final node in _domainNodes) {
        _positions[node.id] = layout[node.id]!;
      }
      _graphSubject.add(_toViewNodes(_domainNodes));
      await _scheduleSavePositions();
    }, isAvailable: () => generation == _scopeGeneration);
  }

  bool get hasCustomNodeSizes =>
      _boardSizes.isNotEmpty &&
      _domainNodes.any(
        (node) =>
            _boardSizes[node.id] != null &&
            _boardSizes[node.id] != nodePresentations.sizeFor(node.kind),
      );

  Future<void> resetNodeSizes() {
    final generation = _scopeGeneration;
    return _enqueue(() async {
      if (!hasCustomNodeSizes) return;
      // Keep the current layout, including nodes positioned automatically.
      for (final node in graph) {
        _positions.putIfAbsent(node.id, () => node.position);
      }
      _boardSizes.clear();
      _graphSubject.add(_toViewNodes(_domainNodes));
      _scheduleBoard();
    }, isAvailable: () => generation == _scopeGeneration);
  }

  // ── Персистентность позиций (с debounce) ──────────────────────────────────

  Future<void> _scheduleSavePositions() async {
    final sphereId = _graphId;
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
        _standaloneWriter.flush(),
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
    await release(_standaloneWriter.close);
    await release(_positionWriter.close);
    await release(_noteWriter.close);
    await release(_boardWriter.close);
    await release(saveStatus.dispose);
    await release(_graphSubject.close);
    await release(_standalonePositions.close);
    await release(_notesSubject.close);
    await release(() => onDisposed?.call());
    if (failure case final error?) {
      Error.throwWithStackTrace(error.$1, error.$2);
    }
  }

  // ── Notes (стикеры) ────────────────────────────────────────────────────────────

  /// Создаёт новую заметку в центре видимой области.
  Future<void> createNote({Offset? position}) =>
      _enqueue(() => _createNote(position));

  Future<void> _createNote(Offset? position) async {
    if (_graphId == null) return;
    final center = position ?? const Offset(worldCenter, worldCenter);
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
    Offset? position,
  }) => _enqueue(
    () => _createNoteWithText(
      title: title,
      text: text,
      obsidianPath: obsidianPath,
      position: position,
    ),
  );

  Future<void> _createNoteWithText({
    required String title,
    required String text,
    String? obsidianPath,
    Offset? position,
  }) async {
    final sphereId = _graphId;
    if (sphereId == null || _disposed) return;
    if (obsidianPath != null && obsidianRepository == null) {
      throw StateError('Плагин заметок отключён.');
    }
    final center = position ?? const Offset(worldCenter, worldCenter);
    final noteText = obsidianPath != null
        ? await obsidianRepository!.readContent(obsidianPath)
        : (title.isNotEmpty ? '$title\n\n$text' : text);
    if (_disposed || _graphId != sphereId) return;
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
    if (_graphId == null) return;
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
    if (_graphId == null) return;
    moveNote(id, x, y);
    _scheduleSaveNotes();
  }

  /// Live-курсор ресайза заметки: обновляет size в памяти без персиста.
  /// Границы синхронизированы с clamp в DefaultNoteCard (120..800 / 80..800).
  void resizeNote(String id, double width, double height) {
    if (!_accepting) return;
    if (_graphId == null) return;
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
    if (_graphId == null) return;
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
    final sphereId = _graphId;
    if (sphereId == null) return;
    await _flush();
    if (!_disposed && _graphId == sphereId) await _loadNotes(sphereId);
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
      if (cacheChanged && _board != null && !isIndependentCanvas) {
        _scheduleBoard();
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
    final sphereId = _graphId;
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
    _graphId = null;
    _graphSubject.add(const []);
    _notesSubject.add(const []);
    await positionsRepository.saveLastSphereId(sphereId);
    await _loadPositions(sphereId);
    await _openBoard(sphereId);
    await _loadNotes(sphereId);
    if (_disposed) return;
    _graphId = sphereId;
    saveStatus.value =
        _standaloneWriter.isIdle && _positionWriter.isIdle && _noteWriter.isIdle
        ? GraphSaveStatus.saved
        : GraphSaveStatus.saving;
    _domainNodes = const [];
    _graphSubject.add(const []); // сбрасываем устаревшие данные прошлой сферы
    _graphSubscription = graphBuilder
        .watchGraph(
          sphereId,
          standaloneIds: _standalonePositions.map(
            (positions) => {...positions.keys, ..._removedTaskIds},
          ),
        )
        .listen((nodes) {
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
