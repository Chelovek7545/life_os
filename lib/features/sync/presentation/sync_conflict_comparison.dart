import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:sync_plugin/sync_logic.dart';

typedef SyncFieldDifference = ({
  String label,
  List<String?> values,
  bool text,
  bool changed,
  List<String>? path,
});
typedef SyncDifferenceSection = ({
  String? title,
  List<SyncFieldDifference> fields,
});

const _equals = DeepCollectionEquality();

String syncEntityKind(String type) => switch (type) {
  'task' => 'Задача',
  'workLog' => 'Запись времени',
  'project' => 'Проект',
  'goal' => 'Цель',
  'sphere' => 'Сфера',
  'tag' => 'Тег',
  'habit' => 'Привычка',
  'habitEntry' => 'Отметка привычки',
  'note' => 'Заметка Markdown',
  'sticker' => 'Стикер',
  'canvasNode' => 'Положение узла',
  'canvasBoard' => 'Доска Canvas',
  _ => 'Запись',
};

String syncRevisionTitle(
  SyncRevision revision, [
  Map<String, String> names = const {},
]) {
  final data = _payload(revision);
  if (data == null) return names[revision.key] ?? 'Удаление';
  return switch (revision.entityType) {
    'canvasBoard' =>
      names['sphere/${data['sphereId']}'] ??
          syncEntityKind(revision.entityType),
    'canvasNode' =>
      _entityName(names, data['nodeId']) ?? syncEntityKind(revision.entityType),
    'habitEntry' => [
      names['habit/${data['habitId']}'],
      data['dateKey'],
    ].nonNulls.join(' · '),
    'sticker' => _caption(data['markdownPath'] ?? data['text']) ?? 'Стикер',
    _ =>
      _caption(
            data['title'] ??
                data['name'] ??
                data['path'] ??
                data['description'],
          ) ??
          names[revision.key] ??
          syncEntityKind(revision.entityType),
  };
}

List<SyncDifferenceSection> compareSyncVersions(
  List<SyncRevision> versions,
  Map<String, String> names, {
  bool includeUnchanged = false,
}) {
  final payloads = versions.map(_payload).toList();
  final type = versions.first.entityType;
  final sections = <SyncDifferenceSection>[];
  final deletion = versions.any((version) => version.deleted);
  if (deletion) {
    sections.add((
      title: null,
      fields: [
        (
          label: 'Состояние записи',
          values: [
            for (final version in versions)
              version.deleted ? 'Удалена' : 'Сохранена',
          ],
          text: false,
          changed: true,
          path: null,
        ),
      ],
    ));
  }
  if (type == 'canvasBoard') {
    sections.addAll(_boards(payloads, names));
  } else {
    final fields = _fields(
      payloads,
      names,
      omit: const {'id', 'stickerId', 'nodeId'},
      includeUnchanged: includeUnchanged,
    );
    if (fields.isNotEmpty) sections.add((title: null, fields: fields));
  }
  if (!sections.any(
        (section) => section.fields.any((field) => field.changed),
      ) &&
      !_same(payloads)) {
    sections.add((
      title: null,
      fields: [
        (
          label: 'Данные версий',
          values: versions.map((version) => version.payload).toList(),
          text: true,
          changed: true,
          path: null,
        ),
      ],
    ));
  }
  return sections;
}

