import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';

import 'canvas_visuals.dart';

const _taskStatuses = {
  'open': 'Открыто',
  'notStarted': 'Не начато',
  'inProgress': 'В работе',
  'done': 'Выполнено',
};

String canvasTaskKind(String kind) => kind == 'subTask' ? 'task' : kind;

class CanvasFilters {
  const CanvasFilters({
    this.kinds = const {},
    this.statuses = const {},
    this.projects = const {},
    this.tags = const {},
  });

  final Set<String> kinds;
  final Set<String> statuses;
  final Set<String> projects;
  final Set<String> tags;

  bool get active =>
      kinds.isNotEmpty ||
      statuses.isNotEmpty ||
      projects.isNotEmpty ||
      tags.isNotEmpty;
  bool includesKind(String kind) =>
      kinds.isEmpty || kinds.contains(canvasTaskKind(kind));

  bool includesCard(GraphNodeData node, String? project) {
    if (!includesKind(node.kind)) return false;
    if (node.kind == 'project')
      return projects.isEmpty || projects.contains(node.id);
    if (canvasTaskKind(node.kind) != 'task') return true;
    final taskTags = node.attributes['tagNames'];
    return (statuses.isEmpty ||
            statuses.contains(node.attributes['taskStatus'])) &&
        (projects.isEmpty || projects.contains(project)) &&
        (tags.isEmpty || (taskTags is Iterable && taskTags.any(tags.contains)));
  }
}

class CanvasDisplayOptions {
  const CanvasDisplayOptions({
    this.nodeScale = 1,
    this.grid = true,
    this.straight = false,
    this.animations = true,
    this.labels = true,
    this.details = true,
  });
  final double nodeScale;
  final bool grid, straight, animations, labels, details;
}

typedef CanvasSearchResult = ({
  String id,
  String kind,
  String title,
  String details,
});

Future<CanvasSearchResult?> showCanvasSearch(
  BuildContext context,
  List<CanvasSearchResult> cards, {
  bool notesOnly = false,
}) => showDialog<CanvasSearchResult>(
  context: context,
  builder: (context) => _CanvasSearch(cards: cards, notesOnly: notesOnly),
);

class _CanvasSearch extends StatefulWidget {
  const _CanvasSearch({required this.cards, required this.notesOnly});
  final List<CanvasSearchResult> cards;
  final bool notesOnly;

  @override
  State<_CanvasSearch> createState() => _CanvasSearchState();
}

class _CanvasSearchState extends State<_CanvasSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.cards
        .where(
          (card) =>
              (!widget.notesOnly || card.kind == 'note') &&
              '${card.title}\n${card.details}'.toLowerCase().contains(_query),
        )
        .toList();
    return AlertDialog(
      title: Text(widget.notesOnly ? 'Заметки канваса' : 'Поиск по канвасу'),
      content: SizedBox(
        width: 430,
        height: 320,
        child: Column(
          children: [
            TextField(
              autofocus: !widget.notesOnly,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.notesOnly
                    ? 'Поиск заметок'
                    : 'Название или текст',
              ),
              onChanged: (text) =>
                  setState(() => _query = text.trim().toLowerCase()),
              onSubmitted: (_) {
                if (matches.isNotEmpty) Navigator.pop(context, matches.first);
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('Ничего не найдено'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final card = matches[index];
                        return ListTile(
                          leading: Icon(
                            canvasKindIcon(card.kind),
                            color: canvasKindColor(card.kind),
                          ),
                          title: Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(canvasKindLabel(card.kind)),
                          onTap: () => Navigator.pop(context, card),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

Future<CanvasFilters?> showCanvasFilters(
  BuildContext context, {
  required CanvasFilters initial,
  required Set<String> availableKinds,
  required Map<String, String> availableProjects,
  required Set<String> availableTags,
  bool layersOnly = false,
}) {
  final kinds = {...initial.kinds};
  final statuses = {...initial.statuses};
  final projects = {...initial.projects};
  final tags = {...initial.tags};
  return showDialog<CanvasFilters>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        Widget group(
          String title,
          Map<String, String> options,
          Set<String> selection,
        ) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 3,
                children: [
                  for (final option in options.entries)
                    FilterChip(
                      label: Text(option.value),
                      selected: selection.contains(option.key),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          selection.add(option.key);
                        } else {
                          selection.remove(option.key);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        );
        return AlertDialog(
          title: Text(layersOnly ? 'Видимость слоёв' : 'Фильтры канваса'),
          scrollable: true,
          content: SizedBox(
            width: 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                group('Типы карточек', {
                  for (final kind in {...availableKinds, ...kinds})
                    kind: canvasKindLabel(kind),
                }, kinds),
                if (!layersOnly &&
                    (availableKinds.contains('task') || statuses.isNotEmpty))
                  group('Статусы задач', _taskStatuses, statuses),
                if (!layersOnly && availableProjects.isNotEmpty)
                  group('Проекты', availableProjects, projects),
                if (!layersOnly && availableTags.isNotEmpty)
                  group('Теги задач', {
                    for (final tag in availableTags) tag: tag,
                  }, tags),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                layersOnly
                    ? CanvasFilters(
                        statuses: statuses,
                        projects: projects,
                        tags: tags,
                      )
                    : const CanvasFilters(),
              ),
              child: const Text('Сбросить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                CanvasFilters(
                  kinds: kinds,
                  statuses: statuses,
                  projects: projects,
                  tags: tags,
                ),
              ),
              child: const Text('Применить'),
            ),
          ],
        );
      },
    ),
  );
}

Future<CanvasDisplayOptions?> showCanvasDisplayOptions(
  BuildContext context,
  CanvasDisplayOptions initial, {
  required bool canResetSizes,
  required Future<void> Function() resetSizes,
}) {
  var grid = initial.grid;
  var straight = initial.straight;
  var animations = initial.animations;
  var labels = initial.labels;
  var details = initial.details;
  var nodeScale = initial.nodeScale;
  return showDialog<CanvasDisplayOptions>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        Widget toggle(String title, bool value, ValueChanged<bool> change) =>
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              value: value,
              onChanged: (value) => setState(() => change(value)),
            );
        return AlertDialog(
          title: const Text('Настройки отображения'),
          scrollable: true,
          content: SizedBox(
            width: 390,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Размер узлов · ${(nodeScale * 100).round()}%'),
                Slider(
                  min: .8,
                  max: 1.4,
                  divisions: 6,
                  value: nodeScale,
                  onChanged: (value) => setState(() => nodeScale = value),
                ),
                toggle('Прямые связи', straight, (value) => straight = value),
                toggle('Сетка', grid, (value) => grid = value),
                toggle('Анимации', animations, (value) => animations = value),
                toggle('Подписи карточек', labels, (value) => labels = value),
                toggle(
                  'Подробности карточек',
                  details,
                  (value) => details = value,
                ),
                if (canResetSizes)
                  TextButton(
                    onPressed: () async {
                      await resetSizes();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Сбросить сохранённые размеры'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, const CanvasDisplayOptions()),
              child: const Text('Сбросить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                CanvasDisplayOptions(
                  nodeScale: nodeScale,
                  grid: grid,
                  straight: straight,
                  animations: animations,
                  labels: labels,
                  details: details,
                ),
              ),
              child: const Text('Применить'),
            ),
          ],
        );
      },
    ),
  );
}
