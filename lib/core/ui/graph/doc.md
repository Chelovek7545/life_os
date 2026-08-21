# Документация GraphView

## 1. Архитектура

Однонаправленный поток данных. Виджет не владеет состоянием — он рендерит снимки и сообщает о намерениях:

```
                        ┌─────────────────────────────┐
  Stream<List<GraphNode>> │                             │
 ───────────────────────▶│          GraphView          │
  полные снимки,          │  diff → анимации → рендер   │
  свежие объекты          │                             │
                          │  жесты → GraphAction        │
 ◀─────────────────────── │                             │
        onAction          └─────────────────────────────┘
```

Хост — drift-DAO, BLoC, rxdart-субъект, WebSocket-клиент, `StreamController` — применяет действия и эмитит новый снимок. Цикл замыкается.

## 2. Быстрый старт

```dart
final store = GraphNodeStore()..seed(); // любой источник из демо

GraphView(
  nodes: store.nodes,
  onAction: store.apply, // Future<void> совместим с ValueChanged
)
```

Всё. Появление узлов, отрисовка рёбер, пан/зум, ghost'ы — внутри.

## 3. Справочник API

### `GraphView`

| Параметр | Тип | По умолчанию | Описание |
|---|---|---|---|
| `nodes` | `Stream<List<GraphNode>>` | — | **Обязателен.** Полный список узлов на каждую эмиссию |
| `onAction` | `ValueChanged<GraphAction>?` | `null` | Намерения пользователя |
| `theme` | `GraphViewTheme` | `.deep` | Палитра (`deep`, `paper` или своя) |
| `layout` | `GraphLayout` | `const GraphLayout()` | Размеры узлов, зазоры, размер мира |
| `camera` | `GraphViewCamera?` | `null` | Императивная камера |
| `nodeBuilder` | `NodeWidgetBuilder?` | `null` | Свой рендер узла вместо `DefaultNodeCard` |
| `showControls` | `bool` | `true` | Встроенный зум-кластер |
| `doubleTapCreatesRoot` | `bool` | `true` | Дабл-тап по фону → `CreateRootAction` |
| `longPressDeletes` | `bool` | `true` | Long-press → `RemoveAction` |
| `minScale` / `maxScale` | `double` | `0.25` / `2.5` | Границы зума |
| `ghostTimeout` | `Duration` | `2500 ms` | Сколько ghost ждёт реальный узел |

### `GraphNode`

| Поле | Назначение |
|---|---|
| `id` | Стабильный идентификатор — по нему работает diff |
| `label` | Текст узла |
| `index` | Порядок создания; управляет стаггером появления |
| `depth` | 0 для корней; определяет цвет из `depthRamp` |
| `parentId` | Родитель → ребро. `null` — корень |
| `position` | Координаты левого верхнего угла в мировых координатах |

`clone()` — дешёвая копия для эмиссий (см. §6).

### `GraphAction` (sealed)

| Действие | Когда fires | Контракт хоста |
|---|---|---|
| `CreateRootAction(at, label)` | дабл-тап по фону | создать корень; `at` — подсказка позиции |
| `CreateChildAction(parentId, at, label)` | тап по «+» узла | создать потомка; там уже стоит ghost |
| `MoveAction(id, to)` | **каждый кадр драга** | только live-курсор; не персистировать |
| `MoveEndAction(id, to)` | отпускание/отмена драга | **точка коммита** — писать в БД здесь |
| `RemoveAction(id)` | long-press / ✕ | удаление (поддерево — решение хоста) |
| `SelectAction(id)` | тап по узлу / фону | информационно; выделение живёт в виджете |
| `ToggleCollapseAction(id, collapsed)` | Cворачивание нод |

Обработчик хоста — исчерпывающий `switch` (sealed гарантирует полноту):

```dart
void _onAction(GraphAction a) => switch (a) {
  CreateRootAction(:final at, :final label) => repo.addRoot(at, label),
  CreateChildAction(:final parentId, :final at) => repo.addChild(parentId, at),
  MoveAction() => null,
  MoveEndAction(:final id, :final to) => repo.persistPosition(id, to),
  RemoveAction(:final id) => repo.removeSubtree(id),
  SelectAction(:final id) => panel.focus(id),
  ToggleCollapseAction() => 
};
```

### `NodeState` (для `nodeBuilder`)

`node`, `size`, `selected`, `canDelete`, `accent` — данные; `select()`, `addChild()`, `remove()`, `dragStart`, `dragUpdate`, `dragEnd` — проводка жестов. Кастомный узел **обязан** повесить drag-callbacks и `dragEnd` (включая `onPanCancel`), иначе оптимистичный драг сломается.

