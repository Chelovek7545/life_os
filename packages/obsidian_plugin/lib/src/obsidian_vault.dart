import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:notes_api/notes_api.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'vault_files.dart';

class ObsidianVault
    implements
        VaultNotesApi,
        NotesLibrarySourcesApi,
        VaultCanvasApi,
        VaultCanvasBoardsApi,
        CanvasStorageFoldersApi,
        MarkdownNoteSaveApi,
        MarkdownNoteDeleteApi,
        MarkdownNoteRenameApi {
  ObsidianVault({
    VaultFiles files = const LocalVaultFiles(),
    Stream<FileSystemEvent> Function(Directory)? watchDirectory,
  }) : _files = files,
       _watchDirectory = watchDirectory == null
           ? files.watch
           : ((path) => watchDirectory(Directory(path)));
  final VaultFiles _files;
  final Stream<FileSystemEvent> Function(String) _watchDirectory;
  final _changes = StreamController<VaultState>.broadcast();
  @override
  VaultState get obsidianState => state;
  @override
  VaultState get graphMarkdownState {
    if (state.vaultPath.isEmpty) return VaultState();
    final directory = p.normalize(
      p.joinAll([state.vaultPath, ...p.posix.split(folders.notes)]),
    );
    return VaultState(
      vaultPath: directory,
      notes: [
        for (final note in state.notes)
          if (p.isWithin(directory, note.absolutePath)) note,
      ],
      isLoading: state.isLoading,
      error: state.error,
    );
  }

  final _noteRenames = StreamController<NotePathChange>.broadcast();
  final _renamedPaths = <String, String>{};
  @override
  String resolveNotePath(String path) =>
      _renamedPaths[p.normalize(path)] ?? path;
  @override
  Stream<NotePathChange> watchNoteRenames() => _noteRenames.stream;
  VaultState _state = VaultState();
  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};
  Timer? _debounce;
  Future<void> _tail = Future.value();
  bool _active = false;
  bool _disposed = false;
  Future<void>? _disposal;
  int _generation = 0;
  int _vaultSelectionGeneration = 0;
  VaultFolders _folders = const VaultFolders();
  @override
  VaultFolders get folders => _folders;

  String _normalizeFolder(String value) {
    final input = value.trim();
    final context = input.contains('\\') ? p.windows : p.posix;
    final parts = context.split(input);
    if (p.windows.rootPrefix(input).isNotEmpty ||
        p.posix.isAbsolute(input) ||
        parts.contains('..') ||
        parts.any((part) => RegExp(r'[<>:"|?*]').hasMatch(part))) {
      throw ArgumentError(
        'Выберите папку внутри vault, без .. и абсолютного пути.',
      );
    }
    final result = p.posix.normalize(p.posix.joinAll(parts));
    return result == '.' ? '' : result;
  }

  String _folderPath(String root, String relative) =>
      p.joinAll([root, ...p.posix.split(relative)]);

  @override
  Future<void> configureFolders(VaultFolders value, {bool copyBoards = true}) {
    if (_disposed || _disposal != null) {
      return Future.error(StateError('Vault is disposed.'));
    }
    final next = VaultFolders(
      boards: _normalizeFolder(value.boards),
      notes: _normalizeFolder(value.notes),
      exports: _normalizeFolder(value.exports),
      backups: _normalizeFolder(value.backups),
    );
    final root = state.vaultPath;
    final selection = _vaultSelectionGeneration;
    return _enqueue(() async {
      if (selection != _vaultSelectionGeneration) {
        throw StateError('Vault изменён.');
      }
      if (copyBoards &&
          _active &&
          root.isNotEmpty &&
          next.boards != _folders.boards) {
        final source = _folderPath(root, _folders.boards);
        final target = _folderPath(root, next.boards);
        final copies = <(String, String, String)>[];
        if (await _files.type(source) == FileSystemEntityType.directory) {
          for (final entity in await _files.list(source)) {
            if (entity.type != FileSystemEntityType.file ||
                p.extension(entity.name) != '.canvas' ||
                !RegExp(
                  r'^[a-zA-Z0-9_-]+$',
                ).hasMatch(p.basenameWithoutExtension(entity.name))) {
              continue;
            }
            final previous = p.join(source, entity.name);
            final destination = p.join(target, entity.name);
            final content = await _readRequired(previous);
            final existing = await _files.read(destination);
            if (existing != null) {
              if (existing != content) {
                throw FileSystemException(
                  'В выбранной папке уже есть другая доска',
                  destination,
                );
              }
            } else {
              copies.add((previous, destination, content));
            }
          }
        }
        for (final copy in copies) {
          await _files.createDirectory(target);
          await _files.writeNew(copy.$2, copy.$3);
        }
        for (final copy in copies) {
          if (await _files.read(copy.$1) != copy.$3) {
            throw FileSystemException(
              'Исходная доска изменилась во время копирования',
              copy.$1,
            );
          }
        }
      }
      final notesChanged = next.notes != _folders.notes;
      _folders = next;
      if (notesChanged && _active && root.isNotEmpty) {
        await _scan(root, _generation);
      }
    });
  }

  @override
  Future<List<String>> listFolders() {
    _checkActive();
    final root = state.vaultPath;
    return _enqueue(() async {
      if (root.isEmpty) throw StateError('Сначала выберите vault.');
      final result = <String>[''];
      Future<void> visit(String directory) async {
        for (final entity in await _files.list(directory)) {
          if (entity.type == FileSystemEntityType.directory &&
              !entity.name.startsWith('.')) {
            final path = p.join(directory, entity.name);
            result.add(p.posix.joinAll(p.split(p.relative(path, from: root))));
            await visit(path);
          }
        }
      }

      await visit(root);
      result.sort();
      return result;
    });
  }

  @override
  VaultState get state => _state;

  @override
  Stream<VaultState> watch() => Stream.multi((listener) {
    listener.add(_state);
    final subscription = _changes.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  }, isBroadcast: true);

  void _publish(VaultState state) {
    if (_disposed) return;
    _state = state;
    _changes.add(state);
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> openVault(String path) {
    if (_disposed || _disposal != null)
      return Future.error(StateError('Vault is disposed.'));
    _active = true;
    _vaultSelectionGeneration++;
    final generation = ++_generation;
    _debounce?.cancel();
    return _enqueue(() async {
      await _cancelWatchers();
      if (!_active || generation != _generation) return;
      final vaultPath = path.trim().isEmpty
          ? ''
          : p.normalize(p.absolute(path.trim()));
      _publish(
        VaultState(vaultPath: vaultPath, isLoading: vaultPath.isNotEmpty),
      );
      if (vaultPath.isEmpty) return;
      await _scan(vaultPath, generation);
    });
  }

  @override
  Future<void> refresh() {
    if (!_active || _disposed) return Future.value();
    final generation = _generation;
    final vaultPath = state.vaultPath;
    return _enqueue(() async {
      if (!_active || generation != _generation || vaultPath.isEmpty) return;
      _publish(
        VaultState(vaultPath: vaultPath, notes: state.notes, isLoading: true),
      );
      await _scan(vaultPath, generation);
    });
  }

  Future<void> _scan(String vaultPath, int generation) async {
    try {
      if (await _files.type(vaultPath) != FileSystemEntityType.directory) {
        throw FileSystemException('Указанная папка не существует', vaultPath);
      }
      final notes = <VaultNote>[];
      final directories = <String>[];
      await _scanDirectory(vaultPath, vaultPath, notes, directories);
      final added = await _syncWatchers(directories, vaultPath, generation);
      if (added && _active && generation == _generation) {
        // Capture changes that happened before a newly indexed directory was watched.
        notes.clear();
        directories.clear();
        await _scanDirectory(vaultPath, vaultPath, notes, directories);
        await _syncWatchers(directories, vaultPath, generation);
      }
      notes.sort((a, b) => a.relativePath.compareTo(b.relativePath));
      if (_active && generation == _generation)
        _publish(VaultState(vaultPath: vaultPath, notes: notes));
    } catch (error) {
      if (_active && generation == _generation) {
        _publish(
          VaultState(
            vaultPath: vaultPath,
            notes: state.notes,
            error: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> _scanDirectory(
    String directory,
    String root,
    List<VaultNote> notes,
    List<String> directories,
  ) async {
    directories.add(directory);
    for (final entity in await _files.list(directory)) {
      if (entity.name.startsWith('.')) continue;
      final path = p.join(directory, entity.name);
      if (entity.type == FileSystemEntityType.directory) {
        await _scanDirectory(path, root, notes, directories);
      } else if (p.extension(entity.name).toLowerCase() == '.md') {
        try {
          notes.add(
            VaultNote(
              absolutePath: path,
              relativePath: p.relative(path, from: root),
              title: p.basenameWithoutExtension(entity.name),
              modifiedAt: entity.modifiedAt,
              content: p.isWithin(_folderPath(root, _folders.notes), path)
                  ? await _readRequired(path)
                  : '',
            ),
          );
        } on FileSystemException {
          // Files can disappear between the directory listing and stat.
          if (await _files.type(path) == FileSystemEntityType.file) rethrow;
        }
      }
    }
  }

  Future<bool> _syncWatchers(
    List<String> directories,
    String root,
    int generation,
  ) async {
    if (!_active || generation != _generation) return false;
    final paths = directories.toSet();
    for (final old
        in _watchers.keys.where((path) => !paths.contains(path)).toList()) {
      await _watchers.remove(old)!.cancel();
    }
    var added = false;
    for (final directory in directories) {
      if (!_active || generation != _generation) break;
      if (_watchers.containsKey(directory)) continue;
      _watchers[directory] = _watchDirectory(directory).listen(
        (event) {
          final relative = p.relative(event.path, from: root);
          if (p.split(relative).any((part) => part.startsWith('.'))) return;
          if (event.isDirectory ||
              p.extension(event.path).toLowerCase() == '.md' ||
              event.type == FileSystemEvent.move) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (_active && generation == _generation) unawaited(refresh());
            });
          }
        },
        onError: (Object error) {
          if (_active && generation == _generation) {
            _publish(
              VaultState(
                vaultPath: state.vaultPath,
                notes: state.notes,
                error: error.toString(),
              ),
            );
          }
        },
      );
      added = true;
    }
    return added;
  }

  Future<void> _cancelWatchers() async {
    final watchers = _watchers.values.toList();
    _watchers.clear();
    await Future.wait(watchers.map((watcher) => watcher.cancel()));
  }

  void _checkActive() {
    if (!_active || _disposed) throw StateError('Vault plugin is stopped.');
  }

  @override
  Future<CanvasBoardSession> openCanvasBoard(String sphereId) async {
    _checkActive();
    if (state.vaultPath.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sphereId)) {
      throw ArgumentError('Не выбран vault или неверный ID сферы.');
    }
    return _VaultCanvasBoard(
      this,
      state.vaultPath,
      sphereId,
      _vaultSelectionGeneration,
    );
  }

  @override
  String canvasNotePath(String absolutePath) {
    _checkActive();
    final root = state.vaultPath;
    final target = p.normalize(p.absolute(resolveNotePath(absolutePath)));
    if (root.isEmpty || !p.isWithin(root, target)) {
      throw ArgumentError('Canvas notes must be inside the selected vault.');
    }
    return p.split(p.relative(target, from: root)).join('/');
  }

  @override
  Future<String> createCanvas(String sphereId, Map<String, Object?> document) {
    _checkActive();
    final root = state.vaultPath;
    final selection = _vaultSelectionGeneration;
    final content = const JsonEncoder.withIndent('  ').convert(document);
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(sphereId)) {
      return Future.error(ArgumentError.value(sphereId, 'sphereId'));
    }
    return _enqueue(() async {
      if (root.isEmpty || selection != _vaultSelectionGeneration) {
        throw StateError('The selected vault has changed or is empty.');
      }
      final directory = _folderPath(root, _folders.exports);
      await _files.createDirectory(directory);
      // Every export is a new snapshot; never overwrite an Obsidian document.
      final id = const Uuid().v4();
      final path = p.join(directory, '$sphereId-$id.canvas');
      await _files.writeNew(path, content);
      return path;
    });
  }

  Future<String> _readRequired(String path) async =>
      await _files.read(path) ??
      (throw FileSystemException('Файл не найден', path));

  Future<bool> withMarkdownSyncFolder(
    Future<void> Function(MarkdownSyncFolder folder) action,
  ) {
    final root = state.vaultPath;
    final selection = _vaultSelectionGeneration;
    final relative = folders.notes;
    if (!_active || root.isEmpty || relative.isEmpty)
      return Future.value(false);
    return _enqueue(() async {
      void check() {
        _checkActive();
        if (selection != _vaultSelectionGeneration ||
            relative != folders.notes) {
          throw StateError('Папка заметок изменилась во время обмена.');
        }
      }

      check();
      if (await _files.type(root) != FileSystemEntityType.directory) {
        return false;
      }
      final folder = MarkdownSyncFolder._(
        _files,
        root,
        p.posix.split(relative),
        check,
      );
      try {
        await action(folder);
        check();
        return true;
      } finally {
        if (folder._changed &&
            _active &&
            selection == _vaultSelectionGeneration) {
          await _scan(root, _generation);
        }
      }
    });
  }

  @override
  Future<String> readContent(String absolutePath) async {
    _checkActive();
    return _enqueue(() => _readRequired(resolveNotePath(absolutePath)));
  }

  @override
  Future<void> writeContent(String absolutePath, String content) async {
    _checkActive();
    return _enqueue(() async {
      final path = resolveNotePath(absolutePath);
      final expected = await _readRequired(path);
      if (!await _files.replace(path, content, expected: expected)) {
        throw FileSystemException(
          'Заметка изменилась во время сохранения',
          path,
        );
      }
      final modifiedAt = DateTime.now();
      _publish(
        VaultState(
          vaultPath: state.vaultPath,
          notes: [
            for (final note in state.notes)
              if (p.equals(note.absolutePath, p.absolute(path)))
                VaultNote(
                  absolutePath: note.absolutePath,
                  relativePath: note.relativePath,
                  title: note.title,
                  modifiedAt: modifiedAt,
                  content: content,
                )
              else
                note,
          ],
        ),
      );
    });
  }

  @override
  Future<void> deleteMarkdownNote(String path) {
    _checkActive();
    final root = state.vaultPath;
    final selection = _vaultSelectionGeneration;
    final notesFolder = _folderPath(root, _folders.notes);
    return _enqueue(() async {
      void checkSelection() {
        if (root.isEmpty ||
            selection != _vaultSelectionGeneration ||
            !p.equals(notesFolder, _folderPath(root, _folders.notes))) {
          throw StateError('Папка заметок изменена. Обновите библиотеку.');
        }
      }

      checkSelection();
      final target = p.normalize(p.absolute(resolveNotePath(path)));
      if (!p.isWithin(notesFolder, target) ||
          p.extension(target).toLowerCase() != '.md' ||
          await _files.type(target, followLinks: false) !=
              FileSystemEntityType.file) {
        throw ArgumentError('Удалять можно только .md файлы из папки Notes.');
      }
      final resolvedFolder = await _files.canonicalPath(notesFolder);
      final resolvedFile = await _files.canonicalPath(target);
      if (!p.isWithin(resolvedFolder, resolvedFile)) {
        throw ArgumentError('Файл находится за пределами папки Notes.');
      }
      checkSelection();
      await _files.delete(target);
      _publish(
        VaultState(
          vaultPath: state.vaultPath,
          notes: [
            for (final note in state.notes)
              if (!p.equals(note.absolutePath, target)) note,
          ],
        ),
      );
    });
  }

  @override
  Future<VaultNote> createNote(String title, String content) async {
    _checkActive();
    final root = state.vaultPath;
    final selection = _vaultSelectionGeneration;
    return _enqueue(() async {
      if (root.isEmpty || selection != _vaultSelectionGeneration) {
        throw StateError('Vault изменён или не выбран.');
      }
      final sanitized = title
          .trim()
          .replaceAll(RegExp(r'[<>:"|?*]'), '_')
          .replaceAll('/', '_')
          .replaceAll(String.fromCharCode(92), '_');
      if (sanitized.isEmpty || sanitized == '.' || sanitized == '..')
        throw ArgumentError.value(title, 'title');
      final directory = _folderPath(root, _folders.notes);
      await _files.createDirectory(directory);
      final stem = p.extension(sanitized).toLowerCase() == '.md'
          ? p.basenameWithoutExtension(sanitized)
          : sanitized;
      final path = p.join(directory, '$stem.md');
      await _files.writeNew(path, content);
      final note = VaultNote(
        absolutePath: path,
        relativePath: p.relative(path, from: state.vaultPath),
        title: sanitized,
        modifiedAt: DateTime.now(),
        content: content,
      );
      _publish(
        VaultState(vaultPath: state.vaultPath, notes: [...state.notes, note]),
      );
      return note;
    });
  }

  String _rewriteNotePaths(
    String content,
    String root,
    String Function(String) resolve,
  ) {
    final data = jsonDecode(content) as Map<String, dynamic>;
    var changed = false;
    for (final node in data['nodes'] as List? ?? []) {
      for (final key in ['file', 'background']) {
        final value = node[key];
        if (value is! String || value.isEmpty) continue;
        final absolute = p.isAbsolute(value)
            ? p.normalize(value)
            : p.normalize(p.joinAll([root, ...p.posix.split(value)]));
        final next = resolve(absolute);
        if (p.equals(absolute, next)) continue;
        node[key] = p.isWithin(root, next)
            ? p.split(p.relative(next, from: root)).join('/')
            : next;
        changed = true;
      }
      final pulse = node['pulse'];
      if (pulse is Map && pulse['externalPath'] is String) {
        final path = pulse['externalPath'] as String;
        final next = resolve(path);
        if (!p.equals(path, next)) {
          pulse['externalPath'] = next;
          changed = true;
        }
      }
    }
    return changed ? const JsonEncoder.withIndent('  ').convert(data) : content;
  }

  String _rebaseRenamedNotes(String content, String root) =>
      _renamedPaths.isEmpty
      ? content
      : _rewriteNotePaths(content, root, resolveNotePath);

  Future<void> _remapBoardReferences(String previous, String next) async {
    final root = state.vaultPath;
    final selection = _vaultSelectionGeneration;
    if (root.isEmpty) return;
    final directory = _folderPath(root, folders.boards);
    if (await _files.type(directory) != FileSystemEntityType.directory) return;
    for (final file in await _files.list(directory)) {
      if (file.type != FileSystemEntityType.file ||
          p.extension(file.name) != '.canvas' ||
          !RegExp(
            r'^[a-zA-Z0-9_-]+$',
          ).hasMatch(p.basenameWithoutExtension(file.name))) {
        continue;
      }
      final raw = await _readRequired(p.join(directory, file.name));
      final updated = _rewriteNotePaths(
        raw,
        root,
        (path) => p.equals(path, previous) ? next : path,
      );
      if (updated == raw) continue;
      final board = _VaultCanvasBoard(
        this,
        root,
        p.basenameWithoutExtension(file.name),
        selection,
      );
      await board._write(updated, expected: raw);
    }
  }

  void _registerRenamedPath(String previous, String next) {
    final redirects = <String, String>{
      for (final entry in _renamedPaths.entries)
        entry.key: p.equals(entry.value, previous) ? next : entry.value,
      p.normalize(previous): next,
    }..removeWhere((key, value) => p.equals(key, value));
    _renamedPaths
      ..clear()
      ..addAll(redirects);
    _publish(
      VaultState(
        vaultPath: state.vaultPath,
        notes: [
          for (final note in state.notes)
            if (p.equals(note.absolutePath, previous))
              VaultNote(
                absolutePath: next,
                relativePath: p.relative(next, from: state.vaultPath),
                title: p.basenameWithoutExtension(next),
                modifiedAt: note.modifiedAt,
                content: note.content,
              )
            else
              note,
        ],
        isLoading: state.isLoading,
        error: state.error,
      ),
    );
    _noteRenames.add(NotePathChange(previous, next));
  }

  Future<void> remapNoteReferences(String previous, String next) {
    _checkActive();
    return _enqueue(() async {
      await _remapBoardReferences(previous, next);
      _registerRenamedPath(previous, next);
    });
  }

  @override
  Future<String> renameMarkdownNote(
    String path,
    String title, {
    Future<void> Function(String previous, String next)? updateReferences,
  }) {
    _checkActive();
    final selection = _vaultSelectionGeneration;
    final name = title.trim();
    final stem = p.extension(name).toLowerCase() == '.md'
        ? p.basenameWithoutExtension(name)
        : name;
    if (stem.isEmpty ||
        name.toLowerCase() == '.md' ||
        stem == '.' ||
        stem == '..' ||
        RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(name) ||
        stem.endsWith('.') ||
        stem.endsWith(' ')) {
      return Future.error(
        ArgumentError('Укажите допустимое имя файла без пути.'),
      );
    }
    return _enqueue(() async {
      if (selection != _vaultSelectionGeneration) {
        throw StateError('Хранилище изменено.');
      }
      final previous = p.normalize(p.absolute(resolveNotePath(path)));
      if (p.extension(previous).toLowerCase() != '.md') {
        throw ArgumentError('Переименование доступно только для .md.');
      }
      final next = p.join(p.dirname(previous), '$stem.md');
      if (p.equals(previous, next)) return previous;
      final content = await _readRequired(previous);
      await _files.writeNew(next, content);
      try {
        await _remapBoardReferences(previous, next);
        await updateReferences?.call(previous, next);
        if (selection != _vaultSelectionGeneration) {
          throw StateError('Хранилище изменено.');
        }
        if (await _files.read(previous) != content) {
          throw StateError(
            'Исходная заметка изменилась во время переименования.',
          );
        }
        _registerRenamedPath(previous, next);
        await _files.delete(previous);
      } catch (error) {
        throw FileSystemException(
          'Переименование не завершено. Исходник сохранён, новая копия: $next. $error',
          previous,
        );
      }
      return next;
    });
  }

  @override
  Future<String> saveMarkdownCopy(String directory, String title, String text) {
    _checkActive();
    if (!p.isAbsolute(directory)) {
      throw ArgumentError('Выберите абсолютный путь папки.');
    }
    final name = title.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final stem = p.extension(name).toLowerCase() == '.md'
        ? p.basenameWithoutExtension(name)
        : name;
    if (stem.isEmpty || stem == '.' || stem == '..') {
      throw ArgumentError('Укажите имя заметки.');
    }
    return _enqueue(() async {
      final folder = p.normalize(directory);
      if (await _files.type(folder) != FileSystemEntityType.directory) {
        throw FileSystemException('Папка не найдена', folder);
      }
      final path = p.join(folder, '$stem.md');
      await _files.writeNew(path, text);
      return path;
    });
  }

  Future<void> flush() => _tail;

  Future<void> stop() async {
    _active = false;
    _generation++;
    _debounce?.cancel();
    _debounce = null;
    await _cancelWatchers();
    await _tail;
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    await stop();
    _disposed = true;
    await _changes.close();
    await _noteRenames.close();
  }
}

