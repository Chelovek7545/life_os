import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/glassPopUpMenuButton.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('GlassPopUpMenuButton', () {
    testWidgets('renders more_vert icon', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const GlassPopUpMenuButton(overflowActions: []),
      ));

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows menu items on tap', (tester) async {
      await tester.pumpWidget(createTestWidget(
        GlassPopUpMenuButton(
          overflowActions: [
            PopUpMenuAction(
              icon: Icons.edit,
              label: 'Edit',
              onTap: () {},
            ),
            PopUpMenuAction(
              icon: Icons.delete,
              label: 'Delete',
              onTap: () {},
            ),
          ],
        ),
      ));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('calls action onTap from menu', (tester) async {
      bool editTapped = false;
      await tester.pumpWidget(createTestWidget(
        GlassPopUpMenuButton(
          overflowActions: [
            PopUpMenuAction(
              icon: Icons.edit,
              label: 'Edit',
              onTap: () => editTapped = true,
            ),
          ],
        ),
      ));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(editTapped, isTrue);
    });
  });
}
