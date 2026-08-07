import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/ui/date_and_time_pick_button.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

typedef OnTaskSubmit = void Function(Task task);
typedef OnCancel = void Function();

class CollapsibleTaskForm extends StatefulWidget {
  const CollapsibleTaskForm({
    super.key,
    required this.task,
    required this.height,
    required this.onSubmit,
    required this.onCancel,
    required this.projects,
    required this.isEditMode,
    required this.onDelete,
    required this.onFormVisibilityChanged,
    required this.onChanged,
    this.forceExpanded = false,
  });

  final OnTaskSubmit onSubmit;
  final Function(String) onDelete;
  final OnCancel onCancel;
  final Stream<List<Project>> projects;
  final Task task;
  final bool isEditMode;
  final double height;
  final ValueChanged<bool>? onFormVisibilityChanged;
  final bool forceExpanded;

  //Нужно при чтобы хранить значения при изменении ориентации
  final ValueChanged<Task>? onChanged;

  @override
  State<CollapsibleTaskForm> createState() => _CollapsibleTaskFormState();
}

class _CollapsibleTaskFormState extends State<CollapsibleTaskForm> {
  // Границы размеров формы
  static const double _minHeight = 60.0; // Видна только шапка-хэндл
  static const double _midHeight = 190;
  late double _maxHeight; // Полностью развернутая форма

  // Текущая высота формы
  late double _currentHeight;
  VoidCallback? _onTitleChanged;
  VoidCallback? _onDescChanged;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedProjectId;
  DateTime? _dueDate;
  DateTime? _startsAt;
  DateTime? _endsAt;

  TaskStatus _taskStatus = TaskStatus.notStarted;

  bool get isEditMode => widget.isEditMode;

  bool _isUpdating = false;

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
    _maxHeight = widget.height;

