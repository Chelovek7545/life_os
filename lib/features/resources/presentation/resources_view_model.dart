import 'package:flutter/material.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/resources/data/obsidian_repository.dart';
import 'package:rxdart/subjects.dart';



class ResourcesViewModel extends ChangeNotifier {
  final GraphNotesRepository _graphNotesRepo;
  final ObsidianRepository _obsidianRepo;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  ResourcesViewModel({required this._graphNotesRepo, required this._obsidianRepo});

  final BehaviorSubject<List<ObsidianNote>> _obsidianNotesSubject =
      BehaviorSubject.seeded(const <ObsidianNote>[]);
  Stream<List<ObsidianNote>> get obsidianNotesStream => _obsidianNotesSubject.stream;
  List<ObsidianNote> get obsidianNotes => _obsidianNotesSubject.value;


  Future<void> scanVault(String vaultPath) async {
    await _obsidianRepo.scanVault(vaultPath, () {
      _isLoading = true;
      notifyListeners();
      }, (e) { _error = e;
      notifyListeners();
      });
    _obsidianRepo.addListener( ()=> _obsidianNotesSubject.add(_obsidianRepo.notes));
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  List<HierarchyNode> getHierarchyTree() {
    return _obsidianRepo.getHierarchyTree();
  }

  Future<void> updateNoteContent(String absolutePath, String text) async {
    _obsidianRepo.updateNoteContent(absolutePath, text);
  }

  // Future<void> createNoteWithText({required String title, required String text, required String obsidianPath}) async {
    
  // }

  List<gv.GraphNote> getAllNotes() {
    return _graphNotesRepo.getAllNotes();
   }





}
