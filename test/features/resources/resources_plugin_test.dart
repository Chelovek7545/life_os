import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_api/notes_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:resources_plugin/resources_plugin.dart';
import '../../support/memory_graph_sources.dart';
import '../lifegraph/support/plugin_harness.dart';

void main() {
  test(
    'resources works without a vault and subscribes to the catalog once',
    () async {
      final notes = MemoryCanvasNotes();
      final ui = PluginUiRegistry();
      notes.source.emit([const NoteDocument(id: 'local', text: 'Cached text')]);
      final module = ResourcesPlugin(
        notes: notes,
        ui: ui,
        screen: (_, _) => const Text('Library'),
      );
      final host = PluginHost(module.plugins);
      await host.start();
      final model = module.viewModel;
      model.initialize();
      expect(model.hasVault, isFalse);
      expect(model.getAllNotes().single.text, 'Cached text');
      expect(notes.source.listeners, hasLength(1));
      expect(() => model.getAllNotes().clear(), throwsUnsupportedError);
      await expectLater(model.readNoteContent('unknown'), throwsStateError);
      await host.stop();
      expect(notes.source.listeners, isEmpty);
      expect(ui.screens, isEmpty);
      ui.dispose();
    },
  );

  test(
    'resource writes finish before source shutdown and old models reject new work',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      await h.host.start();
      final model = h.resources.viewModel;
      h.vault.writeGate = Completer<void>();
      h.vault.writeEntered = Completer<void>();
      final saving = model.updateNoteContent('library.md', 'Saved');
      await h.vault.writeEntered!.future;
      var stopped = false;
      final closing = h.host.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      expect(h.vault.stopped, isFalse);
      await expectLater(
        model.updateNoteContent('library.md', 'Stale'),
        throwsStateError,
      );
      h.vault.writeGate!.complete();
      await saving;
      await closing;
      expect(h.vault.files['library.md'], 'Saved');
      expect(h.vault.events, ['write:library.md', 'source.stop']);
      await h.host.start();
      expect(h.resources.viewModel, isNot(same(model)));
      expect(
        await h.resources.viewModel.readNoteContent('library.md'),
        'Saved',
      );
    },
  );

  test(
    'resource shutdown waits for accepted reads and asynchronous cancellation',
    () async {
      final notes = MemoryCanvasNotes();
      final vault = MemoryVault();
      final model = ResourcesViewModel(notes: notes, vault: vault);
      vault.files['note'] = 'Text';
      vault.readGate = Completer<void>();
      vault.readEntered = Completer<void>();
      notes.source.cancelGate = Completer<void>();
      final reading = model.readNoteContent('note');
      await vault.readEntered!.future;
      var closed = false;
      final closing = model.close().then((_) => closed = true);
      vault.readGate!.complete();
      expect(await reading, 'Text');
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      notes.source.cancelGate!.complete();
      await closing;
      expect(notes.source.listeners, isEmpty);
      expect(vault.source.listeners, isEmpty);
      await expectLater(model.refreshVault(), throwsStateError);
    },
  );

  test(
    'source errors are observable and a later snapshot restores the resource model',
    () async {
      final notes = MemoryCanvasNotes();
      final vault = MemoryVault();
      final model = ResourcesViewModel(notes: notes, vault: vault);
      await Future<void>.delayed(Duration.zero);
      notes.source.addError(StateError('Catalog interrupted'));
      await Future<void>.delayed(Duration.zero);
      expect(model.error, contains('Catalog interrupted'));
      notes.source.emit([const NoteDocument(id: 'n', text: 'Recovered')]);
      await Future<void>.delayed(Duration.zero);
      expect(model.error, isNull);
      expect(model.getAllNotes().single.text, 'Recovered');
      vault.failWrite = true;
      await expectLater(
        model.updateNoteContent('note', 'First'),
        throwsStateError,
      );
      await model.updateNoteContent('note', 'Retry');
      expect(vault.files['note'], 'Retry');
      await model.close();
    },
  );

  test(
    'failed resource registration and partial initialization release both sources',
    () async {
      final notes = MemoryCanvasNotes();
      final vault = MemoryVault();
      final ui = PluginUiRegistry();
      final module = ResourcesPlugin(
        notes: notes,
        vault: vault,
        ui: ui,
        screen: (_, _) => const SizedBox(),
      );
      final host = PluginHost(module.plugins);
      notes.source.failWatch = true;
      await expectLater(host.start(), throwsA(isA<PluginLifecycleException>()));
      expect(vault.source.listeners, isEmpty);
      expect(notes.source.listeners, isEmpty);
      expect(() => module.viewModel, throwsStateError);
      notes.source.failWatch = false;
      ui.register(
        'existing',
        screens: [
          PluginScreenContribution(
            id: 'resources',
            label: 'Existing',
            icon: Icons.home,
            builder: (_, _) => const SizedBox(),
          ),
        ],
      );
      await expectLater(host.start(), throwsA(isA<PluginLifecycleException>()));
      expect(ui.screens.single.label, 'Existing');
      expect(vault.source.listeners, isEmpty);
      expect(notes.source.listeners, isEmpty);
      await host.stop();
      ui.dispose();
    },
  );

  test(
    'a cancellation failure still drains the pending resource write and other source',
    () async {
      final notes = MemoryCanvasNotes();
      final vault = MemoryVault();
      final model = ResourcesViewModel(notes: notes, vault: vault);
      notes.source.failCancel = true;
      vault.writeGate = Completer<void>();
      vault.writeEntered = Completer<void>();
      final writing = model.updateNoteContent('note', 'Saved');
      await vault.writeEntered!.future;
      final closing = expectLater(model.close(), throwsStateError);
      vault.writeGate!.complete();
      await writing;
      await closing;
      expect(vault.files['note'], 'Saved');
      expect(vault.source.listeners, isEmpty);
      expect(notes.source.listeners, isEmpty);
    },
  );
}
