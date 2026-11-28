import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';

Widget graphEditSelect<T>({
  required String label,
  required T value,
  required Map<T, String> options,
  required ValueChanged<T> onChanged,
}) => DropdownButtonFormField<T>(
  initialValue: value,
  decoration: InputDecoration(labelText: label),
  isExpanded: true,
  dropdownColor: AppColors.surfaceContainerHigh,
  items: [
    for (final entry in options.entries)
      DropdownMenuItem(
        value: entry.key,
        child: Text(
          entry.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
        ),
      ),
  ],
  onChanged: (selection) {
    if (selection != null) onChanged(selection);
  },
);

class GraphEditDateField extends StatelessWidget {
  const GraphEditDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.withTime = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool withTime;

  Future<void> _pickDate(BuildContext context, DateTime? date) async {
    final initial = date ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 1900 ? initial.year : 1900),
      lastDate: DateTime(initial.year > 2200 ? initial.year : 2200, 12, 31),
      helpText: label,
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (selected == null || !context.mounted) return;
    onChanged(
      !withTime
          ? selected
          : date == null || date.isDateOnly
          ? selected.startOfDay
          : selected.copyWith(hour: date.hour, minute: date.minute),
    );
  }

  Future<void> _pickTime(BuildContext context, DateTime date) async {
    final selected = await chooseTimeForDate(context, date);
    if (selected != null && context.mounted) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final date = value?.toLocal();
    final time = withTime && date != null
        ? OutlinedButton.icon(
            onPressed: () => _pickTime(context, date),
            style: _buttonStyle,
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: Text(
              date.isDateOnly ? 'Добавить время' : formatTimeOfDate(date),
            ),
          )
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inlineTime =
            constraints.maxWidth >= 360 &&
            MediaQuery.textScalerOf(context).scale(16) <= 20;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Text(label, style: AppTypography.bodySm),
            Row(
              spacing: AppSpacing.xs,
              children: [
                Expanded(
                  child: Tooltip(
                    message: 'Выбрать дату · $label',
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(context, date),
                      style: _buttonStyle,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        date == null ? 'Выбрать дату' : formatDate(date),
                      ),
                    ),
                  ),
                ),
                if (inlineTime && time != null) time,
                if (date != null)
                  IconButton(
                    onPressed: () => onChanged(null),
                    tooltip: 'Очистить дату · $label',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      minimumSize: const Size.square(44),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
            ),
            if (!inlineTime && time != null) time,
          ],
        );
      },
    );
  }

  ButtonStyle get _buttonStyle =>
      OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minimumSize: const Size(0, 48),
        foregroundColor: AppColors.onSurface,
        backgroundColor: AppColors.inputGlass,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
        textStyle: AppTypography.bodySm,
      ).copyWith(
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? AppColors.primaryContainer
                : AppColors.inputBorderGlass,
          ),
        ),
      );
}