String buildMergedSyncPayload(
  List<SyncRevision> versions,
  Map<SyncFieldDifference, int> choices,
) {
  final base = versions.first;
  final canvas = base.entityType == 'canvasBoard';
  Map<String, dynamic> read(SyncRevision revision) {
    final payload = _payload(revision)!;
    if (canvas) {
      final document = payload['document'] as Map<String, dynamic>;
      for (final key in ['nodes', 'edges']) {
        final entries = _byId(document[key]);
        if (entries.length != (document[key] as List).length) {
          throw const LocalSyncException(
            'Canvas содержит карточки или связи без уникальных ID.',
          );
        }
        document[key] = {'entries': entries, 'order': entries.keys.toList()};
      }
    }
    return payload;
  }

  final sources = versions.map(read).toList();
  final draft = read(base);
  for (final entry in choices.entries) {
    final path = entry.key.path!;
    final source = _parentOf(sources[entry.value], path);
    final target = _parentOf(draft, path);
    if (source.containsKey(path.last)) {
      target[path.last] = source[path.last];
    } else {
      target.remove(path.last);
    }
  }

  String payload;
  if (canvas) {
    final document = draft['document'] as Map<String, dynamic>;
    for (final key in ['nodes', 'edges']) {
      final group = document[key] as Map<String, dynamic>;
      final entries = group['entries'] as Map<String, Map<String, dynamic>>;
      final order = (group['order'] as List).cast<String>();
      document[key] = [
        for (final id in {...order, ...entries.keys}) ?entries[id],
      ];
    }
    final nodeIds = _byId(document['nodes']).keys.toSet();
    final edges = _byId(document['edges']).values;
    if (edges.any(
      (edge) =>
          !nodeIds.contains(edge['fromNode']) ||
          !nodeIds.contains(edge['toNode']),
    )) {
      throw const LocalSyncException(
        'На доске есть связь с отсутствующей карточкой. Включите карточку или уберите связь.',
      );
    }
    payload = SyncCanvasBoard(draft['sphereId'] as String, document).encode();
  } else {
    if (base.entityType == 'task') {
      // Optional keys have a fixed position in the canonical task codec.
      for (final key in [
        'parentTaskId',
        'predecessorTaskIds',
        'projectId',
        'spaceId',
        'tagIds',
      ]) {
        if (draft.containsKey(key)) {
          final value = draft.remove(key);
          if (key == 'predecessorTaskIds' &&
              value is List &&
              value.length == 1) {
            draft['predecessorTaskId'] = value.single;
          } else {
            draft[key] = value;
          }
        }
      }
    }
    payload = jsonEncode(draft);
  }
  if (SyncPayload.payloadId(base.entityType, payload) != base.entityId) {
    throw const LocalSyncException(
      'Выбранные поля меняют идентификатор записи.',
    );
  }
  return payload;
}

Map<String, dynamic> _parentOf(Map<String, dynamic> root, List<String> path) {
  var node = root;
  for (final key in path.take(path.length - 1)) {
    node = node[key] as Map<String, dynamic>;
  }
  return node;
}

Map<String, dynamic>? _payload(SyncRevision revision) {
  if (revision.payload == null) return null;
  final payload = jsonDecode(revision.payload!) as Map<String, dynamic>;
  if (revision.entityType == 'task') {
    if (payload.remove('predecessorTaskId') case final String id) {
      payload['predecessorTaskIds'] = [id];
    }
  }
  return payload;
}

String? _caption(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final first = value.trim().split('\n').first;
  return first.length <= 96 ? first : '${first.substring(0, 96)}…';
}

String? _entityName(Map<String, String> names, Object? id) {
  if (id is! String) return null;
  return [
    'task',
    'project',
    'goal',
    'sphere',
  ].map((type) => names[SyncPayload.key(type, id)]).nonNulls.firstOrNull;
}

const _labels = {
  'title': 'Название',
  'name': 'Название',
  'label': 'Подпись',
  'description': 'Описание',
  'text': 'Текст',
  'status': 'Статус',
  'createdAt': 'Создано',
  'updatedAt': 'Обновлено',
  'startsAt': 'Начало',
  'endsAt': 'Окончание',
  'dueDate': 'Срок',
  'date': 'Дата',
  'dateKey': 'День',
  'startedAt': 'Начало работы',
  'endedAt': 'Конец работы',
  'completedAt': 'Отмечено',
  'priority': 'Приоритет',
  'space': 'Пространство',
  'spaceId': 'Пространство (ID)',
  'timerSeconds': 'Время таймера, с',
  'effortWeight': 'Вес усилий',
  'tagIds': 'Теги',
  'isArchived': 'В архиве',
  'taskId': 'Задача',
  'parentTaskId': 'Родительская задача',
  'predecessorTaskIds': 'Предыдущие задачи',
  'projectId': 'Проект',
  'parentProjectId': 'Родительский проект',
  'goalId': 'Цель',
  'sphereId': 'Сфера',
  'habitId': 'Привычка',
  'type': 'Тип',
  'time': 'Время выполнения',
  'days': 'Дни недели',
  'durationWeeks': 'Длительность, нед.',
  'reminderTime': 'Напоминание',
  'icon': 'Значок',
  'path': 'Путь к файлу',
  'file': 'Файл карточки',
  'subpath': 'Раздел файла',
  'markdownPath': 'Файл Markdown',
  'url': 'Адрес ссылки',
  'color': 'Цвет',
  'colorHex': 'Цвет',
  'x': 'Положение по X',
  'y': 'Положение по Y',
  'width': 'Ширина',
  'height': 'Высота',
  'fromNode': 'Начальная карточка',
  'toNode': 'Конечная карточка',
  'fromSide': 'Сторона начала',
  'toSide': 'Сторона конца',
  'fromEnd': 'Маркер начала',
  'toEnd': 'Маркер конца',
  'background': 'Фон',
  'backgroundStyle': 'Расположение фона',
  'pulse': 'Свойства Pulse',
};

