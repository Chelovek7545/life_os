import 'package:life_os/core/utils/smart_task_input.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 19, 18);

  test('recognizes the two tasks and exact source ranges from the note', () {
    const input =
        'Завтра в 7 утра сделать дз а с 8 до 9 в понедельник уборку в доме';
    final [homework, cleaning] = parseQuickTasks(input, now);
    expect(homework.title, 'сделать дз');
    expect(homework.startsAt, DateTime(2026, 11, 20, 7));
    expect(homework.endsAt, isNull);
    expect(homework.deadline, isNull);
    expect(cleaning.title, 'уборку в доме');
    expect(cleaning.startsAt, DateTime(2026, 11, 23, 8));
    expect(cleaning.endsAt, DateTime(2026, 11, 23, 9));
    expect(cleaning.issues, isEmpty);
    expect(
      [
        for (final span in cleaning.spans)
          input.substring(span.start, span.end),
      ],
      ['с 8 до 9', 'в понедельник', 'уборку в доме'],
    );
  });

  test(
    'uses local midnight for dates and keeps explicit deadlines separate',
    () {
      final [planned, deadlineOnly, text] = parseQuickTasks(
        'На 03.01 читать; сдать отчёт дедлайн послезавтра, приоритет высокий\n'
        'Разобрать планы и купить продукты',
        now,
      );
      expect(planned.startsAt, DateTime(2027, 1, 3));
      expect(planned.endsAt, isNull);
      expect(deadlineOnly.startsAt, isNull);
      expect(deadlineOnly.deadline, DateTime(2026, 11, 21));
      expect(deadlineOnly.title, 'сдать отчёт');
      expect(deadlineOnly.priority, 2);
      expect(text.title, 'Разобрать планы и купить продукты');
      expect(text.startsAt, isNull);
    },
  );

  test('resolves times of day and validates past-midnight intervals', () {
    final [evening, invalid, repeated] = parseQuickTasks(
      'Встреча с 7 до 9 вечера; Переезд с 22 до 02; Завтра сегодня отчёт',
      now,
    );
    expect(evening.startsAt, DateTime(2026, 11, 19, 19));
    expect(evening.endsAt, DateTime(2026, 11, 19, 21));
    expect(invalid.issues.single, contains('окончания'));
    expect(repeated.issues.single, contains('несколько раз'));
    expect(parseQuickTasks('Встреча в 18:70', now).single.issues, isNotEmpty);
    expect(parseQuickTasks('Встреча на 31.02', now).single.issues, isNotEmpty);
  });

  test(
    'edits the original field and preserves literal titles and other tasks',
    () {
      const input = 'Купить завтра молоко; во вторник спорт';
      final first = parseQuickTasks(input, now).first;
      const title = r'Посмотреть "Завтра"; открыть C:\docs';
      final changed = first.replaceField(
        input,
        QuickTaskField.title,
        quoteQuickTaskTitle(title),
      );
      final [renamed, other] = parseQuickTasks(changed, now);
      expect(renamed.title, title);
      expect(renamed.startsAt, DateTime(2026, 11, 20));
      expect(other.title, 'спорт');
      expect(
        parseQuickTasks(
          renamed.replaceField(changed, QuickTaskField.date, 'на 25.11.2026'),
          now,
        ).first.startsAt,
        DateTime(2026, 11, 25),
      );
    },
  );

  test('removing a leading time keeps the separate task', () {
    const input = 'Сделать дз а в 8 уборка';
    final second = parseQuickTasks(input, now).last;
    final changed = second.replaceField(input, QuickTaskField.time, '');
    final [homework, cleaning] = parseQuickTasks(changed, now);
    expect(homework.title, 'Сделать дз');
    expect(cleaning.title, 'уборка');
    expect(cleaning.startsAt, isNull);
  });
}
