import 'package:flutter/material.dart';

typedef MarkdownNoteInput = ({String title, String text});

Future<MarkdownNoteInput?> showMarkdownNoteDialog(
  BuildContext context, {
  String initialTitle = '',
  bool converting = false,
  bool savingCopy = false,
}) => showDialog<MarkdownNoteInput>(
  context: context,
  builder: (_) => _MarkdownNoteDialog(
    initialTitle: initialTitle,
    converting: converting,
    savingCopy: savingCopy,
  ),
);

class _MarkdownNoteDialog extends StatefulWidget {
  const _MarkdownNoteDialog({
    required this.initialTitle,
    required this.converting,
    required this.savingCopy,
  });
  final String initialTitle;
  final bool converting;
  final bool savingCopy;
  @override
  State<_MarkdownNoteDialog> createState() => _MarkdownNoteDialogState();
}

class _MarkdownNoteDialogState extends State<_MarkdownNoteDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  final _text = TextEditingController();
  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.savingCopy
          ? 'Сохранить копию .md'
          : widget.converting
          ? 'Преобразовать в Markdown'
          : 'Новая Markdown-заметка',
    ),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('markdown-note-title'),
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Название файла'),
            onChanged: (_) => setState(() {}),
          ),
          if (!widget.converting)
            TextField(
              key: const ValueKey('markdown-note-text'),
              controller: _text,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Текст заметки'),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _title.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                title: _title.text.trim(),
                text: _text.text,
              )),
        child: Text(
          widget.savingCopy
              ? 'Сохранить копию'
              : widget.converting
              ? 'Преобразовать'
              : 'Создать .md',
        ),
      ),
    ],
  );
}
