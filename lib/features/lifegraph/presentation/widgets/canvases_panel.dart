import 'package:flutter/material.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/date_format.dart';

import '../life_graph_screen.dart';
import 'canvas_visuals.dart';
import 'create_canvas_dialog.dart';

enum _CanvasFilter {
  all('Все канвасы'),
  structured('Из структуры'),
  free('Свободные');

  const _CanvasFilter(this.label);
  final String label;
}

enum _CanvasSort {
  recent('Сначала недавние'),
  name('По названию');

  const _CanvasSort(this.label);
  final String label;
}

class CanvasesPanel extends StatefulWidget {
  const CanvasesPanel({super.key, required this.model, this.embedded = false});
  final PulseScreenViewModel model;
  final bool embedded;

  @override
  State<CanvasesPanel> createState() => _CanvasesPanelState();
}

class _CanvasesPanelState extends State<CanvasesPanel> {
  String _query = '';
  _CanvasFilter _filter = _CanvasFilter.all;
  _CanvasSort _sort = _CanvasSort.recent;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CanvasSummary>>(
    stream: widget.model.canvasesStream,
    initialData: widget.model.canvases,
    builder: (context, snapshot) {
      final all = snapshot.data ?? widget.model.canvases;
      final boards =
          all.where((board) {
            final matches = switch (_filter) {
              _CanvasFilter.structured => board.sourceId != null,
              _CanvasFilter.free => board.sourceId == null,
              _CanvasFilter.all => true,
            };
            return matches && board.title.toLowerCase().contains(_query);
          }).toList()..sort((left, right) {
            if (_sort == _CanvasSort.recent) {
              final order = (right.updatedAt?.millisecondsSinceEpoch ?? 0)
                  .compareTo(left.updatedAt?.millisecondsSinceEpoch ?? 0);
              if (order != 0) return order;
            }
            return left.title.toLowerCase().compareTo(
              right.title.toLowerCase(),
            );
          });
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = switch (constraints.maxWidth) {
            >= 820 => 3,
            >= 510 => 2,
            _ => 1,
          };
          return CustomScrollView(
            primary: false,
            shrinkWrap: widget.embedded,
            physics: widget.embedded
                ? const NeverScrollableScrollPhysics()
                : null,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: _header(context, constraints.maxWidth),
                ),
              ),
              if (snapshot.hasError)
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverToBoxAdapter(
                    child: OutlinedButton.icon(
                      onPressed: widget.model.retryCanvasCatalog,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить загрузку канвасов'),
                    ),
                  ),
                ),
              if (all.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  sliver: SliverToBoxAdapter(child: _toolbar()),
                ),
              if (boards.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(23),
                    child: Column(
                      children: [
                        Icon(
                          canvasIcon,
                          size: 29,
                          color: canvasKindColor('sphere'),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          all.isEmpty
                              ? 'Пока нет канвасов'
                              : 'Канвасы не найдены',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          all.isEmpty
                              ? 'Начните с пустой доски или выберите структуру.'
                              : 'Измените запрос или фильтр.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: canvasMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: columns == 1 ? 147 : 164,
                    ),
                    itemCount: boards.length,
                    itemBuilder: (context, i) => _CanvasTile(
                      key: ValueKey('canvas:${boards[i].id}'),
                      canvas: boards[i],
                      onOpen: () =>
                          openCanvasBoard(context, widget.model, boards[i]),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );

  Widget _header(BuildContext context, double width) {
    final compact =
        width < 390 || MediaQuery.textScalerOf(context).scale(14) > 18;
    void create() => showCreateCanvas(context, widget.model);
    return Row(
      children: [
        const CanvasBadge(size: 34),
        const SizedBox(width: 9),
        const Expanded(
          child: Text(
            'Канвасы',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        if (compact)
          Tooltip(
            message: 'Новый канвас',
            child: FilledButton(
              key: const ValueKey('canvas-create'),
              onPressed: create,
              style: canvasPrimaryButton().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(38, 38)),
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              ),
              child: const Icon(Icons.add, size: 19),
            ),
          )
        else
          FilledButton.icon(
            key: const ValueKey('canvas-create'),
            onPressed: create,
            style: canvasPrimaryButton(),
            icon: const Icon(Icons.add, size: 19),
            label: const Text('Новый канвас'),
          ),
      ],
    );
  }

  Widget _toolbar() => Row(
    children: [
      Expanded(
        child: TextField(
          onChanged: (text) =>
              setState(() => _query = text.trim().toLowerCase()),
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Поиск канвасов',
            prefixIcon: Icon(Icons.search, size: 18),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
      const SizedBox(width: 4),
      PopupMenuButton<_CanvasFilter>(
        tooltip: 'Фильтр: ${_filter.label}',
        icon: Icon(
          Icons.filter_alt_outlined,
          color: _filter == _CanvasFilter.all ? canvasMuted : AppColors.primary,
        ),
        initialValue: _filter,
        onSelected: (value) => setState(() => _filter = value),
        itemBuilder: (_) => [
          for (final value in _CanvasFilter.values)
            PopupMenuItem(value: value, child: Text(value.label)),
        ],
      ),
      PopupMenuButton<_CanvasSort>(
        tooltip: 'Сортировка: ${_sort.label}',
        icon: const Icon(Icons.sort, color: canvasMuted),
        initialValue: _sort,
        onSelected: (value) => setState(() => _sort = value),
        itemBuilder: (_) => [
          for (final value in _CanvasSort.values)
            PopupMenuItem(value: value, child: Text(value.label)),
        ],
      ),
    ],
  );
}

class _CanvasTile extends StatelessWidget {
  const _CanvasTile({super.key, required this.canvas, required this.onOpen});
  final CanvasSummary canvas;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final labelHeight = 18 + scaler.scale(15) + scaler.scale(12);
    final kind = canvas.sourceKind ?? 'entity';
    return Material(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: canvasStroke),
      ),
      color: AppColors.surfaceContainer,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Ink(child: CanvasThumbnail.document(canvas.preview)),
            ),
            const Divider(height: 1, color: canvasStroke),
            SizedBox(
              height: labelHeight,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          canvas.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              canvasKindIcon(kind),
                              color: canvasKindColor(kind),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [
                                  canvasCardCount(canvas.cardCount),
                                  if (canvas.updatedAt case final date?)
                                    formatDate(date.toLocal()),
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.12,
                                  color: canvasMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'Действия канваса',
                    icon: const Icon(
                      Icons.more_horiz,
                      size: 19,
                      color: canvasMuted,
                    ),
                    onSelected: (_) => onOpen(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0, child: Text('Открыть канвас')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCreateCanvas(
  BuildContext context,
  PulseScreenViewModel model, {
  String? sourceId,
}) async {
  final canvas = await showDialog<CanvasSummary>(
    context: context,
    builder: (_) => CreateCanvasDialog(model: model, sourceId: sourceId),
  );
  if (canvas != null && context.mounted) {
    await openCanvasBoard(context, model, canvas);
  }
}

Future<void> openCanvasBoard(
  BuildContext context,
  PulseScreenViewModel model,
  CanvasSummary canvas,
) async {
  final navigator = Navigator.of(context);
  try {
    CanvasSummary? next = canvas;
    while (context.mounted && next != null) {
      final graph = await model.openCanvas(next);
      try {
        if (!navigator.mounted) return;
        next = await navigator.push(
          MaterialPageRoute<CanvasSummary>(
            builder: (_) => LifeGraphScreen(
              viewModel: graph,
              canvasChoices: model.canvases,
            ),
          ),
        );
      } finally {
        await graph.dispose();
      }
      if (context.mounted) await model.reloadCanvases();
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть канвас. $error')),
      );
    }
  }
}

enum _RelatedCanvasAction { create }

Future<void> showRelatedCanvases(
  BuildContext context,
  PulseScreenViewModel model, {
  required String sourceId,
  required String title,
}) async {
  final result = await showDialog<Object>(
    context: context,
    builder: (context) {
      final related = model.canvases.where(
        (canvas) => canvas.sourceId == sourceId,
      );
      return SimpleDialog(
        title: Text('Канвасы · $title'),
        children: [
          for (final canvas in related)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, canvas),
              child: Text(canvas.title),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, _RelatedCanvasAction.create),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.add),
              title: Text('Новый канвас'),
            ),
          ),
        ],
      );
    },
  );
  if (!context.mounted) return;
  if (result is CanvasSummary) {
    await openCanvasBoard(context, model, result);
  } else if (result == _RelatedCanvasAction.create) {
    await showCreateCanvas(context, model, sourceId: sourceId);
  }
}
