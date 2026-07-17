import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';

import '../../../../test_helpers.dart';

Widget createDayCard({
  String day = '15',
  String weekday = 'mon',
  bool isSelected = false,
  VoidCallback? onTap,
}) {
  return createTestWidget(
    child: DateTimelineCard(
      day: day,
      weekday: weekday,
      isSelected: isSelected,
      onTap: onTap ?? () {},
    ),
  );
}

void main() {
  group('DateTimelineCard', () {
    testWidgets('renders day and weekday text', (tester) async {
      await tester.pumpWidget(createDayCard(day: '20', weekday: 'sat'));

      expect(find.text('20'), findsOneWidget);
      expect(find.text('sat'), findsOneWidget);
    });

    testWidgets('renders with divider between weekday and day', (tester) async {
      await tester.pumpWidget(createDayCard());

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(createDayCard(onTap: () => tapped = true));

      await tester.tap(find.byType(DateTimelineCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('isSelected false renders without gradient', (tester) async {
      await tester.pumpWidget(createDayCard(isSelected: false));

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.gradient, isNull);
    });

    testWidgets('isSelected true renders with gradient', (tester) async {
      await tester.pumpWidget(createDayCard(isSelected: true));

      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.gradient, isNotNull);
    });
  });
}
