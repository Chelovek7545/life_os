import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:notes_api/notes_api.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/core/ui/hierarchy/build_note_hierarchy.dart';

class ResourcesViewModel extends ChangeNotifier {
  ResourcesViewModel({required NotesCatalog notes, VaultNotesApi? vault})
    : _notes = notes,
      _vault = vault {
    _vaultSubscription = _vault?.watch().listen((_) {
      if (!_disposed) notifyListeners();
    });
    _notesSubscription = _notes.watchNotes().listen((_) {
      if (!_disposed) notifyListeners();
    });
  }
  final NotesCatalog _notes;
  final VaultNotesApi? _vault;
  StreamSubscription<VaultState>? _vaultSubscription;
  StreamSubscription<List<NoteDocument>>? _notesSubscription;
  bool _disposed = false;
  bool get hasVault => _vault != null;
  bool get isLoading => _vault?.state.isLoading ?? false;
  String? get error => _vault?.state.error;
  String get vaultPath => _vault?.state.vaultPath ?? '';
  List<VaultNote> get vaultNotes => _vault?.state.notes ?? const [];
  List<HierarchyNode> getHierarchyTree() => buildVaultHierarchy(vaultNotes);
  Future<void> refreshVault() => _vault?.refresh() ?? Future.value();
  Future<String> readNoteContent(String path) {
    final vault = _vault;
    if (vault == null)
      return Future.error(StateError('Vault plugin is unavailable.'));
    return vault.readContent(path);
  }

  Future<void> updateNoteContent(String path, String text) {
    final vault = _vault;
    if (vault == null)
      return Future.error(StateError('Vault plugin is unavailable.'));
    return vault.writeContent(path, text);
  }

  List<NoteDocument> getAllNotes() => _notes.notes;
  @override
  void dispose() {
    _disposed = true;
    unawaited(_vaultSubscription?.cancel());
    unawaited(_notesSubscription?.cancel());
    super.dispose();
  }
}
