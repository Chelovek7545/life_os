import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';

//TODO: Сделать обработку ситуации когда токена нет или он невалидный

/// Сервис для Telegram-бота с доступом к данным приложения
class LocalBotService {
  String? _botToken;
  final GetTasksWithProjectsUseCase _tasksWithProjectsUseCase;
  TeleDart? _teleDart;
  final ValueNotifier<bool> isRunning = ValueNotifier<bool>(false);

  /// Completer для ожидания ввода токена снаружи (UI или CLI)
  Completer<String>? _tokenCompleter;

  /// Абстрактный колбэк для запроса токена (возвращает Future<String?>).
  /// Во Flutter тут будет показ Dialog, а в CLI — stdin.readLineSync()
   Future<String?> Function()? onTokenRequested;

  LocalBotService({
    String? botToken,
    required GetTasksWithProjectsUseCase tasksWithProjectsUseCase,
    this.onTokenRequested,
  }) : _botToken = botToken,
       _tasksWithProjectsUseCase = tasksWithProjectsUseCase;

  // /// Метод для ручной передачи токена из UI или внешнего кода
  // void provideToken(String token) {
  //   if (token.trim().isEmpty) return;

  //   if (_tokenCompleter != null && !_tokenCompleter!.isCompleted) {
  //     _tokenCompleter!.complete(token.trim());
  //   } else {
  //     _botToken = token.trim();
  //   }
  // }

  String? proveToken(String token) {
    if (token.trim().isEmpty) return null;
    return token;
  }

  // /// Получение и сохранение токена (Память -> SharedPreferences -> Completer)
  // Future<String?> _resolveToken() async {
  //   // 1. Проверяем локальное поле
  //   if (_botToken != null && _botToken!.trim().isNotEmpty) {
  //     return _botToken;
  //   }

  //   // 2. Проверяем сохраненный токен в SharedPreferences
    
  //   final savedToken = SettingsService.tgToken.value;
  //   if (savedToken == '' && savedToken.isNotEmpty) {
  //     _botToken = savedToken;
  //     return savedToken;
  //   }

  //   // 3. Если токена нет нигде — запускаем Completer
  //   _tokenCompleter = Completer<String>();

  //   // Если передан обработчик запроса (UI или CLI), вызываем его
  //   if (onTokenRequested != null) {
  //     final requestedToken = await onTokenRequested!();
  //     if (requestedToken != null && requestedToken.isNotEmpty) {
  //       _tokenCompleter!.complete(requestedToken.trim());
  //     } else if (!_tokenCompleter!.isCompleted) {
  //       _tokenCompleter!.completeError('Токен не был предоставлен.');
  //     }
  //   }

  //   try {
  //     print("Ожидание ввода токена...");
  //     final token = await _tokenCompleter!.future;

  //     // Сохраняем в SharedPreferences и локальное поле
  //     await SettingsService.setTgToken(token);
  //     _botToken = token;
  //     return token;
  //   } catch (e) {
  //     print('Ошибка получения токена: $e');
  //     return null;
  //   } finally {
  //     _tokenCompleter = null;
  //   }
  // }

  /// Получение локальных задач
  Future<String> _getTasks() async {
    try {
      final tasksWithProject = await _tasksWithProjectsUseCase
          .getTasksWithProjects();

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

  Future<void> startBot() async {
    // 1. Если бот уже запущен, предварительно останавливаем его
    if (isRunning.value) {
      await stopBot();
    }

    // 2. Изолируем асинхронный контекст TeleDart внутри Zone,
    // чтобы фоновые ошибки 409 Conflict не ломали Flutter-приложение
    runZonedGuarded(
      () async {
        // Получаем или запрашиваем токен
        try {
          final token = proveToken(SettingsService.tgToken.value);
          
          if (token == null) {
            print('Запуск бота отменен: отсутсвует токен.');
            return;
          }
          final telegram = Telegram(token);
          
          // Сбрасываем вебхуки и зависшие сессии Telegram ДО старта LongPolling
          try {
            await telegram.deleteWebhook(dropPendingUpdates: true);
          } catch (e) {
            print('Предупреждение при deleteWebhook: $e');
          }
          
          final me = await telegram.getMe();
          final event = Event(me.username!);
          
          _teleDart = TeleDart(token, event);
          _teleDart!.start();
          isRunning.value = true;
          print("Start bot: успешно запущен с токеном (${token.substring(0, 5)}...)");
          
          // Обработка команды /start
          _teleDart!.onCommand('start').listen((message) {
            message.reply('Привет! Бот запущен локально из Flutter-приложения.');
          });
          
          // Обработка команды /getTasks
          _teleDart!.onCommand('getTasks').listen((message) async {
            final appData = await _getTasks();
            message.reply('Данные из приложения:\n$appData');
          });
        } on Exception catch (e) {
          print(e);
        }
      },
      (error, stackTrace) {
        // 3. Перехватываем необработанные фоновые исключения LongPolling
        if (error.toString().contains('409') ||
            error.toString().contains('LongPollingException')) {
          print(
            'Перехвачена фоновая ошибка Telegram (409 Conflict): старая сессия закрыта.',
          );
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

      // Даем 1.5 секунды серверам Telegram на закрытие активного HTTP сокета
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (e) {
      print('Ошибка при остановке бота: $e');
    } finally {
      _teleDart = null;
      isRunning.value = false;
    }
  }
  
  /// Сбросить сохраненный токен (например, для смены бота)
  Future<void> resetSavedToken() async {
    SettingsService.setTgToken('');  
    _botToken = null;
    print("Сохраненный токен удален.");
  }
}
