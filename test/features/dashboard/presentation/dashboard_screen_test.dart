import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:life_os/features/dashboard/domain/dashboard_card_item.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen_state.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_view_model.dart';

class FakeDashboardViewModel implements DashboardViewModel {
  final BehaviorSubject<DashboardScreenState> _stateController;

  FakeDashboardViewModel({DashboardScreenState? initialState})
      : _stateController = BehaviorSubject<DashboardScreenState>.seeded(
          initialState ?? const DashboardScreenLoading(),
        );

  @override
  Stream<DashboardScreenState> get state => _stateController.stream;

  void addState(DashboardScreenState state) => _stateController.add(state);

  @override
  void dispose() => _stateController.close();

  @override
  void initialize() {}
}

Widget createTestWidget(FakeDashboardViewModel viewModel) {
  return MaterialApp(
    home: Scaffold(
      body: DashboardScreen(viewModel: viewModel),
    ),
  );
}

void main() {
  group('DashboardScreen', () {
    testWidgets('shows loading indicator on loading state', (tester) async {
      final viewModel = FakeDashboardViewModel(
        initialState: const DashboardScreenLoading(),
      );
      addTearDown(() => viewModel.dispose());

      await tester.pumpWidget(createTestWidget(viewModel));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message on error state', (tester) async {
      final viewModel = FakeDashboardViewModel(
        initialState: const DashboardScreenError('Something went wrong'),
      );
      addTearDown(() => viewModel.dispose());

      await tester.pumpWidget(createTestWidget(viewModel));
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('shows Overview title', (tester) async {
      final viewModel = FakeDashboardViewModel(
        initialState: const DashboardScreenLoaded([]),
      );
      addTearDown(() => viewModel.dispose());

      await tester.pumpWidget(createTestWidget(viewModel));
      await tester.pump();

      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('renders dashboard cards when loaded with items', (tester) async {
      final viewModel = FakeDashboardViewModel(
        initialState: DashboardScreenLoaded([
          DashboardCardItem(icon: Icons.task_alt, title: 'Tasks', value: '5'),
          DashboardCardItem(icon: Icons.dashboard_customize, title: 'Projects', value: '3'),
        ]),
      );
      addTearDown(() => viewModel.dispose());

      await tester.pumpWidget(createTestWidget(viewModel));
      await tester.pump();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt), findsOneWidget);
      expect(find.byIcon(Icons.dashboard_customize), findsOneWidget);
    });

    testWidgets('shows initial text on initial state', (tester) async {
      final viewModel = FakeDashboardViewModel(
        initialState: const DashboardScreenInitial(),
      );
      addTearDown(() => viewModel.dispose());

      await tester.pumpWidget(createTestWidget(viewModel));
      await tester.pump();

      expect(find.text('initial'), findsOneWidget);
    });
  });
}
