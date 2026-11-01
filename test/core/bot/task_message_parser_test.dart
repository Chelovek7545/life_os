import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_plugin/telegram_plugin.dart' show TaskMessageParser;

void main() {
  const parser = TaskMessageParser();
  final now = DateTime(2026, 10, 30, 12);

  test('interprets a task, relative date, and project locally', () {
    final draft = parser.parse(
      'Добавь задачу Купить книгу завтра в проект "Учёба"',
      now,
    );
    expect(draft?.title, 'Купить книгу');
    expect(draft?.scheduledAt, DateTime(2026, 10, 31));
    expect(draft?.projectName, 'Учёба');
  });

  test('rejects ambiguous and destructive messages', () {
    expect(parser.parse('удали задачу', now), isNull);
    expect(parser.parse('задача:', now), isNull);
    expect(parser.parse('одна\nдругая', now), isNull);
    expect(parser.parse('Купить книгу в понедельник', now), isNull);
  });
}
