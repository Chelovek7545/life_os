import 'dart:async';
import 'package:graph_api/graph_api.dart';
import 'package:notes_api/notes_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_api/goals_api.dart';

class MemorySource<T> {
  MemorySource(this.value);
  T value;
  final listeners = <MultiStreamController<T>>{};
  bool failWatch = false;
  bool failCancel = false;
  Completer<void>? cancelGate;
  Stream<T> watch() {
    if (failWatch) throw StateError('Source failed');
    return Stream.multi((sink) {
      listeners.add(sink);
      sink.add(value);
      sink.onCancel = () async {
        await cancelGate?.future;
        listeners.remove(sink);
        if (failCancel) throw StateError('Cancellation failed');
      };
    });
  }

  void emit(T next) {
    value = next;
    for (final sink in listeners) {
      sink.add(next);
    }
  }

  void addError(Object error) {
    for (final sink in listeners) {
      sink.addError(error);
    }
  }
}

class MemorySpheres implements SpheresApi {
  final items = <String, Sphere>{};
  final source = MemorySource<List<Sphere>>([]);
  @override
  Stream<List<Sphere>> watchAllSpheres() => source.watch();
  @override
  Future<List<Sphere>> getAllSpheres() async => items.values.toList();
  @override
  Future<Sphere?> getSphere(String id) async => items[id];
  @override
  Future<void> addSphere(Sphere sphere) async {
    items[sphere.id] = sphere;
    source.emit(items.values.toList());
  }

  @override
  Future<void> updateSphere(Sphere sphere) => addSphere(sphere);
  @override
  Future<void> deleteSphere(String id) async {
    items.remove(id);
    source.emit(items.values.toList());
  }
}

class MemoryGoals implements GoalsQueries {
  final source = MemorySource<List<Goal>>([]);
  @override
  Stream<List<Goal>> watchAllGoals() => source.watch();
  @override
  Stream<List<Goal>> watchGoalsBySphere(String id) => source.watch().map(
    (goals) => goals.where((goal) => goal.sphereId == id).toList(),
  );
  @override
  Future<List<Goal>> getAllGoals() async => source.value;
  @override
  Future<List<Goal>> getGoalsBySphere(String id) async =>
      source.value.where((goal) => goal.sphereId == id).toList();
  @override
  Future<Goal?> getGoal(String id) async {
    for (final goal in source.value) {
      if (goal.id == id) return goal;
    }
    return null;
  }
}

class MemoryPositions implements GraphPositionsStore {
  final values = <String, Map<String, GraphPoint>>{};
  String? last;
  Completer<void>? loadGate;
  Completer<void>? loadEntered;
  bool failLoad = false;
  @override
  Future<Map<String, GraphPoint>?> loadPositions(String id) async {
    if (loadEntered case final signal? when !signal.isCompleted) {
      signal.complete();
    }
    await loadGate?.future;
    if (failLoad) throw StateError('Could not read positions');
    return values[id];
  }

  @override
  Future<void> savePositions(
    String id,
    Map<String, GraphPoint> positions,
  ) async => values[id] = Map.unmodifiable(positions);
  @override
  Future<void> deletePositions(String id) async => values.remove(id);
  @override
  Future<String?> loadLastSphereId() async => last;
  @override
  Future<void> saveLastSphereId(String id) async => last = id;
}

class MemoryCanvasNotes implements CanvasNotesStore, NotesCatalog {
  final values = <String, List<CanvasNote>>{};
  final source = MemorySource<List<NoteDocument>>([]);
  Completer<void>? writeGate;
  Completer<void>? writeEntered;
  bool failWrite = false;
  @override
  List<NoteDocument> get notes => source.value;
  @override
  Stream<List<NoteDocument>> watchNotes() => source.watch();
  @override
  Future<List<CanvasNote>?> loadNotes(String id) async => values[id];
  @override
  Future<void> saveNotes(String id, List<CanvasNote> notes) async {
    if (writeEntered case final signal? when !signal.isCompleted) {
      signal.complete();
    }
    await writeGate?.future;
    if (failWrite) throw StateError('Note save failed');
    values[id] = List.unmodifiable(notes);
    source.emit([
      for (final group in values.values)
        for (final note in group) note.document,
    ]);
  }

  @override
  Future<void> deleteNotes(String id) async {
    values.remove(id);
    source.emit([
      for (final group in values.values)
        for (final note in group) note.document,
    ]);
  }
}

class MemoryVault implements VaultNotesApi {
  final source = MemorySource<VaultState>(VaultState());
  final files = <String, String>{};
  final events = <String>[];
  bool stopped = false;
  bool failWrite = false;
  Completer<void>? writeGate;
  Completer<void>? writeEntered;
  Completer<void>? readGate;
  Completer<void>? readEntered;
  @override
  VaultState get state => source.value;
  @override
  Stream<VaultState> watch() => source.watch();
  @override
  Future<void> refresh() async => source.emit(source.value);
  @override
  Future<String> readContent(String path) async {
    if (readEntered case final signal? when !signal.isCompleted) {
      signal.complete();
    }
    await readGate?.future;
    if (stopped) throw StateError('Vault stopped before read finished');
    return files[path] ?? '';
  }

  @override
  Future<void> writeContent(String path, String text) async {
    if (writeEntered case final signal? when !signal.isCompleted) {
      signal.complete();
    }
    await writeGate?.future;
    if (stopped) throw StateError('Vault stopped before write finished');
    if (failWrite) {
      failWrite = false;
      throw StateError('Vault write failed');
    }
    files[path] = text;
    events.add('write:$path');
    source.emit(state);
  }

  @override
  Future<VaultNote> createNote(String title, String content) async {
    final note = VaultNote(
      absolutePath: title,
      relativePath: title,
      title: title,
      modifiedAt: DateTime(2026),
      content: content,
    );
    await writeContent(title, content);
    return note;
  }
}
