import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/bot/bot_keyboard.dart';
import 'package:teledart/model.dart';

void main() {
  test('home menu exposes supported actions', () {
    final data = BotKeyboard.home().inlineKeyboard
        .expand((row) => row)
        .map((button) => button.callbackData)
        .toSet();
    expect(
      data,
      containsAll([
        'menu:task',
        'menu:today',
        'menu:add',
        'menu:project',
        'menu:help',
      ]),
    );
  });

  test('task keyboard offers navigation and bounded callback payloads', () {
    const id = '12345678-1234-1234-1234-123456789012';
    final keyboard = BotKeyboard.tasks(
      [id],
      viewId: id,
      page: 2,
      hasNext: true,
    );
    expect(keyboard.inlineKeyboard.first.single.text, '11');
    final data = keyboard.inlineKeyboard
        .expand((row) => row)
        .map((button) => button.callbackData!)
        .toList();
    expect(data, contains('task:$id'));
    expect(data, contains('view:$id:1'));
    expect(data, contains('view:$id:3'));
    expect(data.every((value) => utf8.encode(value).length <= 64), isTrue);
  });

  test('number buttons select the matching task in screenshot order', () {
    final ids = List.generate(6, (i) => 'task-$i');
    final keyboard = BotKeyboard.tasks(
      ids,
      viewId: 'view-id',
      page: 1,
      hasNext: false,
    );
    final numberButtons = keyboard.inlineKeyboard.first;
    expect(numberButtons.map((button) => button.text).toList(), [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
    ]);
    expect(numberButtons.map((button) => button.callbackData).toList(), [
      for (final id in ids) 'task:$id',
    ]);
  });

  test(
    'completed task has no finish button but keeps worklog and delete actions',
    () {
      final keyboard = BotKeyboard.taskDetail('task-id', done: true);
      final data = keyboard.inlineKeyboard
          .expand((row) => row)
          .map((InlineKeyboardButton button) => button.callbackData)
          .toList();
      expect(data, isNot(contains('done:task-id')));
      expect(
        data,
        containsAll([
          'edit:task-id',
          'logs:task-id',
          'logadd:task-id',
          'delete:task-id',
        ]),
      );
    },
  );

  test('edit menus expose fields and fit Telegram callback limit', () {
    const id = '12345678-1234-1234-1234-123456789012';
    final callbacks =
        [
              BotKeyboard.editTask(id),
              BotKeyboard.editStatus(id),
              BotKeyboard.editPriority(id),
            ]
            .expand((menu) => menu.inlineKeyboard.expand((row) => row))
            .map((button) => button.callbackData!);
    expect(callbacks, contains('editfield:title:$id'));
    expect(callbacks, contains('editfield:scheduledAt:$id'));
    expect(callbacks, contains('editfield:dueDate:$id'));
    expect(callbacks, contains('editstatus:done:$id'));
    expect(callbacks, contains('editpriority:2:$id'));
    expect(callbacks, contains('taskback:$id'));
    expect(callbacks.every((data) => utf8.encode(data).length <= 64), isTrue);
  });
}