class MarkdownSyncFolder {
  MarkdownSyncFolder._(this._files, this._root, this._parts, this._check);

  final VaultFiles _files;
  final String _root;
  final List<String> _parts;
  final void Function() _check;
  bool _changed = false;

  String get scope => p.canonicalize(p.joinAll([_root, ..._parts]));

  Future<bool> _directories(
    List<String> segments, {
    required bool create,
  }) async {
    var directory = _root;
    for (final segment in segments) {
      _check();
      directory = p.join(directory, segment);
      final type = await _files.type(directory, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        if (!create) return false;
        await _files.createDirectory(directory);
      } else if (type != FileSystemEntityType.directory) {
        throw FileSystemException('Путь заметки занят', directory);
      }
    }
    return true;
  }

  Future<({bool exists, Map<String, String> files})> read() async {
    final files = <String, String>{};
    final exists = await _directories(_parts, create: false);
    Future<void> visit(String directory, List<String> parents) async {
      for (final entry in await _files.list(directory)) {
        _check();
        if (entry.name.startsWith('.') ||
            p.posix.basename(entry.name) != entry.name ||
            p.windows.basename(entry.name) != entry.name) {
          continue;
        }
        final path = p.join(directory, entry.name);
        final segments = [...parents, entry.name];
        final type = await _files.type(path, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          await visit(path, segments);
        } else if (type == FileSystemEntityType.file &&
            p.extension(path).toLowerCase() == '.md') {
          final text = await _files.read(path);
          if (text != null) files[p.posix.joinAll(segments)] = text;
        }
      }
    }

    if (exists) await visit(p.joinAll([_root, ..._parts]), const []);
    _check();
    return (exists: exists, files: files);
  }

