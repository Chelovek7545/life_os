import '../notes_api.dart' show NoteDocument;

class CanvasNote {
  const CanvasNote({
    required this.document,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.index,
  });
  final NoteDocument document;
  final double x;
  final double y;
  final double width;
  final double height;
  final int index;
  String get id => document.id;
  String get text => document.text;
}

abstract interface class CanvasNotesStore {
  Future<List<CanvasNote>?> loadNotes(String sphereId);
  Future<void> saveNotes(String sphereId, List<CanvasNote> notes);
  Future<void> deleteNotes(String sphereId);
}
