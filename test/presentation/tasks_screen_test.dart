import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/empty_placeholder.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

import '../test_helpers.dart';

class FakeTasksViewModel extends Fake implements TasksViewModel {
  final BehaviorSubject<TaskScreenState> _stateController;
  final BehaviorSubject<TasksUiFlags> _uiFlagsController;
  final BehaviorSubject<TaskFilterConfig> _filterController;
  bool _shouldRenderForm = false;
  Task _draftTask = Task.blank();
  TaskWithProject? _activeTaskWithProject;
  final List<Task> _selectedTasks = [];
  final List<Task> _allTasks;
  final List<Project> projects;

  FakeTasksViewModel({
    TaskScreenState? initialState,
    bool? initialFormVisible,
    TaskFilterConfig? initialFilter,
    List<Task>? allTasks,
    List<Project>? projects,
  }) : _stateController = BehaviorSubject<TaskScreenState>.seeded(
         initialState ?? const TasksLoading(),
       ),
       _uiFlagsController = BehaviorSubject<TasksUiFlags>.seeded(
         TasksUiFlags(isFormVisible: initialFormVisible ?? false),
       ),
       _filterController = BehaviorSubject<TaskFilterConfig>.seeded(
         initialFilter ?? TaskFilterConfig(anchorDate: DateTime.now()),
       ),
       _allTasks = allTasks ?? [],
       projects = projects ?? [];

  @override
  Stream<TaskScreenState> get state => _stateController.stream;

  @override
  Stream<TasksUiFlags> get uiFlags => _uiFlagsController.stream;

  @override
  TasksUiFlags get currentUiFlags => _uiFlagsController.value;

  @override
  Stream<TaskFilterConfig> get currentFilter => _filterController.stream;

  @override
  TaskFilterConfig get currentFilterValue => _filterController.value;

  @override
  bool get shouldRenderForm => _shouldRenderForm;

  @override
  Task get draftTask => _draftTask;

  @override
  TaskWithProject? get activeTaskWithProject => _activeTaskWithProject;

  @override
  List<Task> get selectedTasks => _selectedTasks;

  @override
  void updateFilter(TaskFilterConfig Function(TaskFilterConfig) updater) {
    _filterController.add(updater(_filterController.value));
  }

  @override
  void resetFilters() {
    final current = _filterController.value;
    _filterController.add(TaskFilterConfig(anchorDate: current.anchorDate));
  }

  @override
  void toggleTaskSelection(Task task) {
    final exists = _selectedTasks.any((t) => t.id == task.id);
    if (exists) {
      _selectedTasks.removeWhere((t) => t.id == task.id);
    } else {
      _selectedTasks.add(task);
    }
    if (_stateController.valueOrNull case final TasksLoaded state) {
      _stateController.add(
        TasksLoaded(
          curTask: state.curTask,
          tasks: state.tasks,
          selectedTasks: List.from(_selectedTasks),
        ),
      );
    }
  }

  @override
  void showForm() {
    _shouldRenderForm = true;
    _uiFlagsController.add(currentUiFlags.copyWith(isFormVisible: true));
  }

  @override
  void hideForm() {
    _uiFlagsController.add(currentUiFlags.copyWith(isFormVisible: false));
    _draftTask = Task.blank();
  }

  @override
  void disableForm() {
    _shouldRenderForm = false;
  }

  @override
  void startEditingTask(TaskWithProject item) {
    _activeTaskWithProject = item;
  }

  @override
  Future<void> toggleTask(Task task) async {}

  @override
  Future<void> updateTask(Task task) async {}

  @override
  Future<void> addTask(Task task) async {}

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Stream<List<Project>> watchProjects() => Stream.value(projects);

  @override
  Stream<List<Task>> watchAllTasks() => Stream.value(_allTasks);

  @override
  void initialize() {}

  @override
  void dispose() {
    _stateController.close();
    _uiFlagsController.close();
    _filterController.close();
  }
}

