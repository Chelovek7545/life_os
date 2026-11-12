# LifeGraph / Pulse

Встроенный модуль графа Life OS: обзор сфер и статистики, проекция бизнес-карточек,
независимые доски, стикеры и Markdown-заметки, раскладка, Canvas и файловые команды.

**[Полное руководство: все функции, управление, настройки, API и ограничения](../../docs/lifegraph-plugin.md)**

[Формат Canvas, Obsidian и сохранность данных](../../docs/obsidian-canvas.md).

Публичные точки входа: `lifegraph_logic.dart` (без Flutter),
`lifegraph_plugin.dart` (модуль/модели UI), `canvas_document.dart`,
`canvas_board.dart`, `canvas_note_mapper.dart`, `graph_storage_settings.dart`.
Конкретные файловые/Drift/UI-адаптеры подключаются приложением через конструкторы.
Модуль не загружает сторонний исполняемый код динамически.
