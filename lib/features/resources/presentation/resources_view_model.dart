import 'package:flutter/foundation.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/resources/data/obsidian_repository.dart';
import 'package:rxdart/subjects.dart';

class ResourcesViewModel extends ChangeNotifier {
  ResourcesViewModel({
    required GraphNotesRepository graphNotesRepo,
    required ObsidianRepository obsidianRepo,
  }) : _graphNotesRepo = graphNotesRepo,
       _obsidianRepo = obsidianRepo {
    _obsidianRepo.addListener(_onNotesChanged);
    _graphNotesRepo.addListener(_onGraphNotesChanged);
    _onNotesChanged();
  }
  final GraphNotesRepository _graphNotesRepo;
  final ObsidianRepository _obsidianRepo;
  final _obsidianNotesSubject = BehaviorSubject<List<ObsidianNote>>.seeded(
    const [],
  );
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;
  int _scanGeneration = 0;
  Future<void> _scanQueue = Future.value();

  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<List<ObsidianNote>> get obsidianNotesStream =>
      _obsidianNotesSubject.stream;
  List<ObsidianNote> get obsidianNotes => _obsidianNotesSubject.value;

  void _onNotesChanged() {
    if (_disposed) return;
    _obsidianNotesSubject.add(List.unmodifiable(_obsidianRepo.notes));
    notifyListeners();
  }

  void _onGraphNotesChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> scanVault(String vaultPath) {
    final generation = ++_scanGeneration;
    final result = _scanQueue.then((_) async {
      if (_disposed || generation != _scanGeneration) return;
      _isLoading = true;
      _error = null;
      notifyListeners();
      try {
        await _obsidianRepo.scanVault(vaultPath, () {}, (error) {
          if (!_disposed && generation == _scanGeneration) _error = error;
        });
      } catch (error) {
        if (!_disposed && generation == _scanGeneration)
          _error = error.toString();
      } finally {
        if (!_disposed && generation == _scanGeneration) {
          _isLoading = false;
          notifyListeners();
        }
      }
    });
    _scanQueue = result;
    return result;
  }

  Future<void> get pendingScan => _scanQueue;
  List<HierarchyNode> getHierarchyTree() => _obsidianRepo.getHierarchyTree();
  Future<void> updateNoteContent(String absolutePath, String text) =>
      _obsidianRepo.updateNoteContent(absolutePath, text);
  List<gv.GraphNote> getAllNotes() => _graphNotesRepo.getAllNotes();

  @override
  void dispose() {
    _disposed = true;
    _scanGeneration++;
    _obsidianRepo.removeListener(_onNotesChanged);
    _graphNotesRepo.removeListener(_onGraphNotesChanged);
    _obsidianNotesSubject.close();
    super.dispose();
  }
}
