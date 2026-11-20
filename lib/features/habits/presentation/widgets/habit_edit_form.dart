import 'dart:async';

import 'package:flutter/material.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_panels.dart'
    show
        HabitTimePresentation,
        habitColorFor,
        habitIconFor,
        habitTimeFromTimeOfDay,
        kHabitColors,
        kHabitIcons;
import 'package:life_os/features/habits/presentation/widgets/habit_panel_style.dart';

const _timeOptions = [
  ('Утро', Icons.wb_sunny_outlined, MorningHabit()),
  ('День', Icons.restaurant, LunchHabit()),
  ('Вечер', Icons.nightlight_outlined, EveningHabit()),
  ('В любое время', Icons.schedule, AnytimeHabit()),
];

const _iconLabels = {
  'task_alt': 'Галочка',
  'fitness_center': 'Тренировка',
  'directions_run': 'Бег',
  'medication': 'Лекарство',
  'restaurant': 'Питание',
  'menu_book': 'Чтение',
  'self_improvement': 'Медитация',
  'spa': 'Растение',
  'bedtime': 'Сон',
  'water_drop': 'Вода',
  'mood': 'Настроение',
  'school': 'Учёба',
  'laptop': 'Компьютер',
  'local_drink': 'Напиток',
  'payments': 'Финансы',
};

const _colorLabels = [
  'Оранжевый',
  'Сиреневый',
  'Голубой',
  'Зелёный',
  'Розовый',
  'Жёлтый',
  'Коралловый',
  'Бирюзовый',
];

const _accentFill = Color(0xFFBD4D24);
const _selectedFill = Color(0xFF543427);

class HabitEditForm extends StatefulWidget {
  const HabitEditForm({
    super.key,
    required this.initial,
    required this.onSave,
    this.onDelete,
  });

  final Habit? initial;
  final FutureOr<void> Function(Habit) onSave;
  final FutureOr<void> Function()? onDelete;

  @override
  State<HabitEditForm> createState() => _HabitEditFormState();
}

