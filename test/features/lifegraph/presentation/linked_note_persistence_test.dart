import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_api/notes_api.dart';
import 'package:path/path.dart' as p;
import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/features/lifegraph/data/drift_graph_deletion.dart';
import 'package:life_os/features/lifegraph/domain/canvas_note.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import '../../../support/test_app.dart';

class PendingVault extends Fake implements VaultNotesApi {
  bool fail = false;
  Completer<void>? gate;
  String text = 'file text';
  @override
  Future<String> readContent(String path) async => text;
  @override
  Future<void> writeContent(String path, String value) async {
    if (fail) throw StateError('write failed');
    await gate?.future;
    text = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DependencyContainer app;
  late Sphere sphere;
  setUp(() async {
    app = await createTestApp(enableObsidian: false);
    sphere = Sphere.create(name: 'Notes');
    await app.spheresRepository.addSphere(sphere);
    await app.graphNotesRepository.saveNotes(sphere.id, [
      CanvasNote(
        document: const NoteDocument(
          id: 'linked',
          text: 'cached text',
          source: NoteReference(sourceId: 'obsidian', path: '/note.md'),
        ),
        x: 0,
        y: 0,
        width: 212,
        height: 150,
        index: 0,
      ),
    ]);
  });
  tearDown(() => app.dispose());
  Future<LifeGraphViewModel> open(VaultNotesApi? vault) async {
    final vm = LifeGraphViewModel(
      spheresRepository: app.spheresRepository,
      goalsRepository: app.goalsRepository,
      projectsRepository: app.projectsRepository,
      tasksRepository: app.tasksRepository,
      positionsRepository: app.graphPositionsRepository,
      notesRepository: app.graphNotesRepository,
      graphBuilder: app.graphBuilder,
      deletion: DriftGraphDeletion(app.database),
      obsidianRepository: vault,
    );
    await vm.switchSphere(sphere.id);
    return vm;
  }

  test(
    'viewed external content is cached for a later session without its source',
    () async {
      final vm = await open(PendingVault());
      expect(vm.notes.single.text, 'file text');
      await vm.dispose();
      final offline = await open(null);
      expect(offline.notes.single.text, 'file text');
      await offline.dispose();
    },
  );
  test(
    'flush waits for the linked file before recording a saved snapshot',
    () async {
      final vault = PendingVault()..gate = Completer<void>();
      final vm = await open(vault);
      expect(vm.notes.single.text, 'file text');
      await vm.updateNoteText('linked', 'edited');
      var done = false;
      final saving = vm.flush().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      vault.gate!.complete();
      await saving;
      expect(vault.text, 'edited');
      expect(
        (await app.graphNotesRepository.loadNotes(sphere.id))!.single.text,
        'edited',
      );
      await vm.dispose();
    },
  );
  test('failed external writes remain unsaved and can be retried', () async {
    final vault = PendingVault()..fail = true;
    final vm = await open(vault);
    await vm.updateNoteText('linked', 'edited');
    await expectLater(vm.flush(), throwsStateError);
    expect(vm.saveStatus.value, GraphSaveStatus.failed);
    expect(
      (await app.graphNotesRepository.loadNotes(sphere.id))!.single.text,
      'cached text',
    );
    vault.fail = false;
    await vm.flush();
    expect(vault.text, 'edited');
    expect(vm.saveStatus.value, GraphSaveStatus.saved);
    await vm.dispose();
  });
  test(
    'disabled sources preserve cached text and expose linked notes as read-only',
    () async {
      final vm = await open(null);
      expect(vm.notes.single.text, 'cached text');
      expect(vm.notes.single.isReadOnly, isTrue);
      await expectLater(
        vm.updateNoteText('linked', 'unsafe edit'),
        throwsStateError,
      );
      expect(vm.notes.single.text, 'cached text');
      await vm.dispose();
    },
  );
  test(
    'app shutdown flushes open graphs before stopping the real vault',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'life_os_shutdown_',
      );
      final file = File(p.join(directory.path, 'note.md'));
      await file.writeAsString('original');
      final previous = SettingsService.obsidianVaultPath.value;
      DependencyContainer? realApp;
      try {
        SettingsService.obsidianVaultPath.value = directory.path;
        realApp = await createTestApp(enableObsidian: true);
        final graphSphere = Sphere.create(name: 'Shutdown');
        await realApp.spheresRepository.addSphere(graphSphere);
        final vm = await realApp.pulseScreenViewModel.openGraph(graphSphere.id);
        await vm.createNoteWithText(
          title: 'Note',
          text: '',
          obsidianPath: file.path,
        );
        await vm.updateNoteText(vm.notes.single.id, 'saved on shutdown');
        await realApp.dispose();
        expect(await file.readAsString(), 'saved on shutdown');
      } finally {
        await realApp?.dispose();
        SettingsService.obsidianVaultPath.value = previous;
        await file.delete();
        await directory.delete();
      }
    },
  );
}
