import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/smart_task_input.dart';
import 'package:tasks_api/tasks_api.dart';

class PulseQuickTaskAction extends StatefulWidget {
  const PulseQuickTaskAction({
    super.key,
    required this.addTask,
    required this.isActive,
    required this.onSaved,
  });

  final Future<void> Function(Task) addTask;
  final bool Function() isActive;
  final ValueChanged<int> onSaved;

  @override
  State<PulseQuickTaskAction> createState() => _PulseQuickTaskActionState();
}

class _PulseQuickTaskActionState extends State<PulseQuickTaskAction> {
  String _draft = '';

  Future<void> _open() async {
    final isActive = widget.isActive;
    if (!isActive()) return;
    final saved = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.surfaceDim.withValues(alpha: .75),
      builder: (_) => _QuickTaskNote(
        initialText: _draft,
        addTask: widget.addTask,
        isActive: () => mounted && isActive(),
        onDraftChanged: (text) => _draft = text,
      ),
    );
    if (saved != null && mounted && isActive()) widget.onSaved(saved);
  }

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.edit_note_rounded, size: 23);
    if (MediaQuery.sizeOf(context).width < 600) {
      return IconButton(
        tooltip: 'Быстрый ввод',
        color: AppColors.primary,
        onPressed: _open,
        icon: icon,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surfaceContainerLow,
          side: BorderSide(color: AppColors.borderGlass),
        ),
        onPressed: _open,
        icon: icon,
        label: const Text('Быстрый ввод'),
      ),
    );
  }
}

class _QuickTaskNote extends StatefulWidget {
  const _QuickTaskNote({
    required this.initialText,
    required this.addTask,
    required this.isActive,
    required this.onDraftChanged,
  });

  final String initialText;
  final Future<void> Function(Task) addTask;
  final bool Function() isActive;
  final ValueChanged<String> onDraftChanged;

  @override
  State<_QuickTaskNote> createState() => _QuickTaskNoteState();
}

