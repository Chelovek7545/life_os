import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/domain/habit_visuals.dart';

class HabitEditForm extends StatefulWidget {
  const HabitEditForm({
    super.key,
    required this.initial,
    required this.onSave,
    this.onDelete,
  });

  final Habit? initial;
  final ValueChanged<Habit> onSave;
  final VoidCallback? onDelete;

  @override
  State<HabitEditForm> createState() => _HabitEditFormState();
}

class _HabitEditFormState extends State<HabitEditForm> {
  late final TextEditingController _titleController;
  late HabitType _type;
  late List<int> _days;
  int? _durationWeeks;
  late String _icon;
  late String _color;
  TimeOfDay? _reminderTime;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _type = initial?.type ?? const MorningHabit();
    _days = List.from(initial?.schedule.daysOfWeek ?? kAllWeekdays);
    _durationWeeks = initial?.schedule.durationWeeks;
    _icon = initial?.icon ?? 'task_alt';
    _color = initial?.colorHex ?? kHabitColors.first;
    _reminderTime = initial?.reminderTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _type.time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _type = TimeHabit(time: picked));
    }
  }

  Future<void> _pickReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final schedule = HabitSchedule(
      daysOfWeek: _days,
      durationWeeks: _durationWeeks,
    );

    widget.onSave(
      (widget.initial ?? Habit.create(title: title, type: _type))
          .copyWith(
            title: title,
            type: _type,
            schedule: schedule,
            icon: _icon,
            colorHex: _color,
            reminderTime: _reminderTime,
            clearReminderTime: _reminderTime == null,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 0,
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _isEditing ? 'Edit habit' : 'New habit',
                  style: AppTypography.headlineLgMobile.copyWith(fontSize: 20),
                ),
                const Spacer(),
                if (_isEditing && widget.onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _titleController,
              style: AppTypography.bodyMd,
              decoration: const InputDecoration(
                hintText: 'Drink water, read 20 pages…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('When', style: AppTypography.codeLabel),
            const SizedBox(height: AppSpacing.sm),
            PillSwitcher(
              selectedIndex: _type.kind.index,
              options: const [
                Icon(Icons.wb_sunny_outlined),
                Icon(Icons.restaurant_outlined),
                Icon(Icons.nights_stay_outlined),
                Icon(Icons.schedule),
              ],
              onSelectionChanged: (index) {
                setState(() {
                  _type = switch (HabitTypeKind.values[index]) {
                    HabitTypeKind.lunch => const LunchHabit(),
                    HabitTypeKind.evening => const EveningHabit(),
                    HabitTypeKind.time => const TimeHabit(
                        time: TimeOfDay(hour: 9, minute: 0),
                      ),
                    HabitTypeKind.morning => const MorningHabit(),
                  };
                });
              },
            ),
            if (_type.kind == HabitTypeKind.time) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time),
                  label: Text((_type as TimeHabit).formatTime),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Days', style: AppTypography.codeLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: kAllWeekdays.map((day) {
                final selected = _days.contains(day);
                return ChoiceChip(
                  label: Text(
                    getWeekDayName(day),
                    style: AppTypography.codeLabel.copyWith(fontSize: 10),
                  ),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _days = {..._days, day}.toList();
                      } else {
                        _days = _days.where((d) => d != day).toList();
                        if (_days.isEmpty) _days = [...kAllWeekdays];
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Duration', style: AppTypography.codeLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final (label, weeks) in [
                  ('∞', null),
                  ('1 week', 1),
                  ('2 weeks', 2),
                  ('3 weeks', 3),
                ])
                  ChoiceChip(
                    label: Text(label, style: AppTypography.codeLabel),
                    selected: _durationWeeks == weeks,
                    onSelected: (_) => setState(() => _durationWeeks = weeks),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Reminder', style: AppTypography.codeLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickReminder,
                  icon: const Icon(Icons.notifications_outlined),
                  label: Text(
                    _reminderTime == null
                        ? 'No reminder'
                        : '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}',
                  ),
                ),
                if (_reminderTime != null)
                  IconButton(
                    tooltip: 'Clear reminder',
                    onPressed: () => setState(() => _reminderTime = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Icon', style: AppTypography.codeLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: kHabitIcons.entries.map((entry) {
                final selected = _icon == entry.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () => setState(() => _icon = entry.key),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryContainer
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : AppColors.borderGlass,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      size: 20,
                      color: selected ? Colors.white : AppColors.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Color', style: AppTypography.codeLabel),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: kHabitColors.map((hex) {
                final selected = _color == hex;
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: habitColorFor(hex),
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.white, width: 2)
                          : Border.all(color: AppColors.borderGlass),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
