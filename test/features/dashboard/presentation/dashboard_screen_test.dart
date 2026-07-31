import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/features/dashboard/data/dashboard_widgets_dao.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen.dart';
import 'package:life_os/features/dashboard/data/dashboard_widgets_repository.dart';
import 'package:drift/native.dart';

void main() {
  setUp(() {
    final dc = DependencyContainer();
    dc.database = AppDatabase(NativeDatabase.memory());
    dc.dashboardWidgetsDao = DashboardWidgetsDao(dc.database);
    dc.dashboardWidgetsRepository =
        DashboardWidgetsRepository(dc.dashboardWidgetsDao);
  });

  tearDown(() {
    DependencyContainer().database.close();
  });

  group('DashboardScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DashboardScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