class _QuickTaskNoteState extends State<_QuickTaskNote> {
  late final TextEditingController _controller;
  final _textFocus = FocusNode();
  late List<QuickTaskDraft> _drafts;
  late bool _showTextInput;
  bool _saving = false;
  bool _editingField = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final text = widget.initialText;
    _controller = TextEditingController(text: text);
    _drafts = parseQuickTasks(text, DateTime.now());
    _showTextInput = _drafts.isEmpty;
  }

  @override
  void dispose() {
    _textFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    widget.onDraftChanged(text);
    setState(() {
      _drafts = parseQuickTasks(text, DateTime.now());
      _error = null;
    });
  }

  void _toggleTextInput() {
    setState(() => _showTextInput = !_showTextInput);
    if (_showTextInput) {
      _textFocus.requestFocus();
    } else {
      _textFocus.unfocus();
    }
  }

  void _setText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _onChanged(text);
  }

  Future<void> _save() async {
    final drafts = _drafts;
    if (_saving || drafts.isEmpty || drafts.any((d) => d.issues.isNotEmpty)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = 0;
    try {
      for (final draft in drafts) {
        if (!mounted || !widget.isActive()) {
          throw StateError('Quick task panel closed.');
        }
        await widget.addTask(
          Task.blank().copyWith(
            title: draft.title,
            startsAt: Wrapped(draft.startsAt),
            endsAt: Wrapped(draft.endsAt),
            dueDate: Wrapped(draft.deadline),
            priority: draft.priority,
          ),
        );
        saved++;
      }
    } catch (_) {
      if (!mounted) return;
      if (saved > 0) _setText(_controller.text.substring(drafts[saved].start));
      setState(() {
        _saving = false;
        _error = saved == 0
            ? 'Не удалось сохранить задачи. Попробуйте ещё раз.'
            : 'Сохранено: $saved. В заметке остались задачи для повторной попытки.';
      });
      return;
    }
    if (!mounted) return;
    _setText('');
    Navigator.pop(context, saved);
  }

  Future<void> _edit(QuickTaskDraft draft, QuickTaskField field) async {
    if (_saving || _editingField || !widget.isActive()) return;
    final original = _controller.text;
    _editingField = true;
    String? value;
    try {
      value = await switch (field) {
        QuickTaskField.title => _editTitle(draft.title),
        QuickTaskField.date => _editDate(draft.day),
        QuickTaskField.deadline => _editDate(draft.deadline, deadline: true),
        QuickTaskField.time => showDialog<String>(
          context: context,
          builder: (_) => _QuickTaskTimeDialog(
            start: draft.startMinute,
            end: draft.endMinute,
            canClear: draft.spans.any(
              (span) => span.field == QuickTaskField.time,
            ),
          ),
        ),
        QuickTaskField.priority => _editPriority(),
      };
    } finally {
      _editingField = false;
    }
    if (!mounted ||
        value == null ||
        _controller.text != original ||
        !widget.isActive()) {
      return;
    }
    _setText(draft.replaceField(original, field, value));
  }

  Future<String?> _editDate(DateTime? initial, {bool deadline = false}) async {
    final value = initial ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: value.year < 1900 ? DateTime(value.year) : DateTime(1900),
      lastDate: DateTime(value.year > 2100 ? value.year : 2100, 12, 31),
      helpText: deadline ? 'Дедлайн' : 'Дата задачи',
      cancelText: 'Отмена',
      confirmText: 'Применить',
    );
    if (date == null) return null;
    return '${deadline ? 'дедлайн' : 'на'} ${formatDate(date)}';
  }

  Future<String?> _editTitle(String title) => showDialog<String>(
    context: context,
    builder: (_) => _QuickTaskTitleDialog(title: title),
  );

  Future<String?> _editPriority() => showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Приоритет'),
      children: [
        for (final label in _priorityLabels)
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, 'приоритет ${label.toLowerCase()}'),
            child: Text(label),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final drafts = _drafts;
    final enabled =
        !_saving &&
        drafts.isNotEmpty &&
        drafts.every((draft) => draft.issues.isEmpty);
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        constraints: const BoxConstraints(maxWidth: 720),
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        child: GlassPanel(
          hasBlur: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.md,
                children: [
                  Row(
                    spacing: AppSpacing.sm,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.primaryContainer,
                      ),
                      Expanded(
                        child: Text(
                          'Быстрый ввод',
                          style: AppTypography.bodyMd.copyWith(
                            fontSize: 22,
                            height: 1.2,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  _composer(enabled),
                  if (_error case final error?)
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (drafts.isNotEmpty) ...[
                    Row(
                      spacing: AppSpacing.sm,
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        Expanded(
                          child: Text(
                            'Черновики задач · ${drafts.length}',
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    for (final draft in drafts)
                      _QuickTaskPreview(
                        draft: draft,
                        edit: _saving ? null : (field) => _edit(draft, field),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _composer(bool enabled) => GlassPanel(
    hasBlur: false,
    borderRadius: AppRadius.xl,
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        if (_drafts.isNotEmpty)
          _FormattedQuickNote(
            text: _controller.text,
            drafts: _drafts,
            edit: _saving ? null : _edit,
          ),
        if (_showTextInput || _drafts.isEmpty)
          TextField(
            key: const ValueKey('pulse.quick-task.input'),
            autofocus: true,
            focusNode: _textFocus,
            readOnly: _saving,
            controller: _controller,
            onChanged: _onChanged,
            minLines: 2,
            maxLines: 7,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            cursorColor: AppColors.primaryContainer,
            style: AppTypography.bodyMd,
            decoration: InputDecoration(
              hintText:
                  'Завтра в 7 утра сделать дз, а с 8 до 9 в понедельник — уборка в доме',
              labelText: _drafts.isEmpty ? null : 'Текст заметки',
              hintStyle: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: .65),
              ),
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            if (_drafts.isEmpty)
              Text(
                'Новая строка — новая задача',
                style: AppTypography.bodySm.copyWith(fontSize: 12),
              )
            else
              TextButton.icon(
                onPressed: _saving ? null : _toggleTextInput,
                icon: Icon(
                  _showTextInput ? Icons.check_rounded : Icons.edit_outlined,
                  size: 17,
                ),
                label: Text(_showTextInput ? 'Готово' : 'Редактировать текст'),
              ),
            FilledButton.icon(
              key: const ValueKey('pulse.quick-task.save'),
              onPressed: enabled ? _save : null,
              style: AppButtonStyles.saveButton,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                _drafts.length == 1 ? 'Добавить задачу' : 'Добавить задачи',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FormattedQuickNote extends StatelessWidget {
  const _FormattedQuickNote({
    required this.text,
    required this.drafts,
    required this.edit,
  });

  final String text;
  final List<QuickTaskDraft> drafts;
  final void Function(QuickTaskDraft, QuickTaskField)? edit;

  static final _preposition = RegExp(
    r'^(?:на|в|во|с)[ \t]+',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final content = <InlineSpan>[];
    var offset = 0;
    for (final draft in drafts) {
      final startMinute = draft.startMinute;
      final hasSingleTitle =
          draft.spans
              .where((span) => span.field == QuickTaskField.title)
              .length ==
          1;
      for (final span in draft.spans) {
        final raw = text.substring(span.start, span.end);
        final prefixLength =
            span.field == QuickTaskField.date ||
                span.field == QuickTaskField.time
            ? _preposition.matchAsPrefix(raw)?.end ?? 0
            : 0;
        final label = switch (span.field) {
          QuickTaskField.title when hasSingleTitle => draft.title,
          QuickTaskField.time
              when startMinute != null && draft.issues.isEmpty =>
            _clockRangeLabel(startMinute, draft.endMinute),
          _ => raw.substring(prefixLength),
        };
        content
          ..add(
            TextSpan(text: text.substring(offset, span.start + prefixLength)),
          )
          ..add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _InlineQuickParameter(
                field: span.field,
                label: label,
                onPressed: edit == null ? null : () => edit!(draft, span.field),
              ),
            ),
          );
        offset = span.end;
      }
    }
    content.add(TextSpan(text: text.substring(offset)));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text.rich(
          key: const ValueKey('pulse.quick-task.formatted'),
          TextSpan(children: content),
          style: AppTypography.bodyMd,
        ),
      ),
    );
  }
}

class _InlineQuickParameter extends StatelessWidget {
  const _InlineQuickParameter({
    required this.field,
    required this.label,
    required this.onPressed,
  });

  final QuickTaskField field;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, hint) = switch (field) {
      QuickTaskField.title => (Icons.check_box_outlined, 'Изменить название'),
      QuickTaskField.date => (Icons.calendar_today_outlined, 'Изменить дату'),
      QuickTaskField.time => (Icons.schedule_outlined, 'Изменить время'),
      QuickTaskField.deadline => (
        Icons.event_busy_outlined,
        'Изменить дедлайн',
      ),
      QuickTaskField.priority => (Icons.flag_outlined, 'Изменить приоритет'),
    };
    final accent = field == QuickTaskField.title
        ? AppColors.primaryContainer
        : AppColors.primary;
    return Semantics(
      hint: hint,
      child: ActionChip(
        onPressed: onPressed,
        backgroundColor: AppColors.primaryContainer.withValues(alpha: .16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: .42)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        labelPadding: const EdgeInsets.only(left: 5, right: 1),
        labelStyle: AppTypography.bodySm.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        avatarBoxConstraints: const BoxConstraints.tightFor(
          width: 17,
          height: 17,
        ),
        avatar: Icon(icon, size: 17, color: accent),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Flexible(
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

const _priorityLabels = ['Низкий', 'Обычный', 'Высокий'];

String _clockLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

String _clockRangeLabel(int start, int? end) => end == null
    ? _clockLabel(start)
    : '${_clockLabel(start)}–${_clockLabel(end)}';

class _QuickTaskPreview extends StatelessWidget {
  const _QuickTaskPreview({required this.draft, required this.edit});

  final QuickTaskDraft draft;
  final ValueChanged<QuickTaskField>? edit;

  @override
  Widget build(BuildContext context) {
    final start = draft.startMinute;
    final end = draft.endMinute;
    final day = draft.day;
    final deadline = draft.deadline;
    return GlassPanel(
      hasBlur: false,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      borderRadius: AppRadius.lg,
      borderColor: draft.issues.isEmpty
          ? null
          : AppColors.tertiary.withValues(alpha: .45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              const Icon(
                Icons.task_alt_outlined,
                color: AppColors.primaryContainer,
                size: 20,
              ),
              Expanded(
                child: Text(
                  draft.title.isEmpty ? 'Без названия' : draft.title,
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Изменить название',
                onPressed: edit == null
                    ? null
                    : () => edit!(QuickTaskField.title),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _chip(
                QuickTaskField.date,
                Icons.event_outlined,
                day == null ? 'Дата' : formatDate(day),
              ),
              _chip(
                QuickTaskField.time,
                Icons.schedule,
                start == null ? 'Время' : _clockRangeLabel(start, end),
              ),
              if (deadline != null ||
                  draft.spans.any(
                    (span) => span.field == QuickTaskField.deadline,
                  ))
                _chip(
                  QuickTaskField.deadline,
                  Icons.event_busy_outlined,
                  deadline == null
                      ? 'Дедлайн'
                      : 'Дедлайн ${formatDate(deadline)}',
                ),
              _chip(
                QuickTaskField.priority,
                Icons.flag_outlined,
                _priorityLabels[draft.priority],
              ),
            ],
          ),
          for (final issue in draft.issues)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                issue,
                style: AppTypography.bodySm.copyWith(color: AppColors.tertiary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(QuickTaskField field, IconData icon, String label) => ActionChip(
    avatar: Icon(icon, size: 16, color: AppColors.primary),
    label: Text(label, overflow: TextOverflow.ellipsis),
    labelStyle: AppTypography.codeLabel.copyWith(letterSpacing: 0, height: 1.2),
    backgroundColor: AppColors.surfaceContainerHigh.withValues(alpha: .45),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    side: BorderSide(color: AppColors.borderGlass),
    onPressed: edit == null ? null : () => edit!(field),
  );
}

class _QuickTaskTitleDialog extends StatefulWidget {
  const _QuickTaskTitleDialog({required this.title});

  final String title;

  @override
  State<_QuickTaskTitleDialog> createState() => _QuickTaskTitleDialogState();
}

class _QuickTaskTitleDialogState extends State<_QuickTaskTitleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.title)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.title.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.pop(context, quoteQuickTaskTitle(title));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Название задачи'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Применить')),
    ],
  );
}

class _QuickTaskTimeDialog extends StatefulWidget {
  const _QuickTaskTimeDialog({
    required this.start,
    required this.end,
    required this.canClear,
  });

  final int? start;
  final int? end;
  final bool canClear;

  @override
  State<_QuickTaskTimeDialog> createState() => _QuickTaskTimeDialogState();
}

class _QuickTaskTimeDialogState extends State<_QuickTaskTimeDialog> {
  late int _start = widget.start ?? 9 * 60;
  late int? _end = widget.end;

  Future<void> _pick({required bool isEnd}) async {
    final minute = (isEnd ? _end : _start) ?? (_start + 60).clamp(0, 1439);
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: isEnd ? 'Конец' : 'Начало',
      cancelText: 'Отмена',
      confirmText: 'Применить',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || value == null) return;
    setState(() {
      final selected = value.hour * 60 + value.minute;
      if (isEnd) {
        _end = selected;
      } else {
        _start = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final end = _end;
    final valid = end == null || end > _start;
    return AlertDialog(
      scrollable: true,
      title: const Text('Время задачи'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: () => _pick(isEnd: false),
            child: Text('Начало · ${_clockLabel(_start)}'),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => _pick(isEnd: true),
                child: Text(
                  end == null
                      ? 'Добавить окончание'
                      : 'Конец · ${_clockLabel(end)}',
                ),
              ),
              if (end != null)
                IconButton(
                  tooltip: 'Убрать окончание',
                  onPressed: () => setState(() => _end = null),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
            ],
          ),
          if (!valid) const Text('Окончание должно быть позже начала.'),
        ],
      ),
      actions: [
        if (widget.canClear)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Убрать время'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: !valid
              ? null
              : () => Navigator.pop(
                  context,
                  end == null
                      ? 'в ${_clockLabel(_start)}'
                      : 'с ${_clockLabel(_start)} до ${_clockLabel(end)}',
                ),
          child: const Text('Применить'),
        ),
      ],
    );
  }
}
