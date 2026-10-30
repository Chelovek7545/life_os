import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:life_os/core/bot/bot_task_store.dart';
import 'package:life_os/core/bot/bot_task_list_formatter.dart';
import 'package:life_os/core/bot/bot_polling_fetcher.dart';
import 'package:life_os/core/bot/bot_keyboard.dart';
import 'package:life_os/core/bot/bot_task_edit.dart';
import 'package:life_os/core/bot/task_message_parser.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/work_log_model.dart';
import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';
import 'package:uuid/uuid.dart';

class _PendingAction {
  _PendingAction(this.userId, this.chatId, this.run, this.resultMarkup)
    : expires = DateTime.now().add(const Duration(minutes: 5));
  final int userId;
  final int chatId;
  final Future<String> Function() run;
  final InlineKeyboardMarkup resultMarkup;
  final DateTime expires;
}

class _InlineView {
  _InlineView(this.userId, this.chatId, this.render)
    : expires = DateTime.now().add(const Duration(minutes: 15));
  final int userId;
  final int chatId;
  final Future<void> Function(int page, int messageId, String viewId) render;
  final DateTime expires;
}

class _TaskEditSession {
  _TaskEditSession(this.taskId, this.field, this.updatedAt, this.messageId)
    : expires = DateTime.now().add(const Duration(minutes: 10));

  final String taskId;
  final BotTaskEditField field;
  final DateTime updatedAt;
  final int messageId;
  final DateTime expires;
}

class _WorklogQuery {
  const _WorklogQuery(
    this.taskId,
    this.from,
    this.until,
    this.status,
    this.search,
  );
  final String taskId;
  final DateTime? from;
  final DateTime? until;
  final int? status;
  final String? search;
}

class LocalBotService {
  LocalBotService({
    required BotTaskStore taskStore,
    required TasksRepository tasksRepository,
    required WorkLogsRepository workLogsRepository,
    String? botToken,
    this.onTokenRequested,
    this.onInvalidToken,
  }) : _store = taskStore,
       _tasks = tasksRepository,
       _logs = workLogsRepository,
       _botToken = botToken;

  final BotTaskStore _store;
  final TasksRepository _tasks;
  final WorkLogsRepository _logs;
  final Map<String, _PendingAction> _pending = {};
  final Map<String, _InlineView> _views = {};
  final Map<String, _TaskEditSession> _editSessions = {};
  String? _botToken;
  TeleDart? _bot;
  BotPollingFetcher? _polling;
  bool _starting = false;
  int _generation = 0;
  StreamSubscription? _messages;
  StreamSubscription? _callbacks;
  final ValueNotifier<bool> isRunning = ValueNotifier(false);
  Future<String?> Function()? onTokenRequested;
  FutureOr<void> Function(String errorMessage)? onInvalidToken;
  FutureOr<void> Function(String errorMessage)? onPollingError;

  Set<int> get _allowed => SettingsService.tgAllowedUsers.value
      .split(RegExp(r'[,;\s]+'))
      .map(int.tryParse)
      .whereType<int>()
      .where((id) => id > 0)
      .toSet();

  bool _authorized(int? id, String type) =>
      type == 'private' && id != null && _allowed.contains(id);

  Future<void> startBot() async {
    if (_starting || isRunning.value) return;
    _starting = true;
    final generation = _generation;
    try {
      await _startBot(generation);
    } finally {
      _starting = false;
    }
  }

  Future<void> _startBot(int generation) async {
    if (_allowed.isEmpty) {
      debugPrint('Telegram: укажите разрешённые User ID в настройках.');
      await onInvalidToken?.call(
        'Укажите разрешённые Telegram User ID в настройках.',
      );
      return;
    }
    var token = SettingsService.tgToken.value.trim();
    if (token.isEmpty) token = _botToken?.trim() ?? '';
    if (token.isEmpty) token = (await onTokenRequested?.call())?.trim() ?? '';
    if (token.isEmpty) return;
    try {
      final telegram = Telegram(token);
      final me = await telegram.getMe();
      if (generation != _generation) return;
      if (me.username == null) throw StateError('У бота нет username');
      await telegram.deleteWebhook();
      if (generation != _generation) return;
      final polling = BotPollingFetcher(
        telegram,
        onConflict: () =>
            scheduleMicrotask(() => unawaited(_reportPollingConflict())),
        onUnauthorized: () =>
            scheduleMicrotask(() => unawaited(_reportInvalidToken())),
        onFailure: () =>
            scheduleMicrotask(() => unawaited(_reportPollingFailure())),
      );
      final bot = TeleDart(token, Event(me.username!), fetcher: polling);
      _polling = polling;
      _bot = bot;
      _messages = bot
          .onMessage(entityType: '*')
          .listen(
            (message) => unawaited(
              _handleMessage(message).catchError((Object error) {
                debugPrint('Ошибка обработки сообщения Telegram: $error');
              }),
            ),
            onError: (Object error) =>
                debugPrint('Ошибка потока сообщений Telegram: $error'),
          );
      _callbacks = bot.onCallbackQuery().listen(
        (callback) => unawaited(
          _handleCallback(callback).catchError((Object error) {
            debugPrint('Ошибка callback Telegram: $error');
          }),
        ),
        onError: (Object error) =>
            debugPrint('Ошибка потока callback Telegram: $error'),
      );
      bot.start();
      isRunning.value = true;
      unawaited(_registerCommands(telegram));
    } catch (error) {
      final value = error.toString().toLowerCase();
      if (value.contains('401') ||
          value.contains('404') ||
          value.contains('unauthorized')) {
        await onInvalidToken?.call('Неверный токен Telegram-бота.');
      } else {
        debugPrint('Ошибка запуска Telegram-бота: $error');
      }
      await stopBot();
    }
  }

