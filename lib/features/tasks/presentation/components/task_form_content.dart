import 'package:life_os/features/tasks/presentation/task_status_visuals.dart';
import 'package:tasks_api/tasks_api.dart'
    show WorkLogsApi, Task, TaskStatus, TaskSequenceDirection;
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/ui/base_container.dart';
import 'package:life_os/core/ui/app_dropdown_menu.dart';
import 'package:life_os/core/ui/date_and_time_pick_button.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:projects_api/projects_api.dart';
import 'package:life_os/features/tasks/presentation/components/work_logs_section.dart';
import '../widgets/existing_task_picker_dialog.dart';

typedef OnTaskSubmit = void Function(Task task);
typedef OnTaskSequenceChange =
    Future<void> Function(
      String id,
      TaskSequenceDirection direction, {
      required String? oldTaskId,
      required String? newTaskId,
    });

/// Содержимое формы задачи: поля, выбор дат/проекта/статуса и сохранение.
/// Не зависит от того, где показано — в шторке, панели или диалоге.
/// Прогрессы [midProgress]/[maxProgress] используются для анимаций раскрытия.
class TaskFormContent extends StatefulWidget {
  const TaskFormContent({
    super.key,
    required this.task,
    required this.projects,
    required this.isEditMode,
    required this.onSubmit,
    required this.onDelete,
    required this.onChanged,
    required this.midProgress,
    required this.maxProgress,
    this.workLogs,
    this.watchTasks,
    this.onSequenceChange,
    this.resetAfterSubmit = true,
  });

  final Task task;
  final WorkLogsApi? workLogs;
  final Stream<List<Task>> Function()? watchTasks;
  final OnTaskSequenceChange? onSequenceChange;
  final bool resetAfterSubmit;
  final Stream<List<Project>> projects;
  final bool isEditMode;
  final OnTaskSubmit onSubmit;
  final Function(String) onDelete;

  /// Нужно чтобы хранить значения при изменении ориентации.
  final ValueChanged<Task>? onChanged;

  final double midProgress;
  final double maxProgress;

  @override
  State<TaskFormContent> createState() => TaskFormContentState();
}

