import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_note_creation_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required ValueChanged<GraphNoteCreation?> onResult,
    bool canCreate = true,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showGraphNoteCreationDialog(
                  context,
                  canCreateMarkdown: canCreate,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final (label, expected) in [
    ('Пустой стикер', GraphNoteCreation.sticker),
    ('Из Obsidian', GraphNoteCreation.obsidian),
    ('Из Markdown-хранилища', GraphNoteCreation.markdownLibrary),
    ('Создать .md', GraphNoteCreation.markdownFile),
  ]) {
    testWidgets('$label returns the correct action from the tile menu', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var finished = false;
      GraphNoteCreation? result;
      await open(
        tester,
        onResult: (value) {
          finished = true;
          result = value;
        },
      );
      expect(find.text('Добавить заметку'), findsOneWidget);
      expect(find.text('Отмена'), findsNothing);
      final first = tester.getRect(find.text('Пустой стикер'));
      final last = tester.getRect(find.text('Создать .md'));
      expect(first.left, lessThan(last.left));
      expect((first.center.dy - last.center.dy).abs(), lessThan(12));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, expected);
      expect(find.text('Добавить заметку'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (size, scale) in [
    (const Size(360, 640), 1.7),
    (const Size(640, 360), 1.3),
  ]) {
    testWidgets(
      'menu fits $size with text scale $scale and closes from the header',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var finished = false;
        await open(tester, scale: scale, onResult: (_) => finished = true);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Создать .md'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Закрыть'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Закрыть'));
        await tester.pumpAndSettle();
        expect(finished, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('file creation stays disabled without storage, Escape cancels', (
    tester,
  ) async {
    var finished = false;
    await open(tester, canCreate: false, onResult: (_) => finished = true);
    await tester.tap(find.text('Создать .md'));
    await tester.pumpAndSettle();
    expect(finished, isFalse);
    expect(find.text('Добавить заметку'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });
}