  Future<void> write(
    String relative,
    String? content, {
    required String? expected,
  }) async {
    final segments = p.posix.split(relative);
    if (p.posix.isAbsolute(relative) ||
        p.posix.normalize(relative) != relative ||
        segments.any(
          (segment) =>
              segment.startsWith('.') ||
              p.windows.basename(segment) != segment ||
              segment.contains(':'),
        ) ||
        p.posix.extension(relative).toLowerCase() != '.md') {
      throw const FormatException('Invalid Markdown path.');
    }
    final parents = [..._parts, ...segments.take(segments.length - 1)];
    final available = await _directories(parents, create: content != null);
    final path = p.joinAll([_root, ...parents, segments.last]);
    _check();
    final type = available
        ? await _files.type(path, followLinks: false)
        : FileSystemEntityType.notFound;
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw FileSystemException('Путь заметки занят', path);
    }
    final actual = type == FileSystemEntityType.file
        ? await _files.read(path)
        : null;
    if (actual == content) return;
    _check();
    if (actual != expected) {
      throw FileSystemException('Заметка изменилась во время обмена', path);
    }
    if (content == null) {
      await _files.delete(path);
    } else if (actual == null) {
      await _files.writeNew(path, content);
    } else if (!await _files.replace(path, content, expected: expected)) {
      throw FileSystemException('Заметка изменилась во время обмена', path);
    }
    _changed = true;
  }
}

