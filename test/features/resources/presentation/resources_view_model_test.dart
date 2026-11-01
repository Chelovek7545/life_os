import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/resources/data/obsidian_repository.dart';
import 'package:life_os/features/resources/presentation/resources_view_model.dart';

class FakeVault extends ObsidianRepository {
  int listeners = 0;
  bool fail = false;
  @override
  void addListener(void Function() listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(void Function() listener) {
    listeners--;
    super.removeListener(listener);
  }

  @override
  List<ObsidianNote> get notes => [
    ObsidianNote(
      absolutePath: '/note.md',
      relativePath: 'note.md',
      title: 'Note',
      content: '',
      modifiedAt: DateTime(2026, 10, 31),
    ),
  ];
  @override
  Future<void> scanVault(
    String path,
    Function() onLoading,
    Function(String) onError,
  ) async {
    if (fail) onError('missing vault');
    notifyListeners();
  }
}

void main() {
  test(
    'publishes initial notes, subscribes once and removes the listener',
    () async {
      final vault = FakeVault();
      final notes = GraphNotesRepository(obsidianRepository: vault);
      final vm = ResourcesViewModel(graphNotesRepo: notes, obsidianRepo: vault);
      expect(vm.obsidianNotes.single.title, 'Note');
      await vm.scanVault('/vault');
      await vm.scanVault('/vault');
      expect(vault.listeners, 1);
      expect(vm.obsidianNotes.single.title, 'Note');
      vault.fail = true;
      await vm.scanVault('/missing');
      expect(vm.error, 'missing vault');
      expect(vm.isLoading, isFalse);
      vm.dispose();
      expect(vault.listeners, 0);
      vault.notifyListeners();
      notes.dispose();
      vault.dispose();
    },
  );
}
