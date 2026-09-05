import 'package:flutter/material.dart';
import '../data/routine_repository.dart';
import '../domain/routine_models.dart';
import 'routine_style.dart';

Future<RoutineItem?> showRoutineItemEditor(
  BuildContext context, {
  RoutineItem? item,
  List<({String id, String name, int color})> spheres = const [],
  int? weekday,
  int? start,
  bool singleDate = false,
}) => showDialog<RoutineItem>(
  context: context,
  builder: (_) => RoutineItemEditor(
    item: item,
    spheres: spheres,
    weekday: weekday,
    start: start,
    singleDate: singleDate,
  ),
);

class _SlotDraft {
  _SlotDraft(RoutineSlot s)
    : id = s.id,
      days = s.days.toSet(),
      timed = s.timed,
      overnight = (s.end ?? 0) > 1440,
      start = TextEditingController(text: clockLabel(s.start ?? 540)),
      end = TextEditingController(text: clockLabel(s.end ?? 600));
  final String id;
  final Set<int> days;
  bool timed;
  bool overnight;
  final TextEditingController start;
  final TextEditingController end;
  void dispose() {
    start.dispose();
    end.dispose();
  }

  RoutineSlot value() {
    int parse(String value) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
      if (match == null) {
        throw const FormatException('Введите время в формате ЧЧ:ММ.');
      }
      final h = int.parse(match[1]!);
      final m = int.parse(match[2]!);
      if (h > 23 || m > 59) {
        throw const FormatException('Время: от 00:00 до 23:59.');
      }
      return h * 60 + m;
    }

    return RoutineSlot(
      id: id,
      days: days.toList()..sort(),
      start: timed ? parse(start.text) : null,
      end: timed ? parse(end.text) + (overnight ? 1440 : 0) : null,
    );
  }
}

class RoutineItemEditor extends StatefulWidget {
  const RoutineItemEditor({
    super.key,
    this.item,
    this.spheres = const [],
    this.weekday,
    this.start,
    this.singleDate = false,
  });
  final RoutineItem? item;
  final List<({String id, String name, int color})> spheres;
  final int? weekday;
  final int? start;
  final bool singleDate;
  @override
  State<RoutineItemEditor> createState() => _RoutineItemEditorState();
}