### `GraphViewCamera`

`fitView({animate})` — вписать весь граф; `zoomBy(factor)` — зум к центру вьюпорта; `revealNode(id)` — докрутить до узла. До подключения — безопасные no-op'ы.

## 4. Правила рендера и анимаций

Diff на каждую эмиссию сравнивает поля, а не ссылки:

- **Новый узел** → elastic pop-in + отрисовка входящего ребра с «искрой» на кончике.
- **Удалённый узел** → мгновенное исчезновение (входные анимации есть, выходной — нет; при желании перекрывается `nodeBuilder`).
- **Смена `label`/`parentId`/`depth`** → обновление на месте без пересоздания.
- **Смена `position`** → мгновенный перенос (без tween — источник истины знает лучше; при желании интерполируйте на стороне хоста).
- **Первая эмиссия** → стаггер по `index` (кап 600 мс), fit-камера, отрисовка всех рёбер.

## 5. Оптимистичный UX

- **Ghost.** На «+» и дабл-тап виджет мгновенно рисует пунктирный пульсирующий плейсхолдер в предполагаемой позиции и шлёт действие. Когда в стриме приходит узел с тем же `parentId` и позицией ±48px — ghost сменяется реальным узлом. Если хост не ответил за `ghostTimeout` — ghost гаснет (отказ/ошибка сети видны пользователю).
- **Драг.** Позиция обновляется локально каждый кадр; `MoveAction` летит наружу fire-and-forget; коммит — `MoveEndAction`. Guard `draggingId` не даёт запоздалой эмиссии выдернуть узел из-под курсора.

В демо включите `400 ms` — вся механика становится видна невооружённым глазом.

## 6. Требования к стриму

1. **Полный список** на каждую эмиссию, не дельты.
2. **Свежие объекты**: diff сравнивает поля, поэтому мутировать инстансы in-place нельзя.

```dart
// ❌ diff не увидит изменений
node.label = 'new'; subject.add(nodes);

// ✅ новый объект + новый список
nodes[i] = nodes[i].clone()..label = 'new'; // или copyWith
subject.add(List.of(nodes));
```

3. **Эмиссия при подписке** (текущее состояние сразу): drift `.watch()` и rxdart `BehaviorSubject` так умеют; голый `StreamController` — нет, добавьте `onListen` или replay.
4. **Несколько подписчиков** (виджет + консоль + статистика) — используйте broadcast-стрим или вызывайте `.watch()` повторно.

## 7. Рецепты

**drift** — практически без клея:

```dart
GraphView(
  nodes: db.watchNodes(), // SELECT … .watch() → Stream<List<GraphNode>>
  onAction: (a) => switch (a) {
    CreateRootAction(:final at, :final label) => db.insertRoot(at, label),
    CreateChildAction(:final parentId, :final at) => db.insertChild(parentId, at),
    MoveAction() => null,
    MoveEndAction(:final id, :final to) => db.updatePosition(id, to),
    RemoveAction(:final id) => db.deleteSubtree(id),
    SelectAction() => null,
    ToggleCollapseAction():
  },
)
```

**bloc / rxdart** — состояние редьюсера проецируется в стрим:

```dart
final subject = BehaviorSubject<List<GraphNode>>.seeded(state.nodes);

GraphView(
  nodes: bloc.stream.map((e) => e.nodes).startWith(bloc.state.nodes),
  onAction: bloc.add, // если события блока зеркалят GraphAction
);
```

**Сервер / WebSocket** — входящее сообщение парсится в полный снимок и кладётся в `BehaviorSubject`; `ghostTimeout` стоит поднять до ожидаемого RTT (например, `Duration(seconds: 2)`).

## 8. Подводные камни

- `MoveAction` — высокочастотный: в обработчике только обновление памяти/курсора, запись строго на `MoveEndAction` (иначе 60 INSERT'ов в секунду).
- Смена объекта `nodes` в `didUpdateWidget` переподписывается и сбрасывает внутреннее состояние — не пересоздавайте стрим на каждый build (кэшируйте в `initState`).
- Выделение локальное; если нужно внешнее управление (сайд-панель, deep-link) — расширяйте API стримом `selectedId`.
- `index` и `depth` — ответственность хоста: они управляют стаггером и цветом.

## 9. Структура

Два файла: `lib/graph_view.dart` (библиотека, ноль зависимостей, Dart ≥ 3) и `lib/main.dart` (демо: in-memory стор, консоль эмиссий, латентность, внешние мутации). Для продакшена секции библиотеки разносятся по `lib/src/` без изменения API.