  Future<void> _registerCommands(Telegram telegram) async {
    try {
      await telegram
          .setMyCommands([
            BotCommand(command: 'start', description: 'Открыть главное меню'),
            BotCommand(command: 'help', description: 'Команды и примеры'),
            BotCommand(command: 'task', description: 'Просмотр и поиск задач'),
            BotCommand(command: 'edit', description: 'Изменить задачу по ID'),
            BotCommand(command: 'project', description: 'Список проектов'),
            BotCommand(command: 'worklog', description: 'Ворклоги задачи'),
            BotCommand(
              command: 'cancel',
              description: 'Отменить подтверждение',
            ),
          ], scope: BotCommandScopeAllPrivateChats())
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Не удалось обновить команды Telegram: ${error.runtimeType}');
    }
    try {
      await telegram
          .setChatMenuButton(null, MenuButtonCommands())
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Не удалось включить меню Telegram: ${error.runtimeType}');
    }
  }

  Future<void> stopBot() async {
    _generation++;
    isRunning.value = false;
    _pending.clear();
    _views.clear();
    _editSessions.clear();
    final legacyFetcher = _bot?.fetcher;
    final drainLegacy =
        _polling == null &&
        legacyFetcher is LongPolling &&
        legacyFetcher.isPolling;
    _bot?.stop();
    await _messages?.cancel();
    await _callbacks?.cancel();
    _messages = null;
    _callbacks = null;
    await _polling?.stop();
    if (drainLegacy) {
      // The previous Teledart fetcher keeps its HTTP request alive after stop.
      await Future<void>.delayed(const Duration(seconds: 34));
    }
    _polling = null;
    _bot = null;
  }

  Future<void> _reportPollingConflict() async {
    await stopBot();
    await onPollingError?.call(
      'Бот уже получает сообщения в другом экземпляре приложения или сервисе. Остановите его и запустите бота снова.',
    );
  }

  Future<void> _reportPollingFailure() async {
    await stopBot();
    await onPollingError?.call(
      'Не удалось получать сообщения Telegram. Проверьте подключение к сети и попробуйте снова.',
    );
  }

  Future<void> _reportInvalidToken() async {
    await stopBot();
    await onInvalidToken?.call('Неверный токен Telegram-бота.');
  }

  Future<void> resetSavedToken() async {
    await SettingsService.setTgToken('');
    _botToken = null;
  }

  Future<void> _handleMessage(dynamic message) async {
    if (!_authorized(message.from?.id as int?, message.chat.type as String))
      return;
    final text = (message.text as String?)?.trim() ?? '';
    if (text.isEmpty) return;
    try {
      if (!text.startsWith('/')) {
        final key = '${message.from.id}:${message.chat.id}';
        final edit = _editSessions[key];
        if (edit != null) {
          if (DateTime.now().isAfter(edit.expires)) {
            _editSessions.remove(key);
            return _sendOrEdit(
              message.chat.id as int,
              'Время редактирования истекло. Откройте задачу снова.',
              BotKeyboard.home(),
              messageId: edit.messageId,
            );
          }
          return _submitTaskEdit(message, edit, text);
        }
        return _proposeTask(message, text);
      }
      final command = text.split(RegExp(r'\s+')).first;
      final name = command.split('@').first.toLowerCase();
      final args = text.substring(command.length).trim();
      switch (name) {
        case '/start':
        case '/help':
          await _sendHelp(message.chat.id as int);
        case '/cancel':
          _pending.removeWhere((_, action) => action.userId == message.from.id);
          final edit = _editSessions.remove(
            '${message.from.id}:${message.chat.id}',
          );
          if (edit == null) {
            await message.reply('Ожидающее действие отменено.');
          } else {
            await _sendOrEdit(
              message.chat.id as int,
              'Редактирование отменено.',
              BotKeyboard.home(),
              messageId: edit.messageId,
            );
          }
        case '/task':
          await _handleTask(message, args);
        case '/edit':
          if (args.isEmpty) {
            await message.reply('Укажите ID задачи: /edit ID');
          } else {
            _editSessions.remove('${message.from.id}:${message.chat.id}');
            await _showEditTaskMenu(message.chat.id as int, args);
          }
        case '/project':
          await _handleProjects(message, args);
        case '/worklog':
          await _handleWorklog(message, args);
        default:
          await message.reply('Неизвестная команда. Используйте /help.');
      }
    } catch (error) {
      debugPrint('Ошибка Telegram-команды: $error');
      await message.reply(
        'Не удалось выполнить действие. Проверьте результат в приложении.',
      );
    }
  }

