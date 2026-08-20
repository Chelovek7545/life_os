import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/collapsible_sheet.dart';

import '../../test_helpers.dart';

void main() {
  group('CollapsibleSheet', () {
    Widget createSheet({
      required List<double> snapPoints,
      double? initialHeight,
      bool forceExpanded = false,
      ValueChanged<bool>? onVisibilityChanged,
      List<(double, int)>? received,
    }) {
      return createTestWidget(
        child: SizedBox(
          width: 400,
          height: 600,
          child: CollapsibleSheet(
            snapPoints: snapPoints,
            initialHeight: initialHeight,
            forceExpanded: forceExpanded,
            scrollableBody: false,
            onVisibilityChanged: onVisibilityChanged,
            header: const SizedBox(width: double.infinity, height: 60),
            bodyBuilder: (progress, snapIndex) {
              received?.add((progress, snapIndex));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    /// Центр шапки (верхние 60px) шторки, прижатой к низу контейнера 600px.
    Offset headerCenter(double sheetHeight) =>
        Offset(200, 600 - sheetHeight + 30);

    double sheetHeight(WidgetTester tester) =>
        tester.getSize(find.byType(AnimatedContainer).first).height;

    testWidgets('starts at second snap point by default', (tester) async {
      await tester.pumpWidget(createSheet(snapPoints: const [60, 190, 400]));
      await tester.pumpAndSettle();

      expect(sheetHeight(tester), 190);
    });

    testWidgets('initialHeight overrides default', (tester) async {
      await tester.pumpWidget(
        createSheet(
          snapPoints: const [60, 190, 400],
          initialHeight: 400,
        ),
      );
      await tester.pumpAndSettle();

      expect(sheetHeight(tester), 400);
    });

    testWidgets('forceExpanded ignores snap points and initialHeight',
        (tester) async {
      final received = <(double, int)>[];
      await tester.pumpWidget(
        createSheet(
          snapPoints: const [60, 190, 400],
          initialHeight: 60,
          forceExpanded: true,
          received: received,
        ),
      );
      await tester.pumpAndSettle();

      // Всегда на максимуме: прогресс 1.0, последний снаппоинт.
      expect(received, contains((1.0, 2)));
    });

    testWidgets('snaps to nearest snap point after slow drag', (tester) async {
      final received = <(double, int)>[];
      await tester.pumpWidget(
        createSheet(
          snapPoints: const [60, 200, 350, 500],
          initialHeight: 500,
          received: received,
        ),
      );
      await tester.pumpAndSettle();

      // Тянем вниз: 500 - 80 = 420 -> ближе к 350, чем к 500.
      await tester.dragFrom(headerCenter(500), const Offset(0, 80));
      await tester.pumpAndSettle();

      expect(sheetHeight(tester), 350);
      // На снаппоинте 350 (индекс 2): прогресс сегмента 0.0.
      expect(received.last, (0.0, 2));
    });

    testWidgets('with two snap points there is no middle state', (tester) async {
      await tester.pumpWidget(
        createSheet(
          snapPoints: const [60, 400],
          initialHeight: 400,
        ),
      );
      await tester.pumpAndSettle();

      // Тянем вниз: 400 - 250 = 150 -> ближе к 60.
      await tester.dragFrom(headerCenter(400), const Offset(0, 250));
      await tester.pumpAndSettle();

      expect(sheetHeight(tester), 60);
    });

    testWidgets('fast swipe down goes one step down', (tester) async {
      await tester.pumpWidget(
        createSheet(
          snapPoints: const [60, 190, 400],
          initialHeight: 400,
        ),
      );
      await tester.pumpAndSettle();

      await tester.flingFrom(headerCenter(400), const Offset(0, 120), 1000);
      await tester.pumpAndSettle();

      expect(sheetHeight(tester), 190);
    });

    testWidgets('fast swipe up goes one step up', (tester) async {
      await tester.pumpWidget(
        createSheet(
          snapPoints: const [60, 190, 400],
          initialHeight: 190,
        ),
      );
      await tester.pumpAndSettle();

      await tester.flingFrom(headerCenter(190), const Offset(0, -120), 1000);
      await tester.pumpAndSettle();

      expect(sheetHeight(tester), 400);
    });

    testWidgets('collapsing to minimum reports visibility change',
        (tester) async {
      final visibility = <bool>[];
      await tester.pumpWidget(
        createSheet(
          snapPoints: const [60, 190, 400],
          initialHeight: 400,
          onVisibilityChanged: visibility.add,
        ),
      );
      await tester.pumpAndSettle();

      await tester.flingFrom(headerCenter(400), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(sheetHeight(tester), 60);
      expect(visibility, contains(true));
    });

    testWidgets('drag never exceeds snap point bounds', (tester) async {
      await tester.pumpWidget(
        createSheet(
          snapPoints: const [60, 190, 400],
          initialHeight: 190,
        ),
      );
      await tester.pumpAndSettle();

      // Резко тянем за пределы минимума.
      await tester.dragFrom(headerCenter(190), const Offset(0, 1000));
      await tester.pumpAndSettle();

      expect(sheetHeight(tester), 60);
    });
  });
}
