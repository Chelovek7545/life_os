import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';
import 'package:resources_plugin/resources_plugin.dart' show ResourcesViewModel;

void main() {
  testWidgets(
    'local notes remain available when the vault plugin is disabled',
    (tester) async {
      final notes = GraphNotesRepository();
      final vm = ResourcesViewModel(notes: notes);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourcesScreen(viewModel: vm)),
        ),
      );
      await tester.pump();
      expect(find.text('Ресурсы и Заметки'), findsOneWidget);
      expect(find.text('Интеграция с хранилищем отключена.'), findsOneWidget);
      expect(find.text('Нет локальных стикеров на графах.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      await notes.dispose();
    },
  );
}