class _VaultCanvasBoard implements CanvasBoardSession {
  _VaultCanvasBoard(this.vault, this.root, this.sphereId, this.selection);
  final ObsidianVault vault;
  final String root;
  final int selection;
  @override
  String get path =>
      p.join(vault._folderPath(root, vault.folders.boards), '$sphereId.canvas');
  final String sphereId;

  Future<String> _backupPath(String kind) async {
    final directory = vault._folderPath(root, vault.folders.backups);
    await vault._files.createDirectory(directory);
    return p.join(directory, '$sphereId.$kind-${const Uuid().v4()}.canvas');
  }

  void _checkSelection() {
    if (selection != vault._vaultSelectionGeneration) {
      throw StateError('Vault изменён. Откройте граф заново.');
    }
  }

  @override
  String notePath(String absolutePath) {
    _checkSelection();
    absolutePath = vault.resolveNotePath(absolutePath);
    if (!p.isWithin(root, p.normalize(p.absolute(absolutePath)))) {
      throw ArgumentError('Заметка вне выбранного vault.');
    }
    return p.split(p.relative(absolutePath, from: root)).join('/');
  }

  @override
  String resolveNote(String relativePath) {
    _checkSelection();
    final parts = relativePath.replaceAll('\\', '/').split('/');
    if (p.isAbsolute(relativePath) || parts.contains('..')) {
      throw ArgumentError('Неверный путь заметки Canvas.');
    }
    final result = p.normalize(p.joinAll([root, ...parts]));
    if (!p.isWithin(root, result)) throw ArgumentError('Заметка вне vault.');
    return vault.resolveNotePath(result);
  }

