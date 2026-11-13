import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/resources/presentation/widgets/markdown_notes_panel.dart';
import 'package:notes_api/notes_api.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

VaultNote file(
  String name,
  String content, {
  String folder = '',
  int day = 9,
}) => VaultNote(
  absolutePath: '/Notes/${folder.isEmpty ? '' : '$folder/'}$name.md',
  relativePath: '$name.md',
  title: name,
  content: content,
  modifiedAt: DateTime(2026, 11, day, 21, 37),
);

void main() {
  final notes = [
    file(
      'Some thoughts',
      '# Some thoughts\nИдеи и заметки по графу, возможные связи и структура.\n– Узлы: задачи, проекты, заметки…',
    ),
    file(
      'Pulse: идеи',
      '- [x] Карточки заметок\n- [ ] Ворклоги в задачах\n- [ ] Плагин-система',
      folder: 'Идеи',
      day: 8,
    ),
    file(
      'Биокомпьютинг',
      'План развития и изучения:\n1. Базовая нейробиология\n2. Органоиды и MEA',
      folder: 'Проекты',
      day: 7,
    ),
    file(
      'Микробиология',
      '## Пигменты бактерий\n• Каротиноиды — защита от УФ\n• Феназины — антимикробное действие',
      folder: 'Учёба',
      day: 6,
    ),
    file(
      'Draft Template',
      'Шаблон для заметок по лекциям:\n– Структура\n– Основные понятия\n– Схемы и связи',
      day: 5,
    ),
    file(
      'Нейрофизиология',
      'Заметки по потенциалу действия и синаптической передаче.',
      day: 4,
    ),
  ];
  Widget panel({
    required Future<void> Function(VaultNote) onOpen,
    double scale = 1,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: MarkdownNotesPanel(
            state: VaultState(vaultPath: '/Notes', notes: notes),
            onOpen: onOpen,
          ),
        ),
      ),
    ),
  );

  for (final width in [360.0, 1200.0]) {
    testWidgets(
      'a single note is square at width $width with standard typography',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final note = file('Only note', 'This excerpt comes from the file.');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MarkdownNotesPanel(
                  state: VaultState(vaultPath: '/Notes', notes: [note]),
                  onOpen: (_) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final size = tester.getSize(find.byKey(ValueKey(note.absolutePath)));
        expect(size.width, closeTo(size.height, .01));
        expect(size.width, lessThanOrEqualTo(220));
        expect(
          tester
              .widget<Text>(find.text('Markdown-заметки графа'))
              .style!
              .fontSize,
          18,
        );
        expect(
          tester.widget<Text>(find.text('Only note')).style!.fontSize,
          AppTypography.bodyMd.fontSize,
        );
        final preview = tester
            .widgetList<Text>(find.byType(Text))
            .singleWhere(
              (text) =>
                  text.textSpan?.toPlainText().contains(
                    'This excerpt comes from the file.',
                  ) ??
                  false,
            );
        expect(preview.style!.fontSize, AppTypography.bodySm.fontSize);
        expect(
          tester.getSize(find.byWidget(preview)).height,
          greaterThanOrEqualTo(19),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'gallery searches names and Markdown text without mixing source files',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? opened;
      await tester.pumpWidget(
        panel(
          onOpen: (note) async {
            opened = note.absolutePath;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('9 нояб. 2026, 21:37'), findsOneWidget);
      expect(find.text('Идеи'), findsOneWidget);
      final first = tester.getRect(find.text('Some thoughts'));
      final second = tester.getRect(find.text('Pulse: идеи'));
      expect(first.top, lessThan(second.bottom));
      expect(first.left, lessThan(second.left));
      final firstCard = tester.getSize(
        find.byKey(ValueKey(notes.first.absolutePath)),
      );
      expect(firstCard.width, greaterThanOrEqualTo(firstCard.height));
      expect(firstCard.width, lessThan(400));
      expect(firstCard.height, lessThanOrEqualTo(220));
      final secondCard = tester.getSize(
        find.byKey(ValueKey(notes[1].absolutePath)),
      );
      expect(firstCard.width / secondCard.width, closeTo(1.5, .01));
      expect(secondCard.width, greaterThanOrEqualTo(secondCard.height));
      final nextRowFirst = tester.getSize(
        find.byKey(ValueKey(notes[4].absolutePath)),
      );
      final nextRowSecond = tester.getSize(
        find.byKey(ValueKey(notes[5].absolutePath)),
      );
      expect(nextRowSecond.width / nextRowFirst.width, closeTo(1.5, .01));
      await tester.enterText(
        find.byKey(const ValueKey('markdown-search')),
        'КАРОТИНОИДЫ',
      );
      await tester.pumpAndSettle();
      expect(find.text('Микробиология'), findsOneWidget);
      expect(find.text('Some thoughts'), findsNothing);
      await tester.tap(find.text('Микробиология'));
      await tester.pumpAndSettle();
      expect(opened, notes[3].absolutePath);
      await tester.enterText(
        find.byKey(const ValueKey('markdown-search')),
        'нет такого текста',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tester.tap(find.byTooltip('Очистить поиск'));
      await tester.pumpAndSettle();
      expect(find.text('Some thoughts'), findsOneWidget);
      await tester.tap(find.byTooltip('Действия заметки').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      expect(opened, notes[0].absolutePath);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed deletion keeps the note and reports the error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarkdownNotesPanel(
              state: VaultState(vaultPath: '/Notes', notes: [notes.first]),
              onOpen: (_) async {},
              onDelete: (_) async => throw StateError('Access denied'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Действия заметки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить заметку'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('markdown-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Some thoughts'), findsOneWidget);
    expect(find.textContaining('Не удалось удалить заметку:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'the gallery remains usable with a narrow viewport and enlarged text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(panel(onOpen: (_) async {}, scale: 1.7));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('markdown-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const ValueKey('markdown-search')),
        'потенциалу',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Нейрофизиология'));
      expect(find.text('Нейрофизиология'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
