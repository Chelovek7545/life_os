import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/app_scroll_behavior.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 4, size.height),
        Paint()..color = (x / 4).round().isEven ? Colors.black : Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

void main() {
  testWidgets(
    'weekday cells still blur content behind the calendar under app scrolling effects',
    (tester) async {
      final originalBlur = SettingsService.hasBlur.value;
      SettingsService.hasBlur.value = true;
      addTearDown(() => SettingsService.hasBlur.value = originalBlur);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 700,
                  height: 150,
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _Stripes())),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 20,
                        child: CalendarRow(
                          selectedDate: DateTime(2026, 11, 8),
                          onDaySelected: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byType(DateTimelineCard).first;
      final origin = tester.getTopLeft(find.byKey(key));
      final cardOrigin = tester.getTopLeft(card) - origin;
      final variation = (await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final values = <int>[];
        for (var dx = 12; dx < 52; dx++) {
          values.add(
            bytes[((cardOrigin.dy.round() + 30) * image.width +
                    cardOrigin.dx.round() +
                    dx) *
                4],
          );
        }
        image.dispose();
        values.sort();
        return values.last - values.first;
      }))!;
      expect(
        variation,
        lessThan(35),
        reason: 'The stripes should blend under the frosted weekday card',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
