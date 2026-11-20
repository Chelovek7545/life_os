import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:projects_api/projects_api.dart' show Project, Wrapped;
import 'package:life_os/features/projects/presentation/projects_screen.dart';
import 'package:projects_plugin/projects_logic.dart'
    show
        ProjectsScreenState,
        ProjectsLoading,
        ProjectsLoaded,
        ProjectsError,
        ProjectsViewModel;
import 'package:life_os/features/projects/presentation/widgets/project_card.dart';
import 'package:tasks_api/tasks_api.dart' show Task, TaskStatus;
import 'package:rxdart/rxdart.dart';

import '../../../test_helpers.dart';

class FakeProjectsViewModel extends Fake implements ProjectsViewModel {
  final BehaviorSubject<ProjectsScreenState> _stateController;

  FakeProjectsViewModel({ProjectsScreenState? initialState})
    : _stateController = BehaviorSubject<ProjectsScreenState>.seeded(
        initialState ?? const ProjectsLoading(),
      );

  @override
  Stream<ProjectsScreenState> get state => _stateController.stream;

  @override
  void initialize() {}

  @override
  Stream<List<Task>> watchAllTasks() => taskController.stream;

  final taskController = BehaviorSubject<List<Task>>.seeded([]);
  final addedProjects = <Project>[];
  final updatedProjects = <Project>[];

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await taskController.close();
  }

  @override
  Future<void> addProjects(Project project) async => addedProjects.add(project);

  @override
  Future<void> updateProject(Project project) async =>
      updatedProjects.add(project);

  @override
  Future<void> deleteProject(String id) async {}

  @override
  Future<Project?> getProject(String id) async => null;

  @override
  Stream<List<Task>> watchTaskByProject(String projectId) => Stream.value([]);

  @override
  Future<void> updateTask(covariant Task task) async {}
}

