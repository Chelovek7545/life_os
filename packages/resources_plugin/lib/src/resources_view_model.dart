import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notes_api/notes_api.dart';

class ResourcesViewModel extends ChangeNotifier {
  ResourcesViewModel({
    required this._notes,
    this._vault,
    bool autoInitialize = true,
  }) {
    if (autoInitialize) {
      try {
        initialize();
      } catch (_) {
        dispose();
        rethrow;
      }
    }
  }
  final NotesCatalog _notes;
  final VaultNotesApi? _vault;
  StreamSubscription<VaultState>? _vaultSubscription;
  StreamSubscription<List<NoteDocument>>? _notesSubscription;
  bool _started = false;
  bool _disposed = false;
  bool _accepting = true;
  String? _vaultError;
  String? _notesError;
  Future<void> _operations = Future.value();
  Future<void>? _closing;
  bool get hasVault => _vault != null;
  bool get isLoading => _vault?.state.isLoading ?? false;
  String? get error => _notesError ?? _vaultError ?? _vault?.state.error;
  String get vaultPath => _vault?.state.vaultPath ?? '';
  List<VaultNote> get vaultNotes =>
      List.unmodifiable(_vault?.state.notes ?? const []);
  List<NoteDocument> getAllNotes() => List.unmodifiable(_notes.notes);

  VaultState? get obsidianState {
    final vault = _vault;
    return vault is NotesLibrarySourcesApi
        ? (vault as NotesLibrarySourcesApi).obsidianState
        : vault?.state;
  }

  VaultState get graphMarkdownState {
    final vault = _vault;
    return vault is NotesLibrarySourcesApi
        ? (vault as NotesLibrarySourcesApi).graphMarkdownState
        : VaultState();
  }

  List<NoteDocument> get markdownNotes {
    final files = <String, NoteDocument>{};
    for (final note in graphMarkdownState.notes) {
      files[note.absolutePath] = NoteDocument(
        id: note.absolutePath,
        text: note.content,
        source: NoteReference(sourceId: 'obsidian', path: note.absolutePath),
      );
    }
    return List.unmodifiable(files.values);
  }

  void initialize() {
    if (!_accepting) throw StateError('Resources module is closed.');
    if (_started) return;
    _started = true;
    _vaultSubscription = _vault?.watch().listen(
      (_) {
        if (_disposed) return;
        _vaultError = null;
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed) return;
        _vaultError = error.toString();
        notifyListeners();
      },
    );
    _notesSubscription = _notes.watchNotes().listen(
      (_) {
        if (_disposed) return;
        _notesError = null;
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed) return;
        _notesError = error.toString();
        notifyListeners();
      },
    );
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (!_accepting) {
      return Future.error(StateError('Resources module is closed.'));
    }
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> refreshVault() =>
      _enqueue(() => _vault?.refresh() ?? Future.value());
  Future<void> flush() => _enqueue(() async {});
  Future<String> readNoteContent(String path) => _enqueue(() {
    final vault = _vault;
    if (vault == null) throw StateError('Vault plugin is unavailable.');
    return vault.readContent(path);
  });
  Future<void> updateNoteContent(String path, String text) => _enqueue(() {
    final vault = _vault;
    if (vault == null) throw StateError('Vault plugin is unavailable.');
    return vault.writeContent(path, text);
  });

  /// Allows widget owners to dispose synchronously while plugin shutdown awaits
  /// the same resource cleanup, including accepted writes and cancellation.
  @override
  void dispose() {
    if (_disposed) return;
    _accepting = false;
    _disposed = true;
    _closing = _close();
    unawaited(_closing!.catchError((Object _, StackTrace _) {}));
    super.dispose();
  }

  Future<void> close() {
    dispose();
    return _closing!;
  }

  Future<void> _close() async {
    await Future.wait([
      _operations,
      Future<void>.sync(() => _vaultSubscription?.cancel()),
      Future<void>.sync(() => _notesSubscription?.cancel()),
    ]);
  }
}
