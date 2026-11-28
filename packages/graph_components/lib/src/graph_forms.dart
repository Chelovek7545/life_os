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

typedef GraphNodeEditContent = ({
  String title,
  IconData icon,
  Widget fields,
  String? error,
  bool saving,
  VoidCallback? onSave,
  VoidCallback? onClose,
});

class GraphNodeEditLayout extends InheritedWidget {
  const GraphNodeEditLayout({
    super.key,
    required this.builder,
    required this.onClose,
    required super.child,
  });

  final Widget Function(BuildContext, GraphNodeEditContent) builder;
  final VoidCallback onClose;

  static GraphNodeEditLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GraphNodeEditLayout>();

  @override
  bool updateShouldNotify(GraphNodeEditLayout oldWidget) =>
      builder != oldWidget.builder || onClose != oldWidget.onClose;
}

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
  final Future<void> Function(bool keepChildren)? onDelete;

  @override
  State<GraphNodeEditDialog> createState() => _GraphNodeEditDialogState();
}

class _GraphNodeEditDialogState extends State<GraphNodeEditDialog> {
  static final _hex = RegExp(r'^#?(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
  late final _title = TextEditingController(text: widget.node.title);
  late final _subtitle = switch (widget.spec.descriptionForEdit) {
    final description? => _descriptionController(description(widget.node)),
    null => TextEditingController(text: widget.node.subtitle),
  };
  late final _color = TextEditingController(text: widget.node.color);
  late Map<String, Object?> _attributes = widget.node.attributes;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _subtitle?.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<void> Function() action) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) _close();
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

  void _close() {
    final layout = context.getInheritedWidgetOfExactType<GraphNodeEditLayout>();
    if (layout != null) {
      layout.onClose();
    } else if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

  void _save() {
    final original = widget.node;
    final title = _title.text.trim();
    var color = _color.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Введите название.');
      return;
    }
    if (color != original.color) {
      if (!_hex.hasMatch(color)) {
        setState(
          () => _error = 'Введите цвет в формате HEX, например #4A90D9.',
        );
        return;
      }
      if (!color.startsWith('#')) color = '#$color';
      color = color.toUpperCase();
    }
    final updated = GraphNodeData(
      id: original.id,
      kind: original.kind,
      title: title,
      subtitle: _subtitle?.text.trim() ?? original.subtitle,
      color: color,
      parentId: original.parentId,
      inheritParentColor: original.inheritParentColor,
      attributes: _attributes,
    );
    final validation = widget.spec.validateEdit?.call(original, updated);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    _submit(() => widget.onSave(updated));
  }

  @override
  Widget build(BuildContext context) {
    final layout = GraphNodeEditLayout.maybeOf(context);
    final fields = FocusScope(
      descendantsAreFocusable: !_saving,
      child: IgnorePointer(
        ignoring: _saving,
        child: _fields(context, styled: layout != null),
      ),
    );
    final VoidCallback? close = _saving ? null : _close;
    final VoidCallback? save = _saving ? null : _save;
    if (layout != null) {
      return layout.builder(context, (
        title: widget.spec.editTitle,
        icon: widget.spec.icon,
        fields: fields,
        error: _error,
        saving: _saving,
        onSave: save,
        onClose: close,
      ));
    }
    return AlertDialog(
      title: Text(widget.spec.editTitle),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              fields,
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onDelete case final remove?)
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text(
              'Удалить',
              style: TextStyle(color: Colors.redAccent),
            ),
            onPressed: _saving ? null : () => _confirmDelete(remove),
          ),
        TextButton(onPressed: close, child: const Text('Отмена')),
        FilledButton(onPressed: save, child: const Text('Сохранить')),
      ],
    );
  }

  Widget _fields(BuildContext context, {required bool styled}) {
    InputDecoration decoration(String label) => InputDecoration(
      labelText: label,
      border: styled ? null : const OutlineInputBorder(),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        TextField(controller: _title, decoration: decoration('Название')),
        if (_subtitle case final description?)
          TextField(
            controller: description,
            decoration: decoration('Описание'),
            minLines: 2,
            maxLines: 4,
          ),
        if (widget.spec.editColor) ...[
          Text(
            'Цвет',
            style: TextStyle(
              color: GraphComponentPalette.of(context).onSurface,
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _color,
            builder: (_, value, _) => _ColorChoices(
              selected: value.text.trim().toUpperCase(),
              onSelected: (color) => _color.text = color,
            ),
          ),
          if (styled)
            TextField(
              controller: _color,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: decoration('Цвет HEX').copyWith(hintText: '#4A90D9'),
            ),
        ],
        if (widget.spec.editFields case final fields?)
          fields(context, _attributes, (patch) {
            if (mounted && !_saving) {
              setState(
                () =>
                    _attributes = Map.unmodifiable({..._attributes, ...patch}),
              );
            }
          }),
      ],
    );
  }

  TextEditingController? _descriptionController(String? text) =>
      text != null ? TextEditingController(text: text) : null;

  Future<void> _confirmDelete(Future<void> Function(bool) remove) async {
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
    if (keep != null && mounted) await _submit(() => remove(keep));
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
        Semantics(
          selected: selected == hex,
          child: IconButton(
            tooltip: 'Цвет $hex',
            onPressed: () => onSelected(hex),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(44),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            icon: DecoratedBox(
              decoration: BoxDecoration(
                color: graphColor(hex),
                shape: BoxShape.circle,
                border: selected == hex
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: SizedBox.square(
                dimension: 32,
                child: selected == hex
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            ),
          ),
        ),
    ],
  );
}