const _relations = {
  'taskId': 'task',
  'parentTaskId': 'task',
  'projectId': 'project',
  'parentProjectId': 'project',
  'goalId': 'goal',
  'sphereId': 'sphere',
  'habitId': 'habit',
};
const _statuses = {
  0: 'Открыта',
  1: 'Выполнена',
  'open': 'Открыта',
  'notStarted': 'Не начата',
  'inProgress': 'В работе',
  'done': 'Выполнена',
  'completed': 'Выполнено',
  'pending': 'Ожидает',
  'skipped': 'Пропущено',
};
const _types = {
  'morning': 'Утром',
  'lunch': 'Днём',
  'evening': 'Вечером',
  'time': 'По времени',
  'anytime': 'В любое время',
  'text': 'Текст',
  'file': 'Файл',
  'link': 'Ссылка',
  'group': 'Группа',
};
const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _textFields = {'text', 'description', 'title', 'name', 'label'};
const _timestamps = {'createdAt', 'updatedAt'};
const _dateFields = {
  ..._timestamps,
  'date',
  'dueDate',
  'startsAt',
  'endsAt',
  'startedAt',
  'endedAt',
  'completedAt',
};
final _isoDate = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}:\d{2}:\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})?$',
);

List<SyncFieldDifference> _fields(
  List<Map<String, dynamic>?> maps,
  Map<String, String> names, {
  Set<String> omit = const {'id'},
  Map<String, String> nodeNames = const {},
  String? prefix,
  bool includeUnchanged = false,
  List<String>? path = const [],
}) {
  final keys = {for (final map in maps.nonNulls) ...map.keys}.difference(omit);
  final fields = <SyncFieldDifference>[];
  final timestamps = <SyncFieldDifference>[];
  for (final key in keys) {
    final values = [for (final map in maps) map?[key]];
    final changed = !_same(values);
    if (!changed && (!includeUnchanged || values.first == null)) continue;
    final label = [?prefix, _labels[key] ?? key].join(' · ');
    final fieldPath = path == null ? null : [...path, key];
    if (values.every((value) => value is Map<String, dynamic>)) {
      final nested = _fields(
        values.cast<Map<String, dynamic>?>(),
        names,
        omit: const {},
        nodeNames: nodeNames,
        prefix: label,
        includeUnchanged: includeUnchanged,
        path: fieldPath,
      );
      if (nested.isNotEmpty) {
        fields.addAll(nested);
        continue;
      }
    }
    final rendered = values
        .map((value) => _display(key, value, names, nodeNames))
        .toList();
    final field = (
      label: label,
      values: changed && _same(rendered)
          ? values.map(_plain).toList()
          : rendered,
      text: changed && _textFields.contains(key),
      changed: changed,
      path: fieldPath,
    );
    (_timestamps.contains(key) ? timestamps : fields).add(field);
  }
  return [...fields, ...timestamps];
}

bool _same(List<Object?> values) =>
    values.skip(1).every((value) => _equals.equals(value, values.first));