void main() {
  group('ProjectsScreen', () {
    late FakeProjectsViewModel viewModel;

    setUp(() {
      viewModel = FakeProjectsViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    Widget createWidget() {
      return MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.surfaceDim,
          colorScheme: const ColorScheme.dark(
            surface: AppColors.surface,
            primary: AppColors.primary,
            onSurface: Colors.white,
          ),
        ),
        home: Scaffold(body: ProjectsScreen(viewModel: viewModel)),
      );
    }

    testWidgets('shows loading indicator initially', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(createWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when state is error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(const ProjectsError('Failed'));
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('shows empty state when no projects', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(projects: [], curProject: null),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.pumpAndSettle();
      expect(find.text('Здесь будут ваши проекты'), findsOneWidget);
    });

    testWidgets('renders project cards when projects exist', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(
          projects: [
            createMockProject(name: 'Project A'),
            createMockProject(name: 'Project B'),
          ],
          curProject: null,
        ),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsNWidgets(2));
    });

    testWidgets('shows new project button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(projects: [], curProject: null),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Новый проект'), findsOneWidget);
      expect(find.byType(SegmentedPillControl), findsOneWidget);
    });

    testWidgets('new project form slides down from the top and saves', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(projects: [], curProject: null),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.tap(find.text('Новый проект'));
      await tester.pump();
      final form = find.byType(EditProjectCard);
      final startY = tester.getTopLeft(form).dy;
      expect(startY, lessThan(0));
      await tester.pump(const Duration(milliseconds: 70));
      final midwayY = tester.getTopLeft(form).dy;
      expect(midwayY, greaterThan(startY));
      await tester.pumpAndSettle();
      final endY = tester.getTopLeft(form).dy;
      expect(endY, greaterThan(midwayY));
      expect(endY, greaterThanOrEqualTo(0));

      await tester.enterText(find.byType(TextFormField).first, 'Новый план');
      await tester.tap(find.text('Создать проект'));
      await tester.pumpAndSettle();
      expect(viewModel.addedProjects.single.name, 'Новый план');
      expect(form, findsNothing);
    });

    testWidgets('edits project color and archive status in the same dialog', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final project = createMockProject(
        name: 'Исходный проект',
      ).copyWith(dueDate: Wrapped(DateTime(2026, 12, 1)));
      viewModel._stateController.add(ProjectsLoaded(projects: [project]));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Действия с проектом'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();

      expect(find.text('Редактировать проект'), findsOneWidget);
      expect(find.text('HEX'), findsNothing);
      final colorButton = find.widgetWithText(OutlinedButton, 'Цвет');
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '#2866BA');
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      expect(find.text('HEX'), findsNothing);
      await tester.tap(find.byTooltip('Убрать срок'));
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('В архиве').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить изменения'));
      await tester.pumpAndSettle();

      final saved = viewModel.updatedProjects.single;
      expect(saved.id, project.id);
      expect(saved.color, '#2866BA');
      expect(saved.isArchived, isTrue);
      expect(saved.dueDate, isNull);
      expect(find.byType(EditProjectCard), findsNothing);
    });

    testWidgets('filters completion and archive and reacts to task updates', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final active = createMockProject(name: 'Active project');
      final completed = createMockProject(name: 'Completed project');
      final archived = createMockProject(
        name: 'Archived project',
      ).copyWith(isArchived: true);
      viewModel._stateController.add(
        ProjectsLoaded(projects: [active, completed, archived]),
      );
      viewModel.taskController.add([
        createMockTask(projectId: active.id),
        createMockTask(projectId: completed.id, status: TaskStatus.done),
      ]);
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsNWidgets(3));
      await tester.tap(find.text('Активные'));
      await tester.pumpAndSettle();
      expect(find.text('Active project'), findsOneWidget);
      expect(find.text('Completed project'), findsNothing);
      expect(find.text('Archived project'), findsNothing);
      await tester.tap(find.text('Завершённые'));
      await tester.pumpAndSettle();
      expect(find.text('Completed project'), findsOneWidget);
      expect(find.text('Active project'), findsNothing);
      viewModel.taskController.add([
        createMockTask(projectId: active.id, status: TaskStatus.done),
        createMockTask(projectId: completed.id, status: TaskStatus.done),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsNWidgets(2));
      await tester.tap(find.text('Архив'));
      await tester.pumpAndSettle();
      expect(find.text('Archived project'), findsOneWidget);
      expect(find.byType(ProjectCard), findsOneWidget);
    });

    testWidgets('switches gallery rows to list without losing projects', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(
          projects: [
            createMockProject(name: 'Project A'),
            createMockProject(name: 'Project B'),
          ],
        ),
      );
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      final cards = find.byType(ProjectCard);
      expect(
        tester.getTopLeft(cards.at(0)).dy,
        tester.getTopLeft(cards.at(1)).dy,
      );
      await tester.tap(find.byTooltip('Список'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(cards.at(1)).dy,
        greaterThan(tester.getTopLeft(cards.at(0)).dy),
      );
      await tester.tap(find.byTooltip('Сетка'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(cards.at(0)).dy,
        tester.getTopLeft(cards.at(1)).dy,
      );
    });

    testWidgets('cards scroll to the top behind the pinned header', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final projects = List.generate(
        18,
        (index) => createMockProject(name: 'Project $index'),
      );
      viewModel._stateController.add(ProjectsLoaded(projects: projects));
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final card = find.byKey(ValueKey(projects.first.id));
      final filters = find.byType(SegmentedPillControl);
      final listButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Список',
      );
      final filterPosition = tester.getCenter(filters);
      final buttonPosition = tester.getCenter(listButton);
      final createButton = find.text('Новый проект');
      final createPosition = tester.getCenter(createButton);
      final gallery = find.byKey(const PageStorageKey('projects.gallery'));
      final scroll = Scrollable.of(tester.element(card)).position;
      final cardTop = tester.getTopLeft(card).dy;
      expect(cardTop, greaterThan(tester.getBottomLeft(listButton).dy));

      scroll.jumpTo(cardTop + 12);
      await tester.pumpAndSettle();

      final screenTop = tester.getTopLeft(find.byType(ProjectsScreen)).dy;
      expect(tester.getTopLeft(gallery).dy, screenTop);
      expect(tester.getTopLeft(card).dy, lessThan(screenTop));
      expect(tester.getBottomLeft(card).dy, greaterThan(filterPosition.dy));
      expect(tester.getCenter(filters), filterPosition);
      expect(tester.getCenter(listButton), buttonPosition);
      expect(tester.getCenter(createButton), createPosition);
      await tester.tap(listButton);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(listButton).isSelected, isTrue);

      final offset = scroll.pixels;
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(EditProjectCard)).dy,
        lessThan(createPosition.dy),
      );
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProjectCard), findsNothing);
      expect(scroll.pixels, offset);
    });

    testWidgets('fits narrow screen with long project text and creation form', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(
          projects: [
            createMockProject(
              name: 'Очень длинное название проекта для проверки переноса',
              description: 'Подробное описание проекта ' * 20,
            ),
          ],
        ),
      );
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ProjectCard), findsOneWidget);
      await tester.tap(find.text('Новый проект'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProjectCard), findsOneWidget);
      final colorButton = find.widgetWithText(OutlinedButton, 'Цвет');
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(360, 340));
      await tester.pumpAndSettle();
      final saveButton = find.text('Создать проект');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      expect(saveButton.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders ProjectsScreen with title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(createWidget());

      expect(find.text('Проекты'), findsOneWidget);
    });
  });
}