  Future<void> _handleTask(dynamic message, String args) async {
    if (args.startsWith('add '))
      return _proposeTask(message, args.substring(4));
    if (args.startsWith('edit ')) {
      _editSessions.remove('${message.from.id}:${message.chat.id}');
      await _showEditTaskMenu(message.chat.id as int, args.substring(5).trim());
      return;
    }
    if (args.startsWith('delete ')) {
      return _confirmDeleteTask(
        message.from.id as int,
        message.chat.id as int,
        args.substring(7).trim(),
      );
    }
    if (args.startsWith('done ')) {
      final task = await _loadTaskWithTags(args.substring(5).trim());
      if (task == null) return message.reply('Задача не найдена.');
      if (task.status == TaskStatus.done)
        return message.reply('Задача уже завершена.');
      await _tasks.updateTask(
        task.copyWith(status: TaskStatus.done, updatedAt: DateTime.now()),
      );
      return message.reply('Задача завершена.');
    }
    await _showTaskList(message.chat.id as int, message.from.id as int, args);
  }

  Future<void> _showTaskList(
    int chatId,
    int userId,
    String args, {
    int? messageId,
  }) async {
    final parsed = _parseTaskFilter(args);
    if (parsed == null) {
      await _bot!.sendMessage(
        chatId,
        'Неверный фильтр. Пример: /task today status:todo page:2',
      );
      return;
    }
    final (filter, page) = parsed;
    final viewId = _registerView(
      userId,
      chatId,
      (nextPage, messageId, id) =>
          _renderTaskList(chatId, filter, nextPage, id, messageId: messageId),
    );
    await _renderTaskList(chatId, filter, page, viewId, messageId: messageId);
  }

  Future<void> _renderTaskList(
    int chatId,
    BotTaskFilter filter,
    int page,
    String viewId, {
    int? messageId,
  }) async {
    final rows = await _store.find(filter, page: page - 1, pageSize: 10);
    if (rows.isEmpty) {
      await _sendOrEdit(
        chatId,
        'Задачи не найдены.',
        BotKeyboard.tasks([], viewId: viewId, page: page, hasNext: false),
        messageId: messageId,
      );
      return;
    }
    final hasNext = rows.length > 10;
    final visible = rows.take(10).toList();
    await _sendOrEdit(
      chatId,
      BotTaskListFormatter.format(visible, page: page, hasNext: hasNext),
      BotKeyboard.tasks(
        visible.map((row) => row.task.id).toList(),
        viewId: viewId,
        page: page,
        hasNext: hasNext,
      ),
      messageId: messageId,
      parseMode: 'HTML',
    );
  }

  (BotTaskFilter, int)? _parseTaskFilter(String args) {
    DateTime? from, until;
    bool overdue = false;
    TaskStatus? status;
    String? project, search;
    int? priority;
    int page = 1;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    for (final match in RegExp(r'\S+:"[^"]+"|\S+').allMatches(args)) {
      final token = match.group(0)!;
      switch (token.toLowerCase()) {
        case 'today':
          from = day;
          until = day.add(const Duration(days: 1));
          continue;
        case 'tomorrow':
          from = day.add(const Duration(days: 1));
          until = day.add(const Duration(days: 2));
          continue;
        case 'week':
          from = day.subtract(Duration(days: day.weekday - 1));
          until = from.add(const Duration(days: 7));
          continue;
        case 'overdue':
          overdue = true;
          continue;
      }
      final separator = token.indexOf(':');
      if (separator < 0) return null;
      final key = token.substring(0, separator).toLowerCase();
      final value = token.substring(separator + 1).replaceAll('"', '').trim();
      if (value.isEmpty) return null;
      switch (key) {
        case 'status':
          status = switch (value.toLowerCase()) {
            'todo' => TaskStatus.notStarted,
            'open' => TaskStatus.open,
            'progress' => TaskStatus.inProgress,
            'done' => TaskStatus.done,
            _ => null,
          };
          if (status == null) return null;
        case 'project':
          project = value;
        case 'search':
          if (value.contains('%') || value.contains('_') || value.length > 100)
            return null;
          search = value;
        case 'priority':
          priority = switch (value.toLowerCase()) {
            'low' => 0,
            'normal' => 1,
            'high' => 2,
            _ => null,
          };
          if (priority == null) return null;
        case 'page':
          page = int.tryParse(value) ?? 0;
          if (page < 1 || page > 1000) return null;
        default:
          return null;
      }
    }
    return (
      BotTaskFilter(
        from: from,
        until: until,
        overdue: overdue,
        status: status,
        project: project,
        search: search,
        priority: priority,
      ),
      page,
    );
  }

  Future<void> _proposeTask(dynamic message, String text) async {
    final draft = const TaskMessageParser().parse(text, DateTime.now());
    if (draft == null)
      return message.reply(
        'Не удалось распознать одну задачу. Пример: /task add Купить книгу завтра',
      );
    String? projectId;
    if (draft.projectName != null) {
      final projects = await _store.findProjects(draft.projectName!);
      if (projects.length != 1)
        return message.reply('Проект не найден или название неоднозначно.');
      projectId = projects.single.id;
    }
    final selectedProjectId = projectId;
    await _confirm(
      message,
      'Создать задачу «${draft.title}»${draft.scheduledAt == null ? '' : ', запланировано ${_date(draft.scheduledAt!)}'}${draft.projectName == null ? '' : ', проект ${draft.projectName}'}?',
      () async {
        if (selectedProjectId != null) {
          final current = await _store.findProjects(draft.projectName!);
          if (current.length != 1 || current.single.id != selectedProjectId)
            return 'Проект изменился. Повторите запрос.';
        }
        final now = DateTime.now();
        final task = Task(
          id: const Uuid().v4(),
          title: draft.title,
          description: '',
          status: TaskStatus.notStarted,
          createdAt: now,
          updatedAt: now,
          startsAt: draft.scheduledAt,
          projectId: selectedProjectId,
          timerSeconds: 0,
          effortWeight: 1,
          tags: const [],
        );
        await _tasks.addTask(task);
        return 'Задача создана: ${task.title}\nID: ${task.id}';
      },
    );
  }