    if (widget.forceExpanded) {
      _currentHeight = _maxHeight;
    } else {
      // Стартуем сразу в развернутом виде, если это редактирование, либо на минимуме
      _currentHeight = widget.isEditMode ? _maxHeight : _midHeight;
    }
    _initFields();
    _onTitleChanged = _emitChanged;
    _onDescChanged = _emitChanged;
    _titleController.addListener(_onTitleChanged!);
    _descController.addListener(_onDescChanged!);
  }

  @override
  void didUpdateWidget(covariant CollapsibleTaskForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.id != oldWidget.task.id) {
      _initFields();
      //print("${widget.task.id} != ${oldWidget.task.id}");
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

  // Метод плавного «прилипания» к границам при завершении жеста
  void _snapToPosition(double velocity) {
    final List<double> snapPoints = [_minHeight, _midHeight, _maxHeight];

    setState(() {
      if (velocity > 400) {
        if (_currentHeight > _midHeight) {
          _currentHeight = _midHeight;
        } else {
          _currentHeight = _minHeight;
        }
        _currentHeight = _minHeight; // Быстрый свайп вниз -> сворачиваем
      } else if (velocity < -400) {
        if (_currentHeight < _midHeight) {
          _currentHeight = _midHeight;
        } else {
          _currentHeight = _maxHeight;
        }
      } else {
        // Зависит от того, к какому краю ближе

        _currentHeight = snapPoints.reduce(
          (closest, point) =>
              (point - _currentHeight).abs() < (closest - _currentHeight).abs()
              ? point
              : closest,
        );
      }
    });
    widget.onFormVisibilityChanged?.call(_currentHeight != snapPoints[2]);
  }

  //--------------------- Methods for fields ------------------------
  void _submitTask() {
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

    if (!isEditMode) {
      _titleController.clear();
      _descController.clear();
      _selectedProjectId = null;
      _dueDate = null;
      _taskStatus = TaskStatus.notStarted;
    }

    // setState(() {
    //   _currentHeight = _minHeight;
    // });
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

  @override
  Widget build(BuildContext context) {
    if (widget.forceExpanded) {
      return _buildForceExpanded(context);
    }

    // ВЫЧИСЛЯЕМ ПАРАМЕТРЫ ДЛЯ ИЗМЕНЕНИЯ ИНТЕРФЕЙСА:
    // Прогресс раскрытия от минимума до среднее состояния (0.0 -> 1.0)
    final double midProgress =
        ((_currentHeight - _minHeight) / (_midHeight - _minHeight)).clamp(
          0.0,
          1.0,
        );
    // Прогресс раскрытия от среднего до максимального состояния (0.0 -> 1.0)
    final double maxProgress =
        ((_currentHeight - _midHeight) / (_maxHeight - _midHeight)).clamp(
          0.0,
          1.0,
        );

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 120,
        ), // Минимальная задержка для сглаживания ручного ввода
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: _currentHeight,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.borderGlass,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            // Динамический цвет: становится темнее и премиальнее при полном раскрытии
            color: Color.lerp(
              AppColors.surface,
              AppColors.surfaceDim,
              maxProgress,
            ), // Пример: меняем цвет фона от высоты
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.xxl),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ЗОНА ДЛЯ ПЕРЕТАСКИВАНИЯ (ХЭНДЛ)
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    // Изменяем высоту в зависимости от движения пальца/курсора
                    // Изменение dy инвертировано, так как движение вверх уменьшает Y, но увеличивает высоту
                    _currentHeight -= details.delta.dy;
                    _currentHeight = _currentHeight.clamp(
                      _minHeight,
                      _maxHeight,
                    );
                  });
                },
                onVerticalDragEnd: (details) {
                  _snapToPosition(details.primaryVelocity ?? 0);
                },
                child: Container(
                  width: double.infinity,
                  height: _minHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors
                      .transparent, // Делаем всю область хэндла кликабельной
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: AlignmentGeometry.centerLeft,
                          child: IconButton(
                            onPressed: () => widget.onCancel(),
                            icon: Icon(Icons.close),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Традиционная полоска-индикатор
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isEditMode ? 'Edit task' : 'New task',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            style: AppButtonStyles.saveButton,
                            onPressed: () => _submitTask(),
                            child: Text(
                              "Save",
                              style: AppTypography.bodySm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ТЕЛО ФОРМЫ
              Expanded(
                child: SingleChildScrollView(
                  physics: _currentHeight == _maxHeight
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(), // Блокируем скролл контента, если форма не на максимуме
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _buildFormContent(midProgress, maxProgress),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForceExpanded(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.borderGlass,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        color: AppColors.surfaceDim,
      ),
      child: Column(
        children: [
          _buildPanelHeader(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _buildFormContent(1.0, 1.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderGlass)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => widget.onCancel(),
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEditMode ? 'Edit task' : 'New task',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: AppButtonStyles.saveButton,
            onPressed: () => _submitTask(),
            child: Text(
              "Save",
              style: AppTypography.bodySm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
                                microsecond: _endsAt?.microsecond
                                

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
                            child: DropdownMenu(
                              width: 180,
                              selectOnly: true,
                              onSelected: _onTaskStatusChange,
                              textStyle: AppTypography.bodySm,
                              trailingIcon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.primary,
                              ),
                              selectedTrailingIcon: const Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: AppColors.primary,
                              ),
                              initialSelection: _taskStatus,
                              menuStyle: MenuStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  AppColors.surfaceContainerLow,
                                ),
                                elevation: WidgetStateProperty.all(8),
                                shape: WidgetStateProperty.all(
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                padding: WidgetStateProperty.all(
                                  EdgeInsets.all(8),
                                ),
                              ),
                              inputDecorationTheme:
                                  AppButtonStyles.baseInputDecoration,
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
                                return DropdownMenu<String?>(
                                  //key чтобы перестраивалось меню и был виден initial
                                  key: ValueKey(
                                    'project_${_selectedProjectId}_${projectsAsync?.length ?? 0}',
                                  ),
                                  initialSelection: _selectedProjectId,
                                  textStyle: AppTypography.bodySm,
                                  hintText: "Choose project",
                                  width: 180,
                                  trailingIcon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primary,
                                  ),
                                  selectedTrailingIcon: const Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    color: AppColors.primary,
                                  ),
                                  inputDecorationTheme:
                                      AppButtonStyles.baseInputDecoration,
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
                if (isEditMode)
                  ElevatedButton(
                    style: AppButtonStyles.saveButton,
                    onPressed: _deleteTask,
                    child: Text("Delete task"),
                  ),
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

class BaseContainer extends StatelessWidget {
  const BaseContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderGlass, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: EdgeInsets.all(AppSpacing.xl),
      child: child,
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
