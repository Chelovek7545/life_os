import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/presentation/components/calendar_task_hint.dart';

void main() {
  testWidgets(
    'Windows hover keeps semantics stable and clears overlays on scroll and disposal',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: [
                for (final label in ['Alpha', 'Beta'])
                  CalendarTaskHint(
                    message: label,
                    child: SizedBox(
                      height: 60,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('Control $label'),
                      ),
                    ),
                  ),
                const SizedBox(height: 1500),
              ],
            ),
          ),
        ),
      );
      final alpha = find.byType(CalendarTaskHint).first;
      final beta = find.byType(CalendarTaskHint).last;
      final original = tester.getSemantics(alpha);
      expect(original.getSemanticsData().tooltip, 'Alpha');
      final id = original.id;
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(OverlayPortal), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      for (var i = 0; i < 4; i++) {
        await mouse.moveTo(tester.getCenter(alpha));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Alpha'), findsOneWidget);
        expect(tester.getSemantics(alpha).id, id);
        await mouse.moveTo(tester.getCenter(beta));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Alpha'), findsNothing);
        expect(find.text('Beta'), findsOneWidget);
        expect(tester.getSemantics(alpha).id, id);
      }
      scroll.jumpTo(20);
      await tester.pump();
      expect(find.text('Beta'), findsNothing);
      await mouse.moveTo(tester.getCenter(alpha));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
