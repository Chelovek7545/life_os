import 'package:flutter/material.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/resources/data/obsidian_repository.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({
    super.key,
    required this.repo,
    required this.obsidianRepo,
    required this.viewModel,
  });

  final GraphNotesRepository repo;
  final ObsidianRepository obsidianRepo;
  final LifeGraphViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: EdgeInsets.all(isLandscape ? 24.0 : 16.0),
      // Оптимизация: Скролл через Slivers для виртуализации памяти
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ресурсы и Заметки',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Обновить Obsidian Vault',
                      onPressed: () {
                        obsidianRepo.scanVault(
                          SettingsService.obsidianVaultPath.value,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Сканирование Obsidian хранилища...'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Иерархия хранилища Obsidian и локальные стикеры графа.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Структура Obsidian Vault',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // --- ОБСИДИАН СЕКЦИЯ (ИЕРАРХИЯ) ---
          SliverToBoxAdapter(
            child: _ObsidianHierarchySection(
              obsidianRepo: obsidianRepo,
              viewModel: viewModel,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // --- ЛОКАЛЬНЫЕ ЗАМЕТКИ ГРАФА ---
          const SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Стикеры графа (Все сферы)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
              ],
            ),
          ),

          // Ленивая сетка карточек графа без shrinkWrap
          ListenableBuilder(
            listenable: repo,
            builder: (context, _) {
              final notes = repo.getAllNotes();
              if (notes.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Нет локальных стикеров на графах.'),
                    ),
                  ),
                );
              }

              return SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        notes[index].text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ObsidianHierarchySection extends StatelessWidget {
  const _ObsidianHierarchySection({
    required this.obsidianRepo,
    required this.viewModel,
  });

  final ObsidianRepository obsidianRepo;
  final LifeGraphViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsService.obsidianVaultPath,
      builder: (context, vaultPath, _) {
        if (vaultPath.isEmpty) {
          return Card(
            color: Colors.orange.withValues(alpha: 0.15),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Путь к Obsidian Vault не указан',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Укажите путь к папке с вашими .md файлами в настройках приложения.',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }

        return ListenableBuilder(
          listenable: obsidianRepo,
          builder: (context, _) {
            if (obsidianRepo.isLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (obsidianRepo.error != null) {
              return Card(
                color: Colors.red.withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    obsidianRepo.error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            final treeNodes = obsidianRepo.getHierarchyTree();
            if (treeNodes.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('В указанном хранилище не найдено .md файлов.'),
                ),
              );
            }

            return Card(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: HierarchyColumn(
                height: 1000,
                nodes: treeNodes,
                emptyText: 'Хранилище пусто',
                onNodeTap: (node) async {
                  if (node.type == NodeType.note && node.data is ObsidianNote) {
                    final note = node.data as ObsidianNote;
                    final content = await note.readContent();

                    if (context.mounted) {
                      _openNoteEditorDialog(context, note, content, obsidianRepo);
                    }
                  }
                },
                trailingBuilder: (node) {
                  if (node.type == NodeType.note && node.data is ObsidianNote) {
                    final note = node.data as ObsidianNote;
                    return IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.hub_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      tooltip: 'Перекинуть на граф',
                      onPressed: () async {
                        final content = await note.readContent();
                        await viewModel.createNoteWithText(
                          title: note.title,
                          text: content,
                          obsidianPath: note.absolutePath,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Заметка "${note.title}" перенесена на граф!',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        );
      },
    );
  }

  void _openNoteEditorDialog(
    BuildContext context,
    ObsidianNote note,
    String initialContent,
    ObsidianRepository repo,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _NoteEditorDialog(
        note: note,
        initialContent: initialContent,
        repo: repo,
      ),
    );
  }
}

/// Изолированный диалог для предотвращения утечек памяти TextEditingController
class _NoteEditorDialog extends StatefulWidget {
  final ObsidianNote note;
  final String initialContent;
  final ObsidianRepository repo;

  const _NoteEditorDialog({
    required this.note,
    required this.initialContent,
    required this.repo,
  });

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late final TextEditingController _controller;

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
      title: Text(widget.note.title),
      content: SizedBox(
        width: 600,
        height: 400,
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Содержимое заметки (.md)',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.repo.updateNoteContent(
              widget.note.absolutePath,
              _controller.text,
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}