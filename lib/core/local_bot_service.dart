import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

/// Сервис для Telegram-бота с доступом к данным приложения
class LocalBotService {
  String? _botToken;
  final GetTasksWithProjectsUseCase _tasksWithProjectsUseCase;
  TeleDart? _teleDart;
  Telegram? _telegramClient;

  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);

  /// Completer для ожидания ввода токена
  Completer<String>? _tokenCompleter;

  /// Колбэк для запроса токена (Dialog во Flutter или stdin в CLI)
  Future<String?> Function()? onTokenRequested;

  /// Колбэк-реакция на 404 / невалидный токен
  FutureOr<void> Function(String errorMessage)? onInvalidToken;

  LocalBotService({
    String? botToken,
    required GetTasksWithProjectsUseCase tasksWithProjectsUseCase,
    this.onTokenRequested,
    this.onInvalidToken,
  })  : _botToken = botToken,
        _tasksWithProjectsUseCase = tasksWithProjectsUseCase;

  // /// Передача токена вручную из внешнего кода / UI
  // void provideToken(String token) {
  //   final cleanToken = token.trim();
  //   if (cleanToken.isEmpty) return;

  //   if (_tokenCompleter != null && !_tokenCompleter!.isCompleted) {
  //     _tokenCompleter!.complete(cleanToken);
  //   } else {
  //     _botToken = cleanToken;
  //   }
  // }

  /// Получение токена (Память -> SettingsService -> Completer / onTokenRequested)
  Future<String?> _resolveToken() async {
    // 1. Проверяем локальное поле
    // if (_botToken != null && _botToken!.trim().isNotEmpty) {
    //   return _botToken!.trim();
    // }

    // 2. Проверяем сохраненный токен в SettingsService
    final savedToken = SettingsService.tgToken.value.trim();
    if (savedToken.isNotEmpty) {
      _botToken = savedToken;
      return savedToken;
    }

    // 3. Запрашиваем новый токен через Completer / Callback
    _tokenCompleter = Completer<String>();

    if (onTokenRequested != null) {
      final requestedToken = await onTokenRequested!();
      if (requestedToken != null && requestedToken.trim().isNotEmpty) {
        _tokenCompleter!.complete(requestedToken.trim());
      } else if (!_tokenCompleter!.isCompleted) {
        _tokenCompleter!.completeError('Токен не предоставлен');
      }
    }

    try {
      print("Ожидание ввода токена...");
      final token = await _tokenCompleter!.future;

      await SettingsService.setTgToken(token);
      _botToken = token;
      return token;
    } catch (e) {
      print('Ошибка получения токена: $e');
      return null;
    } finally {
      _tokenCompleter = null;
    }
  }

  /// Получение локальных задач
  Future<String> _getTasks() async {
    try {
      final tasksWithProject =
          await _tasksWithProjectsUseCase.getTasksWithProjects();

      if (tasksWithProject.isEmpty) {
        return "Задач пока нет.";
      }

      final buffer = StringBuffer();
      for (final t in tasksWithProject) {
        final projectName = t.project?.name ?? 'Без проекта';
        buffer.writeln("Task: ${t.task.title} | Project: $projectName");
      }
      return buffer.toString();
    } catch (e) {
      print('Ошибка при получении задач: $e');
      return 'Не удалось загрузить данные задач.';
    }
  }

  /// Очистка старых сессий сокета на стороне Telegram
  Future<void> _flushTelegramSession(String token) async {
    try {
      _telegramClient = Telegram(token);
      await _telegramClient!.setWebhook('');
      await _telegramClient!.deleteWebhook(dropPendingUpdates: true);
    } catch (_) {
      // Игнорируем ошибки сброса, так как важна проверка getMe
    }
  }

  Future<void> startBot() async {
    if (isRunning.value) {
      await stopBot();
    }

    runZonedGuarded(
      () async {
        final token = await _resolveToken();

        if (token == null || token.isEmpty) {
          print('Запуск бота отменен: отсутствует токен.');
          return;
        }

        try {
          await _flushTelegramSession(token);

          // Инициализация запроса к Telegram API
          _telegramClient ??= Telegram(token);

          // ТУТ происходит проверка валидности токена
          final me = await _telegramClient!.getMe();
          final event = Event(me.username!);

          _teleDart = TeleDart(token, event);
          _teleDart!.start();
          isRunning.value = true;
          print("Start bot: запущен (${token.substring(0, 5)}...)");

          _teleDart!.onCommand('start').listen((message) {
            message.reply('Привет! Бот запущен локально из Flutter-приложения.');
          });

          _teleDart!.onCommand('getTasks').listen((message) async {
            final appData = await _getTasks();
            message.reply('Данные из приложения:\n$appData');
          });

        } catch (e) {
          final errorStr = e.toString().toLowerCase();

          // ОПРЕДЕЛЕНИЕ ОШИБКИ 404 / 401 / Not Found / Unauthorized
          if (errorStr.contains('404') ||
              errorStr.contains('401') ||
              errorStr.contains('not found') ||
              errorStr.contains('unauthorized')) {
            print('❌ Ошибка: Указан невалидный Telegram Token (404 Not Found).');

            // 1. Сбрасываем неверный токен из памяти и настроек
            //await resetSavedToken();

            // 2. Вызываем внешнюю реакцию (UI сообщение, перезапрос токена и т.д.)
            if (onInvalidToken != null) {
              await onInvalidToken!('Указан неверный токен Telegram-бота (404).');
            }
          } else {
            print('Ошибка при запуске бота: $e');
          }

          await stopBot();
        }
      },
      (error, stackTrace) {
        if (error.toString().contains('409') ||
            error.toString().contains('LongPollingException')) {
          print('Перехвачена фоновая ошибка Telegram (409 Conflict).');
        } else {
          print('Неперехваченная ошибка в Telegram боте: $error');
        }
      },
    );
  }

  Future<void> stopBot() async {
    if (_teleDart == null && !isRunning.value) return;

    try {
      isRunning.value = false;
      _teleDart?.stop();
      print("Stop bot");
    } catch (e) {
      print('Ошибка при остановке бота: $e');
    } finally {
      _teleDart = null;
      _telegramClient = null;
      isRunning.value = false;
    }
  }

  /// Сброс сохраненного токена
  Future<void> resetSavedToken() async {
    await SettingsService.setTgToken('');
    _botToken = null;
    print("Сохраненный токен удален.");
  }
}