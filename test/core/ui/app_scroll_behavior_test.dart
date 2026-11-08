import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/app_scroll_behavior.dart';

void main() {
  testWidgets(
    'Material scroll keeps inertia and stretches content at the boundary',
    (tester) async {
      final controller = ScrollController();
      final firstItem = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: SizedBox(
            height: 200,
            child: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemExtent: 50,
              itemBuilder: (_, index) =>
                  SizedBox(key: index == 0 ? firstItem : null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = find.byType(ListView);
      await tester.fling(list, const Offset(0, -150), 1000);
      final released = controller.offset;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(controller.offset, greaterThan(released));
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      final first = find.byKey(firstItem);
      double visibleHeight() =>
          tester.getBottomRight(first).dy - tester.getTopLeft(first).dy;
      final normalHeight = visibleHeight();
      final gesture = await tester.startGesture(tester.getCenter(list));
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.offset, 0);
      expect(visibleHeight(), greaterThan(normalHeight));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(0, 1));
      expect(visibleHeight(), closeTo(normalHeight, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  for (final axis in Axis.values) {
    for (final reverse in [false, true]) {
      testWidgets(
        'fade follows $axis edges with reverse=$reverse and reveals the final item',
        (tester) async {
          final controller = ScrollController();
          final key = GlobalKey();
          var count = 20;
          late StateSetter rebuild;
          await tester.pumpWidget(
            MaterialApp(
              scrollBehavior: const AppScrollBehavior(),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return Center(
                      child: RepaintBoundary(
                        key: key,
                        child: ColoredBox(
                          color: Colors.black,
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: ListView.builder(
                              controller: controller,
                              scrollDirection: axis,
                              reverse: reverse,
                              itemCount: count,
                              itemExtent: 50,
                              itemBuilder: (_, _) =>
                                  const ColoredBox(color: Color(0xFFFF0000)),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<List<int>> edges() async => (await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            int red(int offset) =>
                bytes[((axis == Axis.vertical
                        ? offset * 200 + 100
                        : 100 * 200 + offset) *
                    4)];
            final result = [red(1), red(100), red(198)];
            image.dispose();
            return result;
          }))!;
          final start = await edges();
          expect(start[reverse ? 2 : 0], 255);
          expect(start[reverse ? 0 : 2], lessThan(100));
          controller.jumpTo(100);
          await tester.pumpAndSettle();
          final middle = await edges();
          expect(middle[0], lessThan(100));
          expect(middle[1], 255);
          expect(middle[2], lessThan(100));
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          final end = await edges();
          expect(end[reverse ? 0 : 2], 255);
          rebuild(() => count = 4);
          await tester.pumpAndSettle();
          expect(await edges(), [255, 255, 255]);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        },
      );
    }
  }

  testWidgets(
    'reduced motion uses clamping and custom list physics remain in control',
    (tester) async {
      final controller = ScrollController();
      var reduce = false;
      ScrollPhysics? explicit;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduce),
                child: ListView.builder(
                  controller: controller,
                  physics: explicit,
                  itemCount: 50,
                  itemExtent: 50,
                  itemBuilder: (_, _) => const SizedBox(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.position.physics, isA<ClampingScrollPhysics>());
      expect(find.byType(StretchingOverscrollIndicator), findsOneWidget);
      rebuild(() => reduce = true);
      await tester.pumpAndSettle();
      expect(controller.position.physics, isA<ClampingScrollPhysics>());
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      rebuild(() {
        reduce = false;
        explicit = const NeverScrollableScrollPhysics();
      });
      await tester.pumpAndSettle();
      expect(controller.position.physics.allowUserScrolling, isFalse);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
