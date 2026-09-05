import 'dart:async';
import 'package:flutter/material.dart';
import '../data/routine_repository.dart';
import '../domain/routine_models.dart';
import 'routine_canvas.dart';
import 'routine_editors.dart';
import 'routine_style.dart';
import 'routine_views.dart';
import 'routine_timetable.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key, required this.repository});
  final RoutineRepository repository;
  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen>
    with WidgetsBindingObserver {
  RoutineRepository get repo => widget.repository;
  late DateTime _date = routineDay(repo.now());
  late DateTime _observedToday = routineDay(repo.now());
  final _canvas = GlobalKey<RoutineCanvasState>();
  final _transform = TransformationController(
    Matrix4.identity()
      ..translateByDouble(24, 20, 0, 1)
      ..scaleByDouble(.8, .8, .8, 1),
  );
  final List<RoutinePanel> _panels = [
    RoutinePanel.create('day', 0, 0),
    RoutinePanel.create('table', 472, 0),
    RoutinePanel.create('week', 1764, 0),
    RoutinePanel.create('overview', 0, 732),
    RoutinePanel.create('tracker', 472, 732),
  ];
  List<({String id, String name, int color})> _spheres = [];
  Timer? _layoutTimer;
  Timer? _clockTimer;
  bool _dark = true, _ready = false, _preview = false;
  String _view = 'canvas', _analytics = 'overview', _trackerPeriod = 'month';
  int _period = 30;
  DateTimeRange? _customPeriod;
  final Map<int, String> _dayLabels = {};
  bool _includeToday = false;
  String? _sphere, _template, _item;
  final Map<String, bool> _optimistic = {};
  RoutineSnapshot? _example;
  RoutineSnapshot get data => _preview ? _example! : repo.snapshot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repo.addListener(_refresh);
    _initialize();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _tick() {
    if (!mounted) {
      return;
    }
    final today = routineDay(repo.now());
    setState(() {
      if (dayKey(_date) == dayKey(_observedToday)) {
        _date = today;
      }
      _observedToday = today;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
    }
  }

  Future<void> _initialize() async {
    try {
      await repo.load();
      final board = await repo.readBoard();
      final spheres = await repo.db
          .customSelect('SELECT id,name,color FROM spheres')
          .get();
      if (!mounted) {
        return;
      }
      _spheres = spheres
          .map(
            (s) => (
              id: s.read<String>('id'),
              name: s.read<String>('name'),
              color:
                  0xFF000000 |
                  (int.tryParse(
                        s.read<String>('color').replaceAll('#', ''),
                        radix: 16,
                      ) ??
                      0x8B93A7),
            ),
          )
          .toList();
      if (board != null) {
        final labels = board['dayLabels'] as Map?;
        if (labels != null) {
          for (final e in labels.entries) {
            final day = int.tryParse(e.key.toString());
            if (day != null && day >= 1 && day <= 7 && e.value is String) {
              _dayLabels[day] = e.value;
            }
          }
        }
        _dark = board['dark'] ?? true;
        final list = board['panels'] as List?;
        if (list != null) {
          _panels.clear();
          _panels.addAll(
            list
                .map((j) => RoutinePanel.fromJson(Map<String, dynamic>.from(j)))
                .where((p) => routinePanelTypes.containsKey(p.type)),
          );
          if (board['version'] != 2 && !_panels.any((p) => p.type == 'table')) {
            _panels.add(RoutinePanel.create('table', 0, 1450));
          }
        }
        final matrix = board['transform'] as List?;
        if (matrix != null && matrix.length == 16) {
          final values = matrix.map((n) => (n as num).toDouble()).toList();
          if (values.every((n) => n.isFinite)) {
            final value = Matrix4.fromList(values);
            if (value.getMaxScaleOnAxis() >= .25 &&
                value.getMaxScaleOnAxis() <= 1.75) {
              _transform.value = value;
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _message('Не удалось открыть распорядок: $e');
      }
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  Map<String, dynamic> _board() => {
    'version': 2,
    'dayLabels': {
      for (final e in _dayLabels.entries) e.key.toString(): e.value,
    },
    'dark': _dark,
    'panels': _panels.map((p) => p.toJson()).toList(),
    'transform': _transform.value.storage.toList(),
  };
  void _saveLayout() {
    _layoutTimer?.cancel();
    _layoutTimer = Timer(const Duration(milliseconds: 350), () {
      repo.saveBoard(_board()).catchError((Object e) {
        if (mounted) {
          _message('Не удалось сохранить расположение: $e');
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    repo.removeListener(_refresh);
    _clockTimer?.cancel();
    if (_layoutTimer?.isActive ?? false) {
      _layoutTimer!.cancel();
      unawaited(repo.saveBoard(_board()).catchError((Object _) {}));
    }
    _transform.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _run(Future<void> Function() work, {String? success}) async {
    try {
      await work();
      if (success != null) {
        _message(success);
      }
    } catch (e) {
      _message(e is FormatException ? e.message : 'Не удалось сохранить. $e');
    }
  }

  List<RoutineOccurrence> _entries(DateTime from, DateTime to) => data
      .resolve(from, to)
      .where(
        (o) =>
            (_sphere == null || o.item.sphere == _sphere) &&
            (_template == null || o.templateId == _template) &&
            (_item == null || o.item.id == _item),
      )
      .map(
        (o) => _optimistic.containsKey(o.id)
            ? o.copyWith(completed: _optimistic[o.id])
            : o,
      )
      .toList();
  void _openDay(DateTime day) => setState(() {
    _date = day;
    _view = 'day';
  });
  Future<void> _toggle(RoutineOccurrence o) async {
    if (_optimistic.containsKey(o.id) ||
        o.cancelled ||
        o.date.isAfter(routineDay(repo.now()))) {
      return;
    }
    if (_preview) {
      final ids = {...data.completedIds};
      o.completed ? ids.remove(o.id) : ids.add(o.id);
      setState(
        () => _example = RoutineSnapshot(
          templates: data.templates,
          versions: data.versions,
          activations: data.activations,
          overrides: data.overrides,
          completedIds: ids,
        ),
      );
      return;
    }
    setState(() => _optimistic[o.id] = !o.completed);
    try {
      await repo.setCompleted(o, !o.completed);
    } catch (e) {
      _message('Отметка не сохранена. Попробуйте ещё раз.');
    } finally {
      if (mounted) {
        setState(() => _optimistic.remove(o.id));
      }
    }
  }

  Future<void> _editOccurrence(
    BuildContext context,
    RoutineOccurrence o,
  ) async {
    if (_preview) {
      _message(
        'Это пример. Используйте шаблон, чтобы редактировать расписание.',
      );
      return;
    }
    final initial = RoutineItem(
      id: o.item.id,
      title: o.item.title,
      slots: [
        RoutineSlot(
          id: o.slot.id,
          days: [o.date.weekday],
          start: o.slot.start,
          end: o.slot.end,
        ),
      ],
      sphereId: o.item.sphereId,
      sphere: o.item.sphere,
      color: o.item.color,
      note: o.item.note,
    );
    final edited = await showRoutineItemEditor(
      context,
      item: initial,
      spheres: _spheres,
      singleDate: true,
    );
    if (edited != null) {
      await _run(
        () => repo.saveOverride(
          o.copyWith(item: edited, slot: edited.slots.first, changed: true),
        ),
      );
    }
  }

  Future<void> _addOccurrence(
    BuildContext context, {
    DateTime? date,
    int? start,
  }) async {
    if (_preview) {
      _message('Сначала используйте шаблон примера или закройте пример.');
      return;
    }
    final day = date ?? _date;
    final item = await showRoutineItemEditor(
      context,
      weekday: day.weekday,
      start: start,
      spheres: _spheres,
      singleDate: true,
    );
    if (item != null) {
      await _run(
        () => repo.saveOverride(
          RoutineOccurrence(
            id: newRoutineId(),
            date: day,
            templateId: data.activeOn(day)?.templateId ?? 'one-off',
            item: item,
            slot: item.slots.first,
            added: true,
            changed: true,
          ),
        ),
      );
    }
  }

  Future<void> _occurrenceMenu(
    BuildContext context,
    RoutineOccurrence o,
    String action,
  ) async {
    if (action == 'edit') {
      await _editOccurrence(context, o);
      return;
    }
    if (_preview) {
      _message('Редактирование доступно после применения шаблона.');
      return;
    }
    if (action == 'template') {
      final template = repo.snapshot.templates
          .where((t) => t.id == o.templateId)
          .firstOrNull;
      if (template != null) {
        await showTemplateEditor(
          context,
          repo,
          template: template,
          spheres: _spheres,
        );
      }
    } else if (action == 'cancel') {
      if (o.completed &&
          !await _confirm(
            context,
            'Отменить занятие?',
            'Отметка «${o.item.title}» будет снята. Занятие исключится из расчёта этой даты.',
          )) {
        return;
      }
      await _run(
        () => repo.saveOverride(o.copyWith(cancelled: true)),
        success: 'Занятие отменено на эту дату.',
      );
    } else if (action == 'restore') {
      await _run(() => repo.restore(o));
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String text,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Назад'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      ) ??
      false;
  void _showExample() {
    final items = exampleRoutineItems();
    final version = newRoutineId();
    final template = newRoutineId();
    final activation = newRoutineId();
    final start = shiftDay(mondayOf(repo.now()), -28);
    final base = RoutineSnapshot(
      templates: [
        RoutineTemplate(
          id: template,
          name: 'Учебная неделя · пример',
          versionId: version,
          items: items,
        ),
      ],
      versions: {version: items},
      activations: [
        RoutineActivation(
          id: activation,
          versionId: version,
          templateId: template,
          from: start,
        ),
      ],
    );
    final entries = base.resolve(start, routineDay(repo.now()));
    final done = <String>{};
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].date.isBefore(routineDay(repo.now()))
          ? i % 5 != 1
          : i % 3 == 0) {
        done.add(entries[i].id);
      }
    }
    setState(() {
      _example = RoutineSnapshot(
        templates: base.templates,
        versions: base.versions,
        activations: base.activations,
        completedIds: done,
      );
      _preview = true;
      _sphere = null;
      _template = null;
      _item = null;
    });
  }

  Future<void> _useExample(BuildContext context) async {
    await showTemplateEditor(
      context,
      repo,
      initial: exampleRoutineItems(),
      spheres: _spheres,
    );
    if (mounted && repo.snapshot.templates.isNotEmpty) {
      setState(() {
        _preview = false;
        _template = null;
        _item = null;
        _sphere = null;
      });
    }
  }

  Future<void> _templates(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) => Dialog(
          child: SizedBox(
            width: 680,
            height: MediaQuery.sizeOf(context).height * .8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ваши шаблоны',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Редактируйте неделю один раз. История остаётся на месте.',
                    style: TextStyle(
                      color: paletteOf(context).secondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => showTemplateEditor(
                          context,
                          repo,
                          spheres: _spheres,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Пустой шаблон'),
                      ),
                      OutlinedButton(
                        onPressed: () => showTemplateEditor(
                          context,
                          repo,
                          initial: exampleRoutineItems(),
                          spheres: _spheres,
                        ),
                        child: const Text('Из примера'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: repo.snapshot.templates.isEmpty
                        ? const RoutineEmpty(
                            title: 'Несколько недель — один ритм',
                            subtitle:
                                'Учебная неделя, отпуск или экзамены.\nСоздайте свой первый шаблон.',
                          )
                        : ListView(
                            children: repo.snapshot.templates
                                .map((t) => _templateCard(context, t))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _templateCard(BuildContext context, RoutineTemplate t) {
    final active = repo.snapshot.activeOn(repo.now())?.templateId == t.id;
    final activations = repo.snapshot.activations
        .where((a) => a.templateId == t.id)
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: RoutineSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (active)
                  const Text(
                    'Действует',
                    style: TextStyle(color: routineAccent, fontSize: 11),
                  ),
                if (t.archived)
                  const Text(' · В архиве', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${t.items.length} занятий${activations.isEmpty ? ' · не применён' : ' · с ${dayKey(activations.last.from)}'}',
              style: TextStyle(
                color: paletteOf(context).secondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                TextButton(
                  onPressed: () => showTemplateEditor(
                    context,
                    repo,
                    template: t,
                    spheres: _spheres,
                  ),
                  child: const Text('Изменить'),
                ),
                if (!t.archived)
                  TextButton(
                    onPressed: () async {
                      final min = repo.snapshot.activeOn(repo.now()) == null
                          ? routineDay(repo.now())
                          : shiftDay(repo.now(), 1);
                      final from = await showDatePicker(
                        context: context,
                        initialDate: min,
                        firstDate: min,
                        lastDate: shiftDay(min, 3650),
                      );
                      if (from == null || !context.mounted) {
                        return;
                      }
                      final replacement = repo.snapshot.activations
                          .where((a) => dayKey(a.from) == dayKey(from))
                          .firstOrNull;
                      final future = repo.snapshot.activations
                          .where((a) => a.from.isAfter(from))
                          .toList();
                      final until = future.isEmpty
                          ? 'далее'
                          : 'до ${dayKey(future.first.from)}';
                      if (!await _confirm(
                        context,
                        'Применить «${t.name}»?',
                        'С ${dayKey(from)} $until. ${replacement == null ? '' : 'Запланированное переключение на эту дату будет заменено. '}Прошлые дни сохранятся.',
                      )) {
                        return;
                      }
                      await _run(() => repo.activate(t, from));
                    },
                    child: const Text('Применить'),
                  ),
                TextButton(
                  onPressed: () => showTemplateEditor(
                    context,
                    repo,
                    initial: t.items.map((i) => i.duplicate()).toList(),
                    spheres: _spheres,
                  ),
                  child: const Text('Дублировать'),
                ),
                TextButton(
                  onPressed: () => _run(() => repo.archive(t.id, !t.archived)),
                  child: Text(t.archived ? 'Вернуть из архива' : 'В архив'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = RoutinePalette(_dark);
    return Theme(
      data: p.theme,
      child: Builder(
        builder: (context) => Material(
          color: p.background,
          child: Column(
            children: [
              _header(context, p),
              if (!_ready)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (repo.error != null &&
                  repo.snapshot.templates.isEmpty &&
                  repo.snapshot.activations.isEmpty)
                Expanded(
                  child: RoutineEmpty(
                    title: 'Не удалось загрузить данные',
                    subtitle: repo.error!,
                    action: OutlinedButton(
                      onPressed: () => _run(() => repo.load()),
                      child: const Text('Повторить'),
                    ),
                  ),
                )
              else ...[
                if (_preview)
                  Container(
                    color: routineAccent.withValues(alpha: .1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          size: 17,
                          color: routineAccent,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Демонстрационные данные · отметки не сохраняются',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _useExample(context),
                          child: const Text('Использовать шаблон'),
                        ),
                        IconButton(
                          tooltip: 'Закрыть пример',
                          onPressed: () => setState(() {
                            _preview = false;
                            _sphere = null;
                            _template = null;
                            _item = null;
                          }),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                if (!_preview && data.templates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: RoutineSurface(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Ваша неделя. Ваша композиция.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextButton(
                            onPressed: _showExample,
                            child: const Text('Посмотреть пример'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _templates(context),
                            child: const Text('Создать шаблон'),
                          ),
                        ],
                      ),
                    ),
                  ),
                _controls(context, p),
                Expanded(
                  child: _view == 'canvas'
                      ? RoutineCanvas(
                          key: _canvas,
                          panels: _panels,
                          transform: _transform,
                          date: _date,
                          onChanged: _saveLayout,
                          builder: (panel) => _content(
                            context,
                            panel.type,
                            shiftDay(_date, panel.dayOffset),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: RoutineSurface(
                            padding: EdgeInsets.zero,
                            child: _content(
                              context,
                              _view == 'analytics' ? _analytics : _view,
                              _date,
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, RoutinePalette p) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
    decoration: BoxDecoration(
      color: p.surface.withValues(alpha: .7),
      border: Border(bottom: BorderSide(color: p.border.withValues(alpha: .6))),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 20,
      runSpacing: 12,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFC8AF), Color(0xFFE67F62)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.view_quilt_outlined,
                color: Color(0xFF623520),
                size: 23,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Распорядок',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.8,
                  ),
                ),
                Text(
                  'Планируйте спокойно. Замечайте прогресс.',
                  style: TextStyle(color: p.secondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _dark
                  ? 'Светлое оформление холста'
                  : 'Тёмное оформление холста',
              onPressed: () {
                setState(() => _dark = !_dark);
                _saveLayout();
              },
              icon: Icon(
                _dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
            ),
            TextButton.icon(
              onPressed: () => _templates(context),
              icon: const Icon(Icons.layers_outlined, size: 18),
              label: const Text('Шаблоны'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _addOccurrence(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Пункт'),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _controls(BuildContext context, RoutinePalette p) {
    final tabs = {
      'canvas': 'Холст',
      'day': 'Сегодня',
      'week': 'Неделя',
      'table': 'Таблица',
      'tracker': 'Трекер',
      'analytics': 'Аналитика',
    };
    final active = data.activeOn(_date);
    final activeName = data.templates
        .where((t) => t.id == active?.templateId)
        .firstOrNull
        ?.name;
    final sphereNames = {
      for (final items in data.versions.values)
        for (final i in items) i.sphere,
      for (final o in data.overrides.values) o.item.sphere,
    }.toList()..sort();
    final allItems = <String, String>{
      for (final items in data.versions.values)
        for (final i in items) i.id: i.title,
      for (final o in data.overrides.values) o.item.id: o.item.title,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: p.inset,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Wrap(
                  spacing: 3,
                  children: tabs.entries
                      .map(
                        (t) => TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: _view == t.key ? p.surface : null,
                            foregroundColor: _view == t.key
                                ? p.text
                                : p.secondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => setState(() => _view = t.key),
                          child: Text(
                            t.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _view == t.key
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Предыдущий период',
                    onPressed: () => _navigate(-1),
                    icon: const Icon(Icons.chevron_left, size: 20),
                  ),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null && mounted) {
                        setState(() => _date = date);
                      }
                    },
                    child: Text(
                      '${_date.day} ${monthLabels[_date.month - 1].toLowerCase()} ${_date.year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Следующий период',
                    onPressed: () => _navigate(1),
                    icon: const Icon(Icons.chevron_right, size: 20),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _date = routineDay(repo.now())),
                    child: const Text(
                      'Сегодня',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (activeName != null)
                Text(
                  activeName,
                  style: TextStyle(fontSize: 11, color: p.secondary),
                ),
              _filter<String>(context, 'Все сферы', _sphere, {
                for (final s in sphereNames) s: s,
              }, (v) => setState(() => _sphere = v)),
              _filter<String>(context, 'Все шаблоны', _template, {
                for (final t in data.templates) t.id: t.name,
                'one-off': 'Разовые пункты',
              }, (v) => setState(() => _template = v)),
              _filter<String>(
                context,
                'Все занятия',
                _item,
                allItems,
                (v) => setState(() => _item = v),
              ),
              if (_sphere != null || _template != null || _item != null)
                TextButton(
                  onPressed: () => setState(() {
                    _sphere = null;
                    _template = null;
                    _item = null;
                  }),
                  child: const Text(
                    'Сбросить фильтры',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              if (_view == 'tracker')
                SegmentedButton<String>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: 'week', label: Text('7 дней')),
                    ButtonSegment(value: 'month', label: Text('Месяц')),
                  ],
                  selected: {_trackerPeriod},
                  onSelectionChanged: (v) =>
                      setState(() => _trackerPeriod = v.first),
                ),
              if (_view == 'analytics' || _view == 'canvas') ...[
                _filter<int>(
                  context,
                  'Период',
                  _period,
                  {7: '7 дней', 30: '30 дней', 0: 'Месяц', -1: 'Свои даты'},
                  (v) async {
                    if (v != -1) {
                      setState(() => _period = v ?? 30);
                      return;
                    }
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: shiftDay(repo.now(), 3650),
                      initialDateRange:
                          _customPeriod ??
                          DateTimeRange(
                            start: shiftDay(repo.now(), -29),
                            end: routineDay(repo.now()),
                          ),
                      helpText: 'Период аналитики',
                      saveText: 'Применить',
                    );
                    if (range != null && mounted) {
                      setState(() {
                        _customPeriod = range;
                        _period = -1;
                      });
                    }
                  },
                  allowAll: false,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 30,
                      child: Checkbox(
                        value: _includeToday,
                        onChanged: (v) => setState(() => _includeToday = v!),
                      ),
                    ),
                    const Text(
                      'Включить сегодня',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                if (_includeToday)
                  Text(
                    'Сегодня — предварительно',
                    style: TextStyle(fontSize: 10, color: p.secondary),
                  ),
              ],
              if (_view == 'analytics')
                ...['overview', 'regularity', 'balance'].map(
                  (t) => ChoiceChip(
                    label: Text(
                      routinePanelTypes[t]!.$1,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _analytics == t,
                    onSelected: (_) => setState(() => _analytics = t),
                  ),
                ),
              if (_view == 'day')
                PopupMenuButton<String>(
                  tooltip: 'Действия с днём',
                  onSelected: (v) async {
                    if (_preview) {
                      return;
                    }
                    if (await _confirm(
                      context,
                      'Отменить план дня?',
                      'Будут отменены все пункты на ${dayKey(_date)}, включая скрытые фильтрами. Отметки дня будут сняты.',
                    )) {
                      await _run(() => repo.cancelDay(_date));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Отменить план на эту дату'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filter<T>(
    BuildContext context,
    String label,
    T? value,
    Map<T, String> options,
    ValueChanged<T?> change, {
    bool allowAll = true,
  }) => PopupMenuButton<T>(
    tooltip: label,
    onSelected: (v) {
      if (allowAll && v == value) {
        change(null);
      } else {
        change(v);
      }
    },
    itemBuilder: (_) => options.entries
        .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
        .toList(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: paletteOf(context).surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: paletteOf(context).border.withValues(alpha: .6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              options[value] ?? label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 14),
        ],
      ),
    ),
  );
  void _navigate(int direction) => setState(() {
    if (_view == 'analytics' && _period == -1 && _customPeriod != null) {
      final count =
          _customPeriod!.end.difference(_customPeriod!.start).inDays + 1;
      _customPeriod = DateTimeRange(
        start: shiftDay(_customPeriod!.start, direction * count),
        end: shiftDay(_customPeriod!.end, direction * count),
      );
      _date = _customPeriod!.end;
    } else if ((_view == 'tracker' && _trackerPeriod == 'month') ||
        (_view == 'analytics' && _period == 0)) {
      _date = DateTime(_date.year, _date.month + direction, 1);
    } else {
      _date = shiftDay(
        _date,
        direction *
            (_view == 'week' || _view == 'table'
                ? 7
                : _view == 'analytics'
                ? (_period == 0 ? 30 : _period)
                : 1),
      );
    }
  });

  Widget _content(BuildContext context, String type, DateTime date) {
    final today = repo.now();
    if (type == 'table') {
      final from = mondayOf(date);
      return RoutineTimetable(
        entries: _entries(shiftDay(from, -1), shiftDay(from, 6)),
        date: date,
        today: today,
        onToggle: _toggle,
        onEdit: (o) => _editOccurrence(context, o),
        onAdd: (day, start) => _addOccurrence(context, date: day, start: start),
        dayLabels: _dayLabels,
        onDayLabel: (day) async {
          final controller = TextEditingController(text: _dayLabels[day] ?? '');
          final label = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Подпись: ${weekdayLabels[day - 1]}'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 24,
                decoration: const InputDecoration(
                  labelText: 'Например: очный, онлайн, выходной',
                  helperText: 'Подпись для таблиц на этом холсте',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          );
          // The route may still animate out with its field attached.
          Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
          if (label != null && mounted) {
            setState(() => _dayLabels[day] = label);
            _saveLayout();
          }
        },
      );
    }
    if (type == 'day') {
      return RoutineDayView(
        entries: _entries(date, date),
        today: today,
        onToggle: _toggle,
        onEdit: (o) => _editOccurrence(context, o),
        onMenu: (o, a) => _occurrenceMenu(context, o, a),
        onAdd: () => _addOccurrence(context, date: date),
        pending: _optimistic.keys.toSet(),
      );
    }
    if (type == 'week') {
      final start = mondayOf(date);
      return RoutineWeekView(
        entries: _entries(shiftDay(start, -1), shiftDay(start, 6)),
        date: date,
        today: today,
        onToggle: _toggle,
        onEdit: (o) => _editOccurrence(context, o),
        onMove: (o, s, e) {
          if (_preview) {
            _message('Примените шаблон, чтобы переносить занятия.');
            return;
          }
          _run(
            () => repo.saveOverride(
              o.copyWith(
                slot: RoutineSlot(
                  id: o.slot.id,
                  days: o.slot.days,
                  start: s,
                  end: e,
                ),
                changed: true,
              ),
            ),
          );
        },
        onNew: (d, s) => _addOccurrence(context, date: d, start: s),
      );
    }
    if (type == 'tracker') {
      final from = _trackerPeriod == 'month'
          ? DateTime(date.year, date.month, 1)
          : mondayOf(date);
      final to = _trackerPeriod == 'month'
          ? DateTime(date.year, date.month + 1, 0)
          : shiftDay(from, 6);
      return RoutineTrackerView(
        entries: _entries(from, to),
        from: from,
        to: to,
        today: today,
        onToggle: _toggle,
        onDay: _openDay,
      );
    }
    final limit = _includeToday ? routineDay(today) : shiftDay(today, -1);
    final desiredEnd = _period == -1
        ? _customPeriod!.end
        : (_period == 0 ? DateTime(date.year, date.month + 1, 0) : date);
    final end = desiredEnd.isAfter(limit) ? limit : desiredEnd;
    final start = _period == 0
        ? DateTime(date.year, date.month, 1)
        : _period == -1
        ? _customPeriod!.start
        : shiftDay(end, 1 - _period);
    final days = end.difference(start).inDays + 1;
    return RoutineAnalyticsView(
      entries: _entries(start, end),
      previous: _entries(shiftDay(start, -days), shiftDay(start, -1)),
      today: today,
      onDay: _openDay,
      section: type,
      periodLabel: '${dayKey(start)} — ${dayKey(end)}',
    );
  }
}
