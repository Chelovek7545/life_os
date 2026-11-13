import 'package:flutter/material.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/core/ui/hierarchy/build_note_hierarchy.dart';
import 'package:notes_api/notes_api.dart';
import 'package:path/path.dart' as p;
import 'widgets/markdown_notes_panel.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/markdown_note_dialog.dart';
import 'package:resources_plugin/resources_plugin.dart' show ResourcesViewModel;

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key, required this.viewModel});
  final ResourcesViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final stickers = viewModel
          .getAllNotes()
          .where((note) => note.source == null)
          .toList();
      return Padding(
        padding: const EdgeInsets.all(16),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ресурсы и Заметки',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Обновить заметки',
                        onPressed: !viewModel.hasVault
                            ? null
                            : () async {
                                try {
                                  await viewModel.refreshVault();
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Не удалось обновить хранилище.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Заметки Obsidian, Markdown-файлы и стикеры графа.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final obsidian = _ObsidianNotesPanel(
                        viewModel: viewModel,
                      );
                      final markdown = _MarkdownNotesPanel(
                        viewModel: viewModel,
                      );
                      if (constraints.maxWidth >= 840) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: (constraints.maxWidth * .26).clamp(
                                240.0,
                                300.0,
                              ),
                              child: obsidian,
                            ),
                            const SizedBox(width: 20),
                            Expanded(child: markdown),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          obsidian,
                          const SizedBox(height: 16),
                          markdown,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Стикеры графа (Все сферы)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (stickers.isEmpty)
              const SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Нет локальных стикеров на графах.'),
                  ),
                ),
              )
            else
              SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                itemCount: stickers.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        stickers[index].text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel({
    required this.title,
    required this.icon,
    required this.child,
    this.path = '',
  });
  final String title;
  final IconData icon;
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (path.isNotEmpty) ...[
                const SizedBox(height: 6),
                Tooltip(
                  message: path,
                  child: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 360, child: child),
      ],
    ),
  );
}

Widget _panelMessage(String text) => Padding(
  padding: const EdgeInsets.all(16),
  child: Align(alignment: Alignment.topLeft, child: Text(text)),
);

class _ObsidianNotesPanel extends StatelessWidget {
  const _ObsidianNotesPanel({required this.viewModel});
  final ResourcesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.obsidianState;
    final Widget content;
    if (state == null) {
      content = _panelMessage('Интеграция с хранилищем отключена.');
    } else if (state.vaultPath.isEmpty) {
      content = _panelMessage(
        'Укажите путь к Obsidian Vault в настройках Obsidian.',
      );
    } else if (state.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (state.error != null) {
      content = _panelMessage(state.error!);
    } else if (state.notes.isEmpty) {
      content = _panelMessage('В Obsidian Vault не найдено .md файлов.');
    } else {
      content = HierarchyColumn(
        height: 360,
        nodes: buildVaultHierarchy(state.notes),
        emptyText: 'Хранилище пусто',
        onNodeTap: (node) {
          if (node.data case final VaultNote note) {
            _openFileNoteEditor(
              context,
              viewModel,
              note.title,
              note.absolutePath,
            );
          }
        },
      );
    }
    return _NotesPanel(
      title: 'Obsidian Vault',
      icon: Icons.account_tree_outlined,
      path: state?.vaultPath ?? '',
      child: content,
    );
  }
}

class _MarkdownNotesPanel extends StatelessWidget {
  const _MarkdownNotesPanel({required this.viewModel});
  final ResourcesViewModel viewModel;

  @override
  Widget build(BuildContext context) => MarkdownNotesPanel(
    key: ValueKey(viewModel.graphMarkdownState.vaultPath),
    state: viewModel.graphMarkdownState,
    onDelete: viewModel.canDeleteMarkdown
        ? (note) => viewModel.deleteMarkdownNote(note.absolutePath)
        : null,
    onOpen: (note) => _openFileNoteEditor(
      context,
      viewModel,
      p.basenameWithoutExtension(note.absolutePath),
      note.absolutePath,
      cachedContent: note.content,
    ),
    onCreate: viewModel.canCreateMarkdown
        ? () async {
            final value = await showMarkdownNoteDialog(context);
            if (value == null || !context.mounted) return null;
            return viewModel.createMarkdownNote(value.title, value.text);
          }
        : null,
  );
}

Future<void> _openFileNoteEditor(
  BuildContext context,
  ResourcesViewModel viewModel,
  String title,
  String path, {
  String? cachedContent,
}) async {
  String content;
  var readOnly = false;
  try {
    content = await viewModel.readNoteContent(path);
  } catch (error) {
    if (!context.mounted) return;
    if (cachedContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть заметку: $error')),
      );
      return;
    }
    content = cachedContent;
    readOnly = true;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _NoteEditorDialog(
      title: title,
      path: path,
      initialContent: content,
      viewModel: viewModel,
      readOnly: readOnly,
    ),
  );
}

/// Изолированный диалог для предотвращения утечек памяти TextEditingController
class _NoteEditorDialog extends StatefulWidget {
  final String title;
  final String path;
  final String initialContent;
  final ResourcesViewModel viewModel;
  final bool readOnly;

  const _NoteEditorDialog({
    required this.title,
    required this.path,
    required this.initialContent,
    required this.viewModel,
    this.readOnly = false,
  });

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title),
          if (widget.readOnly) ...[
            const SizedBox(height: 8),
            const Text(
              'Исходный файл недоступен. Показана сохранённая версия.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: TextField(
          key: const ValueKey('resource-note-body'),
          controller: _controller,
          enabled: !_saving,
          readOnly: widget.readOnly,
          maxLines: null,
          expands: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Содержимое заметки (.md)',
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        if (!widget.readOnly)
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() {
                      _saving = true;
                      _error = null;
                    });
                    try {
                      await widget.viewModel.updateNoteContent(
                        widget.path,
                        _controller.text,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (error) {
                      if (mounted) {
                        setState(() {
                          _saving = false;
                          _error = error.toString();
                        });
                      }
                    }
                  },
            child: const Text('Сохранить'),
          ),
      ],
    );
  }
}
