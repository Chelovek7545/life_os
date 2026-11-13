export 'src/canvas_note.dart';

class NoteReference {
  const NoteReference({required this.sourceId, required this.path});
  final String sourceId;
  final String path;
}

class NoteDocument {
  const NoteDocument({required this.id, required this.text, this.source});
  final String id;
  final String text;
  final NoteReference? source;
}

class VaultNote {
  const VaultNote({
    required this.absolutePath,
    required this.relativePath,
    required this.title,
    required this.modifiedAt,
    this.content = '',
  });
  final String absolutePath;
  final String relativePath;
  final String title;
  final DateTime modifiedAt;
  final String content;
}

class VaultState {
  VaultState({
    this.vaultPath = '',
    List<VaultNote> notes = const [],
    this.isLoading = false,
    this.error,
  }) : notes = List.unmodifiable(notes);
  final String vaultPath;
  final List<VaultNote> notes;
  final bool isLoading;
  final String? error;
}

abstract interface class VaultNotesApi {
  VaultState get state;
  Stream<VaultState> watch();
  Future<void> refresh();
  Future<String> readContent(String absolutePath);
  Future<void> writeContent(String absolutePath, String content);
  Future<VaultNote> createNote(String title, String content);
}

abstract interface class NotesLibrarySourcesApi {
  VaultState get graphMarkdownState;
  VaultState? get obsidianState;
}

abstract interface class VaultCanvasApi {
  String canvasNotePath(String absolutePath);
  Future<String> createCanvas(String sphereId, Map<String, Object?> document);
}

abstract interface class VaultCanvasBoardsApi {
  Future<CanvasBoardSession> openCanvasBoard(String sphereId);
}

abstract interface class CanvasBoardSession {
  String get path;
  String notePath(String absolutePath);
  String resolveNote(String relativePath);
  Future<String?> read();
  Future<void> write(String content, {required String? expected});
}

class CanvasBoardConflict implements Exception {
  const CanvasBoardConflict(this.recoveryPath);
  final String recoveryPath;
  @override
  String toString() =>
      'Canvas изменён снаружи. Копия правок Pulse: $recoveryPath';
}

abstract interface class NotesCatalog {
  List<NoteDocument> get notes;
  Stream<List<NoteDocument>> watchNotes();
}

abstract interface class VaultSettings {
  String get vaultPath;
  Stream<String> watchVaultPath();
}

class VaultFolders {
  const VaultFolders({
    this.boards = 'Pulse/Boards',
    this.notes = 'Pulse/Notes',
    this.exports = 'Pulse/Canvases',
    this.backups = 'Pulse/Backups',
  });
  final String boards;
  final String notes;
  final String exports;
  final String backups;
  Map<String, String> toJson() => {
    'boards': boards,
    'notes': notes,
    'exports': exports,
    'backups': backups,
  };
  factory VaultFolders.fromJson(Map<String, dynamic> value) => VaultFolders(
    boards: value['boards'] as String? ?? 'Pulse/Boards',
    notes: value['notes'] as String? ?? 'Pulse/Notes',
    exports: value['exports'] as String? ?? 'Pulse/Canvases',
    backups: value['backups'] as String? ?? 'Pulse/Backups',
  );
}

abstract interface class CanvasStorageFoldersApi {
  VaultFolders get folders;
  Future<void> configureFolders(VaultFolders folders, {bool copyBoards = true});
  Future<List<String>> listFolders();
}

abstract interface class MarkdownNoteSaveApi {
  Future<String> saveMarkdownCopy(String directory, String title, String text);
}

/// Deletes a Markdown file inside the currently configured graph Notes folder.
/// Canvas cards and their cached content are retained.
abstract interface class MarkdownNoteDeleteApi {
  Future<void> deleteMarkdownNote(String path);
}

class NotePathChange {
  const NotePathChange(this.previousPath, this.path);
  final String previousPath;
  final String path;
}

abstract interface class MarkdownNoteRenameApi {
  Future<String> renameMarkdownNote(String path, String title);
  String resolveNotePath(String path);
  Stream<NotePathChange> watchNoteRenames();
}
