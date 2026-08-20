import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/ui/collapsible_sheet.dart';
import 'package:life_os/core/ui/heirarchy_view.dart';
import 'package:life_os/core/ui/layout/split_view.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/habits/presentation/habits_calendar_panel.dart';
import 'package:life_os/features/habits/presentation/habits_sheet.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/habits/presentation/todays_habits_panel.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/create_sphere_dialog.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

/// Задача идёт прямо сейчас: не выполнена и её окно `startsAt..endsAt`
/// содержит текущий момент.
bool _isTaskActiveNow(Task t) {
  final now = DateTime.now();
  return t.status != TaskStatus.done &&
      t.startsAt != null &&
      t.endsAt != null &&
      !t.startsAt!.isAfter(now) &&
      !t.endsAt!.isBefore(now);
}

/// Активная задача «сейчас»: приоритет у in-progress, затем по времени начала.
Task? _activeTaskOf(List<Task> tasks) {
  final candidates = tasks.where(_isTaskActiveNow).toList()
    ..sort((a, b) {
      final aProgress = a.status == TaskStatus.inProgress ? 0 : 1;
      final bProgress = b.status == TaskStatus.inProgress ? 0 : 1;
      if (aProgress != bProgress) return aProgress.compareTo(bProgress);
      return a.startsAt!.compareTo(b.startsAt!);
    });
  return candidates.isEmpty ? null : candidates.first;
}

/// PULSE — список сфер жизни. По тапу открывает [LifeGraphScreen] (граф сферы)
/// через [Navigator.push]. Создание сферы — кнопкой в AppBar.
class PulseScreen extends StatefulWidget {
  final LifeGraphViewModel viewModel;
  final HabitsViewModel habitsViewModel;
  final ValueChanged<Task>? onOpenTask;
  final ValueChanged<Task>? onCompleteTask;

  const PulseScreen({
    super.key,
    required this.viewModel,
    required this.habitsViewModel,
    this.onOpenTask,
    this.onCompleteTask,
  });

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  bool _isHabitsMapVisible = false;

  void _openHabitsMap() => setState(() => _isHabitsMapVisible = true);

  void _closeHabitsMap() => setState(() => _isHabitsMapVisible = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      appBar: AppBar(
        centerTitle: true,
        title: Text('PULSE', style: AppTypography.headlineLgMobile),
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Habits',
            onPressed: () => showAllHabitsSheet(
              context: context,
              viewModel: widget.habitsViewModel,
            ),
            icon: const Icon(Icons.repeat_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, asyncSnapshot) {
          bool isSplit = asyncSnapshot.maxWidth >= 900;

          final hierarchyPanel = SingleChildScrollView(
            child: HierarchyPanel(viewModel: widget.viewModel),
          );
          final spheresPanel = SingleChildScrollView(
            child: _SpheresPanel(
              viewModel: widget.viewModel,
              onCreate: () => _showCreateSphereDialog(context),
              onOpenSphere: (sphere) => _openGraph(context, sphere),
            ),
          );

          final Widget body;
          if (isSplit) {
            final centerColumn = Column(
              children: [
                Expanded(
                  child: _StatsPanel(
                    viewModel: widget.viewModel,
                    onOpenTask: widget.onOpenTask,
                    onCompleteTask: widget.onCompleteTask,
                  ),
                ),
                Expanded(
                  child: TodaysHabitsPanel(
                    viewModel: widget.habitsViewModel,
                    onOpenCalendar: _openHabitsMap,
                  ),
                ),
              ],
            );
            body = SplitView(
              minSizes: [300, 300, 300],
              axis: Axis.horizontal,
              dividerThickness: 2,
              dividerBuilder: (context, dividerIndex, axis) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.borderGlass,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
              initialWeights: [0.15, 0.7, 0.15],
              children: [hierarchyPanel, centerColumn, spheresPanel],
            );
          } else {
            body = ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _StatsPanel(
                  viewModel: widget.viewModel,
                  expand: false,
                  onOpenTask: widget.onOpenTask,
                  onCompleteTask: widget.onCompleteTask,
                ),
                const SizedBox(height: 12),
                TodaysHabitsPanel(
                  viewModel: widget.habitsViewModel,
                  onOpenCalendar: _openHabitsMap,
                  expand: false,
                ),
                const SizedBox(height: 12),
                HierarchyPanel(viewModel: widget.viewModel, expand: false),
                const SizedBox(height: 12),
                _SpheresPanel(
                  viewModel: widget.viewModel,
                  expand: false,
                  onCreate: () => _showCreateSphereDialog(context),
                  onOpenSphere: (sphere) => _openGraph(context, sphere),
                ),
              ],
            );
          }
          final List<double> snapPoints = [
            60,
            190,
            MediaQuery.sizeOf(context).height * 0.85,
          ];
          return Stack(
            children: [
              body,
              if (_isHabitsMapVisible)
                CollapsibleSheet(
                  snapPoints: snapPoints,

                  initialHeight: MediaQuery.sizeOf(context).height * 0.85,
                  header: HabitsMapHeader(onClose: _closeHabitsMap),
                  bodyBuilder: (progress, snapIndex) => HabitsCalendarPanel(
                    viewModel: widget.habitsViewModel,
                    progress: progress,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openGraph(BuildContext context, Sphere sphere) async {
    await widget.viewModel.switchSphere(sphere.id);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LifeGraphScreen(viewModel: widget.viewModel),
      ),
    );
  }

  Future<void> _showCreateSphereDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => CreateSphereDialog(viewModel: widget.viewModel),
    );
  }
}

/// Панель иерархии: проект -> задача -> subtask. Строит дерево из
/// live-стримов проектов и задач (subtask = задача с заполненным parentTaskId).
class HierarchyPanel extends StatelessWidget {
  final LifeGraphViewModel viewModel;
  final bool expand;

