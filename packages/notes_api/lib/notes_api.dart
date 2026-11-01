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

abstract interface class NotesCatalog {
  List<NoteDocument> get notes;
  Stream<List<NoteDocument>> watchNotes();
}

abstract interface class VaultSettings {
  String get vaultPath;
  Stream<String> watchVaultPath();
}