class _HabitEditFormState extends State<HabitEditForm> {
  late final TextEditingController _titleController;
  late HabitType _type;
  late Set<int> _days;
  int? _durationWeeks;
  late String _icon;
  late String _color;
  late TimeOfDay _reminderTime;
  late bool _reminderEnabled;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _type = initial?.type ?? const MorningHabit();
    _days = (initial?.schedule.daysOfWeek ?? kAllWeekdays).toSet();
    _durationWeeks = initial?.schedule.durationWeeks;
    _icon = initial?.icon ?? 'task_alt';
    _color = initial?.colorHex ?? kHabitColors.first;
    _reminderEnabled = initial?.reminderTime != null;
    _reminderTime =
        initial?.reminderTime?.toTimeOfDay() ??
        const TimeOfDay(hour: 8, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initialTime) => showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );

  Future<void> _pickScheduledTime() async {
    final picked = await _pickTime(
      _type.time?.toTimeOfDay() ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _type = TimeHabit(time: habitTimeFromTimeOfDay(picked)));
    }
  }

  Future<void> _pickReminder() async {
    final picked = await _pickTime(_reminderTime);
    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    await _run(
      () => widget.onSave(
        (widget.initial ?? Habit.create(title: title, type: _type)).copyWith(
          title: title,
          type: _type,
          schedule: HabitSchedule(
            daysOfWeek: kAllWeekdays.where(_days.contains).toList(),
            durationWeeks: _durationWeeks,
          ),
          icon: _icon,
          colorHex: _color,
          reminderTime: _reminderEnabled
              ? habitTimeFromTimeOfDay(_reminderTime)
              : null,
          clearReminderTime: !_reminderEnabled,
        ),
      ),
    );
  }

  Future<void> _run(FutureOr<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось сохранить изменения. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Material(
        color: habitPanelBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(habitPanelRadius),
          ),
          side: BorderSide(color: habitPanelBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final duration = _buildDuration();
            final reminder = _buildReminder();

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 14,
                16,
                wide ? 24 : 14,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildTitleField(),
                  const SizedBox(height: 14),
                  _buildTimeOptions(wide),
                  const SizedBox(height: 12),
                  _buildDays(),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: duration),
                        const SizedBox(width: 12),
                        Expanded(child: reminder),
                      ],
                    )
                  else ...[
                    duration,
                    const SizedBox(height: 12),
                    reminder,
                  ],
                  const SizedBox(height: 12),
                  _buildIcons(),
                  const SizedBox(height: 12),
                  _buildColors(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _buildSaveButton(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isEditing = widget.initial != null;
    return Row(
      children: [
        const HabitIconBadge(
          icon: Icons.layers_outlined,
          color: habitPanelAccent,
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 24, color: habitPanelBorder),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isEditing ? 'Редактировать привычку' : 'Новая привычка',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (isEditing && widget.onDelete != null) ...[
          _headerButton(
            tooltip: 'Удалить привычку',
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFFF6D6D),
            onPressed: () => _run(widget.onDelete!),
          ),
          const SizedBox(width: 6),
        ],
        _headerButton(
          tooltip: 'Закрыть',
          icon: Icons.close_rounded,
          color: habitPanelLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _headerButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: _busy ? null : onPressed,
    icon: Icon(icon, size: 22),
    style: IconButton.styleFrom(
      foregroundColor: color,
      backgroundColor: Colors.white.withValues(alpha: .05),
      minimumSize: const Size.square(42),
      side: const BorderSide(color: habitPanelBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _buildTitleField() => DecoratedBox(
    decoration: habitPanelCard(),
    child: TextField(
      controller: _titleController,
      enabled: !_busy,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      cursorColor: habitPanelAccent,
      style: const TextStyle(color: Colors.white, fontSize: 17),
      decoration: InputDecoration(
        hintText: 'Название привычки',
        hintStyle: const TextStyle(color: Color(0xFFB9AAA5)),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: habitPanelAccent),
        ),
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          child: HabitIconBadge(
            icon: habitIconFor(_icon),
            color: habitColorFor(_color),
          ),
        ),
      ),
    ),
  );

  Widget _buildTimeOptions(bool wide) {
    final options = [
      for (final (label, icon, type) in _timeOptions)
        _HabitOption(
          label: label,
          icon: icon,
          selected: _type.kind == type.kind,
          strong: true,
          onPressed: _busy ? null : () => setState(() => _type = type),
        ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _sectionTitle(
            Icons.calendar_today_outlined,
            'Когда',
            trailing: TextButton.icon(
              onPressed: _busy ? null : _pickScheduledTime,
              style: TextButton.styleFrom(
                foregroundColor: habitPanelLabel,
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
              ),
              icon: const Icon(Icons.more_time, size: 18),
              label: Text(_type.timeLabel ?? 'Точное время'),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: habitPanelCard(),
          child: wide
              ? _optionRow(options)
              : Column(
                  children: [
                    _optionRow(options.take(2)),
                    const SizedBox(height: 6),
                    _optionRow(options.skip(2)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDays() {
    final weekdays = kAllWeekdays.take(5).toSet();
    final weekends = kAllWeekdays.skip(5).toSet();
    final label = _days.length == 7
        ? 'Каждый день'
        : _days.length == 5 && _days.containsAll(weekdays)
        ? 'По будням'
        : _days.length == 2 && _days.containsAll(weekends)
        ? 'По выходным'
        : 'Выбор дней';

    return _section(
      icon: Icons.calendar_today_outlined,
      title: 'Дни недели',
      trailing: PopupMenuButton<Set<int>>(
        enabled: !_busy,
        tooltip: 'Расписание по дням',
        color: const Color(0xFF302828),
        onSelected: (days) => setState(() => _days = days),
        itemBuilder: (context) => [
          for (final (label, days) in [
            ('Каждый день', kAllWeekdays.toSet()),
            ('По будням', weekdays),
            ('По выходным', weekends),
          ])
            PopupMenuItem(
              value: days,
              child: Text(
                label,
                style: const TextStyle(color: habitPanelLabel),
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: habitPanelLabel, fontSize: 12),
                ),
              ),
              const Icon(Icons.expand_more, size: 18, color: habitPanelLabel),
            ],
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => _optionRow([
          for (final day in kAllWeekdays)
            _HabitOption(
              label: habitWeekdays[day - 1],
              selected: _days.contains(day),
              icon: _days.contains(day) && constraints.maxWidth >= 410
                  ? Icons.check_rounded
                  : null,
              horizontalPadding: 1,
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        if (!_days.remove(day)) _days.add(day);
                        if (_days.isEmpty) _days.addAll(kAllWeekdays);
                      });
                    },
            ),
        ], spacing: 4),
      ),
    );
  }

  Widget _buildDuration() {
    final initialWeeks = widget.initial?.schedule.durationWeeks;

    return _section(
      icon: Icons.repeat_rounded,
      title: 'Длительность',
      child: _optionRow([
        for (final weeks in [
          null,
          1,
          2,
          3,
          if (initialWeeks != null && initialWeeks > 3) initialWeeks,
        ])
          _HabitOption(
            label: weeks == null ? '∞' : '$weeks нед',
            tooltip: weeks == null ? 'Без ограничения' : null,
            selected: _durationWeeks == weeks,
            horizontalPadding: 2,
            onPressed: _busy
                ? null
                : () => setState(() => _durationWeeks = weeks),
          ),
      ]),
    );
  }

  Widget _buildReminder() => _section(
    icon: Icons.notifications_none_rounded,
    title: 'Напоминание',
    trailing: Semantics(
      label: 'Напоминание',
      child: Switch(
        value: _reminderEnabled,
        onChanged: _busy
            ? null
            : (enabled) => setState(() => _reminderEnabled = enabled),
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFFDD713D),
        inactiveThumbColor: habitPanelLabel,
        inactiveTrackColor: const Color(0xFF322B2B),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    child: _HabitOption(
      label: formatStoredTime(habitTimeFromTimeOfDay(_reminderTime)),
      icon: Icons.notifications_none_rounded,
      trailingIcon: Icons.expand_more,
      onPressed: _busy || !_reminderEnabled ? null : _pickReminder,
    ),
  );

  Widget _buildIcons() => _section(
    icon: Icons.view_in_ar_outlined,
    title: 'Иконка',
    child: Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final entry in kHabitIcons.entries)
          SizedBox(
            width: 46,
            child: _HabitOption(
              icon: entry.value,
              tooltip: _iconLabels[entry.key],
              selected: _icon == entry.key,
              onPressed: _busy ? null : () => setState(() => _icon = entry.key),
            ),
          ),
      ],
    ),
  );

  Widget _buildColors() => _section(
    icon: Icons.palette_outlined,
    title: 'Цвет',
    child: Material(
      type: MaterialType.transparency,
      child: _buildColorOptions(),
    ),
  );

  Widget _buildColorOptions() => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final (index, hex) in kHabitColors.indexed)
        Tooltip(
          message: _colorLabels[index],
          child: Semantics(
            button: true,
            selected: _color == hex,
            child: InkWell(
              onTap: _busy ? null : () => setState(() => _color = hex),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Ink(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: habitColorFor(hex),
                    shape: BoxShape.circle,
                    border: _color == hex
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                    boxShadow: _color == hex
                        ? [
                            BoxShadow(
                              color: habitColorFor(hex).withValues(alpha: .35),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: _color == hex
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : null,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _buildSaveButton() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _titleController,
    builder: (context, value, _) {
      final enabled = !_busy && value.text.trim().isNotEmpty;
      return ElevatedButton.icon(
        onPressed: enabled ? _save : null,
        icon: const Icon(Icons.check_rounded, size: 24),
        label: const Text('Сохранить'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          backgroundColor: _accentFill,
          disabledBackgroundColor: const Color(0xFF2D2523),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(
            color: enabled ? habitPanelAccent : habitPanelBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    },
  );

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
    decoration: habitPanelCard(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(icon, title, trailing: trailing),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _sectionTitle(IconData icon, String title, {Widget? trailing}) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            Icon(icon, color: habitPanelLabel, size: 21),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              flex: 3,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Flexible(
                flex: 2,
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
            ],
          ],
        ),
      );

  Widget _optionRow(Iterable<Widget> options, {double spacing = 6}) => Row(
    children: [
      for (final (index, option) in options.indexed) ...[
        if (index > 0) SizedBox(width: spacing),
        Expanded(child: option),
      ],
    ],
  );
}

class _HabitOption extends StatelessWidget {
  const _HabitOption({
    this.label,
    this.icon,
    this.trailingIcon,
    this.tooltip,
    this.selected,
    this.strong = false,
    this.horizontalPadding = 6,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final IconData? trailingIcon;
  final String? tooltip;
  final bool? selected;
  final bool strong;
  final double horizontalPadding;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final active = selected == true;
    final fill = active
        ? (strong ? _accentFill : _selectedFill)
        : Colors.white.withValues(alpha: .025);
    final button = Semantics(
      selected: selected,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 6,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: fill,
          disabledBackgroundColor: fill,
          foregroundColor: active && strong
              ? Colors.white
              : active && label == null
              ? habitPanelAccent
              : habitPanelLabel,
          disabledForegroundColor: Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: active ? habitPanelAccent : habitPanelBorder),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, size: label == null ? 21 : 17),
            if (label != null) ...[
              if (icon != null) const SizedBox(width: 4),
              Flexible(child: Text(label!, textAlign: TextAlign.center)),
            ],
            if (trailingIcon != null) ...[
              const Spacer(),
              Icon(trailingIcon, size: 17),
            ],
          ],
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
