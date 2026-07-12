import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/ui/date_pick_button.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
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
  });

  final OnTaskSubmit onSubmit;
  final OnCancel onCancel;
  final Stream<List<Project>> projects;
  final Task task;
  final bool isEditMode;
  final double height;

  @override
  State<CollapsibleTaskForm> createState() => _CollapsibleTaskFormState();
}

class _CollapsibleTaskFormState extends State<CollapsibleTaskForm> {
  // Границы размеров формы
  static const double _minHeight = 60.0; // Видна только шапка-хэндл
  static const double _midHeight = 140;
  late double _maxHeight; // Полностью развернутая форма

  // Текущая высота формы
  late double _currentHeight;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedProjectId;
  DateTime? _dueDate;
  DateTime? _startsAt;
  DateTime? _endsAt;

  TaskStatus _taskStatus = TaskStatus.notStarted;

  bool get isEditMode => widget.isEditMode;

  @override
  void initState() {
    super.initState();
    _maxHeight = widget.height;

    // Стартуем сразу в развернутом виде, если это редактирование, либо на минимуме
    _currentHeight = widget.isEditMode ? _maxHeight : _midHeight;
    _initFields();
  }

  @override
  void didUpdateWidget(covariant CollapsibleTaskForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.id != oldWidget.task.id) {
      _initFields();
      print("${widget.task.id} != ${oldWidget.task.id}");
    }
  }

  void _initFields() {
    _titleController.text = widget.task.title;
    _descController.text = widget.task.description;
    _selectedProjectId = widget.task.projectId;
    _startsAt = widget.task.startsAt;
    _endsAt = widget.task.endsAt;
    _dueDate = widget.task.dueDate;
    _taskStatus = widget.task.status;
  }

  @override
  void dispose() {
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

  void _onProjectChange(String? newValue) {
    setState(() {
      _selectedProjectId = newValue;
    });
  }

  void _onDueDateChange(DateTime? selected) {
    setState(() => _dueDate = selected);
  }

  void _onTaskStatusChange(TaskStatus? v) {
    setState(() {
      _taskStatus = v ?? _taskStatus;
    });
  }

  void _onStartsAtChange(DateTime? selected) {
    setState(() => _startsAt = selected);
  }

  void _onEndsAtChange(DateTime? selected) {
    setState(() => _endsAt = selected);
  }

  @override
  Widget build(BuildContext context) {
    // Вычисляем общий прогресс раскрытия (от 0.0 до 1.0) для базовых анимаций шапки
    final double totalProgress =
        ((_currentHeight - _minHeight) / (_maxHeight - _minHeight)).clamp(
          0.0,
          1.0,
        );

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

              //Theme.of(context).cardColor,
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
            //mainAxisSize: MainAxisSize.min,
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

  Widget _buildFormContent(double midProgress, double maxProgress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
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

        // 2. БЛОК ДОПОЛНИТЕЛЬНЫХ ПОЛЕЙ — плавно проявляется ТОЛЬКО при переходе от Mid к Ma
        if (_currentHeight > _midHeight - 50)
          Opacity(
            opacity: maxProgress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                // const SizedBox(height: 16),

                // Row(
                //   children: [
                //     Expanded(
                //       child: PillSwitcher(
                //         options: ["TASK", "EVENT"],
                //         onSelectionChanged: (typeId) {},
                //       ),
                //     ),
                //   ],
                // ),
                SizedBox(height: AppMargins.md),

                Row(
                  children: [
                    Expanded(
                      child: datePickButton(
                        context,
                        label: "Starts at",
                        date: _startsAt,
                        onDateChange: _onStartsAtChange,
                      ),
                    ),
                    SizedBox(
                      width: AppMargins.lg,
                      child: Center(child: Text("-")),
                    ),
                    Expanded(
                      child: datePickButton(
                        context,
                        label: "Ends at",
                        date: _endsAt,
                        onDateChange: _onEndsAtChange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppMargins.lg),
                // Opacity(
                //   opacity: midProgress,
                //   child: ElevatedButton(
                //     onPressed: _currentHeight > _minHeight + 30
                //         ? _submitTask
                //         : null,
                //     style: ElevatedButton.styleFrom(
                //       padding: const EdgeInsets.symmetric(vertical: 16),
                //     ),
                //     child: Text(
                //       isEditMode ? 'Сохранить изменения' : 'Добавить задачу',
                //     ),
                //   ),
                // ),
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
                                // ТЕ САМЫЕ ОТСТУПЫ: задаем внутренние отступы для всего контейнера меню
                                padding: WidgetStateProperty.all(
                                  EdgeInsets.all(
                                    8,
                                  ), // Элементы внутри меню не будут прижаты к его краям
                                ),
                              ),
                              inputDecorationTheme:
                                  AppButtonStyles.baseInputDecoration,
                              dropdownMenuEntries: [
                                ...TaskStatus.values.map((e) {
                                  return DropdownMenuEntry(
                                    value: e,
                                    label: e.name,
                                    //style: AppButtonStyles.menuButtonStyle(),
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
                                // if (snapshot.connectionState ==
                                //     ConnectionState.waiting) {
                                //   return Text("Waiting...");
                                // }
                                final projectsAsync = snapshot.data;
                                return DropdownMenu<String?>(
                                  // 1. Настройка текста внутри меню
                                  textStyle: AppTypography.bodySm,
                                  hintText: "Choose project",
                                  width: 180,
                                  // 2. Настройка цвета стрелочки (как на image_adb2e3.png, она имеет оттенок primary)
                                  trailingIcon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primary,
                                  ),
                                  selectedTrailingIcon: const Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    color: AppColors.primary,
                                  ),

                                  // 3. Стилизация самой плашки (поля ввода)
                                  inputDecorationTheme:
                                      AppButtonStyles.baseInputDecoration,
                                  // 4. Стилизация выпадающего списка (всплывающего окна)
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

                                  // Данные (для примера)
                                  //initialValue: 'System Core v2',
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
                                                  overflow: TextOverflow.ellipsis,
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

                          Container(
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
                                //mainAxisSize: MainAxisSize.min,
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
              ],
            ),
          ),
      ],
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
