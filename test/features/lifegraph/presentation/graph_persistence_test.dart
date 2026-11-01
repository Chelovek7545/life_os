import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import '../../../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DependencyContainer app;
  setUp(() async {
    app = await createTestApp();
  });
  tearDown(() => app.dispose());

  test('closing a graph immediately persists the latest note text', () async {
    final sphere = Sphere.create(name: 'First');
    await app.spheresRepository.addSphere(sphere);
    final vm = await app.pulseScreenViewModel.openGraph(sphere.id);
    await vm.createNote();
    await vm.updateNoteText(vm.notes.single.id, 'saved before debounce');
    await vm.dispose();
    final saved = await app.graphNotesRepository.loadNotes(sphere.id);
    expect(saved!.single.text, 'saved before debounce');
  });

  test(
    'switching spheres saves the old snapshot under its original sphere',
    () async {
      final first = Sphere.create(name: 'First');
      final second = Sphere.create(name: 'Second');
      await app.spheresRepository.addSphere(first);
      await app.spheresRepository.addSphere(second);
      final vm = await app.pulseScreenViewModel.openGraph(first.id);
      await vm.createNote();
      await vm.updateNoteText(vm.notes.single.id, 'first sphere');
      await vm.switchSphere(second.id);
      expect(vm.notes, isEmpty);
      expect(
        (await app.graphNotesRepository.loadNotes(first.id))!.single.text,
        'first sphere',
      );
      await vm.createNote();
      await vm.updateNoteText(vm.notes.single.id, 'second sphere');
      await vm.flush();
      expect(vm.saveStatus.value, GraphSaveStatus.saved);
      expect(
        (await app.graphNotesRepository.loadNotes(second.id))!.single.text,
        'second sphere',
      );
      await vm.dispose();
    },
  );
}
