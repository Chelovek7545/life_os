import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:path/path.dart' as p;

class MarkdownNoteEditor extends StatefulWidget {
  const MarkdownNoteEditor({
    super.key,
    required this.title,
    required this.path,
    required this.initialContent,
    required this.startEditing,
    this.onSave,
  });

  final String title;
  final String path;
  final String initialContent;
  final bool startEditing;
  final Future<void> Function(String text)? onSave;

  @override
  State<MarkdownNoteEditor> createState() => _MarkdownNoteEditorState();
}

enum _NoteMode { preview, edit }

class _MarkdownNoteEditorState extends State<MarkdownNoteEditor> {
  late final _controller = TextEditingController(text: widget.initialContent);
  late var _mode = widget.startEditing && widget.onSave != null
      ? _NoteMode.edit
      : _NoteMode.preview;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final save = widget.onSave;
    if (_saving || save == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await save(_controller.text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Не удалось сохранить заметку. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit = widget.onSave != null;
    final error = _error;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        actionsPadding: const EdgeInsets.all(12),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 760,
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canEdit)
                SegmentedButton<_NoteMode>(
                  segments: const [
                    ButtonSegment(
                      value: _NoteMode.preview,
                      label: Text(
                        'Предпросмотр',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ButtonSegment(
                      value: _NoteMode.edit,
                      label: Text(
                        'Редактирование',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: _saving
                      ? null
                      : (selection) {
                          FocusScope.of(context).unfocus();
                          setState(() => _mode = selection.single);
                        },
                )
              else
                Text(
                  'Исходный файл недоступен. Показана сохранённая версия.',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _mode == _NoteMode.edit
                    ? TextField(
                        key: const ValueKey('resource-note-body'),
                        controller: _controller,
                        enabled: !_saving,
                        onChanged: (_) => setState(() {}),
                        expands: true,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontFamily: 'JetBrainsMono'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Текст в формате Markdown',
                        ),
                      )
                    : _controller.text.trim().isEmpty
                    ? const Center(child: Text('Пустая заметка'))
                    : Markdown(
                        data: _controller.text,
                        selectable: true,
                        imageDirectory: Uri.directory(
                          p.dirname(widget.path),
                        ).toString(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          if (canEdit)
            FilledButton(
              onPressed: _saving || _controller.text == widget.initialContent
                  ? null
                  : _save,
              child: const Text('Сохранить'),
            ),
        ],
      ),
    );
  }
}
