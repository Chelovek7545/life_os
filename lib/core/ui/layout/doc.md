# Документация `SplitView`

## Назначение

`SplitView` — это переиспользуемый виджет, который размещает несколько панелей в ряд или колонку и позволяет пользователю менять их размер перетаскиванием разделителей.

Он хорошо подходит как базовый строительный блок для Adobe-подобного интерфейса:

```text
[Layers | Editor | Inspector]
```

или:

```text
+----------------------+
|                      |
|       Editor         |
|                      |
+----------------------+
|       Timeline       |
+----------------------+
```

или вложенно:

```text
+--------+----------------------+-----------+
|        |                      |           |
| Layers |       Editor         | Inspector |
|        |                      |           |
|        +----------------------+           |
|        |       Timeline       |           |
+--------+----------------------+-----------+
```

---

## Базовый пример

```dart
SplitView(
  axis: Axis.horizontal,
  initialWeights: const [0.25, 0.5, 0.25],
  minSizes: const [200, 300, 200],
  children: const [
    LeftPanel(),
    CenterPanel(),
    RightPanel(),
  ],
)
```

---

## Параметры

### `axis`

Тип:

```dart
Axis
```

Обязательный параметр.

Определяет направление расположения панелей.

```dart
Axis.horizontal
```

Панели располагаются слева направо.

Разделители тянутся по горизонтали.

```dart
Axis.vertical
```

Панели располагаются сверху вниз.

Разделители тянутся по вертикали.

---

### `children`

Тип:

```dart
List<Widget>
```

Обязательный параметр.

Список панелей, которые нужно разместить внутри `SplitView`.

Пример:

```dart
children: [
  LayersPanel(),
  EditorPanel(),
  InspectorPanel(),
]
```

---

### `weights`

Тип:

```dart
List<double>?
```

Необязательный параметр.

Если передать `weights`, виджет переходит в контролируемый режим.

Пример:

```dart
SplitView(
  axis: Axis.horizontal,
  weights: _weights,
  onWeightsChanged: (newWeights) {
    setState(() {
      _weights = newWeights;
    });
  },
  children: [
    PanelA(),
    PanelB(),
    PanelC(),
  ],
)
```

В контролируемом режиме источник истины — родитель.

Если пользователь тянет разделитель, `SplitView` вызывает:

```dart
onWeightsChanged
```

Родитель должен обновить состояние и передать новые `weights` обратно.

---

### `initialWeights`

Тип:

```dart
List<double>?
```

Необязательный параметр.

Используется в неконтролируемом режиме.

Пример:

```dart
SplitView(
  axis: Axis.horizontal,
  initialWeights: const [0.2, 0.6, 0.2],
  children: [
    PanelA(),
    PanelB(),
    PanelC(),
  ],
)
```

Если `initialWeights` не передан, размеры распределяются поровну:

```dart
[1/3, 1/3, 1/3]
```

Если длина `initialWeights` меньше количества детей, недостающие значения считаются нулевыми и затем нормализуются.

Если сумма весов меньше или равна нулю, веса распределяются равномерно.

---

### `minSizes`

Тип:

```dart
List<double>?
```

Необязательный параметр.

Минимальные размеры панелей вдоль основной оси.

Для:

```dart
Axis.horizontal
```

это минимальные ширины.

Для:

```dart
Axis.vertical
```

это минимальные высоты.

Пример:

```dart
SplitView(
  axis: Axis.horizontal,
  minSizes: const [220, 320, 260],
  children: [
    LayersPanel(),
    EditorPanel(),
    InspectorPanel(),
  ],
)
```

Если `minSizes` короче, чем список детей, для недостающих панелей минимальный размер считается `0`.

---

### `onWeightsChanged`

Тип:

```dart
ValueChanged<List<double>>?
```

Необязательный параметр.

Вызывается, когда пользователь изменил размеры панелей.

Пример:

```dart
onWeightsChanged: (weights) {
  debugPrint('New weights: $weights');
}
```

Этот callback удобен для:

- сохранения layout;
- синхронизации с state management;
- аналитики;
- автоматической подстройки интерфейса.

---

### `dividerThickness`

Тип:

```dart
double
```

По умолчанию:

```dart
8.0
```

Определяет толщину разделителя.

Фактически это и визуальная толщина, и область попадания курсором/пальцем.

Для desktop можно использовать:

```dart
dividerThickness: 6
```

Для touch-интерфейсов лучше:

```dart
dividerThickness: 10
```

или даже:

```dart
dividerThickness: 12
```

---

### `dividerBuilder`

Тип:

```dart
SplitDividerBuilder?
```

Необязательный параметр.

Позволяет кастомизировать разделитель.

Сигнатура:

```dart
Widget Function(
  BuildContext context,
  int dividerIndex,
  Axis axis,
)
```

Пример:

