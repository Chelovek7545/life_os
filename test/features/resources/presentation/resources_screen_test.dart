import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/resources/data/obsidian_repository.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';
import 'package:life_os/features/resources/presentation/resources_view_model.dart';

void main() {
  testWidgets('renders title and local notes without global dependencies', (tester) async {
    final obsidian = ObsidianRepository();
    final notes = GraphNotesRepository(obsidianRepository: obsidian);
    final viewModel = ResourcesViewModel(graphNotesRepo: notes, obsidianRepo: obsidian);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ResourcesScreen(viewModel: viewModel))));
    expect(find.text('Ресурсы и Заметки'), findsOneWidget);
    expect(find.text('Нет локальных стикеров на графах.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    viewModel.dispose();
    notes.dispose();
    obsidian.dispose();
  });
}
