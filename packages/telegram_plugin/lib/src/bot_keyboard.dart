import 'package:teledart/model.dart';

class BotKeyboard {
  const BotKeyboard._();

  static InlineKeyboardMarkup home() => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(text: '📋 Задачи', callbackData: 'menu:task'),
        InlineKeyboardButton(text: '📅 Сегодня', callbackData: 'menu:today'),
      ],
      [
        InlineKeyboardButton(
          text: '➕ Создать задачу',
          callbackData: 'menu:add',
        ),
      ],
      [
        InlineKeyboardButton(text: '🗂 Проекты', callbackData: 'menu:project'),
        InlineKeyboardButton(
          text: '⚠️ Просрочено',
          callbackData: 'menu:overdue',
        ),
      ],
      [InlineKeyboardButton(text: '❔ Помощь', callbackData: 'menu:help')],
    ],
  );

  static InlineKeyboardMarkup tasks(
    List<String> taskIds, {
    required String viewId,
    required int page,
    required bool hasNext,
  }) => InlineKeyboardMarkup(
    inlineKeyboard: [
      for (var start = 0; start < taskIds.length; start += 6)
        [
          for (var i = start; i < taskIds.length && i < start + 6; i++)
            InlineKeyboardButton(
              text: '${(page - 1) * 10 + i + 1}',
              callbackData: 'task:${taskIds[i]}',
            ),
        ],
      [
        InlineKeyboardButton(text: 'Сегодня', callbackData: 'menu:today'),
        InlineKeyboardButton(text: 'Завтра', callbackData: 'menu:tomorrow'),
        InlineKeyboardButton(text: 'Неделя', callbackData: 'menu:week'),
      ],
      [
        InlineKeyboardButton(text: 'Все', callbackData: 'menu:task'),
        InlineKeyboardButton(text: 'Просрочено', callbackData: 'menu:overdue'),
      ],
      if (page > 1 || hasNext)
        [
          if (page > 1)
            InlineKeyboardButton(
              text: '← Назад',
              callbackData: 'view:$viewId:${page - 1}',
            ),
          if (hasNext)
            InlineKeyboardButton(
              text: 'Дальше →',
              callbackData: 'view:$viewId:${page + 1}',
            ),
        ],
    ],
  );

  static InlineKeyboardMarkup taskDetail(
    String id, {
    required bool done,
  }) => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: '✏️ Редактировать',
          callbackData: 'edit:$id',
        ),
      ],
      if (!done)
        [InlineKeyboardButton(text: '✅ Завершить', callbackData: 'done:$id')],
      [
        InlineKeyboardButton(text: '📝 Ворклоги', callbackData: 'logs:$id'),
        InlineKeyboardButton(text: '✍️ Записать', callbackData: 'logadd:$id'),
      ],
      [InlineKeyboardButton(text: '🗑 Удалить', callbackData: 'delete:$id')],
      [InlineKeyboardButton(text: '📋 К задачам', callbackData: 'menu:task')],
    ],
  );

  static InlineKeyboardMarkup editTask(String id) => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: 'Название',
          callbackData: 'editfield:title:$id',
        ),
        InlineKeyboardButton(
          text: 'Описание',
          callbackData: 'editfield:description:$id',
        ),
      ],
      [
        InlineKeyboardButton(
          text: 'План',
          callbackData: 'editfield:scheduledAt:$id',
        ),
        InlineKeyboardButton(
          text: 'Срок',
          callbackData: 'editfield:dueDate:$id',
        ),
      ],
      [
        InlineKeyboardButton(
          text: 'Проект',
          callbackData: 'editfield:project:$id',
        ),
        InlineKeyboardButton(
          text: 'Статус',
          callbackData: 'editfield:status:$id',
        ),
      ],
      [
        InlineKeyboardButton(
          text: 'Приоритет',
          callbackData: 'editfield:priority:$id',
        ),
      ],
      [InlineKeyboardButton(text: '← К задаче', callbackData: 'taskback:$id')],
    ],
  );

  static InlineKeyboardMarkup editStatus(String id) => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: 'Не начата',
          callbackData: 'editstatus:todo:$id',
        ),
        InlineKeyboardButton(
          text: 'Открыта',
          callbackData: 'editstatus:open:$id',
        ),
      ],
      [
        InlineKeyboardButton(
          text: 'В работе',
          callbackData: 'editstatus:progress:$id',
        ),
        InlineKeyboardButton(
          text: 'Завершена',
          callbackData: 'editstatus:done:$id',
        ),
      ],
      [InlineKeyboardButton(text: '← Назад', callbackData: 'edit:$id')],
    ],
  );

  static InlineKeyboardMarkup editPriority(String id) => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(
          text: 'Низкий',
          callbackData: 'editpriority:0:$id',
        ),
        InlineKeyboardButton(
          text: 'Обычный',
          callbackData: 'editpriority:1:$id',
        ),
        InlineKeyboardButton(
          text: 'Высокий',
          callbackData: 'editpriority:2:$id',
        ),
      ],
      [InlineKeyboardButton(text: '← Назад', callbackData: 'edit:$id')],
    ],
  );

  static InlineKeyboardMarkup worklogs(
    List<String> ids, {
    required String viewId,
    required int page,
    required bool hasNext,
  }) => InlineKeyboardMarkup(
    inlineKeyboard: [
      for (var i = 0; i < ids.length; i++)
        [
          InlineKeyboardButton(
            text: '🗑 Удалить запись ${i + 1}',
            callbackData: 'logdel:${ids[i]}',
          ),
        ],
      if (page > 1 || hasNext)
        [
          if (page > 1)
            InlineKeyboardButton(
              text: '← Назад',
              callbackData: 'view:$viewId:${page - 1}',
            ),
          if (hasNext)
            InlineKeyboardButton(
              text: 'Дальше →',
              callbackData: 'view:$viewId:${page + 1}',
            ),
        ],
      [InlineKeyboardButton(text: '📋 К задачам', callbackData: 'menu:task')],
    ],
  );

  static InlineKeyboardMarkup pages(String viewId, int page, bool hasNext) =>
      InlineKeyboardMarkup(
        inlineKeyboard: [
          if (page > 1 || hasNext)
            [
              if (page > 1)
                InlineKeyboardButton(
                  text: '← Назад',
                  callbackData: 'view:$viewId:${page - 1}',
                ),
              if (hasNext)
                InlineKeyboardButton(
                  text: 'Дальше →',
                  callbackData: 'view:$viewId:${page + 1}',
                ),
            ],
          [InlineKeyboardButton(text: '🏠 Меню', callbackData: 'menu:help')],
        ],
      );

  static InlineKeyboardMarkup confirm(String id) => InlineKeyboardMarkup(
    inlineKeyboard: [
      [
        InlineKeyboardButton(text: 'Подтвердить', callbackData: 'ok:$id'),
        InlineKeyboardButton(text: 'Отмена', callbackData: 'no:$id'),
      ],
    ],
  );
}
