import 'dart:convert';
import 'dart:io';

import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/lifegraph/data/graph_storage_repository.dart';
import 'package:lifegraph_plugin/canvas_board.dart';
import 'package:notes_api/notes_api.dart';
import 'package:path/path.dart' as p;
import 'package:sync_plugin/sync_logic.dart';

import 'drift_sync_store.dart';

class SyncCanvasBoards {
  const SyncCanvasBoards(this.store, this.storage, this.catalog);

  final DriftSyncStore store;
  final GraphStorageRepository storage;
  final GraphNotesRepository catalog;

  Future<void> reconcile(
    Iterable<String> sphereIds, {
    required Future<void> Function(Set<String>) refresh,
    bool afterReceive = false,
  }) async {
    final changed = <String>{};
    try {
      await storage.withSyncStorage(() async {
        if (storage.state.vaultPath.isEmpty) return;
        final paths = _CanvasFilePaths(storage);
        final boards = <String, _BoardFile>{};
        for (final sphereId in sphereIds) {
          final session = await storage.openCanvasBoard(sphereId);
          final raw = await session.read();
          final file = _BoardFile(sphereId, session, raw, paths);
          boards[file.scope] = file;
        }
        final snapshots = boards.map(
          (scope, board) => MapEntry(scope, board.snapshot),
        );
        final plans = await store.stageExternalNotes(
          'canvasBoard',
          snapshots.values.toList(),
          adoptUntrackedBoards: {
            if (afterReceive)
              for (final board in boards.values)
                if (board.generatedOnly) board.scope,
          },
        );
        for (final plan in plans) {
          final local = boards[plan.scope]!;
          final incoming = SyncCanvasBoard.decode(plan.target.payload!);
          final unchanged =
              snapshots[local.scope]!.payloads[incoming.id] ==
              plan.target.payload;
          final content = unchanged
              ? local.raw!
              : await local.localize(incoming);
          if (!unchanged) {
            await local.session.write(
              content,
              expected: local.raw,
              backupPrevious: true,
            );
          }
          changed.add(local.sphereId);
          await catalog.saveNotes(
            local.sphereId,
            CanvasBoardDocument(content).notes(local.session.resolveNote),
          );
          await store.checkpointNote(plan.scope, plan.target);
        }
      });
    } on CanvasBoardConflict {
      throw const LocalSyncException(
        'Canvas изменился во время обмена. Повторите синхронизацию.',
      );
    } finally {
      if (changed.isNotEmpty) await refresh(changed);
    }
  }
}

class _BoardFile {
  _BoardFile(this.sphereId, this.session, this.raw, this.paths)
    : _local = raw == null
          ? null
          : (CanvasBoardDocument(raw)..validateScope(sphereId));

  static const _notesPath = 'syncNotesFile';
  static const _localPath = 'syncLocalFile';
  static const _placeholderText = 'Локальный файл';

  final String sphereId;
  final CanvasBoardSession session;
  final String? raw;
  final _CanvasFilePaths paths;
  final CanvasBoardDocument? _local;

  String get scope => 'canvas:${p.canonicalize(session.path)}';

  bool get generatedOnly {
    final board = _local;
    return board != null &&
        board.data.keys.every(const {'nodes', 'edges', 'pulse'}.contains) &&
        board.nodes.every((node) => board.entityId(node) != null) &&
        board.edges.every(
          (edge) =>
              (edge['id'] as String).startsWith('pulse-hierarchy:') ||
              (edge['id'] as String).startsWith('pulse-sequence:'),
        );
  }

  ExternalNoteSnapshot get snapshot {
    final board = _local;
    final id = canvasEntryId(sphereId, 'board');
    if (board == null) {
      return (
        scope: scope,
        idPrefix: id,
        payloads: const {},
        captureDeletes: false,
      );
    }
    final wire = SyncCanvasBoard(sphereId, {
      ...board.data,
      'nodes': board.nodes.map(_portableNode).toList(),
    }).encode();
    if (utf8.encode(wire).length > SyncRevision.maxPayloadBytes) {
      throw const LocalSyncException(
        'Файл Canvas превышает лимит синхронизации в 1 МиБ.',
      );
    }
    return (
      scope: scope,
      idPrefix: id,
      payloads: {id: wire},
      captureDeletes: false,
    );
  }

  Map<String, dynamic> _portableNode(Map<String, dynamic> node) {
    final metadata = node['pulse'];
    final details = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : <String, dynamic>{};
    final external = details.remove('externalPath');
    final isFile = node['type'] == 'file';
    final file = isFile && node['file'] is String
        ? node['file'] as String
        : null;
    final alreadyLocal =
        details[_localPath] == true && node['text'] == _placeholderText;
    details.remove('cachedText');
    details.remove(_notesPath);
    if (!isFile && external is! String && !alreadyLocal) {
      return details.containsKey(_localPath)
          ? {...node, 'pulse': details..remove(_localPath)}
          : node;
    }

    String? source;
    if (external is String) {
      source = external;
    } else if (file != null && _relativeFile(file)) {
      source = session.resolveNote(file);
    }
    final relative = source == null ? null : paths.relativeNote(source);
    if (relative != null) {
      return {
        ...node,
        'type': 'file',
        'file': relative.toLowerCase(),
        'pulse': details
          ..remove(_localPath)
          ..[_notesPath] = true,
      }..remove('text');
    }
    if (external is! String && file != null && _relativeFile(file)) {
      return {...node, 'pulse': details..remove(_localPath)};
    }
    return _placeholder(node, details);
  }