String? _display(
  String key,
  Object? value,
  Map<String, String> names,
  Map<String, String> nodeNames,
) {
  if (value == null) return null;
  if (_dateFields.contains(key) && value is String) {
    final date = _isoDate.firstMatch(value);
    if (date != null) {
      final zone = date[5];
      return '${date[3]}.${date[2]}.${date[1]} · ${date[4]}'
          '${zone == null
              ? ''
              : zone == 'Z'
              ? ' UTC'
              : ' $zone'}';
    }
  }
  final relation = _relations[key];
  if (relation != null && value is String && value.isNotEmpty) {
    return names[SyncPayload.key(relation, value)] ?? value;
  }
  if ((key == 'fromNode' || key == 'toNode') && value is String) {
    return nodeNames[value] ?? value;
  }
  if (key == 'tagIds' && value is List) {
    return value.map((id) => names['tag/$id'] ?? id).join(', ');
  }
  if (key == 'predecessorTaskIds' && value is List) {
    return value.map((id) => names[id] ?? id).join(', ');
  }
  if (key == 'days' && value is List) {
    return value
        .map(
          (day) =>
              day is int && day >= 1 && day <= 7 ? _weekdays[day - 1] : day,
        )
        .join(', ');
  }
  if (key == 'status') return _statuses[value] ?? _plain(value);
  if (key == 'type') return _types[value] ?? _plain(value);
  return _plain(value);
}

String? _plain(Object? value) => switch (value) {
  null => null,
  true => 'Да',
  false => 'Нет',
  Map() || List() => const JsonEncoder.withIndent('  ').convert(value),
  _ => value.toString(),
};

Iterable<SyncDifferenceSection> _boards(
  List<Map<String, dynamic>?> payloads,
  Map<String, String> names,
) sync* {
  final documents = [
    for (final payload in payloads)
      payload?['document'] as Map<String, dynamic>?,
  ];
  final boardFields = _fields(
    documents,
    names,
    omit: const {'nodes', 'edges'},
    path: const ['document'],
  );
  if (boardFields.isNotEmpty) {
    yield (title: 'Свойства доски', fields: boardFields);
  }

  final nodes = documents.map((document) => _byId(document?['nodes'])).toList();
  final nodeNames = <String, String>{};
  for (final map in nodes) {
    for (final entry in map.entries) {
      nodeNames.putIfAbsent(entry.key, () => _nodeTitle(entry.value, names));
    }
  }
  for (final group in ['nodes', 'edges']) {
    final entries = group == 'nodes'
        ? nodes
        : documents.map((document) => _byId(document?['edges'])).toList();
    final allIds = {for (final entry in entries) ...entry.keys};
    for (final id in allIds) {
      final values = [for (final entry in entries) entry[id]];
      if (_same(values)) continue;
      final path = ['document', group, 'entries', id];
      final presenceChanged = values.any((value) => value == null);
      final first = values.nonNulls.first;
      final title = group == 'nodes'
          ? 'Карточка «${nodeNames[id]}»'
          : 'Связь «${nodeNames[first['fromNode']] ?? first['fromNode'] ?? id}» → '
                '«${nodeNames[first['toNode']] ?? first['toNode'] ?? id}»';
      final fields = <SyncFieldDifference>[
        if (presenceChanged)
          (
            label: 'Наличие на доске',
            values: [
              for (final value in values)
                value == null ? 'Отсутствует' : 'Есть',
            ],
            text: false,
            changed: true,
            path: path,
          ),
        ..._fields(
          values,
          names,
          nodeNames: nodeNames,
          path: presenceChanged ? null : path,
        ),
      ];
      if (fields.isNotEmpty) yield (title: title, fields: fields);
    }
    final common = allIds
        .where((id) => entries.every((entry) => entry.containsKey(id)))
        .toSet();
    final orders = [
      for (final entry in entries) entry.keys.where(common.contains).toList(),
    ];
    if (!_same(orders)) {
      yield (
        title: null,
        fields: [
          (
            label: group == 'nodes' ? 'Порядок карточек' : 'Порядок связей',
            values: [
              for (final order in orders)
                order.map((id) => nodeNames[id] ?? id).join('\n'),
            ],
            text: true,
            changed: true,
            path: ['document', group, 'order'],
          ),
        ],
      );
    }
  }
}

Map<String, Map<String, dynamic>> _byId(Object? entries) => {
  if (entries is List)
    for (final item in entries.whereType<Map<String, dynamic>>())
      if (item['id'] case final String id) id: item,
};

String _nodeTitle(Map<String, dynamic> node, Map<String, String> names) {
  final metadata = node['pulse'];
  return (metadata is Map ? _entityName(names, metadata['entityId']) : null) ??
      _caption(node['label'] ?? node['file'] ?? node['text'] ?? node['url']) ??
      node['id'].toString();
}