  const HierarchyPanel({required this.viewModel, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final list = StreamBuilder<List<Project>>(
      stream: viewModel.projectsStream,
      initialData: viewModel.projects,
      builder: (context, projectSnapshot) {
        final projects = projectSnapshot.data ?? const <Project>[];
        return StreamBuilder<List<Task>>(
          stream: viewModel.tasksStream,
          initialData: viewModel.tasks,
          builder: (context, taskSnapshot) {
            final tasks = taskSnapshot.data ?? const <Task>[];

            final nodes = <HierarchyNode>[
              for (final project in projects)
                if (!project.isArchived)
                  HierarchyNode(
                    id: project.id,
                    title: project.name,
                    type: NodeType.project,
                    icon: Icons.folder,
                    dotColor: parseHexColor(project.color),
                    isExpanded: true,
                    children: [
                      for (final task in _projectTasks(tasks, project.id))
                        HierarchyNode(
                          id: task.id,
                          title: task.title,
                          type: NodeType.task,
                          children: [
                            for (final sub in _taskSubtasks(tasks, task.id))
                              HierarchyNode(
                                id: sub.id,
                                title: sub.title,
                                type: NodeType.subtask,
                                dotColor: sub.status.color,
                              ),
                          ],
                        ),
                    ],
                  ),
            ];

            return HierarchyColumn(nodes: nodes);
          },
        );
      },
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Spacer(),
            Text("Hierarchy", style: AppTypography.headlineLg),
            const Spacer(),
            const SizedBox(width: AppMargins.md),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final flexible = expand && constraints.maxHeight.isFinite;
            return flexible
                ? Expanded(child: SingleChildScrollView(child: list))
                : SingleChildScrollView(child: list);
          },
        ),
      ],
    );
  }

  /// Задачи уровня проекта (не subtask'и).
  List<Task> _projectTasks(List<Task> tasks, String projectId) {
    return tasks
        .where((t) => t.projectId == projectId && t.parentTaskId == null)
        .toList();
  }

  /// Subtask'и задачи (родитель — задача).
  List<Task> _taskSubtasks(List<Task> tasks, String taskId) {
    return tasks.where((t) => t.parentTaskId == taskId).toList();
  }
}

/// Строка списка целей: цвет-индикатор, название, имя сферы.
class _GoalTile extends StatelessWidget {
  final Goal goal;
  final String sphereName;

  const _GoalTile({required this.goal, required this.sphereName});

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(goal.color);