class _RoutineItemEditorState extends State<RoutineItemEditor> {
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _note = TextEditingController(text: widget.item?.note ?? '');
  late final List<_SlotDraft> _slots =
      (widget.item?.slots ??
              [
                RoutineSlot(
                  id: newRoutineId(),
                  days: widget.weekday == null
                      ? [1, 2, 3, 4, 5]
                      : [widget.weekday!],
                  start: widget.start ?? 540,
                  end: (widget.start ?? 540) + 60,
                ),
              ])
          .map(_SlotDraft.new)
          .toList();
  late String _sphere = widget.item?.sphere ?? 'Без сферы';
  String? _error;
  static const _basic = {
    'Без сферы': 0xFF8B93A7,
    'Личное': 0xFFBDA2EE,
    'Здоровье': 0xFF9FCB83,
    'Образование': 0xFF7FA9ED,
    'Работа': 0xFF87AED2,
    'Отдых': 0xFFE3B26E,
    'Развитие': 0xFF85C8B0,
  };
  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    for (final s in _slots) {
      s.dispose();
    }
    super.dispose();
  }

  void _save() {
    try {
      final sphere = widget.spheres.where((s) => s.name == _sphere).firstOrNull;
      final value = RoutineItem(
        id: widget.item?.id ?? newRoutineId(),
        title: _title.text.trim(),
        slots: _slots.map((s) => s.value()).toList(),
        note: _note.text.trim(),
        sphere: _sphere,
        sphereId: sphere?.id,
        color:
            sphere?.color ??
            _basic[_sphere] ??
            widget.item?.color ??
            0xFF8B93A7,
      );
      validateRoutineItems([value]);
      Navigator.pop(context, value);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = {
      ..._basic.keys,
      ...widget.spheres.map((s) => s.name),
      _sphere,
    };
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item == null
                          ? 'Новое занятие'
                          : 'Изменить занятие',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _title,
                        autofocus: true,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Название',
                          hintText: 'Например, утренняя прогулка',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _sphere,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Сфера'),
                        items: names
                            .map(
                              (n) => DropdownMenuItem(value: n, child: Text(n)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _sphere = v!),
                      ),
                      for (var index = 0; index < _slots.length; index++)
                        _slotEditor(_slots[index], index),
                      if (!widget.singleDate)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _slots.add(
                                _SlotDraft(
                                  RoutineSlot(
                                    id: newRoutineId(),
                                    days: [6, 7],
                                    start: 600,
                                    end: 660,
                                  ),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Ещё временной вариант'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Примечание',
                          hintText: 'Необязательно',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotEditor(_SlotDraft s, int index) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: RoutineSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Вариант ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_slots.length > 1)
                IconButton(
                  tooltip: 'Убрать вариант',
                  onPressed: () => setState(() {
                    _slots.remove(s);
                    s.dispose();
                  }),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          if (!widget.singleDate)
            Wrap(
              spacing: 4,
              children: List.generate(
                7,
                (i) => FilterChip(
                  label: Text(weekdayLabels[i]),
                  selected: s.days.contains(i + 1),
                  onSelected: (value) => setState(() {
                    value ? s.days.add(i + 1) : s.days.remove(i + 1);
                  }),
                ),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('По времени'),
            subtitle: Text(
              s.timed
                  ? 'Начало и конец занятия'
                  : 'В течение дня, без учёта часов',
            ),
            value: s.timed,
            onChanged: (v) => setState(() => s.timed = v),
          ),
          if (s.timed) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: s.start,
                    decoration: const InputDecoration(
                      labelText: 'Начало · ЧЧ:ММ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: s.end,
                    decoration: const InputDecoration(
                      labelText: 'Конец · ЧЧ:ММ',
                    ),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Окончание на следующий день',
                style: TextStyle(fontSize: 13),
              ),
              value: s.overnight,
              onChanged: (v) => setState(() => s.overnight = v!),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> showTemplateEditor(
  BuildContext context,
  RoutineRepository repo, {
  RoutineTemplate? template,
  List<RoutineItem>? initial,
  List<({String id, String name, int color})> spheres = const [],
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _TemplateEditor(
    repo: repo,
    template: template,
    initial: initial,
    spheres: spheres,
  ),
);

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({
    required this.repo,
    this.template,
    this.initial,
    required this.spheres,
  });
  final RoutineRepository repo;
  final RoutineTemplate? template;
  final List<RoutineItem>? initial;
  final List<({String id, String name, int color})> spheres;
  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late final _name = TextEditingController(
    text:
        widget.template?.name ??
        (widget.initial != null ? 'Учебная неделя' : 'Моя неделя'),
  );
  late final List<RoutineItem> _items = [
    ...?widget.template?.items,
    ...?widget.initial,
  ];
  late bool _apply =
      widget.repo.snapshot.activations.isEmpty ||
      widget.repo.snapshot.activeOn(widget.repo.now())?.templateId ==
          widget.template?.id;
  late DateTime _date = widget.repo.snapshot.activeOn(widget.repo.now()) == null
      ? routineDay(widget.repo.now())
      : shiftDay(widget.repo.now(), 1);
  String? _error;
  bool _busy = false;
  int? _weekday;

  Future<void> _copyDay() async {
    final targets = <int>{};
    final source = _weekday ?? 1;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text('Копировать ${weekdayLabels[source - 1]}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Занятия выбранных дней будут заменены в этой новой версии шаблона. Прошлая история сохранится.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    if (d != source)
                      FilterChip(
                        label: Text(weekdayLabels[d - 1]),
                        selected: targets.contains(d),
                        onSelected: (v) => refresh(() {
                          if (v) {
                            targets.add(d);
                          } else {
                            targets.remove(d);
                          }
                        }),
                      ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Назад'),
            ),
            FilledButton(
              onPressed: targets.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Копировать'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        final result = copyRoutineDay(_items, source, targets);
        _items
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _edit([int? index]) async {
    final result = await showRoutineItemEditor(
      context,
      item: index == null ? null : _items[index],
      spheres: widget.spheres,
      weekday: _weekday,
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          _items.add(result);
        } else {
          _items[index] = result;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.saveTemplate(
        id: widget.template?.id,
        name: _name.text,
        items: _items,
        applyFrom: _apply ? _date : null,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is FormatException
              ? e.message
              : 'Не удалось сохранить. Попробуйте ещё раз.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 780,
      height: MediaQuery.sizeOf(context).height * .88,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Шаблон недели',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть без сохранения',
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Название шаблона'),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_items.length} занятий · ${minutesLabel(_items.fold<int>(0, (sum, i) => sum + i.slots.fold<int>(0, (s, slot) => s + slot.minutes * slot.days.length)))} в неделю',
                    style: TextStyle(color: paletteOf(context).secondary),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.add),
                  label: const Text('Занятие'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Все'),
                  selected: _weekday == null,
                  onSelected: (_) => setState(() => _weekday = null),
                ),
                for (var d = 1; d <= 7; d++)
                  ChoiceChip(
                    label: Text(weekdayLabels[d - 1]),
                    selected: _weekday == d,
                    onSelected: (_) => setState(() => _weekday = d),
                  ),
                if (_weekday != null)
                  TextButton.icon(
                    onPressed: _busy ? null : _copyDay,
                    icon: const Icon(Icons.copy_all, size: 17),
                    label: const Text('Копировать день'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _items.isEmpty
                  ? const RoutineEmpty(
                      title: 'Ваша неделя начинается здесь',
                      subtitle: 'Добавьте занятия с повторением по дням.',
                    )
                  : ReorderableListView.builder(
                      itemCount: _items.length,
                      onReorderItem: (a, b) => setState(() {
                        _items.insert(b, _items.removeAt(a));
                      }),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        if (_weekday != null &&
                            !item.slots.any((s) => s.days.contains(_weekday))) {
                          return SizedBox.shrink(key: ValueKey(item.id));
                        }
                        return ListTile(
                          key: ValueKey(item.id),
                          contentPadding: const EdgeInsets.only(right: 36),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(
                              item.color,
                            ).withValues(alpha: .15),
                            child: Icon(
                              Icons.circle,
                              color: Color(item.color),
                              size: 10,
                            ),
                          ),
                          title: Text(item.title),
                          subtitle: Text(
                            item.slots
                                .map(
                                  (s) =>
                                      '${s.days.map((d) => weekdayLabels[d - 1]).join(', ')} · ${s.timeLabel}',
                                )
                                .join('\n'),
                            style: TextStyle(
                              fontSize: 12,
                              color: paletteOf(context).secondary,
                            ),
                          ),
                          onTap: _busy ? null : () => _edit(index),
                          trailing: IconButton(
                            tooltip: 'Убрать из новой версии',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _items.removeAt(index)),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _apply,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _apply = v!),
                    ),
                    const Text('Применить с даты'),
                  ],
                ),
                if (_apply)
                  TextButton.icon(
                    onPressed: () async {
                      final min =
                          widget.repo.snapshot.activeOn(widget.repo.now()) ==
                              null
                          ? routineDay(widget.repo.now())
                          : shiftDay(widget.repo.now(), 1);
                      final value = await showDatePicker(
                        context: context,
                        initialDate: _date.isBefore(min) ? min : _date,
                        firstDate: min,
                        lastDate: shiftDay(min, 3650),
                      );
                      if (value != null && mounted) {
                        setState(() => _date = value);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(dayKey(_date)),
                  ),
              ],
            ),
            Text(
              'История сохраняется. Изменения шаблона не меняют прошлые отметки.',
              style: TextStyle(
                fontSize: 12,
                color: paletteOf(context).secondary,
              ),
            ),
            if (_apply &&
                widget.repo.snapshot.activations.any(
                  (a) => dayKey(a.from) == dayKey(_date),
                ))
              Text(
                'Запланированный шаблон с ${dayKey(_date)} будет заменён до следующего переключения.',
                style: const TextStyle(color: routineAccent, fontSize: 12),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Сохранение…' : 'Сохранить шаблон'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