  Map<String, dynamic> _placeholder(
    Map<String, dynamic> node,
    Map<String, dynamic> details,
  ) =>
      {
          ...node,
          'type': 'text',
          'text': _placeholderText,
          'pulse': details
            ..remove(_notesPath)
            ..[_localPath] = true,
        }
        ..remove('file')
        ..remove('subpath');

  Future<String> localize(SyncCanvasBoard incoming) async {
    if (incoming.sphereId != sphereId) {
      throw const FormatException('Canvas belongs to another sphere.');
    }
    final board = CanvasBoardDocument(jsonEncode(incoming.document))
      ..validateScope(sphereId);
    final existing = {
      for (final node in _local?.nodes ?? const <Map<String, dynamic>>[])
        node['id'] as String: node,
    };
    final content = const JsonEncoder.withIndent('  ').convert({
      ...board.data,
      'nodes': [
        for (final node in board.nodes)
          await _localNode(node, existing[node['id']]),
      ],
    });
    CanvasBoardDocument(content).validateScope(sphereId);
    return content;
  }

  Future<Map<String, dynamic>> _localNode(
    Map<String, dynamic> node,
    Map<String, dynamic>? existing,
  ) async {
    final metadata = node['pulse'];
    final details = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : <String, dynamic>{};
    final notePath = details.remove(_notesPath) == true;
    final localFile = details[_localPath] == true;
    details.remove('externalPath');
    final normalized = {...node, if (metadata is Map) 'pulse': details};
    if (localFile) {
      final original = existing?['pulse'];
      final originalExternal = original is Map
          ? original['externalPath']
          : null;
      if (originalExternal is String) {
        return {
          ...normalized,
          'type': 'text',
          'text': existing?['text'] ?? '',
          'pulse': {...details, 'externalPath': originalExternal},
        }..remove('file');
      }
      return _placeholder(normalized, details);
    }
    if (node['type'] != 'file') return normalized;
    final file = node['file'];
    if (file is! String || !_relativeFile(file)) {
      return _placeholder(normalized, details);
    }
    if (notePath) {
      final absolute = await paths.resolveNote(file);
      if (absolute == null) {
        throw const LocalSyncException(
          'Не удалось создать ссылку Canvas на файл в папке Notes.',
        );
      }
      return {...normalized, 'file': session.notePath(absolute)};
    }
    if (!await paths.isSafe(session.resolveNote(file))) {
      throw const LocalSyncException(
        'Путь к файлу карточки Canvas недоступен на этом устройстве.',
      );
    }
    return normalized;
  }

  bool _relativeFile(String value) =>
      value.isNotEmpty &&
      !p.posix.isAbsolute(value) &&
      !p.windows.isAbsolute(value) &&
      p.posix.normalize(value) == value &&
      p.posix
          .split(value)
          .every(
            (part) =>
                part != '..' &&
                part != '.' &&
                !RegExp(r'[\\:\x00]').hasMatch(part),
          );
}

class _CanvasFilePaths {
  _CanvasFilePaths(this.storage)
    : directory = storage.graphMarkdownState.vaultPath,
      vault = storage.state.vaultPath {
    for (final note in storage.graphMarkdownState.notes) {
      if (relativeNote(note.absolutePath) case final path?) {
        _notes[path.toLowerCase()] = note.absolutePath;
      }
    }
  }

  final GraphStorageRepository storage;
  final String directory, vault;
  final _notes = <String, String>{};

  String? relativeNote(String path) {
    if (directory.isEmpty ||
        !p.isAbsolute(path) ||
        !p.isWithin(directory, p.normalize(path))) {
      return null;
    }
    final relative = p.posix.joinAll(
      p.split(p.relative(path, from: directory)),
    );
    return MarkdownSyncNote.isPortable(relative) ? relative : null;
  }

  Future<String?> resolveNote(String relative) async {
    if (directory.isEmpty || !MarkdownSyncNote.isPortable(relative)) {
      return null;
    }
    final target =
        _notes[relative.toLowerCase()] ??
        p.joinAll([directory, ...p.posix.split(relative)]);
    return await isSafe(target) ? target : null;
  }

  Future<bool> isSafe(String target) async {
    if (!p.isWithin(vault, target)) return false;
    final segments = p.split(p.relative(target, from: vault));
    var path = vault;
    for (final (index, segment) in segments.indexed) {
      path = p.join(path, segment);
      final type = await storage.files.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) return true;
      final expected = index == segments.length - 1
          ? FileSystemEntityType.file
          : FileSystemEntityType.directory;
      if (type != expected) return false;
    }
    return true;
  }
}
