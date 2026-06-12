import 'package:flutter/material.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

typedef OnTaskSubmit = void Function(Task task);


//НЕ РАБОТАЕТ
class CollapsibleTaskForm extends StatefulWidget {
  CollapsibleTaskForm({
    super.key,
    Task? task, // Делаем параметр nullable только в конструкторе для удобства вызова
    required this.onSubmit,
    required this.projects,
    required this.isEditMode
  }) : task = task ?? Task.blank();

  final OnTaskSubmit onSubmit;
  final Stream<List<Project>> projects;
  final Task task;
    final bool isEditMode;
  
  @override
  State<CollapsibleTaskForm> createState() => _CollapsibleTaskFormState();
}

class _CollapsibleTaskFormState extends State<CollapsibleTaskForm>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;


  // Контроллеры для полей формы
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedProjectId;
  DateTime? _dueDate;
  // Высота видимой части в свернутом состоянии
  static const double _collapsedHeight = 20.0;

  // Общая высота формы (подбери под свой дизайн)
  static const double _expandedHeight = 450.0;
  
  bool get isEditMode => widget.isEditMode;

  @override
  void initState() {
    super.initState();
    // Инициализируем поля данными, если мы редактируем задачу
    _initFields();
  }

  // Жизненный цикл, который сработает, если во время открытой формы 
  // пользователь выберет другую задачу для редактирования
  @override
  void didUpdateWidget(covariant CollapsibleTaskForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.id != oldWidget.task.id) {
      _initFields();
    }
  }

void _initFields() {
    // Если у таски из конструктора title не пустой (или id совпадает с существующей в базе)
    // В local-first приложениях самый надежный способ понять, новая ли таска — 
    // проверить, пустой ли заголовок или была ли она передана извне.
    // Но так как у нас теперь всегда есть объект, мы можем определить режим по тому, 
    // пустой ли заголовок при инициализации:
    //_isEditMode = widget.task.title == 'Untitled';

    _titleController.text = widget.task.title;
    _descController.text = widget.task.description;
    _selectedProjectId = widget.task.projectId;
    _dueDate = widget.task.dueDate;

    if (isEditMode) {
      _isExpanded = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _toggleForm() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

void _submitTask() {
    final title = _titleController.text.trim();
    
    // С помощью copyWith обновляем данные. 
    // Если это была новая задача — у неё сохранится сгенерированный в Task.blank() UUID.
    // If это редактирование — сохранится старый UUID.
    final updatedTask = widget.task.copyWith(
      title: title.isEmpty ? 'Untitled' : title,
      description: _descController.text.trim(),
      projectId: Wrapped(_selectedProjectId),
      dueDate: Wrapped(_dueDate),
    );

    widget.onSubmit(updatedTask);
    
    // Если это было создание — очищаем переменные стейта для следующей новой задачи
    if (!isEditMode) {
      _titleController.clear();
      _descController.clear();
      _selectedProjectId = null;
      _dueDate = null;
    }

    setState(() {
      _isExpanded = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: double.infinity,
        // Меняем высоту: скрываем всё, кроме шапки
        height: _isExpanded ? _expandedHeight : _collapsedHeight,
        child: GestureDetector(
          // Отслеживаем свайп вниз только когда форма развернута
          onVerticalDragEnd: _isExpanded
              ? (details) {
                  if (details.primaryVelocity! > 100) {
                    _toggleForm(); // Свайп вниз -> сворачиваем
                  }
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Полоска-индикатор и кнопка разворачивания/сворачивания
                GestureDetector(
                  onTap: _toggleForm,
                  child: Container(
                    height: _collapsedHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isEditMode ? 'Редактирование задачи' : 'Новая задача',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: Theme.of(context).primaryColor),
                        ),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 300),
                          turns: _isExpanded
                              ? 0.5
                              : 0, // Стрелка поворачивается
                          child: Icon(
                            Icons.keyboard_arrow_up,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Сама форма (видна только в развернутом состоянии)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Название задачи',
                            
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.task_alt),
                          ),
                        ),
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

                        // Здесь можно добавить выбор даты, приоритета и т.д.
                        StreamBuilder(
                          stream: widget.projects,
                          builder: (_, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return CircularProgressIndicator();
                            }
                            final projectsAsync = snapshot.data;
                            return DropdownButtonFormField<String?>(
                              initialValue: _selectedProjectId,
                              decoration: const InputDecoration(
                                labelText: 'Выберите проект',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.folder_open),
                              ),
                              // Элемент по умолчанию, если проект не выбран
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Без проекта'),
                                ),
                                // Маппим реальные проекты из базы данных
                                if (projectsAsync != null)
                                  ...projectsAsync.map((project) {
                                    return DropdownMenuItem<String?>(
                                      value: project
                                          .id, // В качестве значения используем UUID проекта
                                      child: Row(
                                        children: [
                                          // Иконка или цветной кружок проекта
                                          Icon(
                                            Icons.circle,
                                            //color: Color(project.colorHex),
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
                                  _selectedProjectId =
                                      newValue; // Сохраняем выбранный id проекта в стейт формы
                                });
                              },
                              validator: (value) {
                                // Здесь можно добавить валидацию, если проект обязателен
                                return null;
                              },
                            );
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  _dueDate = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2040),
                                  );
                                  if (_dueDate != null) {
                                    setState(() {});
                                  }
                                }, // Выбор даты
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
                                onPressed: () {}, // Выбор приоритета
                                icon: const Icon(Icons.flag),
                                label: const Text('Приоритет'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _submitTask,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(isEditMode ? 'Сохранить изменения' : 'Добавить задачу'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
