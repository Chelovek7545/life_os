import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/projects/presentation/widgets/project_color_picker.dart';
import 'package:projects_api/projects_api.dart';

enum _ProjectTemplate {
  blank('Пустой', Icons.insert_drive_file_outlined, ''),
  study(
    'Учёба',
    Icons.menu_book_outlined,
    'Цель обучения\n\nТемы и материалы\n\nПлан занятий',
  ),
  research(
    'Исследование',
    Icons.science_outlined,
    'Исследовательский вопрос\n\nМетод\n\nРезультаты',
  ),
  development(
    'Разработка',
    Icons.code,
    'Цель\n\nТребования\n\nПлан реализации',
  ),
  clinical(
    'Клиника',
    Icons.medical_services_outlined,
    'Цель\n\nНаблюдения\n\nПлан и следующие шаги',
  );

  const _ProjectTemplate(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

class EditProjectCard extends StatefulWidget {
  const EditProjectCard({
    super.key,
    required this.onSave,
    required this.onCancel,
    this.project,
    this.isCompleted = false,
  });

  final FutureOr<void> Function(Project project) onSave;
  final VoidCallback onCancel;
  final Project? project;
  final bool isCompleted;

  @override
  State<EditProjectCard> createState() => _EditProjectCardState();
}

class _EditProjectCardState extends State<EditProjectCard> {
  static const _controlFill = Color(0xFF1B1C20);
  static const _orange = AppColors.primaryContainer;
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late Color _color = widget.project == null
      ? _orange
      : parseHexColor(widget.project!.color);
  String? _changedColor;
  late DateTime? _dueDate = widget.project?.dueDate;
  late bool _archived = widget.project?.isArchived ?? false;
  _ProjectTemplate? _template = _ProjectTemplate.blank;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final original = widget.project;
    final name = _name.text.trim();
    final description = _description.text;
    final color = _changedColor ?? original?.color ?? _color.toHex();
    final project = (original ?? Project.create(name: name)).copyWith(
      name: name,
      description: description,
      color: color,
      dueDate: Wrapped(_dueDate),
      isArchived: _archived,
    );
    try {
      await widget.onSave(project);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось сохранить проект. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2140),
    );
    if (mounted && date != null) setState(() => _dueDate = date);
  }

  void _selectTemplate(_ProjectTemplate template) {
    _description.text = template.description;
    setState(() => _template = template);
  }

  InputDecoration _input(String label, {IconData? icon}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: AppColors.borderGlass),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: _controlFill,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _orange),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  Widget _folder({
    required double size,
    required double iconSize,
    bool glow = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _color.withValues(alpha: .25),
            _color.withValues(alpha: .08),
          ],
        ),
        border: Border.all(color: _color.withValues(alpha: .32)),
        boxShadow: [
          if (glow)
            BoxShadow(color: _color.withValues(alpha: .22), blurRadius: 22),
        ],
      ),
      child: Icon(
        Icons.folder_outlined,
        color: Color.lerp(_color, Colors.white, .4),
        size: iconSize,
      ),
    );
  }

  Widget _identity(bool wide) {
    final fields = Column(
      spacing: 12,
      children: [
        TextFormField(
          controller: _name,
          readOnly: _saving,
          cursorColor: _orange,
          textInputAction: TextInputAction.next,
          decoration: _input('Название проекта'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Введите название' : null,
        ),
        TextFormField(
          controller: _description,
          readOnly: _saving,
          cursorColor: _orange,
          decoration: _input('Описание').copyWith(alignLabelWithHint: true),
          minLines: 3,
          maxLines: 5,
          onChanged: widget.project == null
              ? (_) => setState(() => _template = null)
              : null,
        ),
      ],
    );
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 18,
            children: [
              _folder(size: 136, iconSize: 53),
              Expanded(child: fields),
            ],
          )
        : fields;
  }

  Widget _settings(bool wide) {
    final theme = Theme.of(context);
    final date = _dueDate;
    final dateSelector = Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _saving ? null : _pickDate,
            borderRadius: BorderRadius.circular(15),
            child: InputDecorator(
              decoration: _input('Срок', icon: Icons.calendar_today_outlined),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null ? 'Не задан' : formatDate(date),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
        ),
        if (date != null)
          IconButton(
            tooltip: 'Убрать срок',
            onPressed: _saving ? null : () => setState(() => _dueDate = null),
            icon: const Icon(Icons.close, size: 19),
          ),
      ],
    );
    final statusSelector = DropdownButtonFormField<bool>(
      initialValue: _archived,
      decoration: _input('Статус', icon: Icons.layers_outlined),
      isExpanded: true,
      icon: const Icon(Icons.expand_more, size: 20),
      borderRadius: BorderRadius.circular(15),
      dropdownColor: _controlFill,
      items: [
        DropdownMenuItem(
          value: false,
          child: Text(widget.isCompleted ? 'Завершён' : 'Активный'),
        ),
        const DropdownMenuItem(value: true, child: Text('В архиве')),
      ],
      onChanged: _saving ? null : (value) => setState(() => _archived = value!),
    );
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              Expanded(child: dateSelector),
              Expanded(child: statusSelector),
            ],
          )
        : Column(spacing: 12, children: [dateSelector, statusSelector]);
  }

  Widget _templates() {
    final theme = Theme.of(context);
    final enabled =
        !_saving &&
        (_description.text.isEmpty ||
            _description.text == _template?.description);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text('Шаблон описания', style: theme.textTheme.titleSmall),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final template in _ProjectTemplate.values)
              ChoiceChip(
                label: Text(template.label, overflow: TextOverflow.ellipsis),
                labelStyle: TextStyle(
                  color: enabled ? AppColors.onSurface : theme.disabledColor,
                  fontWeight: FontWeight.w600,
                ),
                avatar: Icon(
                  template.icon,
                  size: 18,
                  color: enabled ? AppColors.onSurface : theme.disabledColor,
                ),
                selected: _template == template,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                backgroundColor: _controlFill,
                selectedColor: _orange.withValues(alpha: .28),
                side: BorderSide(
                  color: _template == template
                      ? _orange
                      : AppColors.borderGlass,
                ),
                onSelected: enabled ? (_) => _selectTemplate(template) : null,
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final creating = widget.project == null;
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F1815), Color(0xFF101013), Color(0xFF151215)],
            stops: [0, .35, 1],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            return Padding(
              padding: EdgeInsets.all(wide ? 26 : 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 18,
                  children: [
                    Row(
                      spacing: 12,
                      children: [
                        _folder(
                          size: wide ? 60 : 46,
                          iconSize: wide ? 30 : 24,
                          glow: true,
                        ),
                        Expanded(
                          child: Text(
                            creating ? 'Новый проект' : 'Редактировать проект',
                            style:
                                (wide
                                        ? theme.textTheme.headlineMedium
                                        : theme.textTheme.headlineSmall)
                                    ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: _saving ? null : widget.onCancel,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    _identity(wide),
                    ProjectColorPicker(
                      color: _color,
                      enabled: !_saving,
                      onChanged: (color) => setState(() {
                        _color = color;
                        _changedColor = color.toHex();
                      }),
                    ),
                    _settings(wide),
                    if (creating) _templates(),
                    if (_error case final error?)
                      Text(
                        error,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _saving ? null : widget.onCancel,
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 10,
                            children: [
                              Flexible(
                                child: Text(
                                  _saving
                                      ? 'Сохранение…'
                                      : creating
                                      ? 'Создать проект'
                                      : 'Сохранить изменения',
                                ),
                              ),
                              if (!_saving)
                                Icon(
                                  creating ? Icons.arrow_forward : Icons.check,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
