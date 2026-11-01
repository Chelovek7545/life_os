import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'component_spec.dart';
import 'palette.dart';

const _colors = [
  '#4A90D9',
  '#E8A838',
  '#4CAF50',
  '#E91E63',
  '#9C27B0',
  '#00BCD4',
  '#FF9800',
  '#795548',
  '#607D8B',
  '#F44336',
];

class GraphNodeEditDialog extends StatefulWidget {
  const GraphNodeEditDialog({
    super.key,
    required this.node,
    required this.spec,
    required this.onSave,
    required this.onDelete,
  });
  final GraphNodeData node;
  final GraphNodeComponentSpec spec;
  final Future<void> Function(GraphNodeData) onSave;
  final Future<void> Function(bool keepChildren) onDelete;
  @override
  State<GraphNodeEditDialog> createState() => _GraphNodeEditDialogState();
}

class _GraphNodeEditDialogState extends State<GraphNodeEditDialog> {
  late final _title = TextEditingController(text: widget.node.title);
  late final _subtitle = TextEditingController(text: widget.node.subtitle);
  late String _color = widget.node.color;
  late Map<String, Object?> _attributes = widget.node.attributes;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<void> Function() action) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось выполнить действие. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: GraphComponentPalette.of(context).surfaceContainer,
    title: Text(widget.spec.editTitle),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitle,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            if (widget.spec.editColor) ...[
              const SizedBox(height: 12),
              Text(
                'Цвет:',
                style: TextStyle(
                  color: GraphComponentPalette.of(context).onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _ColorChoices(
                selected: _color,
                onSelected: (color) => setState(() => _color = color),
              ),
            ],
            if (widget.spec.editFields case final fields?)
              fields(context, _attributes, (patch) {
                if (mounted && !_saving) {
                  setState(
                    () => _attributes = Map.unmodifiable({
                      ..._attributes,
                      ...patch,
                    }),
                  );
                }
              }),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton.icon(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        label: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
        onPressed: _saving ? null : _confirmDelete,
      ),
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _saving
            ? null
            : () {
                final original = widget.node;
                final updated = GraphNodeData(
                  id: original.id,
                  kind: original.kind,
                  title: _title.text.trim(),
                  subtitle: _subtitle.text.trim(),
                  color: _color,
                  parentId: original.parentId,
                  inheritParentColor: original.inheritParentColor,
                  attributes: _attributes,
                );
                _submit(() => widget.onSave(updated));
              },
        child: const Text('Сохранить'),
      ),
    ],
  );

  Future<void> _confirmDelete() async {
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GraphComponentPalette.of(ctx).surfaceContainer,
        title: const Text('Удалить ноду?'),
        content: Text(
          'Нода "${widget.node.title}" будет удалена. Выберите, что сделать с дочерними элементами.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Удалить всё поддерево'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить детей (станут невидимыми)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (keep != null && mounted) await _submit(() => widget.onDelete(keep));
  }
}

class GraphChildCreateDialog extends StatefulWidget {
  const GraphChildCreateDialog({
    super.key,
    required this.spec,
    required this.onSave,
  });
  final GraphNodeComponentSpec spec;
  final Future<void> Function(GraphNodeDraft) onSave;
  @override
  State<GraphChildCreateDialog> createState() => _GraphChildCreateDialogState();
}

class _GraphChildCreateDialogState extends State<GraphChildCreateDialog> {
  final _title = TextEditingController();
  String _description = '';
  String? _color;
  Map<String, Object?> _attributes = const {};
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || _title.text.trim().isEmpty) return;
    final draft = GraphNodeDraft(
      kind: widget.spec.kind,
      title: _title.text.trim(),
      subtitle: _description,
      color: _color,
      attributes: _attributes,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(draft);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось создать узел. Повторите попытку.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: GraphComponentPalette.of(context).surfaceContainer,
    title: Text(widget.spec.createTitle),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.spec.createDescription) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => _description = value,
              ),
            ],
            if (widget.spec.createColor) ...[
              const SizedBox(height: 12),
              Text(
                'Цвет:',
                style: TextStyle(
                  color: GraphComponentPalette.of(context).onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _ColorChoices(
                selected: _color,
                onSelected: (color) => setState(() => _color = color),
              ),
            ],
            if (widget.spec.createFields case final fields?) ...[
              const SizedBox(height: 12),
              fields(context, _attributes, (patch) {
                if (mounted && !_saving) {
                  setState(
                    () => _attributes = Map.unmodifiable({
                      ..._attributes,
                      ...patch,
                    }),
                  );
                }
              }),
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Создать'),
      ),
    ],
  );
}

class _ColorChoices extends StatelessWidget {
  const _ColorChoices({required this.selected, required this.onSelected});
  final String? selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final hex in _colors)
        GestureDetector(
          onTap: () => onSelected(hex),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: graphColor(hex),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected == hex ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: selected == hex
                  ? [
                      BoxShadow(
                        color: graphColor(hex).withValues(alpha: .5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
          ),
        ),
    ],
  );
}
