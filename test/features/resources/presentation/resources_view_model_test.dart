import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_api/notes_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/resources/presentation/resources_view_model.dart';

class FakeVault extends Fake implements VaultNotesApi {
  int listeners = 0;
  bool fail = false;
  final _changes = StreamController<VaultState>.broadcast();
  @override
  VaultState state = VaultState(
    notes: [
      VaultNote(
        absolutePath: '/note.md',
        relativePath: 'note.md',
        title: 'Note',
        modifiedAt: DateTime(2026, 11, 1),
      ),
    ],
  );
  @override
  Stream<VaultState> watch() => Stream.multi((listener) {
    listeners++;
    listener.add(state);
    final subscription = _changes.stream.listen(listener.add);
    listener.onCancel = () async {
      listeners--;
      await subscription.cancel();
    };
  }, isBroadcast: true);
  @override
  Future<void> refresh() async {
    state = VaultState(
      notes: state.notes,
      error: fail ? 'missing vault' : null,
    );
    _changes.add(state);
  }

  Future<void> close() => _changes.close();
}

void main() {
  test(
    'subscribes once, publishes source state, and cancels its subscriptions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final vault = FakeVault();
      final notes = GraphNotesRepository();
      await notes.init();
      final vm = ResourcesViewModel(notes: notes, vault: vault);
      expect(vm.vaultNotes.single.title, 'Note');
      await vm.refreshVault();
      await vm.refreshVault();
      expect(vault.listeners, 1);
      vault.fail = true;
      await vm.refreshVault();
      expect(vm.error, 'missing vault');
      expect(vm.isLoading, isFalse);
      vm.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(vault.listeners, 0);
      await notes.dispose();
      await vault.close();
    },
  );
}
