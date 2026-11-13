import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:notes_api/notes_api.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

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
  ObsidianVault({Stream<FileSystemEvent> Function(Directory)? watchDirectory})
    : _watchDirectory = watchDirectory ?? ((directory) => directory.watch());
  final Stream<FileSystemEvent> Function(Directory) _watchDirectory;
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
        final source = Directory(_folderPath(root, _folders.boards));
        final target = Directory(_folderPath(root, next.boards));
        final copies = <(File, File, String)>[];
        if (await source.exists()) {
          await for (final entity in source.list(followLinks: false)) {
            if (entity is! File ||
                p.extension(entity.path) != '.canvas' ||
                !RegExp(
                  r'^[a-zA-Z0-9_-]+$',
                ).hasMatch(p.basenameWithoutExtension(entity.path))) {
              continue;
            }
            final destination = File(
              p.join(target.path, p.basename(entity.path)),
            );
            final content = await entity.readAsString();
            if (await destination.exists()) {
              if (await destination.readAsString() != content) {
                throw FileSystemException(
                  'В выбранной папке уже есть другая доска',
                  destination.path,
                );
              }
            } else {
              copies.add((entity, destination, content));
            }
          }
        }
        for (final copy in copies) {
          await target.create(recursive: true);
          await copy.$2.create(exclusive: true);
          await copy.$2.writeAsString(copy.$3, flush: true);
        }
        for (final copy in copies) {
          if (await copy.$1.readAsString() != copy.$3) {
            throw FileSystemException(
              'Исходная доска изменилась во время копирования',
              copy.$1.path,
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
      Future<void> visit(Directory directory) async {
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
            result.add(
              p.posix.joinAll(p.split(p.relative(entity.path, from: root))),
            );
            await visit(entity);
          }
        }
      }

      await visit(Directory(root));
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
      final directory = Directory(vaultPath);
      if (!await directory.exists())
        throw FileSystemException('Указанная папка не существует', vaultPath);
      final notes = <VaultNote>[];
      final directories = <Directory>[];
      await _scanDirectory(directory, vaultPath, notes, directories);
      final added = await _syncWatchers(directories, vaultPath, generation);
      if (added && _active && generation == _generation) {
        // Capture changes that happened before a newly indexed directory was watched.
        notes.clear();
        directories.clear();
        await _scanDirectory(directory, vaultPath, notes, directories);
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
    Directory directory,
    String root,
    List<VaultNote> notes,
    List<Directory> directories,
  ) async {
    directories.add(directory);
    await for (final entity in directory.list(followLinks: false)) {
      if (p.basename(entity.path).startsWith('.')) continue;
      if (entity is Directory) {
        await _scanDirectory(entity, root, notes, directories);
      } else if (entity is File &&
          p.extension(entity.path).toLowerCase() == '.md') {
        try {
          notes.add(
            VaultNote(
              absolutePath: entity.absolute.path,
              relativePath: p.relative(entity.path, from: root),
              title: p.basenameWithoutExtension(entity.path),
              modifiedAt: (await entity.stat()).modified,
              content:
                  p.isWithin(
                    _folderPath(root, _folders.notes),
                    entity.absolute.path,
                  )
                  ? await entity.readAsString()
                  : '',
            ),
          );
        } on FileSystemException {
          // Files can disappear between the directory listing and stat.
          if (await entity.exists()) rethrow;
        }
      }
    }
  }

  Future<bool> _syncWatchers(
    List<Directory> directories,
    String root,
    int generation,
  ) async {
    if (!_active || generation != _generation) return false;
    final paths = directories.map((directory) => directory.path).toSet();
    for (final old
        in _watchers.keys.where((path) => !paths.contains(path)).toList()) {
      await _watchers.remove(old)!.cancel();
    }
    var added = false;
    for (final directory in directories) {
      if (!_active || generation != _generation) break;
      if (_watchers.containsKey(directory.path)) continue;
      _watchers[directory.path] = _watchDirectory(directory).listen(
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
      final directory = Directory(_folderPath(root, _folders.exports));
      await directory.create(recursive: true);
      // Every export is a new snapshot; never overwrite an Obsidian document.
      final id = const Uuid().v4();
      final file = File(p.join(directory.path, '$sphereId-$id.canvas'));
      final temporary = File(p.join(directory.path, '.$id.tmp'));
      try {
        await temporary.writeAsString(content, flush: true);
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
      return file.path;
    });
  }

  @override
  Future<String> readContent(String absolutePath) async {
    _checkActive();
    return _enqueue(() async {
      return File(resolveNotePath(absolutePath)).readAsString();
    });
  }

  @override
  Future<void> writeContent(String absolutePath, String content) async {
    _checkActive();
    return _enqueue(() async {
      final file = File(resolveNotePath(absolutePath));
      if (!await file.exists())
        throw FileSystemException('Заметка не найдена', absolutePath);
      final temporary = File(
        p.join(
          file.parent.path,
          '.' +
              p.basename(file.path) +
              '.life-os-' +
              const Uuid().v4() +
              '.tmp',
        ),
      );
      try {
        await temporary.writeAsString(content, flush: true);
        await temporary.rename(file.path);
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
      final modifiedAt = (await file.stat()).modified;
      _publish(
        VaultState(
          vaultPath: state.vaultPath,
          notes: [
            for (final note in state.notes)
              if (p.equals(note.absolutePath, file.absolute.path))
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
          await FileSystemEntity.type(target, followLinks: false) !=
              FileSystemEntityType.file) {
        throw ArgumentError('Удалять можно только .md файлы из папки Notes.');
      }
      final file = File(target);
      final resolvedFolder = await Directory(
        notesFolder,
      ).resolveSymbolicLinks();
      final resolvedFile = await file.resolveSymbolicLinks();
      if (!p.isWithin(resolvedFolder, resolvedFile)) {
        throw ArgumentError('Файл находится за пределами папки Notes.');
      }
      checkSelection();
      await file.delete();
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
      final directory = Directory(_folderPath(root, _folders.notes));
      await directory.create(recursive: true);
      final stem = p.extension(sanitized).toLowerCase() == '.md'
          ? p.basenameWithoutExtension(sanitized)
          : sanitized;
      final file = File(p.join(directory.path, '$stem.md'));
      await file.create(exclusive: true);
      await file.writeAsString(content, flush: true);
      final note = VaultNote(
        absolutePath: file.absolute.path,
        relativePath: p.relative(file.path, from: state.vaultPath),
        title: sanitized,
        modifiedAt: (await file.stat()).modified,
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
    final directory = Directory(_folderPath(root, folders.boards));
    if (!await directory.exists()) return;
    await for (final file in directory.list(followLinks: false)) {
      if (file is! File ||
          p.extension(file.path) != '.canvas' ||
          !RegExp(
            r'^[a-zA-Z0-9_-]+$',
          ).hasMatch(p.basenameWithoutExtension(file.path))) {
        continue;
      }
      final raw = await file.readAsString();
      final updated = _rewriteNotePaths(
        raw,
        root,
        (path) => p.equals(path, previous) ? next : path,
      );
      if (updated == raw) continue;
      final board = _VaultCanvasBoard(
        this,
        root,
        p.basenameWithoutExtension(file.path),
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
      final original = File(previous);
      final content = await original.readAsString();
      final destination = File(next);
      await destination.create(exclusive: true);
      await destination.writeAsString(content, flush: true);
      try {
        await _remapBoardReferences(previous, next);
        await updateReferences?.call(previous, next);
        if (selection != _vaultSelectionGeneration) {
          throw StateError('Хранилище изменено.');
        }
        if (await original.readAsString() != content) {
          throw StateError(
            'Исходная заметка изменилась во время переименования.',
          );
        }
        _registerRenamedPath(previous, next);
        await original.delete();
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
      final folder = Directory(p.normalize(directory));
      if (!await folder.exists()) {
        throw FileSystemException('Папка не найдена', folder.path);
      }
      final file = File(p.join(folder.path, '$stem.md'));
      await file.create(exclusive: true);
      await file.writeAsString(text, flush: true);
      return file.path;
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
    final directory = Directory(vault._folderPath(root, vault.folders.backups));
    await directory.create(recursive: true);
    return p.join(
      directory.path,
      '$sphereId.$kind-${const Uuid().v4()}.canvas',
    );
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

  Future<String?> _read() async {
    final file = File(path);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<String?> read() {
    vault._checkActive();
    return vault._enqueue(() {
      _checkSelection();
      return _read();
    });
  }

  @override
  Future<void> write(String content, {required String? expected}) {
    vault._checkActive();
    return vault._enqueue(() async {
      _checkSelection();
      return _write(
        vault._rebaseRenamedNotes(content, root),
        expected: expected == null
            ? null
            : vault._rebaseRenamedNotes(expected, root),
      );
    });
  }

  Future<void> _write(String content, {required String? expected}) async {
    _checkSelection();
    final directory = Directory(p.dirname(path));
    await directory.create(recursive: true);
    final temporary = File(p.join(directory.path, '.${const Uuid().v4()}.tmp'));
    try {
      await temporary.writeAsString(content, flush: true);
      // Compare complete bytes-as-text immediately before replacement, not mtimes.
      if (await _read() != expected) {
        final recovery = await _backupPath('conflict');
        await temporary.rename(recovery);
        throw CanvasBoardConflict(recovery);
      }
      if (expected == null) {
        // Keep the initial migrated layout independently of future cache writes.
        await File(
          await _backupPath('migration'),
        ).writeAsString(content, flush: true);
      }
      if (await _read() != expected) {
        final recovery = await _backupPath('conflict');
        await temporary.rename(recovery);
        throw CanvasBoardConflict(recovery);
      }
      await temporary.rename(path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