  Future<void> _handleProjects(dynamic message, String args) async {
    final page = args.isEmpty
        ? 1
        : (args.startsWith('page:') ? int.tryParse(args.substring(5)) : null);
    if (page == null || page < 1 || page > 1000)
      return message.reply('Пример: /project page:2');
    await _showProjects(message.chat.id as int, message.from.id as int, page);
  }

  Future<void> _showProjects(
    int chatId,
    int userId,
    int page, {
    int? messageId,
  }) async {
    final viewId = _registerView(
      userId,
      chatId,
      (nextPage, messageId, id) =>
          _renderProjects(chatId, nextPage, id, messageId: messageId),
    );
    await _renderProjects(chatId, page, viewId, messageId: messageId);
  }

  Future<void> _renderProjects(
    int chatId,
    int page,
    String viewId, {
    int? messageId,
  }) async {
    final projects =
        await (_store.db.select(_store.db.projects)
              ..orderBy([(p) => OrderingTerm(expression: p.name)])
              ..limit(11, offset: (page - 1) * 10))
            .get();
    if (projects.isEmpty) {
      await _sendOrEdit(
        chatId,
        'Проекты не найдены.',
        BotKeyboard.pages(viewId, page, false),
        messageId: messageId,
      );
      return;
    }
    await _sendOrEdit(
      chatId,
      'Проекты, стр. $page:\n${projects.take(10).map((p) => '• ${_short(p.name, 100)}${p.isArchived ? ' (архив)' : ''}\nID: ${p.id}').join('\n')}${projects.length > 10 ? '\nСледующая страница: page:${page + 1}' : ''}',
      BotKeyboard.pages(viewId, page, projects.length > 10),
      messageId: messageId,
    );
  }

  Future<void> _handleWorklog(dynamic message, String args) async {
    if (args.startsWith('add ')) {
      final match = RegExp(
        r'^add\s+(\S+)\s+(.+)$',
        dotAll: true,
      ).firstMatch(args);
      if (match == null || match.group(2)!.trim().length > 500)
        return message.reply('Пример: /worklog add ID_задачи описание');
      final taskId = match.group(1)!;
      if (await _store.getTask(taskId) == null)
        return message.reply('Задача не найдена.');
      final description = match.group(2)!.trim();
      return _confirm(
        message,
        'Добавить ворклог к задаче $taskId: ${_short(description, 200)}?',
        () async {
          if (await _store.getTask(taskId) == null)
            return 'Задача удалена. Повторите запрос.';
          final log = WorkLog(
            id: const Uuid().v4(),
            status: 0,
            taskId: taskId,
            date: DateTime.now(),
            description: description,
          );
          await _logs.addWorkLog(log);
          return 'Ворклог добавлен. ID: ${log.id}';
        },
      );
    }
    if (args.startsWith('delete ')) {
      return _confirmDeleteWorklog(
        message.from.id as int,
        message.chat.id as int,
        args.substring(7).trim(),
      );
    }
    String? taskId, search;
    DateTime? from, until;
    int? status;
    int page = 1;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    for (final match in RegExp(r'\S+:"[^"]+"|\S+').allMatches(args)) {
      final token = match.group(0)!;
      switch (token.toLowerCase()) {
        case 'today':
          from = day;
          until = day.add(const Duration(days: 1));
          continue;
        case 'tomorrow':
          from = day.add(const Duration(days: 1));
          until = day.add(const Duration(days: 2));
          continue;
        case 'week':
          from = day.subtract(Duration(days: day.weekday - 1));
          until = from.add(const Duration(days: 7));
          continue;
      }
      final separator = token.indexOf(':');
      if (separator < 0)
        return message.reply('Неверный фильтр ворклогов. Используйте /help.');
      final key = token.substring(0, separator).toLowerCase();
      final value = token.substring(separator + 1).replaceAll('"', '').trim();
      if (value.isEmpty) return message.reply('Пустое значение фильтра.');
      switch (key) {
        case 'task':
          taskId = value;
        case 'search':
          if (value.contains('%') || value.contains('_') || value.length > 100)
            return message.reply('Поиск: до 100 символов, без % и _.');
          search = value;
        case 'status':
          status = int.tryParse(value);
          if (status == null || status < 0 || status > 100)
            return message.reply(
              'Статус ворклога должен быть числом от 0 до 100.',
            );
        case 'page':
          page = int.tryParse(value) ?? 0;
          if (page < 1 || page > 1000)
            return message.reply('Номер страницы должен быть от 1 до 1000.');
        default:
          return message.reply('Неверный фильтр ворклогов. Используйте /help.');
      }
    }
    if (taskId == null)
      return message.reply(
        'Укажите task:ID_задачи. Пример: /worklog task:ID today',
      );
    if (await _store.getTask(taskId) == null)
      return message.reply('Задача не найдена.');
    await _showWorklogs(
      message.chat.id as int,
      message.from.id as int,
      _WorklogQuery(taskId, from, until, status, search),
      page,
    );
  }

