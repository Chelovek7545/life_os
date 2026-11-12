import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart';
import 'package:notes_api/notes_api.dart';
import 'package:spheres_api/spheres_api.dart';
import '../../../support/test_app.dart';

class ExportVault extends Fake implements VaultNotesApi, VaultCanvasApi {
  Map<String, Object?>? document;
  @override
  VaultState get state => VaultState(vaultPath: '/test-vault');
  @override
  String canvasNotePath(String absolutePath) => 'Notes/note.md';
  @override
  Future<String> createCanvas(
    String sphereId,
    Map<String, Object?> value,
  ) async {
    document = value;
    return '/test-vault/$sphereId.canvas';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DependencyContainer app;
  late Sphere sphere;
  setUp(() async {
    app = await createTestApp(enableObsidian: false);
    sphere = Sphere.create(name: 'Canvas sphere');
    await app.spheresRepository.addSphere(sphere);
  });
  tearDown(() => app.dispose());
  Future<LifeGraphViewModel> open(VaultNotesApi? vault) async {
    final vm = LifeGraphViewModel(
      spheresRepository: app.spheresRepository,
      positionsRepository: app.graphPositionsRepository,
      notesRepository: app.graphNotesRepository,
      graphBuilder: app.graphBuilder,
      nodePresentations: app.graphPresentations,
      nodeEditors: app.graphEditors,
      commands: app.graphCommands,
      obsidianRepository: vault,
    );
    addTearDown(vm.dispose);
    await vm.switchSphere(sphere.id);
    await vm.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
    return vm;
  }

  test('export flushes latest positions and pending note text', () async {
    final vault = ExportVault();
    final vm = await open(vault);
    expect(vm.canExportCanvas, isTrue);
    vm.commitMove(sphere.id, 150, 250);
    await vm.createNote();
    await vm.updateNoteText(vm.notes.single.id, 'last edit');
    expect(await vm.exportCanvas(), endsWith('${sphere.id}.canvas'));
    final nodes = vault.document!['nodes'] as List;
    expect(nodes[0]['x'], 150);
    expect(nodes[0]['y'], 250);
    expect(nodes[0]['text'], contains('Canvas sphere'));
    expect(nodes[1]['text'], 'last edit');
    expect(
      (await app.graphNotesRepository.loadNotes(sphere.id))!.single.text,
      'last edit',
    );
    expect(
      (await app.graphPositionsRepository.loadPositions(sphere.id))![sphere.id],
      const GraphPoint(150, 250),
    );
  });
  test('export unavailable without a vault and after graph disposal', () async {
    final vm = await open(null);
    expect(vm.canExportCanvas, isFalse);
    await expectLater(vm.exportCanvas(), throwsStateError);
    await vm.dispose();
    await expectLater(vm.exportCanvas(), throwsStateError);
  });

  testWidgets('graph export control writes a canvas and shows its location', (
    tester,
  ) async {
    final vault = ExportVault();
    final vm = await tester.runAsync(() => open(vault));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: LifeGraphScreen(viewModel: vm!)),
      );
      await vm.refreshNotes();
      await tester.pump();
      await tester.tap(find.byTooltip('Экспорт Canvas'));
      await vm.flush();
    });
    await tester.pumpAndSettle();
    expect(vault.document, isNotNull);
    expect(
      find.text('Canvas сохранён: /test-vault/${sphere.id}.canvas'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await vm!.dispose();
    });
    await tester.pumpAndSettle();
  });
}
