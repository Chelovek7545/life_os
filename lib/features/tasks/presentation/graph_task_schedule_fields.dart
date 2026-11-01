import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/date_pick_button.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';

class GraphTaskScheduleFields extends StatefulWidget {
  const GraphTaskScheduleFields({super.key, required this.onChanged});
  final ValueChanged<Map<String, Object?>> onChanged;
  @override
  State<GraphTaskScheduleFields> createState() =>
      _GraphTaskScheduleFieldsState();
}

class _GraphTaskScheduleFieldsState extends State<GraphTaskScheduleFields> {
  DateTime? _dueDate;
  DateTime? _startsAt;
  DateTime? _endsAt;
  void _emit() => widget.onChanged({
    'dueDate': _dueDate,
    'startsAt': _startsAt,
    'endsAt': _endsAt,
  });
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Начало — конец:',
        style: TextStyle(color: AppColors.onSurface),
      ),
      const SizedBox(height: 8),
      GlassPanel(
        blurLevel: 0,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _TimeChip(
                icon: Icons.calendar_month,
                label: _startsAt == null
                    ? 'Set day'
                    : '${formatDate(_startsAt!)}${_endsAt != null && _startsAt!.startOfDay != _endsAt!.startOfDay ? " - ${formatDate(_endsAt!)}" : ""}',
                isActive: _startsAt != null,
                onPressed: _pickDay,
                onCancel: _clearTimes,
              ),
              const SizedBox(width: 8),
              _TimeChip(
                icon: Icons.access_time,
                label: _startsAt != null && !_startsAt!.isDateOnly
                    ? formatTimeOfDate(_startsAt!)
                    : 'Set start time',
                isActive: _startsAt != null && !_startsAt!.isDateOnly,
                onPressed: _pickStartTime,
                onCancel: _clearStartTime,
              ),
              const SizedBox(width: 6),
              const Text('-', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 6),
              _TimeChip(
                icon: Icons.access_time,
                label: _endsAt != null && !_endsAt!.isDateOnly
                    ? formatTimeOfDate(_endsAt!)
                    : 'Set end time',
                isActive: _endsAt != null && !_endsAt!.isDateOnly,
                onPressed: _pickEndTime,
                onCancel: _clearEndTime,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Срок выполнения:',
        style: TextStyle(color: AppColors.onSurface),
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 200),
        child: datePickButton(
          context,
          label: 'Выбрать дату',
          date: _dueDate,
          onDateChange: (d) {
            if (!mounted) return;
            setState(() => _dueDate = d);
            _emit();
          },
        ),
      ),
    ],
  );
  // ── Начало / конец (чипы, как в собранной форме задачи) ─────────────────

  Future<void> _pickDay() async {
    final selected = await chooseDateOnly(context, _startsAt);
    if (selected == null || !mounted) return;
    _onStartsAtChange(
      selected.copyWith(hour: _startsAt?.hour, minute: _startsAt?.minute),
    );
    _onEndsAtChange(
      selected.copyWith(hour: _endsAt?.hour, minute: _endsAt?.minute),
    );
  }

  void _clearTimes() {
    setState(() {
      _startsAt = null;
      _endsAt = null;
    });
    _emit();
  }

  Future<void> _pickStartTime() async {
    if (_startsAt == null) return;
    final selected = await chooseTimeForDate(context, _startsAt!);
    if (selected != null && _validateStart(selected) && mounted) {
      _onStartsAtChange(selected);
    }
  }

  Future<void> _pickEndTime() async {
    if (_endsAt == null && _startsAt == null) return;
    final selected = await chooseTimeForDate(context, _endsAt ?? _startsAt!);
    if (selected != null && _validateEnd(selected) && mounted) {
      _onEndsAtChange(
        _startsAt?.copyWith(hour: selected.hour, minute: selected.minute),
      );
    }
  }

  void _clearStartTime() {
    _onStartsAtChange(_startsAt?.startOfDay);
  }

  void _clearEndTime() {
    _onEndsAtChange(_endsAt?.startOfDay);
  }

  //Валидация не блокирует выбор: порядок дат/времён автоматически выравнивается
  //в _onStartsAtChange/_onEndsAtChange (та же автокорректировка, что в форме задачи)
  bool _validateStart(DateTime date) => true;

  bool _validateEnd(DateTime date) => true;

  //Та же автокорректировка порядка дат/времён, что в CollapsibleTaskForm
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
    _emit();
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
    _emit();
  }
}

class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final VoidCallback onCancel;

  const _TimeChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
    required this.onCancel,
  });

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