  Future<void> _showWorklogs(
    int chatId,
    int userId,
    _WorklogQuery query,
    int page, {
    int? messageId,
  }) async {
    final viewId = _registerView(
      userId,
      chatId,
      (nextPage, messageId, id) =>
          _renderWorklogs(chatId, query, nextPage, id, messageId: messageId),
    );
    await _renderWorklogs(chatId, query, page, viewId, messageId: messageId);
  }

  Future<void> _renderWorklogs(
    int chatId,
    _WorklogQuery query,
    int page,
    String viewId, {
    int? messageId,
  }) async {
    final logs = await _logs.getPageForTask(
      query.taskId,
      limit: 11,
      offset: (page - 1) * 10,
      from: query.from,
      until: query.until,
      status: query.status,
      search: query.search,
    );
    if (logs.isEmpty) {
      await _sendOrEdit(
        chatId,
        'Ворклоги не найдены.',
        BotKeyboard.worklogs([], viewId: viewId, page: page, hasNext: false),
        messageId: messageId,
      );
      return;
    }
    await _sendOrEdit(
      chatId,
      'Ворклоги, стр. $page:\n${logs.take(10).map((log) => '• ${_date(log.date)}: ${_short(log.description, 180)}\nID: ${log.id}').join('\n')}${logs.length > 10 ? '\nСледующая страница: page:${page + 1}' : ''}',
      BotKeyboard.worklogs(
        logs.take(10).map((log) => log.id).toList(),
        viewId: viewId,
        page: page,
        hasNext: logs.length > 10,
      ),
      messageId: messageId,
    );
  }

