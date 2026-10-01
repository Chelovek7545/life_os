# Pulse: локальная разработка под Windows

Исходный репозиторий (`upstream`): https://github.com/Chelovek7545/life_os.git
Ваш форк (`origin`): https://github.com/articherkk/life_os.git
Актуальная ветка и цель pull request: `obsidian-sync-feature`, коммит `42940e7`.

Flutter 3.44.0 и Dart 3.12.0 установлены в `.tools/flutter`.
Кэш пакетов: `.tools/pub-cache`. Эти папки и результаты сборки исключены из Git.
Visual Studio Community 2022 с C++, CMake и Windows SDK уже установлен.
Режим разработчика Windows включён с вашего согласия для символических ссылок плагинов.
Android SDK для сборки Windows не нужен.

## Сборка и запуск

Из PowerShell в папке проекта:

```powershell
.\flutter.cmd doctor -v
.\build-windows.ps1
.\dist\Pulse\Pulse.exe
```

После успешной сборки в корне появляется ярлык `Pulse.lnk`.
Переносить приложение следует целиком с папкой `dist/Pulse`: EXE требует DLL и папку `data` рядом.
Flutter добавлен в пользовательский PATH; новые терминалы подхватят его автоматически.
В текущем терминале можно пользоваться `.\flutter.cmd`.

```powershell
.\flutter.cmd run -d windows
.\flutter.cmd analyze
.\flutter.cmd test
```

## Данные

Используется встроенная SQLite через Drift. Отдельный SQL-сервер устанавливать не нужно.
Приложение хранит базу `tasks.sqlite` в системной папке «Документы» текущего пользователя.
Заметки графа, позиции и настройки также используют SharedPreferences, поэтому одной копии SQLite недостаточно для полного резервного копирования.

## Git

Ветка `obsidian-sync-feature` отслеживает `upstream/obsidian-sync-feature`.
Отправка по умолчанию настроена на ваш форк `origin`.
Имя и email автора берутся из существующих настроек Git.
Для каждой доработки создавайте отдельную ветку:

```powershell
git switch -c my-change
git status
git add <нужные-файлы>
git commit -m "Описание изменений"
git push -u origin my-change
```

Затем создайте PR на GitHub:
- base repository: `Chelovek7545/life_os`
- base branch: `obsidian-sync-feature` (не `main`)
- head repository: `articherkk/life_os`
- compare branch: `my-change`

Проверка `git push --dry-run origin obsidian-sync-feature` прошла успешно.
Прямая запись в исходный репозиторий не требуется для работы через PR.

Установка не создаёт коммитов и не отправляет изменения автоматически.

## Результаты проверки 2026-09-05

- Генерация Drift и Mockito завершилась успешно.
- `flutter analyze --no-pub`: 7 ошибок в тестах после изменений API, 32 предупреждения, 85 информационных замечаний. Полный отчёт: `.tools/analyze-current.log`.
- `flutter test --no-pub --reporter expanded`: 476 успешных проверок, 21 ошибка, включая ошибки загрузки тестовых файлов. Полный отчёт: `.tools/test-current.log`.
- Проверки чтения, записи и удаления данных в SQLite прошли.
- Release-сборка Windows успешна: `dist/Pulse/Pulse.exe`; журнал `.tools/build-windows.log`.
- Приложение запущено; проверены стартовый экран Pulse, задачи и библиотека.
- Obsidian Vault пока не подключён: путь к вашей папке Markdown-файлов задаётся в настройках.

## Предложения по развитию

Сильные стороны: граф связей сфер, целей, проектов и задач; локальное хранение;
разделение кода по функциям и слоям; собственная тёмная тема; большой набор тестов;
интеграция с локальными Markdown-заметками Obsidian.

Приоритетные улучшения: исправить упавшие тесты и добавить Windows-сборку в CI;
реализовать обратный отсчёт таймера (сейчас кнопка меняет только состояние);
подключить переключатели темы, уведомлений и языка в настройках;
добавить резервное копирование SQLite вместе с заметками и настройками;
привести русские и английские надписи к единой локализации.
