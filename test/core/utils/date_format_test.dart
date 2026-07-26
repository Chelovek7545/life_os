import 'package:life_os/core/utils/date_format.dart';
import 'package:test/test.dart';

void main() {
  group('formatDate', () {
    test('formats date as DD.MM.YYYY', () {
      expect(formatDate(DateTime(2024, 1, 15)), '15.01.2024');
      expect(formatDate(DateTime(2024, 12, 1)), '01.12.2024');
      expect(formatDate(DateTime(2024, 3, 5)), '05.03.2024');
    });
  });

  group('getWeekDayName', () {
    test('returns MON for Monday', () {
      expect(getWeekDayName(DateTime.monday), 'MON');
    });

    test('returns TUE for Tuesday', () {
      expect(getWeekDayName(DateTime.tuesday), 'TUE');
    });

    test('returns WED for Wednesday', () {
      expect(getWeekDayName(DateTime.wednesday), 'WED');
    });

    test('returns THU for Thursday', () {
      expect(getWeekDayName(DateTime.thursday), 'THU');
    });

    test('returns FRI for Friday', () {
      expect(getWeekDayName(DateTime.friday), 'FRI');
    });

    test('returns SAT for Saturday', () {
      expect(getWeekDayName(DateTime.saturday), 'SAT');
    });

    test('returns SUN for Sunday', () {
      expect(getWeekDayName(DateTime.sunday), 'SUN');
    });

    test('returns SUN for unknown index', () {
      expect(getWeekDayName(0), 'SUN');
      expect(getWeekDayName(8), 'SUN');
    });
  });

  group('formatTimeOfDate', () {
    test('formats time as HH:MM', () {
      expect(formatTimeOfDate(DateTime(2024, 1, 15, 9, 5)), '09:05');
      expect(formatTimeOfDate(DateTime(2024, 1, 15, 23, 59)), '23:59');
      expect(formatTimeOfDate(DateTime(2024, 1, 15, 0, 0)), '00:00');
      expect(formatTimeOfDate(DateTime(2024, 1, 15, 14, 30)), '14:30');
    });
  });
}