  Future<void> _showTaskDetail(
    int chatId,
    String taskId, {
    int? messageId,
  }) async {
    final task = await _store.getTask(taskId);
    if (task == null) {
      await _sendOrEdit(
        chatId,
        'Задача не найдена.',
        BotKeyboard.home(),
        messageId: messageId,
      );
      return;
    }
    final project = task.projectId == null
        ? 'без проекта'
        : (await _store.getProjectName(task.projectId!)) ?? 'без проекта';
    final text =
        '${task.title}\nСтатус: ${task.status.title}\n'
        'Запланировано: ${task.startsAt == null ? 'не запланирована' : _date(task.startsAt!)}\n'
        'Срок: ${task.dueDate == null ? 'не указан' : _date(task.dueDate!)}\n'
        'Проект: $project\n'
        'Приоритет: ${switch (task.priority) {
          2 => 'высокий',
          1 => 'обычный',
          _ => 'низкий',
        }}\n'
        '${task.description.isEmpty ? '' : '\n${_short(task.description, 800)}\n'}'
        'ID: ${task.id}';
    await _sendOrEdit(
      chatId,
      text,
      BotKeyboard.taskDetail(task.id, done: task.status == TaskStatus.done),
      messageId: messageId,
    );
  }

  Future<void> _showEditTaskMenu(
    int chatId,
    String taskId, {
    int? messageId,
  }) async {
    final task = await _store.getTask(taskId);
    if (task == null) {
      await _sendOrEdit(
        chatId,
        'Задача не найдена.',
        BotKeyboard.home(),
        messageId: messageId,
      );
      return;
    }
    await _sendOrEdit(
      chatId,
      'Что изменить в задаче «${_short(task.title, 150)}»?',
      BotKeyboard.editTask(taskId),
      messageId: messageId,
    );
  }

  Future<Task?> _loadTaskWithTags(String taskId) async {
    for (final task in await _tasks.getAllTasks()) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  Future<void> _submitTaskEdit(
    dynamic message,
    _TaskEditSession session,
    String input,
  ) async {
    final key = '${message.from.id}:${message.chat.id}';
    final task = await _loadTaskWithTags(session.taskId);
    if (task == null || task.updatedAt != session.updatedAt) {
      _editSessions.remove(key);
      await _sendOrEdit(
        message.chat.id as int,
        'Задача изменилась или удалена. Откройте её снова.',
        BotKeyboard.home(),
        messageId: session.messageId,
      );
      return;
    }
    String? projectId;
    if (session.field == BotTaskEditField.project &&
        input.toLowerCase() != 'без проекта') {
      final projects = await _store.findProjects(input);
      if (projects.length != 1) {
        await _sendOrEdit(
          message.chat.id as int,
          'Проект не найден или название неоднозначно. Отправьте точное название или «без проекта».',
          BotKeyboard.editTask(session.taskId),
          messageId: session.messageId,
        );
        return;
      }
      projectId = projects.single.id;
    }
    final updated = BotTaskEdit.applyText(
      task,
      session.field,
      input,
      DateTime.now(),
      projectId: projectId,
    );
    if (updated == null) {
      final hint = switch (session.field) {
        BotTaskEditField.title =>
          'Название должно содержать от 1 до 300 символов и быть в одной строке.',
        BotTaskEditField.description =>
          'Описание может содержать до 2000 символов. Для очистки отправьте «пусто».',
        BotTaskEditField.scheduledAt =>
          'Используйте ДД.ММ.ГГГГ, «сегодня», «завтра» или «без плана».',
        BotTaskEditField.dueDate =>
          'Используйте ДД.ММ.ГГГГ, «сегодня», «завтра» или «без срока».',
        BotTaskEditField.project =>
          'Отправьте точное название проекта или «без проекта».',
      };
      await _sendOrEdit(
        message.chat.id as int,
        'Некорректное значение. $hint',
        BotKeyboard.editTask(session.taskId),
        messageId: session.messageId,
      );
      return;
    }
    _editSessions.remove(key);
    await _confirmTaskEdit(
      message.from.id as int,
      message.chat.id as int,
      task,
      updated,
      'Сохранить изменение задачи «${_short(task.title, 100)}»: ${_short(input, 160)}?',
      messageId: session.messageId,
    );
  }

  Future<void> _confirmTaskEdit(
    int userId,
    int chatId,
    Task original,
    Task updated,
    String question, {
    int? messageId,
  }) => _confirmForUser(
    userId,
    chatId,
    question,
    () async {
      final current = await _loadTaskWithTags(original.id);
      if (current == null || current.updatedAt != original.updatedAt) {
        return 'Задача изменилась или удалена. Повторите редактирование.';
      }
      if (updated.projectId != current.projectId &&
          updated.projectId != null &&
          await _store.getProjectName(updated.projectId!) == null) {
        return 'Проект удалён. Повторите редактирование.';
      }
      await _tasks.updateTask(
        updated.copyWith(tags: current.tags, updatedAt: DateTime.now()),
      );
      return 'Задача обновлена: ${updated.title}\nID: ${updated.id}';
    },
    messageId: messageId,
    resultMarkup: BotKeyboard.taskDetail(
      updated.id,
      done: updated.status == TaskStatus.done,
    ),
  );

  Future<void> _confirmDeleteTask(
    int userId,
    int chatId,
    String id, {
    int? messageId,
  }) async {
    final task = await _store.getTask(id);
    if (task == null) {
      await _sendOrEdit(
        chatId,
        'Задача не найдена.',
        BotKeyboard.home(),
        messageId: messageId,
      );
      return;
    }
    await _confirmForUser(
      userId,
      chatId,
      'Удалить задачу «${task.title}»?',
      () async {
        final current = await _store.getTask(id);
        if (current == null || current.updatedAt != task.updatedAt) {
          return 'Задача изменилась. Повторите запрос.';
        }
        await _tasks.deleteTask(id);
        return 'Задача удалена.';
      },
      messageId: messageId,
    );
  }

  Future<void> _confirmDeleteWorklog(
    int userId,
    int chatId,
    String id, {
    int? messageId,
  }) async {
    final log = await _logs.getById(id);
    if (log == null) {
      await _sendOrEdit(
        chatId,
        'Ворклог не найден.',
        BotKeyboard.home(),
        messageId: messageId,
      );
      return;
    }
    await _confirmForUser(
      userId,
      chatId,
      'Удалить ворклог «${_short(log.description, 150)}»?',
      () async {
        final current = await _logs.getById(id);
        if (current == null ||
            current.description != log.description ||
            current.date != log.date ||
            current.status != log.status) {
          return 'Ворклог изменился. Повторите запрос.';
        }
        await _logs.deleteWorkLog(id);
        return 'Ворклог удалён.';
      },
      messageId: messageId,
    );
  }

  Future<void> _confirm(
    dynamic message,
    String description,
    Future<String> Function() run,
  ) => _confirmForUser(
    message.from.id as int,
    message.chat.id as int,
    description,
    run,
  );

  Future<void> _confirmForUser(
    int userId,
    int chatId,
    String description,
    Future<String> Function() run, {
    int? messageId,
    InlineKeyboardMarkup? resultMarkup,
  }) async {
    _pending.removeWhere(
      (_, action) =>
          action.userId == userId || DateTime.now().isAfter(action.expires),
    );
    final id = const Uuid().v4();
    _pending[id] = _PendingAction(
      userId,
      chatId,
      run,
      resultMarkup ?? BotKeyboard.home(),
    );
    try {
      await _sendOrEdit(
        chatId,
        '$description\nПодтверждение действует 5 минут.',
        BotKeyboard.confirm(id),
        messageId: messageId,
      );
    } catch (_) {
      _pending.remove(id);
      rethrow;
    }
  }

  String _registerView(
    int userId,
    int chatId,
    Future<void> Function(int page, int messageId, String viewId) render,
  ) {
    _views.removeWhere((_, view) => DateTime.now().isAfter(view.expires));
    if (_views.length >= 100) _views.remove(_views.keys.first);
    final id = const Uuid().v4();
    _views[id] = _InlineView(userId, chatId, render);
    return id;
  }

  Future<void> _sendOrEdit(
    int chatId,
    String text,
    InlineKeyboardMarkup markup, {
    int? messageId,
    String? parseMode,
  }) async {
    if (messageId == null) {
      await _bot!.sendMessage(
        chatId,
        text,
        replyMarkup: markup,
        parseMode: parseMode,
      );
    } else {
      try {
        await _bot!.editMessageText(
          text,
          chatId: chatId,
          messageId: messageId,
          replyMarkup: markup,
          parseMode: parseMode,
        );
      } catch (error) {
        if (!error.toString().toLowerCase().contains(
          'message is not modified',
        )) {
          rethrow;
        }
      }
    }
  }

  Future<void> _sendHelp(int chatId, {int? messageId}) async {
    await _sendOrEdit(
      chatId,
      'Отправьте текст задачи или /task add название.\n'
      '«Сегодня» и «Завтра» при создании задают день планирования.\n'
      '/task [today|tomorrow|week|overdue] [status:todo|open|progress|done] [project:"Имя"] [priority:low|normal|high] [search:текст] [page:2]\n'
      'today/tomorrow/week — по плану, overdue — по сроку.\n'
      '/task edit ID — изменить задачу через кнопки.\n'
      '/edit ID — открыть редактирование задачи.\n'
      '/task delete ID, /task done ID\n/project [page:2]\n'
      '/worklog task:ID [today|tomorrow|week] [status:0] [search:текст] [page:2]\n/worklog add ID описание, /worklog delete ID\n'
      '/cancel — отменить ожидающее действие.',
      BotKeyboard.home(),
      messageId: messageId,
    );
  }

  Future<void> _handleCallback(dynamic callback) async {
    final chat = callback.message?.chat;
    if (chat == null ||
        !_authorized(callback.from.id as int?, chat.type as String)) {
      await callback.answer(text: 'Нет доступа.');
      return;
    }
    try {
      await _dispatchCallback(callback, chat.id as int);
    } catch (error) {
      debugPrint('Ошибка inline-кнопки Telegram: ${error.runtimeType}');
      try {
        await _sendOrEdit(
          chat.id as int,
          'Не удалось выполнить действие. Попробуйте ещё раз.',
          BotKeyboard.home(),
          messageId: callback.message.messageId as int,
        );
      } catch (editError) {
        debugPrint('Не удалось обновить сообщение Telegram: $editError');
      }
    }
  }

  Future<void> _dispatchCallback(dynamic callback, int chatId) async {
    final data = callback.data as String? ?? '';
    final userId = callback.from.id as int;
    final messageId = callback.message.messageId as int;
    if (data.startsWith('menu:')) {
      await callback.answer();
      switch (data.substring(5)) {
        case 'task':
          await _showTaskList(chatId, userId, '', messageId: messageId);
        case 'add':
          await _sendOrEdit(
            chatId,
            'Напишите задачу обычным сообщением или используйте /task add Название. Перед сохранением появится подтверждение.',
            BotKeyboard.home(),
            messageId: messageId,
          );
        case 'today':
          await _showTaskList(chatId, userId, 'today', messageId: messageId);
        case 'tomorrow':
          await _showTaskList(chatId, userId, 'tomorrow', messageId: messageId);
        case 'week':
          await _showTaskList(chatId, userId, 'week', messageId: messageId);
        case 'overdue':
          await _showTaskList(chatId, userId, 'overdue', messageId: messageId);
        case 'project':
          await _showProjects(chatId, userId, 1, messageId: messageId);
        case 'help':
          await _sendHelp(chatId, messageId: messageId);
        default:
          await _sendOrEdit(
            chatId,
            'Кнопка недоступна. Используйте /help.',
            BotKeyboard.home(),
            messageId: messageId,
          );
      }
      return;
    }
    if (data.startsWith('view:')) {
      final parts = data.split(':');
      final page = parts.length == 3 ? int.tryParse(parts[2]) : null;
      final view = parts.length == 3 ? _views[parts[1]] : null;
      if (page == null ||
          page < 1 ||
          page > 1000 ||
          view == null ||
          view.userId != userId ||
          view.chatId != chatId ||
          DateTime.now().isAfter(view.expires)) {
        await callback.answer(text: 'Кнопка устарела. Откройте список снова.');
        return;
      }
      await callback.answer();
      await view.render(page, messageId, parts[1]);
      return;
    }
    if (data.startsWith('task:')) {
      await callback.answer();
      await _showTaskDetail(chatId, data.substring(5), messageId: messageId);
      return;
    }
    if (data.startsWith('taskback:')) {
      _editSessions.remove('$userId:$chatId');
      await callback.answer();
      await _showTaskDetail(chatId, data.substring(9), messageId: messageId);
      return;
    }
    if (data.startsWith('edit:')) {
      _editSessions.remove('$userId:$chatId');
      await callback.answer();
      await _showEditTaskMenu(chatId, data.substring(5), messageId: messageId);
      return;
    }
    if (data.startsWith('editfield:')) {
      final parts = data.split(':');
      final task = parts.length == 3 ? await _store.getTask(parts[2]) : null;
      if (task == null) {
        await callback.answer(text: 'Задача не найдена.');
        return;
      }
      if (parts[1] == 'status' || parts[1] == 'priority') {
        await callback.answer();
        await _sendOrEdit(
          chatId,
          parts[1] == 'status' ? 'Выберите статус:' : 'Выберите приоритет:',
          parts[1] == 'status'
              ? BotKeyboard.editStatus(task.id)
              : BotKeyboard.editPriority(task.id),
          messageId: messageId,
        );
        return;
      }
      final field = switch (parts[1]) {
        'title' => BotTaskEditField.title,
        'description' => BotTaskEditField.description,
        'scheduledAt' => BotTaskEditField.scheduledAt,
        'dueDate' => BotTaskEditField.dueDate,
        'project' => BotTaskEditField.project,
        _ => null,
      };
      if (field == null) {
        await callback.answer(text: 'Неизвестное поле.');
        return;
      }
      _editSessions['$userId:$chatId'] = _TaskEditSession(
        task.id,
        field,
        task.updatedAt,
        messageId,
      );
      await callback.answer();
      final prompt = switch (field) {
        BotTaskEditField.title => 'Отправьте новое название (до 300 символов).',
        BotTaskEditField.description =>
          'Отправьте новое описание (до 2000 символов) или «пусто».',
        BotTaskEditField.scheduledAt =>
          'Отправьте день планирования в формате ДД.ММ.ГГГГ, «сегодня», «завтра» или «без плана».',
        BotTaskEditField.dueDate =>
          'Отправьте срок в формате ДД.ММ.ГГГГ, «сегодня», «завтра» или «без срока».',
        BotTaskEditField.project =>
          'Отправьте точное название проекта или «без проекта».',
      };
      await _sendOrEdit(
        chatId,
        '$prompt\nДля отмены: /cancel. Время ввода — 10 минут.',
        BotKeyboard.editTask(task.id),
        messageId: messageId,
      );
      return;
    }
    if (data.startsWith('editstatus:') || data.startsWith('editpriority:')) {
      final parts = data.split(':');
      final isStatus = parts.first == 'editstatus';
      final task = parts.length == 3 ? await _loadTaskWithTags(parts[2]) : null;
      if (task == null) {
        await callback.answer(text: 'Задача не найдена.');
        return;
      }
      final status = switch (parts[1]) {
        'todo' => TaskStatus.notStarted,
        'open' => TaskStatus.open,
        'progress' => TaskStatus.inProgress,
        'done' => TaskStatus.done,
        _ => null,
      };
      final priority = int.tryParse(parts[1]);
      if ((isStatus && status == null) ||
          (!isStatus && (priority == null || priority < 0 || priority > 2))) {
        await callback.answer(text: 'Неизвестное значение.');
        return;
      }
      _editSessions.remove('$userId:$chatId');
      await callback.answer();
      final updated = isStatus
          ? task.copyWith(status: status)
          : task.copyWith(priority: priority);
      await _confirmTaskEdit(
        userId,
        chatId,
        task,
        updated,
        isStatus
            ? 'Изменить статус задачи «${_short(task.title, 100)}» на ${status!.title}?'
            : 'Изменить приоритет задачи «${_short(task.title, 100)}» на ${switch (priority) {
                0 => 'низкий',
                1 => 'обычный',
                _ => 'высокий',
              }}?',
        messageId: messageId,
      );
      return;
    }
    if (data.startsWith('done:')) {
      final id = data.substring(5);
      final task = await _loadTaskWithTags(id);
      if (task == null || task.status == TaskStatus.done) {
        await callback.answer(
          text: task == null ? 'Задача не найдена.' : 'Уже завершена.',
        );
        return;
      }
      await callback.answer(text: 'Завершаю задачу…');
      await _tasks.updateTask(
        task.copyWith(status: TaskStatus.done, updatedAt: DateTime.now()),
      );
      await _showTaskDetail(chatId, id, messageId: messageId);
      return;
    }
    if (data.startsWith('delete:')) {
      await callback.answer();
      await _confirmDeleteTask(
        userId,
        chatId,
        data.substring(7),
        messageId: messageId,
      );
      return;
    }
    if (data.startsWith('logs:')) {
      final id = data.substring(5);
      if (await _store.getTask(id) == null) {
        await callback.answer(text: 'Задача не найдена.');
        return;
      }
      await callback.answer();
      await _showWorklogs(
        chatId,
        userId,
        _WorklogQuery(id, null, null, null, null),
        1,
        messageId: messageId,
      );
      return;
    }
    if (data.startsWith('logadd:')) {
      final id = data.substring(7);
      final task = await _store.getTask(id);
      if (task == null) {
        await callback.answer(text: 'Задача не найдена.');
        return;
      }
      await callback.answer();
      await _sendOrEdit(
        chatId,
        'Чтобы добавить ворклог, отправьте:\n/worklog add $id описание работы',
        BotKeyboard.taskDetail(id, done: task.status == TaskStatus.done),
        messageId: messageId,
      );
      return;
    }
    if (data.startsWith('logdel:')) {
      await callback.answer();
      await _confirmDeleteWorklog(
        userId,
        chatId,
        data.substring(7),
        messageId: messageId,
      );
      return;
    }
    final parts = data.split(':');
    if (parts.length != 2 || (parts[0] != 'ok' && parts[0] != 'no')) {
      await callback.answer(text: 'Неизвестная кнопка.');
      return;
    }
    final action = _pending[parts[1]];
    if (action == null ||
        action.userId != userId ||
        action.chatId != chatId ||
        DateTime.now().isAfter(action.expires)) {
      _pending.remove(parts[1]);
      await callback.answer(text: 'Подтверждение недействительно или истекло.');
      return;
    }
    _pending.remove(parts[1]);
    await callback.answer(text: parts[0] == 'no' ? 'Отменено.' : 'Выполняю…');
    if (parts[0] == 'no') {
      await _sendOrEdit(
        chatId,
        'Отменено.',
        BotKeyboard.home(),
        messageId: messageId,
      );
      return;
    }
    try {
      await _sendOrEdit(
        chatId,
        await action.run(),
        action.resultMarkup,
        messageId: messageId,
      );
    } catch (error) {
      debugPrint('Ошибка подтверждённого действия: $error');
      await _sendOrEdit(
        chatId,
        'Действие не выполнено. Проверьте данные в приложении.',
        BotKeyboard.home(),
        messageId: messageId,
      );
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  String _short(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max)}…';
}
