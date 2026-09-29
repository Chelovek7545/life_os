import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/resources/data/obsidian_repository.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';
import 'package:mockito/mockito.dart';

class MockGraphNotesRepo extends Mock implements GraphNotesRepository {}
class MockObsidianRepo extends Mock implements ObsidianRepository {
  @override
  List<ObsidianNote> get notes => [];
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
}
class MockLifeGraphViewModel extends Mock implements LifeGraphViewModel {}

void main() {
  group('ResourcesScreen', () {
    testWidgets('renders title and obsidian/local sections', (tester) async {
      final graphNotesRepo = GraphNotesRepository();
      final obsidianRepo = ObsidianRepository();
      // We can mock or use real instances if possible
      // Let's use a dummy or minimal test
      
      // Since LifeGraphViewModel requires many dependencies or can be mocked, let's use Mockito or a fake.
      // Alternatively, let's check if there are other tests we can reference.
    });
  });
}
