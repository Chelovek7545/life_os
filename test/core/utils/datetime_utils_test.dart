import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:test/test.dart';

void main() {
  group('isDateInSameWeek', () {
    test('returns true for dates in same week (Mon-Sun)', () {
      final monday = DateTime(2024, 1, 15); // Monday
      final sunday = DateTime(2024, 1, 21); // Sunday
      final wednesday = DateTime(2024, 1, 17);

      expect(isDateInSameWeek(wednesday, monday), isTrue);
      expect(isDateInSameWeek(sunday, monday), isTrue);
      expect(isDateInSameWeek(monday, wednesday), isTrue);
    });

    test('returns false for dates in different weeks', () {
      final mondayWeek1 = DateTime(2024, 1, 15);
      final mondayWeek2 = DateTime(2024, 1, 22);
      final sundayWeek1 = DateTime(2024, 1, 21);
      final mondayWeek3 = DateTime(2024, 1, 29);

      expect(isDateInSameWeek(mondayWeek2, mondayWeek1), isFalse);
      expect(isDateInSameWeek(mondayWeek3, mondayWeek1), isFalse);
      expect(isDateInSameWeek(sundayWeek1.add(const Duration(days: 1)), mondayWeek1), isFalse);
    });

    test('handles year boundaries', () {
      // Dec 30, 2024 is Monday, week continues into 2025
      final monday = DateTime(2024, 12, 30);
      final sunday = DateTime(2025, 1, 5);

      expect(isDateInSameWeek(sunday, monday), isTrue);
      expect(isDateInSameWeek(DateTime(2025, 1, 6), monday), isFalse);
    });

    test('handles leap year February', () {
      final monday = DateTime(2024, 2, 26); // Leap year
      final sunday = DateTime(2024, 3, 3);

      expect(isDateInSameWeek(sunday, monday), isTrue);
    });

    test('ignores time component', () {
      final mondayMorning = DateTime(2024, 1, 15, 9, 0);
      final mondayNight = DateTime(2024, 1, 15, 23, 59, 59, 999);

      expect(isDateInSameWeek(mondayNight, mondayMorning), isTrue);
    });
  });

  group('getWeekStart', () {
    test('returns Monday for Monday input', () {
      final monday = DateTime(2024, 1, 15);
      final start = getWeekStart(monday);

      expect(start, DateTime(2024, 1, 15));
      expect(start.weekday, DateTime.monday);
    });

    test('returns Monday for Wednesday input', () {
      final wednesday = DateTime(2024, 1, 17);
      final start = getWeekStart(wednesday);

      expect(start, DateTime(2024, 1, 15));
      expect(start.weekday, DateTime.monday);
    });

    test('returns Monday for Sunday input', () {
      final sunday = DateTime(2024, 1, 21);
      final start = getWeekStart(sunday);

      expect(start, DateTime(2024, 1, 15));
      expect(start.weekday, DateTime.monday);
    });

    test('strips time component', () {
      final datetime = DateTime(2024, 1, 17, 14, 30, 45, 123);
      final start = getWeekStart(datetime);

      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);
      expect(start.millisecond, 0);
    });

    test('handles year boundary', () {
      final sunday = DateTime(2024, 12, 29); // Last Sunday of 2024
      final start = getWeekStart(sunday);

      // Week starts on Monday Dec 23, 2024
      expect(start, DateTime(2024, 12, 23));
    });
  });

  group('getDatesForWeek', () {
    test('returns 7 dates starting from Monday', () {
      final anchor = DateTime(2024, 1, 17); // Wednesday
      final dates = getDatesForWeek(anchor);

      expect(dates.length, 7);
      expect(dates.first, DateTime(2024, 1, 15)); // Monday
      expect(dates.last, DateTime(2024, 1, 21)); // Sunday
    });

    test('each date is consecutive', () {
      final dates = getDatesForWeek(DateTime(2024, 1, 15));

      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].difference(dates[i - 1]).inDays, 1);
      }
    });

    test('handles year boundary', () {
      // Dec 29, 2024 is a Sunday, so the week starts on Mon Dec 23, 2024
      // and ends on Sun Dec 29, 2024 (not crossing into 2025)
      final anchor = DateTime(2024, 12, 29);
      final dates = getDatesForWeek(anchor);

      expect(dates.first, DateTime(2024, 12, 23));
      expect(dates.last, DateTime(2024, 12, 29));
    });

    test('handles year boundary crossing', () {
      // Jan 1, 2025 is a Wednesday, week starts Mon Dec 30, 2024
      final anchor = DateTime(2025, 1, 1);
      final dates = getDatesForWeek(anchor);

      expect(dates.first, DateTime(2024, 12, 30));
      expect(dates.last, DateTime(2025, 1, 5));
    });

    test('handles leap year', () {
      final anchor = DateTime(2024, 2, 28); // Wednesday in leap year Feb
      final dates = getDatesForWeek(anchor);

      expect(dates.contains(DateTime(2024, 2, 29)), isTrue); // Feb 29 exists
      expect(dates.last, DateTime(2024, 3, 3));
    });

    test('all dates have time stripped', () {
      final dates = getDatesForWeek(DateTime.now());

      for (final date in dates) {
        expect(date.hour, 0);
        expect(date.minute, 0);
        expect(date.second, 0);
        expect(date.millisecond, 0);
      }
    });
  });

  group('DateTime.startOfDay extension', () {
    test('strips time component', () {
      final dt = DateTime(2024, 1, 15, 14, 30, 45, 123);
      final start = dt.startOfDay;

      expect(start, DateTime(2024, 1, 15));
      expect(start.hour, 0);
      expect(start.minute, 0);
      expect(start.second, 0);
      expect(start.millisecond, 0);
    });

    test('preserves date for midnight', () {
      final dt = DateTime(2024, 1, 15, 0, 0, 0, 0);
      expect(dt.startOfDay, dt);
    });
  });

  group('DateTime.durationInMinutes extension', () {
    test('calculates minutes from hour and minute', () {
      expect(DateTime(2024, 1, 1, 0, 0).durationInMinutes, 0);
      expect(DateTime(2024, 1, 1, 1, 0).durationInMinutes, 60);
      expect(DateTime(2024, 1, 1, 12, 30).durationInMinutes, 750);
      expect(DateTime(2024, 1, 1, 23, 59).durationInMinutes, 1439);
    });

    test('ignores seconds and milliseconds', () {
      expect(DateTime(2024, 1, 1, 10, 30, 45).durationInMinutes, 630);
      expect(DateTime(2024, 1, 1, 10, 30, 0, 500).durationInMinutes, 630);
    });
  });

  group('DateTime.isDateOnly extension', () {
    test('returns true for 00:00:00.001', () {
      final dt = DateTime(2024, 1, 15, 0, 0, 0, 1);
      expect(dt.isDateOnly, isTrue);
    });

    test('returns false when hour is not 0', () {
      expect(DateTime(2024, 1, 15, 1, 0, 0, 1).isDateOnly, isFalse);
    });

    test('returns false when minute is not 0', () {
      expect(DateTime(2024, 1, 15, 0, 1, 0, 1).isDateOnly, isFalse);
    });

    test('returns false when second is not 0', () {
      expect(DateTime(2024, 1, 15, 0, 0, 1, 1).isDateOnly, isFalse);
    });

    test('returns false when millisecond is not 1', () {
      expect(DateTime(2024, 1, 15, 0, 0, 0, 0).isDateOnly, isFalse);
      expect(DateTime(2024, 1, 15, 0, 0, 0, 2).isDateOnly, isFalse);
    });

    test('returns false for normal datetime', () {
      expect(DateTime.now().isDateOnly, isFalse);
    });
  });
}