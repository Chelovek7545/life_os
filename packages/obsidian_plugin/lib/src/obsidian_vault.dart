import 'dart:async';
import 'dart:io';
import 'package:notes_api/notes_api.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class ObsidianVault implements VaultNotesApi {
  ObsidianVault({Stream<FileSystemEvent> Function(Directory)? watchDirectory})
    : _watchDirectory = watchDirectory ?? ((directory) => directory.watch());
  final Stream<FileSystemEvent> Function(Directory) _watchDirectory;
  final _changes = StreamController<VaultState>.broadcast();
  VaultState _state = VaultState();
  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};
  Timer? _debounce;
  Future<void> _tail = Future.value();
  bool _active = false;
  bool _disposed = false;
  Future<void>? _disposal;
  int _generation = 0;
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
  Future<String> readContent(String absolutePath) async {
    _checkActive();
    return _enqueue(() async {
      return File(absolutePath).readAsString();
    });
  }

  @override
  Future<void> writeContent(String absolutePath, String content) async {
    _checkActive();
    return _enqueue(() async {
      final file = File(absolutePath);
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
  Future<VaultNote> createNote(String title, String content) async {
    _checkActive();
    return _enqueue(() async {
      if (state.vaultPath.isEmpty) throw StateError('Vault path is empty.');
      final sanitized = title
          .trim()
          .replaceAll(RegExp(r'[<>:"|?*]'), '_')
          .replaceAll('/', '_')
          .replaceAll(String.fromCharCode(92), '_');
      if (sanitized.isEmpty || sanitized == '.' || sanitized == '..')
        throw ArgumentError.value(title, 'title');
      final file = File(p.join(state.vaultPath, sanitized + '.md'));
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
  }
}
