import 'package:flutter/foundation.dart';

/// Imperative handle for a [CalendarView].
///
/// It is safe to create this object outside the widget tree. Calls made before
/// a view attaches are retained and applied when it does.
class CalendarController extends ChangeNotifier {
  CalendarControllerDelegate? _delegate;
  DateTime? _pendingDate;
  int? _pendingMinutes;
  double? _pendingHourHeight;
  double? _pendingDayWidth;

  DateTime? get focusedDate => _delegate?.focusedDate ?? _pendingDate;

  void goToDate(DateTime date) {
    _pendingDate = date;
    _delegate?.goToDate(date);
    notifyListeners();
  }

  void goToWeek(DateTime date) => goToDate(date);
  void nextWeek() =>
      goToDate((focusedDate ?? DateTime.now()).add(const Duration(days: 7)));
  void previousWeek() => goToDate(
    (focusedDate ?? DateTime.now()).subtract(const Duration(days: 7)),
  );

  void scrollToTime({required int hour, int minute = 0, bool animated = true}) {
    _pendingMinutes = hour * 60 + minute;
    _delegate?.scrollToMinutes(_pendingMinutes!, animated: animated);
  }

  void zoomTo({double? hourHeight, double? dayWidth, bool animated = true}) {
    _pendingHourHeight = hourHeight ?? _pendingHourHeight;
    _pendingDayWidth = dayWidth ?? _pendingDayWidth;
    _delegate?.zoomTo(
      hourHeight: hourHeight,
      dayWidth: dayWidth,
      animated: animated,
    );
  }

  void attach(CalendarControllerDelegate delegate) {
    _delegate = delegate;
    if (_pendingDate != null) delegate.goToDate(_pendingDate!);
    if (_pendingMinutes != null)
      delegate.scrollToMinutes(_pendingMinutes!, animated: false);
    if (_pendingHourHeight != null || _pendingDayWidth != null) {
      delegate.zoomTo(
        hourHeight: _pendingHourHeight,
        dayWidth: _pendingDayWidth,
        animated: false,
      );
    }
  }

  void detach(CalendarControllerDelegate delegate) {
    if (identical(_delegate, delegate)) _delegate = null;
  }
}

abstract interface class CalendarControllerDelegate {
  DateTime get focusedDate;
  void goToDate(DateTime date);
  void scrollToMinutes(int minutes, {required bool animated});
  void zoomTo({double? hourHeight, double? dayWidth, required bool animated});
}