  Future<String?> _read() => vault._files.read(path);

  @override
  Future<String?> read() {
    vault._checkActive();
    return vault._enqueue(() {
      _checkSelection();
      return _read();
    });
  }

  @override
  Future<void> write(
    String content, {
    required String? expected,
    bool backupPrevious = false,
  }) {
    vault._checkActive();
    return vault._enqueue(() async {
      _checkSelection();
      return _write(
        vault._rebaseRenamedNotes(content, root),
        expected: expected == null
            ? null
            : vault._rebaseRenamedNotes(expected, root),
        backupPrevious: backupPrevious,
      );
    });
  }

  Future<void> _write(
    String content, {
    required String? expected,
    bool backupPrevious = false,
  }) async {
    _checkSelection();
    final files = vault._files;
    if (await _read() == content && content == expected) return;
    await files.createDirectory(p.dirname(path));
    if (expected == null && await _read() == null) {
      // Keep the initial migrated layout independently of future cache writes.
      await files.writeNew(await _backupPath('migration'), content);
    } else if (backupPrevious && expected != null) {
      await files.writeNew(await _backupPath('sync'), expected);
    }
    if (!await files.replace(path, content, expected: expected)) {
      final recovery = await _backupPath('conflict');
      await files.writeNew(recovery, content);
      throw CanvasBoardConflict(recovery);
    }
  }
}