    return GlassPanel(
      borderColor: color.withAlpha(20),
      hasBlur: false,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sphereName.isEmpty ? 'Без сферы' : sphereName,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Панель списка сфер с кнопкой создания.
class _SpheresPanel extends StatelessWidget {
  final LifeGraphViewModel viewModel;
  final VoidCallback onCreate;
  final ValueChanged<Sphere> onOpenSphere;
  final bool expand;

  const _SpheresPanel({
    required this.viewModel,
    required this.onCreate,
    required this.onOpenSphere,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final list = StreamBuilder<List<Sphere>>(
      stream: viewModel.spheresStream,
      initialData: viewModel.spheres,
      builder: (context, snapshot) {
        final spheres = snapshot.data ?? const <Sphere>[];
        if (spheres.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _EmptyState(onCreate: onCreate),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < spheres.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _SphereTile(
                  sphere: spheres[i],
                  viewModel: viewModel,
                  onTap: () => onOpenSphere(spheres[i]),
                ),
              ],
            ],
          ),
        );
      },
    );

    final goalsSection = _GoalsSection(viewModel: viewModel, expand: expand);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Spacer(),
            Text("Spheres", style: AppTypography.headlineLg),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              style: AppButtonStyles.menuButtonStyle(),
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Новая сфера',
              onPressed: onCreate,
            ),
            const SizedBox(width: AppMargins.md),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final flexible = expand && constraints.maxHeight.isFinite;
            return flexible
                ? Expanded(child: SingleChildScrollView(child: list))
                : SingleChildScrollView(child: list);
          },
        ),
        goalsSection,
      ],
    );
  }
}

/// Блок целей внутри панели сфер: заголовок + список целей (display-only).
class _GoalsSection extends StatelessWidget {
  final LifeGraphViewModel viewModel;
  final bool expand;

  const _GoalsSection({required this.viewModel, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final list = StreamBuilder<List<Sphere>>(
      stream: viewModel.spheresStream,
      initialData: viewModel.spheres,
      builder: (context, sphereSnapshot) {
        final spheres = sphereSnapshot.data ?? const <Sphere>[];
        final sphereNameOf = <String, String>{
          for (final s in spheres) s.id: s.name,
        };
        return StreamBuilder<List<Goal>>(
          stream: viewModel.goalsStream,
          initialData: viewModel.goals,
          builder: (context, goalSnapshot) {
            final goals = goalSnapshot.data ?? const <Goal>[];
            if (goals.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Нет целей',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < goals.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _GoalTile(
                      goal: goals[i],
                      sphereName: sphereNameOf[goals[i].sphereId] ?? '',
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Spacer(),
            Text("Goals", style: AppTypography.headlineLg),
            const Spacer(),
            const SizedBox(width: AppMargins.md),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final flexible = expand && constraints.maxHeight.isFinite;
            return flexible
                ? Expanded(child: SingleChildScrollView(child: list))
                : SingleChildScrollView(child: list);
          },
        ),
      ],
    );
  }
}

/// Центральная панель Pulse: активная задача «сейчас» + статистика
/// выполненных задач за последние 7 дней.
class _StatsPanel extends StatelessWidget {
  final LifeGraphViewModel viewModel;
  final bool expand;
  final ValueChanged<Task>? onOpenTask;
  final ValueChanged<Task>? onCompleteTask;

  const _StatsPanel({
    required this.viewModel,
    this.expand = true,
    this.onOpenTask,
    this.onCompleteTask,
  });

  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<List<Task>>(
      stream: viewModel.tasksStream,
      initialData: viewModel.tasks,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const <Task>[];
        final activeTask = _activeTaskOf(tasks);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (activeTask != null) ...[
                const Text(
                  'Сейчас',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11.5,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                _ActiveTaskCard(
                  task: activeTask,
                  onTap: onOpenTask,
                  onComplete: onCompleteTask,
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Сегодня',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11.5,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _TodayTimeline(
                tasks: tasks,
                onTap: onOpenTask,
                onComplete: onCompleteTask,
              ),
              const SizedBox(height: 16),
              _WeekBars(tasks: tasks),
            ],
          ),
        );
      },
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Spacer(),
            Text("Stats", style: AppTypography.headlineLg),
            const Spacer(),
            const SizedBox(width: AppMargins.md),
          ],
        ),
        const SizedBox(height: 6),
        if (expand)
          Expanded(child: SingleChildScrollView(child: content))
        else
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: GlassPanel(
              hasBlur: false,
              padding: EdgeInsets.all(AppSpacing.md),
              child: content,
            ),
          ),
      ],
    );
  }
}

