import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/routine_models.dart';
import 'routine_style.dart';

const routinePanelTypes = {
  'day': ('План дня', Icons.wb_sunny_outlined),
  'week': ('Недельное расписание', Icons.view_week_outlined),
  'table': ('Таблица недели', Icons.table_chart_outlined),
  'tracker': ('Трекер отметок', Icons.grid_view_rounded),
  'overview': ('Обзор выполнения', Icons.insights_rounded),
  'regularity': ('Регулярность', Icons.calendar_month_outlined),
  'balance': ('Баланс сфер', Icons.donut_large_rounded),
};

class RoutinePanel {
  RoutinePanel({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.dayOffset = 0,
  });
  final String id;
  final String type;
  double x, y, width, height;
  int dayOffset;
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'dayOffset': dayOffset,
  };
  factory RoutinePanel.fromJson(Map<String, dynamic> j) => RoutinePanel(
    id: j['id'],
    type: j['type'],
    x: (j['x'] as num).toDouble().clamp(0, 9000),
    y: (j['y'] as num).toDouble().clamp(0, 9000),
    width: (j['width'] as num).toDouble().clamp(350, 2000),
    height: (j['height'] as num).toDouble().clamp(320, 1800),
    dayOffset: j['dayOffset'] ?? 0,
  );
  factory RoutinePanel.create(String type, double x, double y) => RoutinePanel(
    id: newRoutineId(),
    type: type,
    x: x,
    y: y,
    width: type == 'table'
        ? 1260
        : type == 'week' || type == 'tracker'
        ? 1000
        : 440,
    height: type == 'week' || type == 'table' ? 700 : 620,
  );
}

class RoutineCanvas extends StatefulWidget {
  const RoutineCanvas({
    super.key,
    required this.panels,
    required this.transform,
    required this.onChanged,
    required this.builder,
    required this.date,
  });
  final List<RoutinePanel> panels;
  final TransformationController transform;
  final VoidCallback onChanged;
  final Widget Function(RoutinePanel) builder;
  final DateTime date;
  @override
  State<RoutineCanvas> createState() => RoutineCanvasState();
}

class RoutineCanvasState extends State<RoutineCanvas> {
  bool _dragging = false;
  bool _hand = false;
  bool _space = false;
  Offset? _lastDragPosition;
  Size _viewport = Size.zero;
  final _focus = FocusNode();
  double get scale => widget.transform.value.getMaxScaleOnAxis();
  @override
  void initState() {
    super.initState();
    widget.transform.addListener(_transformChanged);
  }

  @override
  void dispose() {
    widget.transform.removeListener(_transformChanged);
    _focus.dispose();
    super.dispose();
  }

  void _transformChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void zoom(double factor) {
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final scene = widget.transform.toScene(center);
    final next = (scale * factor).clamp(.25, 1.75);
    widget.transform.value = Matrix4.identity()
      ..translateByDouble(
        center.dx - scene.dx * next,
        center.dy - scene.dy * next,
        0,
        1,
      )
      ..scaleByDouble(next, next, next, 1);
    widget.onChanged();
  }

  void fit() {
    if (widget.panels.isEmpty) {
      return;
    }
    final left = widget.panels.map((p) => p.x).reduce(math.min);
    final top = widget.panels.map((p) => p.y).reduce(math.min);
    final right = widget.panels.map((p) => p.x + p.width).reduce(math.max);
    final bottom = widget.panels.map((p) => p.y + p.height).reduce(math.max);
    final next = math
        .min(
          (_viewport.width - 72) / (right - left),
          (_viewport.height - 110) / (bottom - top),
        )
        .clamp(.25, 1.0);
    widget.transform.value = Matrix4.identity()
      ..translateByDouble(36 - left * next, 24 - top * next, 0, 1)
      ..scaleByDouble(next, next, next, 1);
    widget.onChanged();
  }