```dart
SplitView(
  axis: Axis.horizontal,
  dividerThickness: 10,
  dividerBuilder: (context, index, axis) {
    return Container(
      color: Colors.black26,
    );
  },
  children: [
    PanelA(),
    PanelB(),
  ],
)
```

---

# 4. Как работают веса

Веса нормализуются автоматически.

Можно передать:

```dart
initialWeights: const [1, 2, 1]
```

Или:

```dart
initialWeights: const [0.25, 0.5, 0.25]
```

Или:

```dart
initialWeights: const [10, 20, 10]
```

Все эти варианты дадут одинаковое распределение:

```text
25% / 50% / 25%
```

Внутри веса приводятся к сумме `1.0`.

---

# 5. Как работают минимальные размеры

Допустим, есть горизонтальный split:

```dart
SplitView(
  axis: Axis.horizontal,
  initialWeights: const [0.3, 0.7],
  minSizes: const [200, 300],
  children: [
    PanelA(),
    PanelB(),
  ],
)
```

Если доступная ширина `1000`, а толщина разделителя `8`, то полезная ширина:

```text
1000 - 8 = 992
```

Минимальные размеры:

```text
200 + 300 = 500
```

Свободное место после вычета минимумов:

```text
992 - 500 = 492
```

Дальше свободное место распределяется по весам.

Панель A:

```text
200 + 492 * 0.3 = 347.6
```

Панель B:

```text
300 + 492 * 0.7 = 644.4
```

Итого:

```text
347.6 + 8 + 644.4 = 1000
```

---

# 6. Что происходит при перетаскивании

Когда пользователь тянет разделитель:

1. `SplitView` получает изменение в пикселях:
   ```dart
   dx
   ```
   или:
   ```dart
   dy
   ```

2. Пиксельное изменение переводится в изменение веса.

3. Веса двух соседних панелей обновляются:
   ```dart
   weights[i] += deltaWeight;
   weights[i + 1] -= deltaWeight;
   ```

4. Применяются минимальные размеры.

5. Вызывается:
   ```dart
   onWeightsChanged
   ```

6. Интерфейс перестраивается.

---

# 7. Контролируемый режим

Если ты хочешь полностью контролировать состояние layout извне, используй `weights` и `onWeightsChanged`.

Пример:

```dart
class ControlledSplitExample extends StatefulWidget {
  const ControlledSplitExample({super.key});

  @override
  State<ControlledSplitExample> createState() =>
      _ControlledSplitExampleState();
}

class _ControlledSplitExampleState extends State<ControlledSplitExample> {
  List<double> _weights = const [0.3, 0.7];

  @override
  Widget build(BuildContext context) {
    return SplitView(
      axis: Axis.horizontal,
      weights: _weights,
      minSizes: const [200, 300],
      onWeightsChanged: (newWeights) {
        setState(() {
          _weights = newWeights;
        });
      },
      children: const [
        PanelA(),
        PanelB(),
      ],
    );
  }
}
```

В этом случае:

- `SplitView` сам не хранит веса;
- родитель хранит веса;
- при изменении размеров родитель получает новые веса;
- родитель передаёт обновлённые веса обратно.

---

# 8. Неконтролируемый режим

Если не передавать `weights`, виджет сам хранит состояние.

Пример:

```dart
SplitView(
  axis: Axis.horizontal,
  initialWeights: const [0.3, 0.7],
  children: const [
    PanelA(),
    PanelB(),
  ],
)
```

Это удобно для простых случаев.

---

# 9. Сохранение layout

Чтобы сохранять расположение панелей, используй `onWeightsChanged`.

Например, в простом случае:

```dart
class PersistentSplitExample extends StatefulWidget {
  const PersistentSplitExample({super.key});

  @override
  State<PersistentSplitExample> createState() =>
      _PersistentSplitExampleState();
}

class _PersistentSplitExampleState extends State<PersistentSplitExample> {
  List<double> _weights = const [0.25, 0.5, 0.25];

  @override
  Widget build(BuildContext context) {
    return SplitView(
      axis: Axis.horizontal,
      weights: _weights,
      onWeightsChanged: (newWeights) {
        setState(() {
          _weights = newWeights;
        });

        // Здесь можно сохранить newWeights в SharedPreferences,
        // файл, базу данных или backend.
        debugPrint('Save weights: $newWeights');
      },
      children: const [
        PanelA(),
        PanelB(),
        PanelC(),
      ],
    );
  }
}
```

Для реального приложения лучше сохранять не каждый пиксель, а именно веса:

```json
{
  "rootWeights": [0.22, 0.56, 0.22],
  "centerWeights": [0.70, 0.30]
}
```

Так layout будет лучше переживать изменение размера окна.

---

# 10. Вложенные SplitView

Главная сила этого подхода — вложенность.

Пример:

```dart
SplitView(
  axis: Axis.horizontal,
  children: [
    LayersPanel(),
    SplitView(
      axis: Axis.vertical,
      children: [
        EditorPanel(),
        TimelinePanel(),
      ],
    ),
    InspectorPanel(),
  ],
)
```

Это даёт структуру:

```text
+--------+----------------------+-----------+
|        |                      |           |
| Layers |       Editor         | Inspector |
|        |                      |           |
|        +----------------------+           |
|        |       Timeline       |           |
+--------+----------------------+-----------+
```

Каждый `SplitView` управляет своими весами независимо.

---

# 11. Важные ограничения

## 1. Нужны конечные размеры по основной оси

`SplitView` должен знать доступный размер.

Хорошо:

```dart
Scaffold(
  body: SplitView(...),
)
```

или:

```dart
Expanded(
  child: SplitView(...),
)
```

Плохо:

```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: SplitView(
    axis: Axis.horizontal,
    ...
  ),
)
```

Потому что горизонтальный `SingleChildScrollView` даёт неограниченную ширину.

---

## 2. Минимальные размеры должны быть разумными

Если сумма минимальных размеров больше доступного места, виджет постарается масштабировать панели, но лучше в такой ситуации переключаться на компактный layout.

Например:

```dart
if (width < 900) {
  return CompactLayout();
}

return WorkspaceLayout();
```

---

## 3. Для полного Adobe-опыта нужны дополнительные сущности

Этот `SplitView` решает ресайз.

Но Adobe-подобный интерфейс обычно также включает:

- вкладки панелей;
- drag-and-drop панелей;
- dock-зоны;
- floating-панели;
- сохранение workspace;
- панельные пресеты;
- feature-based доступность панелей;
- автоматическую перестройку под мобильный режим.

Для этого дальше нужно строить уже дерево панелей, например:

```dart
DockNode
SplitNode
TabAreaNode
PanelNode
```

Но `SplitView` можно использовать как рендерер для `SplitNode`.

---

# 12. Как это расширять до Adobe-подобной системы

Дальше рекомендуется сделать модель:

```dart
sealed class DockNode {}

class SplitNode extends DockNode {
  final Axis axis;
  final List<double> weights;
  final List<DockNode> children;
}

class TabAreaNode extends DockNode {
  final List<String> panelIds;
  final int selectedIndex;
}
```

А рендер сделать примерно так:

```dart
Widget buildNode(DockNode node) {
  return switch (node) {
    SplitNode() => SplitView(
        axis: node.axis,
        weights: node.weights,
        children: node.children.map(buildNode).toList(),
      ),
    TabAreaNode() => PanelTabView(
        panelIds: node.panelIds,
        selectedIndex: node.selectedIndex,
      ),
  };
}
```

То есть:

- `SplitView` отвечает за ресайз;
- модель отвечает за структуру;
- panel registry отвечает за контент панелей;
- state manager отвечает за изменения;
- persistence отвечает за сохранение workspace.

---

# 13. Краткая шпаргалка

## Одна колонка / несколько колонок

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final orientation = MediaQuery.of(context).orientation;
    final width = constraints.maxWidth;

    if (width < 900 || orientation == Orientation.portrait) {
      return CompactLayout();
    }

    return WorkspaceLayout();
  },
)
```

---

## Горизонтальный split

```dart
SplitView(
  axis: Axis.horizontal,
  initialWeights: const [0.25, 0.5, 0.25],
  minSizes: const [200, 300, 200],
  children: [
    LeftPanel(),
    CenterPanel(),
    RightPanel(),
  ],
)
```

---

## Вертикальный split

```dart
SplitView(
  axis: Axis.vertical,
  initialWeights: const [0.7, 0.3],
  minSizes: const [200, 150],
  children: [
    TopPanel(),
    BottomPanel(),
  ],
)
```

---

## Контролируемый режим

```dart
SplitView(
  axis: Axis.horizontal,
  weights: weights,
  onWeightsChanged: (next) {
    setState(() => weights = next);
  },
  children: children,
)
```

---

## Кастомный разделитель

```dart
SplitView(
  axis: Axis.horizontal,
  dividerBuilder: (context, index, axis) {
    return Container(
      color: Colors.black26,
    );
  },
  children: children,
)
```

---

## Итог

Теперь у тебя есть переиспользуемый `SplitView`, который:

- поддерживает горизонтальное и вертикальное разделение;
- умеет минимальные размеры;
- умеет контролируемый и неконтролируемый режим;
- нормализует веса;
- поддерживает RTL для горизонтального режима;
- легко вкладывается друг в друга;
- подходит как основа для Adobe-подобного workspace.

Если дальше нужен уже полноценный Adobe-уровень, следующим шагом нужно делать:

```text
PanelRegistry
DockNode tree
TabArea
Drag & Drop
Dock indicators
Floating panels
Workspace persistence
Feature-based panels
```