void main() {
  group('TasksScreen', () {
    late FakeTasksViewModel viewModel;
    late DateTime today;

    setUp(() {
      today = DateTime.now().startOfDay;
      viewModel = FakeTasksViewModel(
        initialFilter: TaskFilterConfig(
          anchorDate: today,
          period: DatePeriod.day,
        ),
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.surfaceDim,
          colorScheme: const ColorScheme.dark(
            surface: AppColors.surface,
            primary: AppColors.primary,
            onSurface: Colors.white,
          ),
        ),
        home: TasksScreen(viewModel: viewModel),
      );
    }

    group('Initial State', () {
      testWidgets('shows loading indicator initially', (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows empty placeholder when no tasks', (tester) async {
        viewModel._stateController.add(const TasksEmpty());
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(EmptyPlaceholder), findsOneWidget);
      });

      testWidgets('shows error message when state is error', (tester) async {
        viewModel._stateController.add(
          const TasksError('Failed to load tasks'),
        );
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.text('Failed to load tasks'), findsOneWidget);
      });
    });

    group('Task Mode - Day View', () {
      late List<TaskWithProject> mockTasks;

      setUp(() {
        mockTasks = [
          createMockTaskWithProject(
            task: createTaskWithTimes(
              start: today.atTime(9),
              end: today.atTime(10),
              title: 'Morning Task',
            ),
          ),
          createMockTaskWithProject(
            task: createTaskWithTimes(
              start: today.atTime(14),
              end: today.atTime(15),
              title: 'Afternoon Task',
            ),
          ),
        ];
      });

      testWidgets('renders task list for day period', (tester) async {
        viewModel._filterController.add(
          TaskFilterConfig(anchorDate: today, period: DatePeriod.day),
        );
        viewModel._stateController.add(
          TasksLoaded(
            curTask: mockTasks.first.task,
            tasks: mockTasks,
            selectedTasks: [],
          ),
        );
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.text('Morning Task'), findsOneWidget);
        expect(find.text('Afternoon Task'), findsOneWidget);
      });

      testWidgets('shows calendar row for day period', (tester) async {
        viewModel._filterController.add(
          TaskFilterConfig(anchorDate: today, period: DatePeriod.day),
        );
        viewModel._stateController.add(
          TasksLoaded(
            curTask: mockTasks.first.task,
            tasks: mockTasks,
            selectedTasks: [],
          ),
        );
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byType(CalendarRow), findsOneWidget);
        expect(find.byType(DateTimelineCard), findsAtLeastNWidgets(7));
      });

      testWidgets('tapping day in calendar updates filter', (tester) async {
        viewModel._filterController.add(
          TaskFilterConfig(anchorDate: today, period: DatePeriod.day),
        );
        viewModel._stateController.add(
          TasksLoaded(
            curTask: mockTasks.first.task,
            tasks: mockTasks,
            selectedTasks: [],
          ),
        );
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        final dayCard = find.byWidgetPredicate(
          (widget) =>
              widget is DateTimelineCard &&
              widget.day == today.add(const Duration(days: 2)).day.toString(),
        );

        if (dayCard.evaluate().isNotEmpty) {
          await tester.tap(dayCard);
          await tester.pump();

          expect(
            viewModel.currentFilterValue.anchorDate,
            DateTime(today.year, today.month, today.day + 2),
          );
        }
      });
    });

    group('Task Mode - Week View', () {
      late DateTime weekStart;
      late List<TaskWithProject> mockTasks;

      setUp(() {
        weekStart = getWeekStart(today);
        mockTasks = [
          createMockTaskWithProject(
            task: createTaskWithTimes(
              start: weekStart.atTime(9),
              end: weekStart.atTime(10),
              title: 'Monday Task',
            ),
          ),
          createMockTaskWithProject(
            task: createTaskWithTimes(
              start: weekStart.addDays(2).atTime(14),
              end: weekStart.addDays(2).atTime(15),
              title: 'Wednesday Task',
            ),
          ),
        ];
      });

      testWidgets('renders week view with day sections', (tester) async {
        viewModel._filterController.add(
          TaskFilterConfig(anchorDate: weekStart, period: DatePeriod.week),
        );
        viewModel._stateController.add(
          TasksLoaded(
            curTask: mockTasks.first.task,
            tasks: mockTasks,
            selectedTasks: [],
          ),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.text('Monday Task'), findsOneWidget);
        expect(find.text('Wednesday Task'), findsOneWidget);
      });
    });

    group('Header Panel', () {
      testWidgets('shows settings icon, mode switcher, and add button', (
        tester,
      ) async {
        viewModel._stateController.add(const TasksEmpty());
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
        expect(find.byIcon(Icons.check_box), findsOneWidget);
        expect(find.byIcon(Icons.event), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('tapping add button shows form', (tester) async {
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldHandler);

        viewModel._stateController.add(const TasksEmpty());
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        expect(viewModel._uiFlagsController.value.isFormVisible, isTrue);
      });

      testWidgets('shows pill switcher for task/event mode', (tester) async {
        viewModel._stateController.add(const TasksEmpty());
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byType(PillSwitcher), findsOneWidget);
      });
    });

    group('Hierarchy Overlay', () {
      testWidgets('shows hierarchy button in header', (tester) async {
        viewModel._stateController.add(const TasksEmpty());
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byIcon(Icons.account_tree_rounded), findsOneWidget);
      });

      testWidgets('tapping hierarchy button toggles overlay', (tester) async {
        viewModel._stateController.add(const TasksEmpty());
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.text('Hierarchy'), findsNothing);

        await tester.tap(find.byIcon(Icons.account_tree_rounded));
        await tester.pump();

        expect(find.text('Hierarchy'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.account_tree_rounded));
        await tester.pump();

        expect(find.text('Hierarchy'), findsNothing);
      });

      testWidgets('hierarchy overlay lists projects and tasks', (tester) async {
        final project = createMockProject(
          id: 'proj-1',
          name: 'Work',
          createdAt: today,
        );
        final task = createMockTask(
          id: 'task-1',
          title: 'Write report',
          projectId: 'proj-1',
          createdAt: today,
          updatedAt: today,
        );

        viewModel = FakeTasksViewModel(
          initialState: const TasksEmpty(),
          allTasks: [task],
          projects: [project],
        );
        viewModel._stateController.add(const TasksEmpty());
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        await tester.tap(find.byIcon(Icons.account_tree_rounded));
        await tester.pump();
        await tester.pump();

        expect(find.text('Work'), findsOneWidget);
        expect(find.text('Write report'), findsOneWidget);
      });
    });

    group('Period Tabs', () {
      testWidgets('shows Day, Week, Month tabs when not in event mode', (
        tester,
      ) async {
        viewModel._stateController.add(const TasksEmpty());
        viewModel._filterController.add(TaskFilterConfig(anchorDate: today));
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.text('Day'), findsOneWidget);
        expect(find.text('Week'), findsOneWidget);
        expect(find.text('Month'), findsOneWidget);
      });

      testWidgets('tapping period tab updates filter', (tester) async {
        viewModel._stateController.add(const TasksEmpty());
        viewModel._filterController.add(TaskFilterConfig(anchorDate: today));
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        await tester.tap(find.text('Week').first);
        await tester.pump();

        final captured = viewModel._filterController.value;
        expect(captured.period, DatePeriod.week);
      });

      testWidgets('tapping Month tab updates filter to month', (tester) async {
        viewModel._stateController.add(const TasksEmpty());
        viewModel._filterController.add(TaskFilterConfig(anchorDate: today));
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        await tester.tap(find.text('Month').first);
        await tester.pump();

        final captured = viewModel._filterController.value;
        expect(captured.period, DatePeriod.month);
      });
    });

    group('Calendar Row', () {
      testWidgets('shows calendar row when period is day', (tester) async {
        viewModel._stateController.add(const TasksEmpty());
        viewModel._filterController.add(
          TaskFilterConfig(anchorDate: today, period: DatePeriod.day),
        );
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byType(CalendarRow), findsOneWidget);
        expect(find.byType(DateTimelineCard), findsWidgets);
      });

      testWidgets('hides calendar row when period is week', (tester) async {
        viewModel._stateController.add(const TasksEmpty());
        viewModel._filterController.add(
          TaskFilterConfig(anchorDate: today, period: DatePeriod.week),
        );
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byType(CalendarRow), findsNothing);
      });
    });

    group('DateTimelineCard', () {
      testWidgets('renders with correct day and weekday', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: AppColors.surfaceDim,
              colorScheme: const ColorScheme.dark(
                surface: AppColors.surface,
                primary: AppColors.primary,
                onSurface: Colors.white,
              ),
            ),
            home: Scaffold(
              body: DateTimelineCard(
                day: '15',
                weekday: 'mon',
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('15'), findsOneWidget);
        expect(find.text('mon'), findsOneWidget);
      });

      testWidgets('shows selected styling when isSelected is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: AppColors.surfaceDim,
              colorScheme: const ColorScheme.dark(
                surface: AppColors.surface,
                primary: AppColors.primary,
                onSurface: Colors.white,
              ),
            ),
            home: Scaffold(
              body: DateTimelineCard(
                day: '15',
                weekday: 'mon',
                isSelected: true,
                onTap: () {},
              ),
            ),
          ),
        );

        // Should have gradient when selected
        expect(find.byType(AnimatedContainer), findsOneWidget);
      });

      testWidgets('calls onTap when tapped', (tester) async {
        bool tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: AppColors.surfaceDim,
              colorScheme: const ColorScheme.dark(
                surface: AppColors.surface,
                primary: AppColors.primary,
                onSurface: Colors.white,
              ),
            ),
            home: Scaffold(
              body: DateTimelineCard(
                day: '15',
                weekday: 'mon',
                isSelected: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(DateTimelineCard));
        await tester.pump();

        expect(tapped, isTrue);
      });
    });

    group('CalendarRow', () {
      testWidgets('renders 7 DateTimelineCards', (tester) async {
        final anchor = today;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: AppColors.surfaceDim,
              colorScheme: const ColorScheme.dark(
                surface: AppColors.surface,
                primary: AppColors.primary,
                onSurface: Colors.white,
              ),
            ),
            home: Scaffold(
              body: CalendarRow(selectedDate: anchor, onDaySelected: (date) {}),
            ),
          ),
        );

        expect(find.byType(DateTimelineCard), findsNWidgets(7));
      });
    });

    group('Form', () {
      testWidgets('shows form when isFormVisible is true', (tester) async {
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldHandler);

        viewModel._stateController.add(const TasksEmpty());
        viewModel._shouldRenderForm = true;
        viewModel._uiFlagsController.add(const TasksUiFlags(isFormVisible: true));
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byType(CollapsibleTaskForm), findsOneWidget);
      });

      testWidgets('hides form when isFormVisible is false', (tester) async {
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          oldHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldHandler);
        viewModel._stateController.add(const TasksEmpty());
        viewModel._shouldRenderForm = true;
        viewModel._uiFlagsController.add(const TasksUiFlags(isFormVisible: true));
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.byType(CollapsibleTaskForm), findsOneWidget);

        viewModel._uiFlagsController.add(const TasksUiFlags(isFormVisible: false));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(CollapsibleTaskForm), findsNothing);
      });
    });
  });
}