  void add(String type) {
    final center = widget.transform.toScene(
      Offset(_viewport.width * .2, _viewport.height * .15),
    );
    setState(
      () => widget.panels.add(
        RoutinePanel.create(
          type,
          math.max(0, center.dx + widget.panels.length * 12),
          math.max(0, center.dy + widget.panels.length * 12),
        ),
      ),
    );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        _viewport = c.biggest;
        return Focus(
          focusNode: _focus,
          autofocus: false,
          onKeyEvent: (node, event) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              setState(() => _space = event is! KeyUpEvent);
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                HardwareKeyboard.instance.isControlPressed) {
              if (event.logicalKey == LogicalKeyboardKey.equal ||
                  event.logicalKey == LogicalKeyboardKey.numpadAdd) {
                zoom(1.15);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.minus ||
                  event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
                zoom(1 / 1.15);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit0) {
                fit();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _CanvasBackdrop(p, widget.transform.value),
                  ),
                ),
              ),
              Listener(
                onPointerDown: (_) => _focus.requestFocus(),
                child: InteractiveViewer(
                  transformationController: widget.transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: .25,
                  maxScale: 1.75,
                  scaleFactor: 650,
                  panEnabled: !_dragging,
                  trackpadScrollCausesScale: true,
                  onInteractionEnd: (_) => widget.onChanged(),
                  child: SizedBox(
                    width: 12000,
                    height: 12000,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final panel in widget.panels) _panel(panel, p),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.panels.isEmpty)
                const IgnorePointer(
                  child: RoutineEmpty(
                    title: 'Чистый холст',
                    subtitle: 'Добавьте таблицу или дашборд кнопкой внизу.',
                    icon: Icons.dashboard_customize_outlined,
                  ),
                ),
              Positioned(
                left: 20,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface.withValues(alpha: .97),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _hand
                            ? 'Выбирать элементы'
                            : 'Перемещать холст (пробел)',
                        isSelected: _hand,
                        onPressed: () => setState(() => _hand = !_hand),
                        icon: Icon(
                          _hand
                              ? Icons.pan_tool_rounded
                              : Icons.near_me_outlined,
                        ),
                        iconSize: 19,
                      ),
                      Container(width: 1, height: 22, color: p.border),
                      IconButton(
                        tooltip: 'Отдалить (Ctrl −)',
                        onPressed: () => zoom(1 / 1.15),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${(scale * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Приблизить (Ctrl +)',
                        onPressed: () => zoom(1.15),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                      IconButton(
                        tooltip: 'Показать всё (Ctrl 0)',
                        onPressed: fit,
                        icon: const Icon(Icons.fit_screen_rounded, size: 20),
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'Добавить на холст',
                        onSelected: add,
                        itemBuilder: (_) => routinePanelTypes.entries
                            .map(
                              (e) => PopupMenuItem(
                                value: e.key,
                                child: Row(
                                  children: [
                                    Icon(e.value.$2, size: 18),
                                    const SizedBox(width: 12),
                                    Text(e.value.$1),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: routineAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.add,
                                color: Color(0xFF30190E),
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Добавить',
                                style: TextStyle(
                                  color: Color(0xFF30190E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (c.maxWidth > 880)
                Positioned(
                  right: 24,
                  bottom: 33,
                  child: IgnorePointer(
                    child: Text(
                      'Колесо — масштаб  ·  пустое место — перемещение',
                      style: TextStyle(color: p.secondary, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _panel(RoutinePanel panel, RoutinePalette p) {
    void begin(DragStartDetails d) {
      _lastDragPosition = d.globalPosition;
      setState(() => _dragging = true);
    }

    void end() {
      setState(() => _dragging = false);
      widget.onChanged();
    }

    final label = routinePanelTypes[panel.type]!;
    return Positioned(
      key: ValueKey(panel.id),
      left: panel.x,
      top: panel.y,
      width: panel.width,
      height: panel.height,
      child: IgnorePointer(
        ignoring: _hand || _space,
        child: RepaintBoundary(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.border.withValues(alpha: .8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: p.dark ? .23 : .07),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: begin,
                      onPanUpdate: (d) {
                        final delta =
                            (d.globalPosition - _lastDragPosition!) / scale;
                        _lastDragPosition = d.globalPosition;
                        setState(() {
                          panel.x = (panel.x + delta.dx).clamp(0, 10000);
                          panel.y = (panel.y + delta.dy).clamp(0, 10000);
                        });
                      },
                      onPanEnd: (_) => end(),
                      onPanCancel: end,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.only(left: 18, right: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                p.inset.withValues(alpha: .75),
                                p.surface,
                              ],
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: p.border.withValues(alpha: .5),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(label.$2, size: 18, color: routineAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  label.$1,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Предыдущий период карточки',
                                onPressed: () {
                                  setState(
                                    () => panel.dayOffset -= panel.type == 'day'
                                        ? 1
                                        : 7,
                                  );
                                  widget.onChanged();
                                },
                                icon: const Icon(Icons.chevron_left, size: 16),
                              ),
                              Tooltip(
                                message:
                                    'Смещение карточки относительно выбранной даты. Нажмите, чтобы сбросить.',
                                child: InkWell(
                                  onTap: () {
                                    setState(() => panel.dayOffset = 0);
                                    widget.onChanged();
                                  },
                                  child: Text(
                                    panel.dayOffset == 0
                                        ? '↗'
                                        : '${panel.dayOffset > 0 ? '+' : ''}${panel.dayOffset} д',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: p.secondary,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Следующий период карточки',
                                onPressed: () {
                                  setState(
                                    () => panel.dayOffset += panel.type == 'day'
                                        ? 1
                                        : 7,
                                  );
                                  widget.onChanged();
                                },
                                icon: const Icon(Icons.chevron_right, size: 16),
                              ),
                              IconButton(
                                tooltip: 'Убрать с холста · данные сохранятся',
                                onPressed: () {
                                  final index = widget.panels.indexOf(panel);
                                  setState(() => widget.panels.remove(panel));
                                  widget.onChanged();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Карточка убрана. Расписание и отметки сохранены.',
                                      ),
                                      action: SnackBarAction(
                                        label: 'Вернуть',
                                        onPressed: () {
                                          if (!mounted) {
                                            return;
                                          }
                                          setState(
                                            () => widget.panels.insert(
                                              math.min(
                                                index,
                                                widget.panels.length,
                                              ),
                                              panel,
                                            ),
                                          );
                                          widget.onChanged();
                                        },
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: p.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.fromLTRB(20, 7, 20, 3),
                      child: Text(
                        dayKey(shiftDay(widget.date, panel.dayOffset)),
                        style: TextStyle(fontSize: 10, color: p.secondary),
                      ),
                    ),
                    Expanded(child: widget.builder(panel)),
                  ],
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: 24,
                  height: 24,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: begin,
                      onPanUpdate: (d) {
                        final delta =
                            (d.globalPosition - _lastDragPosition!) / scale;
                        _lastDragPosition = d.globalPosition;
                        setState(() {
                          panel.width = (panel.width + delta.dx).clamp(
                            350,
                            2000,
                          );
                          panel.height = (panel.height + delta.dy).clamp(
                            320,
                            1800,
                          );
                        });
                      },
                      onPanEnd: (_) => end(),
                      onPanCancel: end,
                      child: Icon(
                        Icons.south_east,
                        size: 12,
                        color: p.secondary.withValues(alpha: .6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasBackdrop extends CustomPainter {
  _CanvasBackdrop(this.palette, this.transform);
  final RoutinePalette palette;
  final Matrix4 transform;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              (palette.dark ? const Color(0xFF596898) : const Color(0xFFBAC8F3))
                  .withValues(alpha: .16),
              palette.background.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .55, 0),
              radius: size.width * .65,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
    final scale = transform.getMaxScaleOnAxis();
    final step = math.max(12.0, 24 * scale);
    final x = transform.storage[12] % step;
    final y = transform.storage[13] % step;
    final dots = Paint()..color = palette.secondary.withValues(alpha: .2);
    for (var dx = x; dx < size.width; dx += step) {
      for (var dy = y; dy < size.height; dy += step) {
        canvas.drawCircle(Offset(dx, dy), .8, dots);
      }
    }
  }

  @override
  bool shouldRepaint(_CanvasBackdrop old) => true;
}
