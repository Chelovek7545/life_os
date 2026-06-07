import 'package:flutter/material.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

typedef OnTaskSubmit = void Function(Task task);

class CollapsibleTaskForm extends StatefulWidget {
  const CollapsibleTaskForm({
    super.key,
    required this.onSubmit,
    required this.projects,
  });

  final OnTaskSubmit onSubmit;
  final Stream<List<Project>> projects;

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

  // Высота видимой части в свернутом состоянии
  static const double _collapsedHeight = 20.0;

  // Общая высота формы (подбери под свой дизайн)
  static const double _expandedHeight = 350.0;

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
    if (title.isEmpty) return;
    final task = Task.blank().copyWith(
      title: title,
      description: _descController.text.trim(),
      projectId: _selectedProjectId,
    );
    widget.onSubmit(task);
    _titleController.clear();
    _descController.clear();
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
                  color: Colors.black.withOpacity(0.1),
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
                          'Новая задача',
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
                            hintText: 'untitled',
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
                                ConnectionState.waiting)
                              return CircularProgressIndicator();
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
                                onPressed: () {}, // Выбор даты
                                icon: const Icon(Icons.calendar_today),
                                label: const Text('Сегодня'),
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
                          child: const Text('Добавить задачу'),
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