/// Карточка активной задачи (окно времени `startsAt..endsAt` содержит сейчас).
class _ActiveTaskCard extends StatelessWidget {
  final Task task;
  final ValueChanged<Task>? onTap;
  final ValueChanged<Task>? onComplete;

  const _ActiveTaskCard({required this.task, this.onTap, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final status = task.status;
    final start = formatTimeOfDate(task.startsAt!);
    final end = formatTimeOfDate(task.endsAt!);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null ? null : () => onTap!(task),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: status.color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onComplete != null)
                    CheckDot(
                      isCompleted: status == TaskStatus.done,
                      onCheckChanged: () => onComplete!(task),
                      isSelected: false,
                      isOverdue: false,
                    ),
                  SizedBox(width: AppMargins.md),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: status.color,
                      boxShadow: [
                        BoxShadow(
                          color: status.color.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '$start – $end',
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.title,
                      style: TextStyle(color: status.color, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Вертикальная лента задач на сегодня: время, точка на линии, название.
/// Активная задача выделена цветом, выполненная зачёркнута.
class _TodayTimeline extends StatelessWidget {
  final List<Task> tasks;
  final ValueChanged<Task>? onTap;
  final ValueChanged<Task>? onComplete;

  const _TodayTimeline({required this.tasks, this.onTap, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTasks =
        tasks
            .where(
              (t) =>
                  t.startsAt != null &&
                  t.startsAt!.year == today.year &&
                  t.startsAt!.month == today.month &&
                  t.startsAt!.day == today.day &&
                  !t.startsAt!.isDateOnly,
            )
            .toList()
          ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));

    if (todayTasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'На сегодня задач нет',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < todayTasks.length; i++) ...[
          _TimelineRow(
            task: todayTasks[i],
            isFirst: i == 0,
            isLast: i == todayTasks.length - 1,
            onTap: onTap,
            onComplete: onComplete,
          ),
          if (i < todayTasks.length - 1) const SizedBox(height: 2),
        ],
      ],
    );
  }
}

/// Строка ленты: время | линия+точка | название | галочка.
class _TimelineRow extends StatelessWidget {
  final Task task;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<Task>? onTap;
  final ValueChanged<Task>? onComplete;

  const _TimelineRow({
    required this.task,
    required this.isFirst,
    required this.isLast,
    this.onTap,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    final active = !done && _isTaskActiveNow(task);
    final accent = task.status.color;
    final lineColor = AppColors.borderGlass;
    final dotColor = done
        ? accent
        : active
        ? accent
        : AppColors.surfaceContainerHigh;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                formatTimeOfDate(task.startsAt!),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: active ? accent : AppColors.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                if (!isFirst) Container(width: 2, height: 10, color: lineColor),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? null : dotColor,
                    border: done ? Border.all(color: dotColor, width: 2) : null,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: dotColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: lineColor)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap == null ? null : () => onTap!(task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationThickness: 1.5,
                          decorationColor: AppColors.onSurfaceVariant,
                          color: done
                              ? AppColors.onSurfaceVariant
                              : active
                              ? AppColors.onSurface
                              : AppColors.onSurface,
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'сейчас',
                          style: TextStyle(color: accent, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (onComplete != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: done ? 'Вернуть в работу' : 'Завершить задачу',
              icon: Icon(
                done ? Icons.check_circle : Icons.check_circle_outline,
                color: done ? task.status.color : AppColors.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => onComplete!(task),
            ),
        ],
      ),
    );
  }
}

/// Столбчатая диаграмма: сколько задач выполнено за каждый из последних 7 дней.
/// Блок включает заголовок с avg-бейджем, сетку, столбцы и градиент-разделитель.
class _WeekBars extends StatefulWidget {
  final List<Task> tasks;

  const _WeekBars({required this.tasks});

  @override
  State<_WeekBars> createState() => _WeekBarsState();
}

class _WeekBarsState extends State<_WeekBars> {
  static const double _chartHeight = 120;
  static const double _maxBarHeight = 64;

  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day - (6 - i)),
    );
    final counts = <int>[];
    var total = 0;
    var maxCount = 0;
    for (final day in days) {
      final count = widget.tasks.where((t) {
        if (t.status != TaskStatus.done) return false;
        final date = t.startsAt ?? t.updatedAt;
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).length;
      counts.add(count);
      total += count;
      if (count > maxCount) maxCount = count;
    }
    if (maxCount == 0) maxCount = 1;
    final avg = total / days.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок: название + avg-бейдж
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.surfaceContainerHigh),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'ВЫПОЛНЕНО ЗА 7 ДНЕЙ',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avg: ${_formatAvg(avg)}/day',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Диаграмма: сетка + столбцы
        SizedBox(
          height: _chartHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        height: 1,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.2,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _buildDay(
                            i,
                            days[i],
                            counts[i],
                            maxCount,
                            today,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Градиент-разделитель
        // Container(
        //   height: 2,
        //   decoration: BoxDecoration(
        //     gradient: LinearGradient(
        //       colors: [
        //         Colors.transparent,
        //         AppColors.surfaceContainerHigh,
        //         Colors.transparent,
        //       ],
        //     ),
        //   ),
        // ),
      ],
    );
  }

  Widget _buildDay(
    int index,
    DateTime day,
    int count,
    int maxCount,
    DateTime today,
  ) {
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final hovered = _hoveredIndex == index;
    final showLabel = count > 0 || hovered;

    final barHeight = count == 0
        ? 4.0
        : (_maxBarHeight * count / maxCount).clamp(4.0, _maxBarHeight);

    final Color barColor;
    if (count == 0) {
      barColor = AppColors.surfaceContainerHigh;
    } else if (isToday) {
      barColor = AppColors.primary;
    } else if (hovered) {
      barColor = AppColors.onSurfaceVariant;
    } else {
      barColor = AppColors.onSurfaceVariant.withValues(alpha: 0.9);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Счётчик над столбиком
          Text(
            '$count',
            style: TextStyle(
              color: (isToday ? AppColors.primary : AppColors.onSurfaceVariant)
                  .withValues(alpha: showLabel ? 1 : 0),
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // Столбик
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(count == 0 ? 4 : 6),
              ),
              boxShadow: isToday && count > 0
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 15,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          // Подпись дня
          Text(
            getWeekDayName(day.weekday),
            style: TextStyle(
              color: isToday ? AppColors.primary : AppColors.onSurfaceVariant,
              fontSize: 9.5,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          // Точка-индикатор текущего дня (слот одинаковой высоты для всех дней,
          // чтобы сегодняшняя колонка не была сдвинута вверх).
          const SizedBox(height: 4),
          SizedBox(
            height: 4,
            child: isToday
                ? const Center(
                    child: SizedBox(
                      width: 4,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  String _formatAvg(double value) {
    final fixed = value.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }
}

/// Строка списка сфер: цвет-индикатор, название, счётчик нод и дата создания.
class _SphereTile extends StatelessWidget {
  final Sphere sphere;
  final LifeGraphViewModel viewModel;
  final VoidCallback onTap;

  const _SphereTile({
    required this.sphere,
    required this.viewModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(sphere.color);
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sphere.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatDate(sphere.createdAt)} · создана',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SphereNodeCount(viewModel: viewModel, sphereId: sphere.id),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white38,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Счётчик нод сферы (без корня-сферы) через live-стрим графа.
class _SphereNodeCount extends StatelessWidget {
  final LifeGraphViewModel viewModel;
  final String sphereId;

  const _SphereNodeCount({required this.viewModel, required this.sphereId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GraphNode>>(
      stream: viewModel.graphBuilder.watchGraph(sphereId),
      builder: (context, snapshot) {
        final content = (snapshot.data?.length ?? 0) - 1;
        final text = content <= 0
            ? 'пусто'
            : '$content ${_plural(content, 'нода', 'ноды', 'нод')}';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11.5,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.public_rounded, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          const Text(
            'Нет сфер жизни',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте первую сферу',
            style: TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Создать сферу'),
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