class TaskFormContentState extends State<TaskFormContent> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  late Stream<List<Task>>? _tasks = widget.watchTasks?.call();
  VoidCallback? _onTitleChanged;
  VoidCallback? _onDescChanged;
  String? _selectedProjectId;
  DateTime? _dueDate;
  DateTime? _startsAt;
  DateTime? _endsAt;

  TaskStatus _taskStatus = TaskStatus.notStarted;

  bool get isEditMode => widget.isEditMode;

  bool _isUpdating = false;
  bool _removingSequenceLink = false;

  void _emitChanged() {
    if (_isUpdating) return;
    widget.onChanged?.call(
      widget.task.copyWith(
        title: _titleController.text.trim().isEmpty
            ? 'Untitled'
            : _titleController.text.trim(),
        description: _descController.text.trim(),
        projectId: Wrapped(_selectedProjectId),
        startsAt: Wrapped(_startsAt),
        endsAt: Wrapped(_endsAt),
        dueDate: Wrapped(_dueDate),
        status: _taskStatus,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initFields();
    _onTitleChanged = _emitChanged;
    _onDescChanged = _emitChanged;
    _titleController.addListener(_onTitleChanged!);
    _descController.addListener(_onDescChanged!);
  }

  @override
  void didUpdateWidget(covariant TaskFormContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.watchTasks != oldWidget.watchTasks) {
      _tasks = widget.watchTasks?.call();
    }
    if (widget.task.id != oldWidget.task.id) {
      _initFields();
    }
  }

  void _initFields() {
    _isUpdating = true;
    _titleController.text = widget.task.title;
    _descController.text = widget.task.description;
    _selectedProjectId = widget.task.projectId;
    _startsAt = widget.task.startsAt;
    _endsAt = widget.task.endsAt;
    _dueDate = widget.task.dueDate;
    _taskStatus = widget.task.status;
    _isUpdating = false;
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged!);
    _descController.removeListener(_onDescChanged!);
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  //--------------------- Methods for fields ------------------------
  void submit() {
    final title = _titleController.text.trim();
    final updatedTask = widget.task.copyWith(
      title: title.isEmpty ? 'Untitled' : title,
      description: _descController.text.trim(),
      projectId: Wrapped(_selectedProjectId),
      startsAt: Wrapped(_startsAt),
      endsAt: Wrapped(_endsAt),
      dueDate: Wrapped(_dueDate),
      status: _taskStatus,
    );

    widget.onSubmit(updatedTask);

    if (!isEditMode && widget.resetAfterSubmit) {
      _titleController.clear();
      _descController.clear();
      _selectedProjectId = null;
      _dueDate = null;
      _taskStatus = TaskStatus.notStarted;
    }
  }

  void _deleteTask() {
    widget.onDelete(widget.task.id);
  }

  void _onProjectChange(String? newValue) {
    setState(() {
      _selectedProjectId = newValue;
    });
    _emitChanged();
  }

  void _onTaskStatusChange(TaskStatus? v) {
    setState(() {
      _taskStatus = v ?? _taskStatus;
    });
    _emitChanged();
  }

  void _onDueDateChange(DateTime? selected) {
    setState(() => _dueDate = selected);
    _emitChanged();
  }

  //WORKING WITH DATES
  void _onStartsAtChange(DateTime? selected) {
    if (selected != null && _endsAt != null) {
      final end = _endsAt!;
      // Старт переехал на более позднюю дату — конец переезжает на ту же дату
      if (selected.startOfDay.isAfter(end.startOfDay)) {
        _endsAt = end.copyWith(
          year: selected.year,
          month: selected.month,
          day: selected.day,
        );
      } else if (selected.startOfDay.isAtSameMomentAs(end.startOfDay) &&
          !selected.isDateOnly &&
          !selected.isBefore(end)) {
        // Тот же день: время конца подстраиваем под старт + 1 час
        _endsAt = selected.add(const Duration(hours: 1));
      }
    }
    setState(() => _startsAt = selected);
    _emitChanged();
  }

  void _onEndsAtChange(DateTime? selected) {
    if (selected != null && _startsAt != null) {
      final start = _startsAt!;
      // Конец переехал на более раннюю дату — старт переезжает на ту же дату
      if (selected.startOfDay.isBefore(start.startOfDay)) {
        _startsAt = start.copyWith(
          year: selected.year,
          month: selected.month,
          day: selected.day,
        );
      } else if (selected.startOfDay.isAtSameMomentAs(start.startOfDay) &&
          !selected.isDateOnly &&
          !selected.isAfter(start)) {
        // Тот же день: время старта подстраиваем под конец - 1 час
        _startsAt = selected.subtract(const Duration(hours: 1));
      }
    }
    setState(() => _endsAt = selected);
    _emitChanged();
  }

  //Валидация не блокирует выбор: порядок дат/времён автоматически выравнивается в _onStartsAtChange/_onEndsAtChange
  bool _validateEndsAt(DateTime date) {
    return true;
  }

  bool _validateStartsAt(DateTime date) {
    return true;
  }

  Widget _buildSequenceFields() {
    return StreamBuilder<List<Task>>(
      stream: _tasks,
      builder: (context, snapshot) {
        final tasks = {
          for (final task in snapshot.data ?? const <Task>[]) task.id: task,
        };
        final task = tasks[widget.task.id];
        if (task == null) return const SizedBox.shrink();
        final successors = tasks.values
            .where((candidate) => candidate.predecessorTaskId == task.id)
            .toList();

        Widget step(TaskSequenceDirection direction, String? linkedId) {
          final previous = direction == TaskSequenceDirection.previous;
          return _sequenceStep(
            icon: previous ? Icons.arrow_upward : Icons.arrow_downward,
            child: _sequenceField(
              previous ? 'Предыдущая задача' : 'Следующая задача',
              tasks[linkedId]?.title,
              onPick: _removingSequenceLink
                  ? null
                  : () => _pickSequenceTask(tasks, task, direction, linkedId),
              onRemove: linkedId == null || _removingSequenceLink
                  ? null
                  : () => _removeSequenceLink(task.id, direction, linkedId),
            ),
          );
        }

        return _sequenceCard(
          key: const ValueKey('task-editor.sequence'),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.link_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Связанные задачи', style: _sectionTitle),
                        Text(
                          'Последовательность выполнения',
                          style: _secondaryText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  PositionedDirectional(
                    start: 11,
                    top: 24,
                    bottom: 24,
                    child: Container(
                      width: 1,
                      color: AppColors.primary.withValues(alpha: .44),
                    ),
                  ),
                  Column(
                    children: [
                      step(
                        TaskSequenceDirection.previous,
                        task.predecessorTaskId,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _sequenceStep(
                          icon: Icons.circle,
                          current: true,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .11),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: Text(
                                  'Текущая задача',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (successors.isEmpty)
                        step(TaskSequenceDirection.next, null)
                      else
                        for (final (index, successor) in successors.indexed)
                          Padding(
                            padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
                            child: step(
                              TaskSequenceDirection.next,
                              successor.id,
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sequenceStep({
    required IconData icon,
    required Widget child,
    bool current = false,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: current
              ? AppColors.primary
              : const Color(0xFF503B33),
          child: Icon(
            icon,
            size: current ? 8 : 15,
            color: current ? AppColors.surface : AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  Widget _sequenceField(
    String label,
    String? title, {
    required VoidCallback? onPick,
    required VoidCallback? onRemove,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.borderGlass),
    );
    return Material(
      color: AppColors.surfaceBright,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPick,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            title ?? 'Без связи',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _secondaryText,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      title == null
                          ? Icons.add_rounded
                          : Icons.swap_horiz_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Убрать связь',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Future<void> _removeSequenceLink(
    String id,
    TaskSequenceDirection direction,
    String linkedId,
  ) async {
    if (_removingSequenceLink) return;
    setState(() => _removingSequenceLink = true);
    try {
      await widget.onSequenceChange!(
        id,
        direction,
        oldTaskId: linkedId,
        newTaskId: null,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось убрать связь.')),
        );
      }
    } finally {
      if (mounted) setState(() => _removingSequenceLink = false);
    }
  }

  void _pickSequenceTask(
    Map<String, Task> tasks,
    Task task,
    TaskSequenceDirection direction,
    String? oldTaskId,
  ) {
    final change = widget.onSequenceChange!;
    final previous = direction == TaskSequenceDirection.previous;
    final candidates =
        tasks.values.where((candidate) {
          if (candidate.id == task.id || candidate.id == oldTaskId) {
            return false;
          }
          if (!previous && candidate.predecessorTaskId != null) return false;
          final targetId = previous ? task.id : candidate.id;
          var predecessorId = previous ? candidate.id : task.id;
          final visited = {targetId};
          while (visited.add(predecessorId)) {
            final next = tasks[predecessorId]?.predecessorTaskId;
            if (next == null) return true;
            predecessorId = next;
          }
          return false;
        }).toList()..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );

    Future<void> apply(String? newTaskId) async {
      if (!mounted ||
          widget.task.id != task.id ||
          widget.onSequenceChange != change ||
          !isEditMode) {
        throw StateError('Редактор задачи закрыт.');
      }
      await change(
        task.id,
        direction,
        oldTaskId: oldTaskId,
        newTaskId: newTaskId,
      );
    }

    showDialog<void>(
      context: context,
      builder: (context) => ExistingTaskPickerDialog(
        title: previous ? 'Предыдущая задача' : 'Следующая задача',
        tasks: candidates,
        emptyText: 'Нет доступных задач',
        errorText: 'Не удалось изменить связь. Откройте список задач заново.',
        onSelect: apply,
        onRemove: oldTaskId == null ? null : () => apply(null),
      ),
    );
  }

  TextStyle? get _sectionTitle => Theme.of(context).textTheme.titleMedium
      ?.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700);

  TextStyle? get _secondaryText => Theme.of(context).textTheme.bodySmall
      ?.copyWith(color: AppColors.onSurface.withValues(alpha: .72));

  Widget _sequenceCard({required Key key, required Widget child}) => Container(
    key: key,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.surfaceBright, AppColors.surfaceContainerLow],
      ),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(color: AppColors.borderGlass),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    return _buildFormContent(widget.midProgress, widget.maxProgress);
  }

  Widget _buildFormContent(double midProgress, double maxProgress) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: midProgress,
            child: Transform.scale(
              scale:
                  0.95 +
                  (0.05 * midProgress), // Слегка увеличивается при открытии
              child: TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  //fillColor: AppColors.surfaceContainer,
                  labelText: 'Название задачи',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.task_alt),
                ),
              ),
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            firstChild: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _QuickActionChip(
                        Icons.calendar_month,
                        _startsAt == null
                            ? "Set day"
                            : '${formatDate(_startsAt!)} ${_endsAt != null && _startsAt!.startOfDay != _endsAt!.startOfDay ? "- ${formatDate(_endsAt!)}" : ""}',
                        isActive: _startsAt != null,
                        onPressed: () async {
                          final selected = await chooseDateOnly(
                            context,
                            _startsAt,
                          );
                          if (selected != null) {
                            _onStartsAtChange(
                              selected.copyWith(
                                hour: _startsAt?.hour,
                                minute: _startsAt?.minute,
                              ),
                            );
                            _onEndsAtChange(
                              selected.copyWith(
                                hour: _endsAt?.hour,
                                minute: _endsAt?.minute,
                                second: _endsAt?.second,
                                millisecond: _endsAt?.millisecond,
                                microsecond: _endsAt?.microsecond,
                              ),
                            );
                          }
                        },
                        onCancel: () {
                          _onStartsAtChange(null);
                          _onEndsAtChange(null);
                        },
                      ),
                      SizedBox(width: AppSpacing.sm),

                      _QuickActionChip(
                        Icons.access_time,
                        _startsAt != null && !_startsAt!.isDateOnly
                            ? formatTimeOfDate(_startsAt!)
                            : "Set start time",
                        isActive: _startsAt != null && !_startsAt!.isDateOnly,
                        onPressed: () async {
                          if (_startsAt == null) return;
                          final selected = await chooseTimeForDate(
                            context,
                            _startsAt!,
                          );
                          if (selected != null && _validateStartsAt(selected)) {
                            _onStartsAtChange(selected);
                          }
                        },
                        onCancel: () =>
                            _onStartsAtChange(_startsAt!.startOfDay),
                      ),
                      SizedBox(width: AppSpacing.sm),

                      Text('-'),
                      SizedBox(width: AppSpacing.sm),

                      _QuickActionChip(
                        Icons.access_time,
                        _endsAt != null && !_endsAt!.isDateOnly
                            ? formatTimeOfDate(_endsAt!)
                            : "Set end time",
                        isActive: _endsAt != null && !_endsAt!.isDateOnly,
                        onPressed: () async {
                          if (_endsAt == null && _startsAt == null) return;

                          final selected = await chooseTimeForDate(
                            context,
                            _endsAt ?? _startsAt!,
                          );
                          if (selected != null && _validateEndsAt(selected)) {
                            _onEndsAtChange(
                              _startsAt?.copyWith(
                                hour: selected.hour,
                                minute: selected.minute,
                              ),
                            );
                          }
                        },
                        onCancel: () => _onEndsAtChange(_endsAt?.startOfDay),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            secondChild: Column(
              //crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextField(
                  controller: _descController,
                  minLines: 3,
                  maxLines: 10,
                  decoration: InputDecoration(
                    fillColor: AppColors.surface,
                    hoverColor: AppColors.surfaceBright,
                    labelText: 'Description',
                    prefixIcon: const Icon(Icons.description),
                  ),
                ),
                SizedBox(height: AppMargins.md),
                Row(
                  children: [
                    Expanded(
                      child: dateAndTimePickButton(
                        context,
                        label: "Starts at",
                        date: _startsAt,
                        onDateChange: _onStartsAtChange,
                        validate: _validateStartsAt,
                      ),
                    ),
                    SizedBox(
                      width: AppMargins.lg,
                      child: Center(child: Text("-")),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          dateAndTimePickButton(
                            context,
                            label: "Ends at",
                            date: _endsAt,
                            onDateChange: _onEndsAtChange,
                            validate: _validateEndsAt,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppMargins.lg),
                BaseContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status',
                            style: AppTypography.codeLabel.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Flexible(
                            child: AppDropdownMenu<TaskStatus>(
                              width: 180,
                              selectOnly: true,
                              onSelected: _onTaskStatusChange,
                              initialSelection: _taskStatus,
                              dropdownMenuEntries: [
                                ...TaskStatus.values.map((e) {
                                  return DropdownMenuEntry(
                                    value: e,
                                    label: e.title,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppMargins.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Projects',
                            style: AppTypography.codeLabel.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Flexible(
                            child: StreamBuilder<List<Project>>(
                              stream: widget.projects,
                              builder: (_, snapshot) {
                                final projectsAsync = snapshot.data;
                                return AppDropdownMenu<String?>(
                                  //key чтобы перестраивалось меню и был виден initial
                                  key: ValueKey(
                                    'project_${_selectedProjectId}_${projectsAsync?.length ?? 0}',
                                  ),
                                  initialSelection: _selectedProjectId,
                                  hintText: "Choose project",
                                  width: 180,
                                  menuStyle: MenuStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                      AppColors.surfaceContainer,
                                    ),
                                    shape: WidgetStateProperty.all(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                  dropdownMenuEntries: [
                                    DropdownMenuEntry<String?>(
                                      label: "No project",
                                      value: null,
                                      style: AppButtonStyles.menuButtonStyle(),
                                    ),
                                    if (projectsAsync != null)
                                      ...projectsAsync.map((project) {
                                        return DropdownMenuEntry<String?>(
                                          style:
                                              AppButtonStyles.menuButtonStyle(
                                                bgColor: parseHexColor(
                                                  project.color,
                                                ),
                                              ),
                                          value: project.id,
                                          label: project.name,
                                          labelWidget: Row(
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                size: 12,
                                                color: parseHexColor(
                                                  project.color,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  project.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                  onSelected: _onProjectChange,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppMargins.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'DueDate',
                              style: AppTypography.codeLabel.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.05,
                                ),
                                overlayColor: AppColors.primary,
                              ),
                              onPressed: () async {
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: _dueDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2040),
                                );
                                _onDueDateChange(selected);
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    _dueDate == null
                                        ? "Choose"
                                        : formatDate(_dueDate!),
                                    style: AppTypography.codeLabel.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16),
                                  if (_dueDate != null)
                                    GestureDetector(
                                      onTap: () => _onDueDateChange(null),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isEditMode &&
                    _tasks != null &&
                    widget.onSequenceChange != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildSequenceFields(),
                ],
                if (widget.task.id.isNotEmpty && widget.isEditMode) ...[
                  const SizedBox(height: 16),
                  if (widget.workLogs != null)
                    WorkLogsSection(
                      taskId: widget.task.id,
                      repository: widget.workLogs!,
                    ),
                ],
                if (isEditMode) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deleteTask,
                      style: OutlinedButton.styleFrom(
                        alignment: AlignmentDirectional.centerStart,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        foregroundColor: const Color(0xFFFF8077),
                        backgroundColor: const Color(0xFF2C1C1B),
                        side: const BorderSide(color: Color(0xFF5F3331)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Удалить задачу'),
                    ),
                  ),
                ],
              ],
            ),
            crossFadeState: maxProgress > 0.1
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip(
    this.icon,
    this.label, {
    required this.isActive,
    required this.onPressed,
    required this.onCancel,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primaryContainer : Colors.white70;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.overdueGlow : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.overdueGlow : AppColors.inputGlass,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onCancel,
              icon: Icon(isActive ? Icons.close : icon, size: 16, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
