import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

typedef OnTaskSubmit = void Function(Task task);

class CollapsibleTaskForm extends StatefulWidget {
  const CollapsibleTaskForm({
    super.key,
    required this.task,
    required this.height,
    required this.onSubmit,
    required this.projects,
    required this.isEditMode,
  });

  final OnTaskSubmit onSubmit;
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
    _dueDate = widget.task.dueDate;
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

  

  void _submitTask() {
    final title = _titleController.text.trim();
    final updatedTask = widget.task.copyWith(
      title: title.isEmpty ? 'Untitled' : title,
      description: _descController.text.trim(),
      projectId: Wrapped(_selectedProjectId),
      dueDate: Wrapped(_dueDate),
    );

    widget.onSubmit(updatedTask);

    if (!isEditMode) {
      _titleController.clear();
      _descController.clear();
      _selectedProjectId = null;
      _dueDate = null;
    }

    setState(() {
      _currentHeight = _minHeight;
    });
    
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
            border: Border.all( color: AppColors.borderGlass, strokeAlign: BorderSide.strokeAlignOutside),
            // Динамический цвет: становится темнее и премиальнее при полном раскрытии
            color: Color.lerp(
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).cardColor,
              maxProgress,
            ), // Пример: меняем цвет фона от высоты
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Динамически меняем размер текста в зависимости от прогресса драга
                          Text(
                            isEditMode
                                ? 'Редактирование задачи'
                                : 'Новая задача',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize:
                                  14 +
                                  (2 *
                                      totalProgress), // Размер шрифта растет при открытии
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: midProgress,
                        child: Transform.scale(
                          scale:
                              0.95 +
                              (0.05 *
                                  midProgress), // Слегка увеличивается при открытии
                          child: TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Название задачи',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.task_alt),
                            ),
                          ),
                        ),
                      ),

                      // 2. БЛОК ДОПОЛНИТЕЛЬНЫХ ПОЛЕЙ — плавно проявляется ТОЛЬКО при переходе от Mid к Ma
                      if (_currentHeight > _midHeight-50)
                        Opacity(
                          opacity: maxProgress,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              TextField(
                                controller: _descController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Описание',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.description),
                                ),
                              ),
                              const SizedBox(height: 16),
                              StreamBuilder<List<Project>>(
                                stream: widget.projects,
                                builder: (_, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const LinearProgressIndicator();
                                  }
                                  final projectsAsync = snapshot.data;
                                  return DropdownButtonFormField<String?>(
                                    value: _selectedProjectId,
                                    decoration: const InputDecoration(
                                      labelText: 'Выберите проект',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.folder_open),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Без проекта'),
                                      ),
                                      if (projectsAsync != null)
                                        ...projectsAsync.map((project) {
                                          return DropdownMenuItem<String?>(
                                            value: project.id,
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.circle,
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(project.name),
                                              ],
                                            ),
                                          );
                                        }),
                                    ],
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedProjectId = newValue;
                                      });
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final selected = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2040),
                                        );
                                        if (selected != null) {
                                          setState(() => _dueDate = selected);
                                        }
                                      },
                                      icon: const Icon(Icons.calendar_today),
                                      label: Text(
                                        _dueDate == null
                                            ? 'Choose date'
                                            : formatDate(_dueDate!),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.flag),
                                      label: const Text('Приоритет'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Opacity(
                                opacity: midProgress,
                                child: ElevatedButton(
                                  onPressed: _currentHeight > _minHeight + 30 ? _submitTask : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  child: Text(
                                    isEditMode
                                        ? 'Сохранить изменения'
                                        : 'Добавить задачу',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
