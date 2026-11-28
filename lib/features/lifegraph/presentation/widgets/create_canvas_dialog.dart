import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart';
import 'package:life_os/core/theme/app_colors.dart';

import 'canvas_visuals.dart';

class CreateCanvasDialog extends StatefulWidget {
  const CreateCanvasDialog({super.key, required this.model, this.sourceId});
  final PulseScreenViewModel model;
  final String? sourceId;

  @override
  State<CreateCanvasDialog> createState() => _CreateCanvasDialogState();
}

class _CreateCanvasDialogState extends State<CreateCanvasDialog> {
  final _name = TextEditingController();
  final _treeScroll = ScrollController();
  late bool _structured = widget.sourceId != null;
  List<GraphNodeData> _catalog = const [];
  CanvasStructure? _structure;
  final _selectedIds = <String>{};
  final _collapsed = <String>{};
  bool _loading = false;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_structured) _loadSources();
  }

  @override
  void dispose() {
    _name.dispose();
    _treeScroll.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    if (_loaded || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.model.canvasSources();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loaded = true;
        if (_sources.any((node) => node.id == widget.sourceId)) {
          _selectSource(widget.sourceId!);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось загрузить структуру.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GraphNodeData> get _sources => _catalog
      .where((node) => const {'sphere', 'goal', 'project'}.contains(node.kind))
      .toList();

  void _selectSource(String id) {
    if (_treeScroll.hasClients) _treeScroll.jumpTo(0);
    final structure = CanvasStructure(_catalog, id);
    _structure = structure;
    _selectedIds
      ..clear()
      ..addAll(structure.nodes.map((node) => node.id));
    _collapsed.clear();
    if (_name.text.trim().isEmpty) _name.text = structure.root?.title ?? '';
  }

  void _setMode(bool structured) {
    setState(() {
      _structured = structured;
      _error = null;
    });
    if (structured) _loadSources();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final board = await widget.model.createCanvas(
        title: _name.text,
        sourceId: _structured ? _structure?.root?.id : null,
        selectedIds: Set.of(_selectedIds),
      );
      if (mounted) Navigator.of(context).pop(board);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Не удалось создать канвас. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave =
        !_saving &&
        _name.text.trim().isNotEmpty &&
        (!_structured || (_structure?.root != null && _selectedIds.isNotEmpty));
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _structured ? 800 : 520),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: canvasStroke),
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF242123),
                  Color(0xFF171619),
                  Color(0xFF211B1B),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const CanvasBadge(),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Новый канвас',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Выберите, с чего начать',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: canvasMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Закрыть',
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _modes(),
                        const SizedBox(height: 16),
                        const _Label('Название'),
                        TextField(
                          controller: _name,
                          key: const ValueKey('canvas-name'),
                          enabled: !_saving,
                          maxLength: 90,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (canSave) _save();
                          },
                          decoration: const InputDecoration(
                            counterText: '',
                            isDense: true,
                            hintText: 'Например, Идеи на месяц',
                          ),
                        ),
                        if (_structured) ..._structureFields(),
                        if (_error case final error?) ...[
                          const SizedBox(height: 12),
                          Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: canvasStroke),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    runSpacing: 8,
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_structured && _structure != null)
                        Text(
                          'Будет добавлено: ${canvasCardCount(_selectedIds.length)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: canvasMuted,
                          ),
                        ),
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: canSave ? _save : null,
                        style: canvasPrimaryButton(),
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Создать канвас'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modes() => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal =
          constraints.maxWidth >= 340 &&
          MediaQuery.textScalerOf(context).scale(13) <= 17;
      final tiles = [
        _ModeTile(
          title: 'Пустой канвас',
          subtitle: 'Добавьте карточки вручную',
          icon: canvasIcon,
          selected: !_structured,
          onTap: _saving ? null : () => _setMode(false),
        ),
        _ModeTile(
          title: 'Из структуры',
          subtitle: 'Выберите ветки для импорта',
          icon: Icons.account_tree_outlined,
          selected: _structured,
          onTap: _saving ? null : () => _setMode(true),
        ),
      ];
      return horizontal
          ? Row(
              children: [
                Expanded(child: tiles.first),
                const SizedBox(width: 10),
                Expanded(child: tiles.last),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tiles.first, const SizedBox(height: 8), tiles.last],
            );
    },
  );

  List<Widget> _structureFields() {
    final structure = _structure;
    return [
      const SizedBox(height: 16),
      const _Label('Источник'),
      if (_loading)
        const LinearProgressIndicator()
      else if (!_loaded)
        OutlinedButton(
          onPressed: _loadSources,
          child: const Text('Повторить загрузку'),
        )
      else if (_sources.isEmpty)
        const Text(
          'Создайте сферу, цель или проект, чтобы импортировать структуру.',
        )
      else
        InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: structure?.root?.id,
              isExpanded: true,
              hint: const Text('Сфера, цель или проект'),
              onChanged: _saving
                  ? null
                  : (id) {
                      if (id != null) setState(() => _selectSource(id));
                    },
              items: [
                for (final node in _sources)
                  DropdownMenuItem(
                    value: node.id,
                    child: Text(
                      '${canvasKindLabel(node.kind)} · ${node.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (structure?.root != null) ...[
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 570;
            final tree = _tree(structure!, wide ? 230 : 176);
            final preview = _preview(structure, wide ? 230 : 130);
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tree),
                      const SizedBox(width: 12),
                      Expanded(child: preview),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [tree, const SizedBox(height: 12), preview],
                  );
          },
        ),
      ],
    ];
  }

  Widget _tree(CanvasStructure structure, double height) {
    final branches = <(GraphNodeData, int)>[];
    void visit(GraphNodeData node, int depth) {
      branches.add((node, depth));
      if (_collapsed.contains(node.id)) return;
      for (final child in structure.childrenOf(node.id)) {
        visit(child, depth + 1);
      }
    }

    visit(structure.root!, 0);
    final subtreeSizes = <String, int>{};
    final checkedSizes = <String, int>{};
    for (final node in structure.nodes.reversed) {
      final children = structure.childrenOf(node.id);
      subtreeSizes[node.id] =
          1 + children.fold(0, (sum, child) => sum + subtreeSizes[child.id]!);
      checkedSizes[node.id] =
          (_selectedIds.contains(node.id) ? 1 : 0) +
          children.fold(0, (sum, child) => sum + checkedSizes[child.id]!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Что добавить'),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0x420D0B0B),
            border: Border.all(color: canvasStroke),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Scrollbar(
            controller: _treeScroll,
            child: ListView.builder(
              controller: _treeScroll,
              primary: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final (node, depth) = branches[index];
                final hasChildren = structure.childrenOf(node.id).isNotEmpty;
                final checked = checkedSizes[node.id]!;
                final bool? value = checked == 0
                    ? false
                    : checked == subtreeSizes[node.id]
                    ? true
                    : null;
                void toggle() => setState(() {
                  final branch = [node];
                  for (var i = 0; i < branch.length; i++) {
                    branch.addAll(structure.childrenOf(branch[i].id));
                  }
                  final ids = branch.map((item) => item.id);
                  if (value == true) {
                    _selectedIds.removeAll(ids);
                  } else {
                    _selectedIds.addAll(ids);
                  }
                });
                return Padding(
                  padding: EdgeInsets.only(
                    left: 4 + 13.0 * depth.clamp(0, 5),
                    right: 8,
                  ),
                  child: Row(
                    children: [
                      if (hasChildren)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tooltip: _collapsed.contains(node.id)
                              ? 'Развернуть'
                              : 'Свернуть',
                          icon: Icon(
                            _collapsed.contains(node.id)
                                ? Icons.chevron_right
                                : Icons.expand_more,
                            size: 16,
                          ),
                          onPressed: () => setState(() {
                            if (!_collapsed.remove(node.id)) {
                              _collapsed.add(node.id);
                            }
                          }),
                        )
                      else
                        const SizedBox(width: 28),
                      Checkbox(
                        key: ValueKey('canvas-include:${node.id}'),
                        semanticLabel: node.title,
                        value: value,
                        tristate: true,
                        activeColor: AppColors.primary,
                        checkColor: AppColors.surfaceDim,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: _saving ? null : (_) => toggle(),
                      ),
                      Icon(
                        canvasKindIcon(node.kind),
                        size: 15,
                        color: canvasKindColor(node.kind),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: InkWell(
                          onTap: _saving ? null : toggle,
                          child: Text(
                            node.title,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _preview(CanvasStructure structure, double height) {
    final nodes = structure.selected(_selectedIds);
    final kinds = nodes
        .map((node) => node.kind == 'subTask' ? 'task' : node.kind)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Предпросмотр'),
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            height: height,
            child: CanvasThumbnail.structure(nodes),
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (final kind in kinds)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '● ',
                      style: TextStyle(color: canvasKindColor(kind)),
                    ),
                    TextSpan(text: canvasKindLabel(kind)),
                  ],
                ),
                style: const TextStyle(fontSize: 10, color: canvasMuted),
              ),
          ],
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : canvasMuted;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? const Color(0x18FF5C00) : const Color(0x0AFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: selected ? const Color(0x66FF8B52) : canvasStroke,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: canvasMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 15,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
