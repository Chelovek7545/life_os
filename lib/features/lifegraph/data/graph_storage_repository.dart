import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:lifegraph_plugin/graph_storage_settings.dart';
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:path/path.dart' as p;
import 'package:plugin_runtime/plugin_runtime.dart';

class GraphStorageRepository
    implements
        AppPlugin,
        VaultNotesApi,
        NotesLibrarySourcesApi,
        VaultCanvasApi,
        VaultCanvasBoardsApi,
        CanvasStorageFoldersApi,
        MarkdownNoteSaveApi,
        MarkdownNoteDeleteApi,
        MarkdownNoteRenameApi {
  GraphStorageRepository({
    required this.target,
    required this.vaultFolders,
    required this.beforeSwitch,
    this.obsidian,
    this.onNoteRenamed,
  });
  final ValueListenable<GraphStorageTarget> target;
  final ValueListenable<VaultFolders> vaultFolders;
  final Future<void> Function() beforeSwitch;
  final ObsidianVault? obsidian;
  final Future<void> Function(String previous, String next)? onNoteRenamed;
  final _noteRenames = StreamController<NotePathChange>.broadcast();
  StreamSubscription<NotePathChange>? _activeRenames;
  StreamSubscription<NotePathChange>? _obsidianRenames;
  @override
  String resolveNotePath(String path) => _reader(path).resolveNotePath(path);
  @override
  Stream<NotePathChange> watchNoteRenames() => _noteRenames.stream;
  @override
  Future<String> renameMarkdownNote(String path, String title) {
    final owner = _reader(path);
    final operation = owner.renameMarkdownNote(
      path,
      title,
      updateReferences: (previous, next) async {
        for (final files in {?_active, ?obsidian}) {
          if (!identical(files, owner)) {
            await files.remapNoteReferences(previous, next);
          }
        }
        await onNoteRenamed?.call(previous, next);
      },
    );
    _copies.add(operation);
    operation.then<void>(
      (_) => _copies.remove(operation),
      onError: (Object _, StackTrace _) {
        _copies.remove(operation);
      },
    );
    return operation;
  }

  Future<void>? _disposal;
  final _changes = StreamController<VaultState>.broadcast();
  final _copies = <Future<String>>{};
  StreamSubscription<VaultState>? _sourceSubscription;
  StreamSubscription<VaultState>? _obsidianSubscription;
  ObsidianVault? _local;
  ObsidianVault? _active;
  VaultFolders? _standbyFolders;
  GraphStorageTarget? _selected;
  Future<void> _tail = Future.value();
  bool _accepting = false;
  int _generation = 0;
  int _rootEpoch = 0;
  @override
  String get id => 'graph.storage';
  @override
  Set<String> get dependencies => {if (obsidian != null) 'obsidian'};
  @override
  VaultState? get obsidianState => obsidian?.state;
  @override
  VaultState get graphMarkdownState =>
      _active?.graphMarkdownState ?? VaultState();
  @override
  VaultState get state {
    final current = _active?.state ?? VaultState();
    final external = identical(_active, obsidian) ? null : obsidian?.state;
    final seen = <String>{};
    return VaultState(
      vaultPath: current.vaultPath,
      notes: [
        for (final note in [...current.notes, ...?external?.notes])
          if (seen.add(p.normalize(note.absolutePath))) note,
      ],
      isLoading: current.isLoading || (external?.isLoading ?? false),
      error: current.error ?? external?.error,
    );
  }

  @override
  VaultFolders get folders =>
      _active?.folders ?? _standbyFolders ?? vaultFolders.value;
  @override
  Stream<VaultState> watch() => Stream.multi((listener) {
    listener.add(state);
    final subscription = _changes.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  }, isBroadcast: true);

  void _check() {
    if (!_accepting) throw StateError('Хранилище графа закрыто.');
  }

  ObsidianVault get _files {
    _check();
    return _active ??
        (throw StateError('Выберите папку Pulse или подключите vault.'));
  }

  void _targetChanged() {
    unawaited(
      selectTarget(target.value).catchError((Object error) {
        if (_accepting) {
          _changes.add(
            VaultState(
              vaultPath: state.vaultPath,
              notes: state.notes,
              error: '$error',
            ),
          );
        }
      }),
    );
  }

  @override
  Future<void> start() async {
    if (_disposal != null) throw StateError('Хранилище графа освобождено.');
    _accepting = true;
    await obsidian?.configureFolders(vaultFolders.value, copyBoards: false);
    await selectTarget(target.value, copyExisting: false);
    _obsidianSubscription = obsidian?.watch().listen((_) {
      if (_accepting && !identical(_active, obsidian)) _changes.add(state);
    });
    _obsidianRenames = obsidian?.watchNoteRenames().listen((change) {
      if (_accepting && !identical(_active, obsidian)) _noteRenames.add(change);
    });
    target.addListener(_targetChanged);
  }

  Future<void> selectTarget(
    GraphStorageTarget choice, {
    bool copyExisting = true,
  }) {
    _check();
    final generation = _generation;
    final result = _tail.then((_) async {
      if (generation != _generation) {
        throw StateError('Выбор хранилища устарел.');
      }
      if (_selected?.mode == choice.mode &&
          _selected?.localPath == choice.localPath) {
        return;
      }
      if (copyExisting &&
          choice.mode == GraphStorageMode.obsidian &&
          (obsidian == null || obsidian!.state.vaultPath.isEmpty)) {
        throw StateError('Подключите vault в настройках Obsidian.');
      }
      if (choice.mode == GraphStorageMode.local &&
          (choice.localPath.trim().isEmpty ||
              !p.isAbsolute(choice.localPath))) {
        throw ArgumentError('Выберите абсолютный путь папки Pulse.');
      }
      if (_selected != null) {
        await Future.wait(_copies.toList());
        await beforeSwitch();
      }
      final previous = _active;
      final oldLocal = _local;
      ObsidianVault? candidate;
      try {
        if (choice.mode == GraphStorageMode.local) {
          candidate = ObsidianVault();
          await candidate.configureFolders(
            GraphStorageTarget.localFolders,
            copyBoards: false,
          );
          final root = p.normalize(p.absolute(choice.localPath));
          await Directory(root).create(recursive: true);
          await candidate.openVault(root);
          if (candidate.state.error != null) {
            throw FileSystemException(candidate.state.error!, root);
          }
        } else {
          candidate = obsidian;
          if (candidate != null) {
            await candidate.configureFolders(
              vaultFolders.value,
              copyBoards: false,
            );
          }
        }
        if (copyExisting &&
            previous != null &&
            candidate != null &&
            previous.state.vaultPath.isNotEmpty &&
            candidate.state.vaultPath.isNotEmpty) {
          await _copyBoards(previous, candidate);
        }
        if (generation != _generation) {
          throw StateError('Выбор хранилища устарел.');
        }
        await _sourceSubscription?.cancel();
        await _activeRenames?.cancel();
        if (generation != _generation) {
          throw StateError('Выбор хранилища устарел.');
        }
        _active = candidate;
        _rootEpoch++;
        _local = choice.mode == GraphStorageMode.local ? candidate : null;
        _selected = choice;
        _sourceSubscription = candidate?.watch().listen((_) {
          if (_accepting) _changes.add(state);
        });
        _activeRenames = candidate?.watchNoteRenames().listen((change) {
          if (_accepting) _noteRenames.add(change);
        });
        _changes.add(state);
        if (oldLocal != null && !identical(oldLocal, candidate)) {
          await oldLocal.dispose();
        }
      } catch (_) {
        if (candidate != null &&
            !identical(candidate, obsidian) &&
            !identical(candidate, _active)) {
          await candidate.dispose();
        }
        rethrow;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  String _relativeFile(String root, String relative) {
    final parts = p.posix.split(relative);
    if (p.posix.isAbsolute(relative) ||
        p.windows.rootPrefix(relative).isNotEmpty ||
        parts.contains('..')) {
      throw const FormatException(
        'Ссылка Canvas выходит за пределы хранилища.',
      );
    }
    final path = p.normalize(p.joinAll([root, ...parts]));
    if (!p.isWithin(root, path)) {
      throw const FormatException('Неверная ссылка Canvas.');
    }
    return path;
  }

  Future<void> _copyBoards(
    ObsidianVault source,
    ObsidianVault destination,
  ) async {
    await source.flush();
    final root = source.state.vaultPath;
    final nextRoot = destination.state.vaultPath;
    final directory = Directory(
      source.folders.boards.isEmpty
          ? root
          : _relativeFile(root, source.folders.boards),
    );
    final plans = <String, (File, String, String)>{};
    if (!await directory.exists()) return;
    await for (final file in directory.list(followLinks: false)) {
      if (file is! File ||
          p.extension(file.path) != '.canvas' ||
          !RegExp(
            r'^[a-zA-Z0-9_-]+$',
          ).hasMatch(p.basenameWithoutExtension(file.path))) {
        continue;
      }
      final targetPath = p.joinAll([
        nextRoot,
        ...p.posix.split(destination.folders.boards),
        p.basename(file.path),
      ]);
      if (p.equals(file.path, targetPath)) continue;
      final original = await file.readAsString();
      final data = jsonDecode(original) as Map<String, dynamic>;
      var changed = false;
      for (final node in data['nodes'] as List? ?? []) {
        for (final key in ['file', 'background']) {
          final relative = node[key];
          if (relative is! String || relative.isEmpty) continue;
          final absolute = p.isAbsolute(relative)
              ? p.normalize(relative)
              : _relativeFile(root, relative);
          if (p.isWithin(nextRoot, absolute)) {
            final rebased = p
                .split(p.relative(absolute, from: nextRoot))
                .join('/');
            changed = changed || rebased != relative;
            node[key] = rebased;
          } else if (key == 'file' &&
              node['type'] == 'file' &&
              p.extension(absolute).toLowerCase() == '.md' &&
              node['subpath'] == null) {
            final metadata = Map<String, dynamic>.from(
              node['pulse'] as Map? ?? {},
            );
            final linked = File(absolute);
            final text = await linked.exists()
                ? await linked.readAsString()
                : metadata['cachedText'] as String? ?? '';
            node.remove('file');
            node['type'] = 'text';
            node['text'] = text;
            node['pulse'] = {
              ...metadata,
              'noteId': metadata['noteId'] ?? node['id'],
              'cachedText': text,
              'externalPath': absolute,
            };
            changed = true;
          } else {
            // Unsupported attachments also stay at their original location.
            changed = changed || absolute != relative;
            node[key] = absolute;
          }
        }
      }
      final content = changed
          ? const JsonEncoder.withIndent('  ').convert(data)
          : original;
      final target = File(targetPath);
      if (await target.exists() && await target.readAsString() != content) {
        throw FileSystemException('В папке уже есть другая доска', targetPath);
      }
      plans[targetPath] = (file, original, content);
    }
    for (final entry in plans.entries) {
      final file = File(entry.key);
      if (!await file.exists()) {
        await file.parent.create(recursive: true);
        await file.create(exclusive: true);
        await file.writeAsString(entry.value.$3, flush: true);
      } else if (await file.readAsString() != entry.value.$3) {
        throw FileSystemException('Целевая доска изменена', file.path);
      }
    }
    for (final entry in plans.values) {
      if (await entry.$1.readAsString() != entry.$2) {
        throw StateError('Исходная доска изменена во время сохранения.');
      }
    }
    if (source.state.vaultPath != root ||
        destination.state.vaultPath != nextRoot) {
      throw StateError('Корень хранилища изменился во время сохранения.');
    }
  }

  @override
  Future<void> configureFolders(
    VaultFolders value, {
    bool copyBoards = true,
  }) async {
    _check();
    if (_selected?.mode == GraphStorageMode.local) {
      await obsidian?.configureFolders(value, copyBoards: false);
      await _files.configureFolders(
        GraphStorageTarget.localFolders,
        copyBoards: false,
      );
    } else {
      if (_active != null) {
        await _active!.configureFolders(value, copyBoards: copyBoards);
      } else {
        final validator = ObsidianVault(
          watchDirectory: (_) => const Stream.empty(),
        );
        try {
          await validator.configureFolders(value, copyBoards: false);
          _standbyFolders = validator.folders;
        } finally {
          await validator.dispose();
        }
      }
    }
    if (_accepting) _changes.add(state);
  }

  @override
  Future<List<String>> listFolders() => _files.listFolders();
  @override
  Future<void> refresh() async {
    _check();
    await Future.wait([
      if (_active != null) _active!.refresh(),
      if (obsidian != null && !identical(_active, obsidian))
        obsidian!.refresh(),
    ]);
  }

  ObsidianVault _reader(String path) {
    _check();
    final source = obsidian;
    if (source != null &&
        source.state.vaultPath.isNotEmpty &&
        p.isWithin(source.state.vaultPath, p.normalize(p.absolute(path)))) {
      return source;
    }
    return _files;
  }

  @override
  Future<String> readContent(String path) => _reader(path).readContent(path);
  @override
  Future<void> writeContent(String path, String text) =>
      _reader(path).writeContent(path, text);
  @override
  Future<VaultNote> createNote(String title, String text) =>
      _files.createNote(title, text);
  @override
  Future<void> deleteMarkdownNote(String path) =>
      _files.deleteMarkdownNote(path);
  @override
  String canvasNotePath(String path) => _files.canvasNotePath(path);
  @override
  Future<String> createCanvas(String sphereId, Map<String, Object?> document) =>
      _files.createCanvas(sphereId, document);
  @override
  Future<CanvasBoardSession> openCanvasBoard(String sphereId) async {
    final files = _files;
    final epoch = _rootEpoch;
    void ensureActive() {
      if (!_accepting || epoch != _rootEpoch || !identical(files, _active)) {
        throw StateError('Хранилище изменено. Откройте граф заново.');
      }
    }

    final session = await files.openCanvasBoard(sphereId);
    ensureActive();
    return _GraphBoardSession(session, ensureActive);
  }

  @override
  Future<String> saveMarkdownCopy(String directory, String title, String text) {
    _check();
    final operation = () async {
      final writer = ObsidianVault(watchDirectory: (_) => const Stream.empty());
      try {
        await writer.openVault('');
        return await writer.saveMarkdownCopy(directory, title, text);
      } finally {
        await writer.dispose();
      }
    }();
    _copies.add(operation);
    operation.then<void>(
      (_) {
        _copies.remove(operation);
      },
      onError: (Object _, StackTrace _) {
        _copies.remove(operation);
      },
    );
    return operation;
  }

  @override
  Future<void> stop() async {
    _accepting = false;
    _generation++;
    _rootEpoch++;
    target.removeListener(_targetChanged);
    (Object, StackTrace)? failure;
    Future<void> release(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stack) {
        failure ??= (error, stack);
      }
    }

    await release(() => _tail);
    await release(() async {
      await _active?.flush();
    });
    await release(() async {
      await Future.wait(_copies.toList());
    });
    await release(() async {
      await _sourceSubscription?.cancel();
    });
    _sourceSubscription = null;
    await release(() async {
      await _obsidianSubscription?.cancel();
    });
    _obsidianSubscription = null;
    await release(() async {
      await _activeRenames?.cancel();
    });
    await release(() async {
      await _obsidianRenames?.cancel();
    });
    _activeRenames = null;
    _obsidianRenames = null;
    await release(() async {
      await _local?.dispose();
    });
    _local = null;
    _active = null;
    _selected = null;
    if (failure case final error?) {
      Error.throwWithStackTrace(error.$1, error.$2);
    }
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    try {
      await stop();
    } finally {
      await _changes.close();
      await _noteRenames.close();
    }
  }
}

class _GraphBoardSession implements CanvasBoardSession {
  _GraphBoardSession(this.inner, this.ensureActive);
  final CanvasBoardSession inner;
  final void Function() ensureActive;
  @override
  String get path => inner.path;
  @override
  String notePath(String path) {
    ensureActive();
    return inner.notePath(path);
  }

  @override
  String resolveNote(String path) {
    ensureActive();
    return inner.resolveNote(path);
  }

  @override
  Future<String?> read() {
    ensureActive();
    return inner.read();
  }

  @override
  Future<void> write(String content, {required String? expected}) =>
      _write(content, expected);
  Future<void> _write(String content, String? expected) async {
    ensureActive();
    await inner.write(content, expected: expected);
  }
}
