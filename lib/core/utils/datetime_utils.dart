  import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';

  const TimeOfDay _clearTimeSentinel = TimeOfDay(hour: -1, minute: -1);

  Future<DateTime?> chooseTimeForDate(BuildContext context, DateTime date) async {
    final hasTime = !date.isDateOnly;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
      builder: hasTime
          ? (context, child) => _TimePickerClearOverlay(
            child: child!,
            onClear: () => Navigator.pop(context, _clearTimeSentinel),
          )
          : null,
    );

    if (identical(result, _clearTimeSentinel)) {
      return date.startOfDay;
    }
    if (result == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      result.hour,
      result.minute,
    );
  }

  class _TimePickerClearOverlay extends StatefulWidget {
    const _TimePickerClearOverlay({required this.child, required this.onClear});

    final Widget child;
    final VoidCallback onClear;

    @override
    State<_TimePickerClearOverlay> createState() =>
        _TimePickerClearOverlayState();
  }

  class _TimePickerClearOverlayState extends State<_TimePickerClearOverlay> {
    final GlobalKey _childKey = GlobalKey();
    Rect? _surface;

    @override
    Widget build(BuildContext context) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      return Stack(
        children: [
          KeyedSubtree(key: _childKey, child: widget.child),
          if (_surface != null)
            Positioned(
              left: _surface!.left,
              right: MediaQuery.sizeOf(context).width - _surface!.right,
              top: _surface!.top - 44,
              child: Center(
                child: ElevatedButton(
                  style: AppButtonStyles.baseButtonStyle,
                  key: const Key('clear-time-picker'),
                  onPressed: widget.onClear,
                  child: const Text('Clear time'),
                ),
              ),
            ),
        ],
      );
    }

    void _measure() {
      if (!mounted) return;
      final ctx = _childKey.currentContext;
      if (ctx == null) return;
      final box = _findDialogSurface(ctx as Element);
      if (box == null) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect != _surface) setState(() => _surface = rect);
    }

    //Ищет Material карты диалога (поверхность) — самую большую по площади
    RenderBox? _findDialogSurface(Element element) {
      RenderBox? found;
      void visit(Element element) {
        final w = element.widget;
        if (w is Material && w.type == MaterialType.card) {
          final ro = element.renderObject;
          if (ro is RenderBox && ro.hasSize) {
            final f = found;
            if (f == null ||
                (ro.size.width * ro.size.height) >
                    (f.size.width * f.size.height)) {
              found = ro;
            }
          }
        }
        element.visitChildElements(visit);
      }
      visit(element);
      return found;
    }
  }

Future<DateTime?> chooseDateOnly(BuildContext context, DateTime? date,) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    final dt =
        date?.copyWith(
          year: selected?.year,
          month: selected?.month,
          day: selected?.day,
        ) ??
        selected?.add(const Duration(milliseconds: 1));
    return dt;
  }


bool isDateInSameWeek(DateTime date, DateTime anchorDate) {
  // Find Monday of the anchor date's week
  final anchorWeekStart = getWeekStart(anchorDate);
  // Week ends on Sunday (start + 6 days)
  final anchorWeekEnd = anchorWeekStart.add(const Duration(days: 6));

  // Check if date falls within [anchorWeekStart, anchorWeekEnd]
  return !date.isBefore(anchorWeekStart) && !date.isAfter(anchorWeekEnd);
}

///Показывает допом на неделю до и после
bool isDateInSameWeekExtended(DateTime date, DateTime anchorDate) {
  // Find Monday of the anchor date's week
  final anchorWeekStart = getWeekStart(anchorDate).subtract(Duration(days: 7));
  // Week ends on Sunday (start + 6 days)
  final anchorWeekEnd = getWeekStart(anchorDate).add(const Duration(days: 14));

  // Check if date falls within [anchorWeekStart, anchorWeekEnd]
  return !date.isBefore(anchorWeekStart) && !date.isAfter(anchorWeekEnd);
}

/// Returns the start of the week (Monday) for a given date
DateTime getWeekStart(DateTime date) {
  final weekday = date.weekday; // 1 = Monday, 7 = Sunday
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}

List<DateTime> getDatesForWeek(DateTime anchorDate) {
  final weekStart = getWeekStart(anchorDate);
  return List.generate(7, (index) => weekStart.add(Duration(days: index)));
}

extension DateTimeStartOfDay on DateTime {
  // Возвращает дату в начале дня (00:00:00), чтобы сравнивать только дни
  DateTime get startOfDay => DateTime(year, month, day).add(const Duration(milliseconds: 1));
}

extension DateTimeDurationInMinutes on DateTime {
  //Пишет длительность в минутах дня(времени)
  int get durationInMinutes => hour * 60 + minute;
}

extension IsDateOnly on DateTime {
  bool get isDateOnly =>
      millisecond == 1 && second == 0 && minute == 0 && hour == 0;
}
