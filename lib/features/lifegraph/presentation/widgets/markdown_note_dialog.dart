import 'package:flutter/material.dart';
import 'package:notes_api/notes_api.dart';

typedef MarkdownNoteInput = ({String title, String text});

Future<T?> showMarkdownNoteDialog<T extends Object>(
  BuildContext context, {
  required Future<T> Function(MarkdownNoteInput) onSave,
  Future<bool> Function(String)? titleExists,
  String initialTitle = '',
  bool converting = false,
  bool savingCopy = false,
}) => showDialog<T>(
  context: context,
  builder: (_) => _MarkdownNoteDialog<T>(
    onSave: onSave,
    titleExists: titleExists,
    initialTitle: initialTitle,
    converting: converting,
    savingCopy: savingCopy,
  ),
);

class _MarkdownNoteDialog<T extends Object> extends StatefulWidget {
  const _MarkdownNoteDialog({
    required this.onSave,
    required this.titleExists,
    required this.initialTitle,
    required this.converting,
    required this.savingCopy,
  });
  final Future<T> Function(MarkdownNoteInput) onSave;
  final Future<bool> Function(String)? titleExists;
  final String initialTitle;
  final bool converting;
  final bool savingCopy;
  @override
  State<_MarkdownNoteDialog<T>> createState() => _MarkdownNoteDialogState<T>();
}

class _MarkdownNoteDialogState<T extends Object>
    extends State<_MarkdownNoteDialog<T>> {
  late final _title = TextEditingController(text: widget.initialTitle);
  final _text = TextEditingController();
  int _titleCheck = 0;
  bool _checkingTitle = false;
  bool _nameTaken = false;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle.isNotEmpty) _checkTitle(widget.initialTitle);
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _checkTitle(String value) async {
    final title = value.trim();
    final check = widget.titleExists;
    final request = ++_titleCheck;
    setState(() {
      _checkingTitle = check != null && title.isNotEmpty;
      _nameTaken = false;
      _saveError = null;
    });
    if (check == null || title.isEmpty) return;
    var taken = false;
    try {
      taken = await check(title);
    } catch (_) {
      // Saving will report any errors other than a confirmed name conflict.
    }
    if (!mounted || request != _titleCheck) return;
    setState(() {
      _checkingTitle = false;
      _nameTaken = taken;
    });
  }

  bool get _canSave =>
      !_saving &&
      !_checkingTitle &&
      !_nameTaken &&
      _title.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final result = await widget.onSave((
        title: _title.text.trim(),
        text: _text.text,
      ));
      if (mounted) Navigator.pop(context, result);
    } on MarkdownNoteNameConflict {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameTaken = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Не удалось сохранить заметку. $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<T>(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
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
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: 'Название файла',
                errorText: _nameTaken
                    ? const MarkdownNoteNameConflict().toString()
                    : null,
                errorMaxLines: 2,
              ),
              onChanged: _checkTitle,
            ),
            if (!widget.converting)
              TextField(
                key: const ValueKey('markdown-note-text'),
                controller: _text,
                enabled: !_saving,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Текст заметки'),
              ),
            if (_saveError case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(
            widget.savingCopy
                ? 'Сохранить копию'
                : widget.converting
                ? 'Преобразовать'
                : 'Создать .md',
          ),
        ),
      ],
    ),
  );
}
