import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';

const spec = GraphNodeComponentSpec(
  kind: 'custom.metric',
  label: 'МЕТРИКА',
  icon: Icons.analytics,
  size: Size(200, 140),
  editTitle: 'Изменить метрику',
  createTitle: 'Добавить метрику',
);

Future<void> open(
  WidgetTester tester,
  Widget dialog, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => dialog),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'arbitrary node kinds render supplied badges and retain card interactions',
    (tester) async {
      var edits = 0;
      var additions = 0;
      var collapses = 0;
      var removals = 0;
      var drags = 0;
      final custom = GraphNodeComponentSpec(
        kind: spec.kind,
        label: spec.label,
        icon: spec.icon,
        size: spec.size,
        editTitle: spec.editTitle,
        createTitle: spec.createTitle,
        badge: (_, _) => const Text('42 измерения'),
      );
      final card = GraphNodeCard(
        node: GraphNodeData(
          id: 'metric',
          kind: spec.kind,
          title: 'Точность',
          color: 'invalid',
        ),
        spec: custom,
        state: GraphNodeInteraction(
          size: spec.size,
          selected: false,
          hasChildren: true,
          collapsed: true,
          hiddenCount: 3,
          accent: Colors.pink,
          select: () {},
          toggleCollapse: () => collapses++,
          dragStart: (_) => drags++,
          dragUpdate: (_) {},
          dragEnd: (_) {},
        ),
        onTap: () => edits++,
        onAddChild: () => additions++,
        onDelete: () => removals++,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: spec.size.width,
                height: spec.size.height,
                child: card,
              ),
            ),
          ),
        ),
      );
      expect(find.text('МЕТРИКА'), findsOneWidget);
      expect(find.text('42 измерения'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      await tester.tap(find.byTooltip('Добавить элемент'));
      await tester.pumpAndSettle();
      expect(additions, 1);
      await tester.tapAt(
        tester.getCenter(find.byTooltip('Развернуть ветку')) -
            const Offset(0, 5),
      );
      await tester.pumpAndSettle();
      expect(collapses, 1);
      await tester.longPress(find.text('Точность'));
      expect(edits, 1);
      await tester.drag(find.text('Точность'), const Offset(35, 20));
      expect(drags, 1);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Точность')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      expect(removals, 1);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generic editing preserves identity, scope and unknown attributes through retries',
    (tester) async {
      final original = GraphNodeData(
        id: 'metric',
        kind: spec.kind,
        title: 'Before',
        subtitle: 'Details',
        color: '#123456',
        parentId: 'owner',
        inheritParentColor: true,
        attributes: {'unit': 'km', 'value': 12},
      );
      GraphNodeData? saved;
      var attempts = 0;
      final custom = GraphNodeComponentSpec(
        kind: spec.kind,
        label: spec.label,
        icon: spec.icon,
        size: spec.size,
        editTitle: spec.editTitle,
        createTitle: spec.createTitle,
        editFields: (_, attributes, onChanged) => TextButton(
          onPressed: () => onChanged({'value': 24}),
          child: Text('Значение ${attributes['value']}'),
        ),
      );
      await open(
        tester,
        GraphNodeEditDialog(
          node: original,
          spec: custom,
          onDelete: (_) async {},
          onSave: (value) async {
            saved = value;
            if (++attempts == 1) throw StateError('Retry');
          },
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'After');
      await tester.tap(find.text('Значение 12'));
      await tester.pump();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось выполнить действие. Повторите попытку.'),
        findsOneWidget,
      );
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Значение 24'), findsOneWidget);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(saved!.kind, spec.kind);
      expect(saved!.id, original.id);
      expect(saved!.parentId, original.parentId);
      expect(saved!.inheritParentColor, isTrue);
      expect(saved!.attributes, {'unit': 'km', 'value': 24});
      expect(saved!.title, 'After');
      expect(() => saved!.attributes.clear(), throwsUnsupportedError);
      expect(find.byType(GraphNodeEditDialog), findsNothing);
    },
  );

  testWidgets(
    'generic creation snapshots additional fields, rejects duplicate submissions and preserves a failed draft',
    (tester) async {
      final gate = Completer<void>();
      GraphNodeDraft? saved;
      var attempts = 0;
      final custom = GraphNodeComponentSpec(
        kind: spec.kind,
        label: spec.label,
        icon: spec.icon,
        size: spec.size,
        editTitle: spec.editTitle,
        createTitle: spec.createTitle,
        createFields: (_, attributes, onChanged) => TextButton(
          onPressed: () => onChanged({'unit': 'km'}),
          child: Text('Единица ${attributes['unit'] ?? 'не выбрана'}'),
        ),
      );
      await open(
        tester,
        GraphChildCreateDialog(
          spec: custom,
          onSave: (draft) async {
            saved = draft;
            if (++attempts == 1) {
              await gate.future;
              throw StateError('Retry');
            }
          },
        ),
      );
      await tester.tap(find.text('Создать'));
      await tester.pump();
      expect(attempts, 0);
      await tester.enterText(find.byType(TextField).first, 'Distance');
      await tester.tap(find.text('Единица не выбрана'));
      await tester.pump();
      await tester.tap(find.text('Создать'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(attempts, 1);
      expect(saved!.attributes, {'unit': 'km'});
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Единица km'), findsOneWidget);
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(saved!.kind, spec.kind);
      expect(find.byType(GraphChildCreateDialog), findsNothing);
    },
  );

  testWidgets(
    'generic edit forwards keepChildren and allows retry after a failed deletion',
    (tester) async {
      var attempts = 0;
      await open(
        tester,
        GraphNodeEditDialog(
          node: GraphNodeData(
            id: 'metric',
            kind: spec.kind,
            title: 'Metric',
            color: '#123456',
          ),
          spec: spec,
          onSave: (_) async {},
          onDelete: (keep) async {
            expect(keep, isTrue);
            if (++attempts == 1) throw StateError('Retry');
          },
        ),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Сохранить детей (станут невидимыми)'));
        await tester.pumpAndSettle();
        if (i == 0) expect(find.byType(GraphNodeEditDialog), findsOneWidget);
      }
      expect(attempts, 2);
      expect(find.byType(GraphNodeEditDialog), findsNothing);
    },
  );

  testWidgets(
    'forms fit a narrow screen with larger text and use the supplied theme palette',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final palette = GraphComponentPalette(
        surface: Colors.white,
        surfaceBright: Colors.white,
        surfaceDim: Colors.white,
        surfaceContainer: Colors.yellow,
        surfaceContainerHigh: Colors.white,
        onSurface: Colors.black,
        onSurfaceVariant: Colors.black,
        borderGlass: Colors.black,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [palette]),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: GraphChildCreateDialog(spec: spec, onSave: (_) async {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
        Colors.yellow,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
