import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/features/dashboard/data/dashboard_layout_repository.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Пустая сохранённая раскладка — экран рендерится без контентных виджетов,
    // которые требуют живой DI-зависимости (TaskListWidget читает tasksRepository).
    SharedPreferences.setMockInitialValues({
      'dashboard_layout': '{"version":1,"items":[]}',
    });
    final dc = DependencyContainer();
    dc.dashboardLayoutRepository = DashboardLayoutRepository();
    dc.dashboardViewModel = DashboardViewModel(dc.dashboardLayoutRepository);
  });

  group('DashboardScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await DependencyContainer().dashboardViewModel.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardScreen(
              viewModel: DependencyContainer().dashboardViewModel,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
