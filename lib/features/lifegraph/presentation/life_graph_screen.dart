import 'package:graph_ui/graph_ui.dart';
import 'package:graph_api/graph_api.dart' show GraphLinkType;
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:life_os/core/ui/hierarchy/build_note_hierarchy.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/features/lifegraph/data/android_graph_files.dart';
import 'package:graph_canvas/graph_canvas.dart' as graph;
import 'package:lifegraph_plugin/lifegraph_plugin.dart'
    show LifeGraphViewModel, GraphSaveStatus, GraphDisconnection;
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_sizes.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:notes_api/notes_api.dart';
import 'package:projects_plugin/projects_logic.dart'
    show ProjectsGraphContributor;
import 'package:tasks_plugin/tasks_logic.dart' show TasksGraphContributor;
import 'widgets/markdown_note_dialog.dart';
import 'widgets/graph_note_creation_dialog.dart';
import 'widgets/graph_note_context_menu.dart';
import 'widgets/graph_directory_picker.dart';

/// Экран графа жизни: сфера -> цель -> проект -> задача.
///
/// Граф — это проекция данных из БД. [graph.GraphView] получает список
/// view-нод стримом из [LifeGraphViewModel] и сам рисует рёбра, анимации,
/// пан/зум и драг; правка/добавление/удаление идут через [graph.GraphAction]
/// и диалоги. Позиции нод авто-сохраняются в репозитории через ViewModel.
class LifeGraphScreen extends StatefulWidget {
  final LifeGraphViewModel viewModel;

  const LifeGraphScreen({
    super.key,
    required this.viewModel,
    this.pickDirectory = pickGraphDirectory,
  });
  final Future<String?> Function() pickDirectory;

  @override
  State<LifeGraphScreen> createState() => _LifeGraphScreenState();
}

enum _SelectionMenuAction { disconnect, delete }

class _LifeGraphScreenState extends State<LifeGraphScreen> {
  final graph.GraphViewCamera _camera = graph.GraphViewCamera();
  String? _syncedSphereId;
  bool _allowPop = false;
  bool _closing = false;
  bool _exporting = false;
  bool _arranging = false;

  Future<void> _arrangeNodes() async {
    if (_arranging) return;
    setState(() => _arranging = true);
    try {
      await widget.viewModel.arrangeNodes();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _camera.fitView();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось разложить граф.')),
      );
    } finally {
      if (mounted) setState(() => _arranging = false);
    }
  }

  Future<void> _resetNodeSizes() async {
    try {
      await widget.viewModel.resetNodeSizes();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сбросить размеры узлов.')),
      );
    }
  }

  Future<void> _reloadCanvas() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Перечитать Canvas?'),
        content: const Text(
          'При конфликте правки Pulse останутся в отдельной копии, а граф загрузится из основного файла.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Перечитать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.viewModel.reloadCanvasBoard();
      if (mounted) {
        setState(() => _syncedSphereId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Canvas загружен: ${AndroidGraphFiles.displayPath(widget.viewModel.canvasBoardPath!)}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _exportCanvas() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await widget.viewModel.exportCanvas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Canvas сохранён: ${AndroidGraphFiles.displayPath(path)}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать Canvas: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // При каждом заходе в граф подтягиваем заметки из хранилища и Obsidian.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.viewModel.refreshNotes());
    });
  }

  //TODO
  @override
  void dispose() {
    super.dispose();
    unawaited(
      widget.viewModel.dispose().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _closing) return;
        _closing = true;
        try {
          if (!widget.viewModel.isClosing) await widget.viewModel.flush();
          if (!mounted) return;
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(result);
          });
        } catch (_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось сохранить граф. Повторите выход.'),
              ),
            );
        } finally {
          _closing = false;
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceDim,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: _buildContent(context)),
              Positioned(
                top: 16,
                left: 16,
                child: graph.ControlButton(
                  theme: AppGraphThemes.dark,
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Назад',
                  onTap: () => Navigator.maybePop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return StreamBuilder<List<graph.GraphNode>>(
      stream: widget.viewModel.graphStream,
      builder: (context, snapshot) {
        final nodes = snapshot.data ?? const <graph.GraphNode>[];
        final sphereId = widget.viewModel.currentSphereId;
        if (sphereId == null) {
          _syncedSphereId = null;
          return const _EmptyState();
        }

        final ready = nodes.any((n) => n.parentId == null && n.id == sphereId);
        if (ready) _maybeFit(sphereId);
        final stale = _syncedSphereId != sphereId;

        return Stack(
          children: [
            Positioned.fill(
              child: graph.GraphView(
                key: ValueKey(sphereId),
                onSelectionContextMenu: _showSelectionMenu,
                onBackgroundContextMenu: ready ? _showCreationMenu : null,
                canStartConnection: _canStartConnection,
                canConnect: _canConnect,
                onConnect: _connectNodes,
                nodes: widget.viewModel.graphStream,
                notes: widget.viewModel.notesStream,
                onAction: _onAction,
                camera: _camera,
                theme: AppGraphThemes.dark,
                layout: appGraphLayout(
                  worldSize: widget.viewModel.canvasWorldSize,
                ),
                nodeBuilder: _nodeBuilder,
                noteBuilder: (context, state) {
                  final model = widget.viewModel;
                  return graph.DefaultNoteCard(
                    state: state,
                    theme: AppGraphThemes.dark,
                    title: state.note.source == null
                        ? null
                        : p.basenameWithoutExtension(state.note.source!.path),
                    onTitleSubmitted: model.canRenameNote(state.note)
                        ? (title) async {
                            await model.renameNote(state.note.id, title);
                          }
                        : null,
                    onContextMenu: state.selected && state.selectionCount > 1
                        ? state.onSelectionContextMenu
                        : (position) => _showNoteMenu(state, position),
                  );
                },
                doubleTapCreatesRoot: false,
                longPressDeletes: false,
                notesDeletable: true,
              ),
            ),
            if (stale)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            Positioned(
              left: 18,
              bottom: 18,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatsChip(count: nodes.length),
                  if (ready && nodes.length > 1)
                    IconButton(
                      tooltip: 'Разложить по веткам',
                      icon: const Icon(Icons.account_tree_outlined),
                      onPressed: _arranging ? null : _arrangeNodes,
                    ),
                  if (ready && widget.viewModel.hasCustomNodeSizes)
                    IconButton(
                      tooltip: 'Сбросить размеры узлов',
                      icon: const Icon(Icons.aspect_ratio_rounded),
                      onPressed: _resetNodeSizes,
                    ),
                ],
              ),
            ),
            Positioned(
              right: 18,
              top: 18,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _SphereDropdown(viewModel: widget.viewModel),
                  const SizedBox(width: 10),
                  _SaveBadge(viewModel: widget.viewModel),
                  if (widget.viewModel.canExportCanvas)
                    IconButton(
                      tooltip: 'Экспорт Canvas',
                      onPressed: _exporting ? null : _exportCanvas,
                      icon: const Icon(Icons.file_upload_outlined),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Как только пришли данные для текущей сферы — вписываем граф в канвас.
  void _maybeFit(String sphereId) {
    if (_syncedSphereId == sphereId) return;
    _syncedSphereId = sphereId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _camera.fitView(animate: false);
    });
  }

  // ── Обработка намерений GraphView ─────────────────────────────────────────

  void _onAction(graph.GraphAction action) {
    switch (action) {
      case graph.CreateRootAction():
      case graph.CreateChildAction():
        // Создание всегда идёт через диалоги (double-tap и «+» отключены).
        break;
      case graph.MoveAction(:final id, :final to):
        // Live-курсор драга: только память, не сохраняем.
        widget.viewModel.moveNode(id, to.dx, to.dy);
      case graph.MoveEndAction(:final id, :final to):
        // Точка коммита — пишем позицию с debounce.
        widget.viewModel.commitMove(id, to.dx, to.dy);
      case graph.RemoveAction():
        break;
      case graph.SelectAction():
        break;
      case graph.ToggleCollapseAction():
        break;
      // Notes actions
      case graph.CreateNoteAction():
        _showCreateNoteOptions(context);
        break;
      case graph.NoteTextChangedAction(:final id, :final text):
        widget.viewModel.updateNoteText(id, text);
        break;
      case graph.MoveNoteAction(:final id, :final to):
        widget.viewModel.moveNote(id, to.dx, to.dy);
        break;
      case graph.MoveNoteEndAction(:final id, :final to):
        widget.viewModel.commitNoteMove(id, to.dx, to.dy);
        break;
      case graph.RemoveNoteAction(:final id):
        widget.viewModel.removeNote(id);
        break;
      case graph.SelectNoteAction():
        break;
      // ── Resize actions ────────────────────────────────────────────────────
      case graph.ResizeNoteAction(:final id, :final size):
        // Live-курсор ресайза: обновляем в памяти, без персиста.
        widget.viewModel.resizeNote(id, size.width, size.height);
      case graph.ResizeNoteEndAction(:final id, :final size):
        // Точка коммита — сохраняем финальный размер с debounce.
        widget.viewModel.commitNoteResize(id, size.width, size.height);
    }
  }

  // ── Кастомный рендер ноды ─────────────────────────────────────────────────

  Widget _nodeBuilder(BuildContext context, graph.NodeState state) =>
      ListenableBuilder(
        listenable: widget.viewModel.nodeEditors,
        builder: (context, _) {
          final node = widget.viewModel.nodeById(state.node.id);
          if (node == null) return const SizedBox.shrink();
          final actions = widget.viewModel.actionsFor(node.id);
          final disconnections = state.selected
              ? widget.viewModel.disconnectionsFor(node.id)
              : const <GraphDisconnection>[];
          final dialogs = GraphNodeDialogs(
            registry: widget.viewModel.nodeEditors,
            commands: widget.viewModel.commands,
          );
          return GraphNodeView(
            registry: widget.viewModel.nodePresentations,
            node: node.toData(),
            interaction: GraphNodeInteraction(
              size: state.size,
              selected: state.selected,
              hasChildren: state.hasChildren,
              collapsed: state.collapsed,
              hiddenCount: state.hiddenCount,
              accent: state.accent,
              descendantProgress: widget.viewModel.taskProgressFor(node.id),
              select: state.select,
              toggleCollapse: state.toggleCollapse,
              dragStart: state.dragStart,
              dragUpdate: state.dragUpdate,
              dragEnd: state.dragEnd,
              startConnection: state.startConnection,
              disconnect: disconnections.isEmpty
                  ? null
                  : () => _chooseDisconnection(disconnections),
              edit: dialogs.canEdit(node.kind)
                  ? () => dialogs.edit(context, actions)
                  : null,
              addChild: dialogs.canAddChild(node.kind)
                  ? () => dialogs.addChild(context, actions)
                  : null,
              remove: widget.viewModel.commands.canDelete(node.kind)
                  ? () => dialogs.remove(context, actions)
                  : null,
              createChild: actions.createChild,
              updateNode: widget.viewModel.commands.canUpdate(node.kind)
                  ? actions.updateNode
                  : null,
              deleteNode: widget.viewModel.commands.canDelete(node.kind)
                  ? actions.deleteNode
                  : null,
            ),
          );
        },
      );

  bool _canStartConnection(String id) {
    final model = widget.viewModel;
    final kind = model.nodeById(id)?.kind;
    return switch (kind) {
      ProjectsGraphContributor.kind => model.commands.canAttach(
        TasksGraphContributor.taskKind,
        kind!,
      ),
      TasksGraphContributor.taskKind || TasksGraphContributor.subTaskKind =>
        model.commands.canAttach(TasksGraphContributor.subTaskKind, kind!),
      _ => false,
    };
  }

  bool _canConnect(String source, String target) {
    final task = widget.viewModel.nodeById(target);
    if (task == null || source == target || !_canStartConnection(source)) {
      return false;
    }
    if (widget.viewModel.nodeById(source)?.kind ==
        ProjectsGraphContributor.kind) {
      return task.kind == TasksGraphContributor.taskKind &&
          task.parentId == null;
    }
    if (task.kind != TasksGraphContributor.taskKind &&
        task.kind != TasksGraphContributor.subTaskKind) {
      return false;
    }
    return _taskLinkTypes(source, target).isNotEmpty;
  }

  Set<GraphLinkType> _taskLinkTypes(String source, String target) {
    final model = widget.viewModel;
    final task = model.nodeById(target);
    if (task == null ||
        task.parentId == source ||
        task.attributes['predecessorTaskId'] == source) {
      return {};
    }

    bool wouldCycle(GraphLinkType type) {
      final visited = {target};
      String? id = source;
      while (id != null) {
        if (!visited.add(id)) return true;
        final node = model.nodeById(id);
        id = type == GraphLinkType.hierarchy
            ? node?.parentId
            : node?.attributes['predecessorTaskId'] as String?;
      }
      return false;
    }

    return {
      if (!wouldCycle(GraphLinkType.hierarchy)) GraphLinkType.hierarchy,
      if (task.attributes['predecessorTaskId'] == null &&
          !wouldCycle(GraphLinkType.sequence))
        GraphLinkType.sequence,
    };
  }

  Future<void> _connectNodes(String source, String target) async {
    final model = widget.viewModel;
    try {
      if (!_canConnect(source, target)) return;
      if (model.nodeById(source)?.kind == ProjectsGraphContributor.kind) {
        await model.connectNodes(source, target);
        return;
      }
      final active = model.connectionGuard(TasksGraphContributor.subTaskKind);
      final task = model.nodeById(target)!;
      final options = _taskLinkTypes(source, target);
      final sourceTitle = model.nodeById(source)!.title;
      final choice = await showDialog<GraphLinkType>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Как связать «${task.title}» с задачей «$sourceTitle»?'),
          children: [
            if (options.contains(GraphLinkType.hierarchy))
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.pop(context, GraphLinkType.hierarchy),
                child: Text(
                  task.kind == TasksGraphContributor.subTaskKind
                      ? 'Перенести подзадачу'
                      : 'Сделать подзадачей',
                ),
              ),
            if (options.contains(GraphLinkType.sequence))
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, GraphLinkType.sequence),
                child: const Text('Сделать следующей задачей'),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      bool available() {
        if (!mounted || !active() || !_canConnect(source, target)) return false;
        if (choice == GraphLinkType.hierarchy &&
            model.nodeById(target)?.parentId != task.parentId) {
          return false;
        }
        return _taskLinkTypes(source, target).contains(choice);
      }

      if (!available()) return;
      await model.connectNodes(
        source,
        target,
        attachmentKind: TasksGraphContributor.subTaskKind,
        linkType: choice,
        isAvailable: available,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать связь: $error')),
      );
    }
  }

  Future<void> _showCreateNoteOptions(BuildContext context) async {
    final choice = await showGraphNoteCreationDialog(
      context,
      canCreateMarkdown: widget.viewModel.canCreateMarkdown,
    );

    if (choice == null) return;
    if (!context.mounted) return;

    if (choice == GraphNoteCreation.sticker) {
      widget.viewModel.createNote();
    } else if (choice == GraphNoteCreation.obsidian) {
      _showVaultNotePicker(context, markdown: false);
    } else if (choice == GraphNoteCreation.markdownLibrary) {
      _showVaultNotePicker(context, markdown: true);
    } else if (choice == GraphNoteCreation.markdownFile) {
      final model = widget.viewModel;
      final path = await showMarkdownNoteDialog(
        context,
        titleExists: model.markdownNoteTitleExists,
        onSave: (value) =>
            model.createMarkdownNote(title: value.title, text: value.text),
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              'Заметка создана: ${AndroidGraphFiles.displayPath(path)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _convertNote(graph.NoteState state) async {
    state.endEdit();
    final title = state.text
        .split('\n')
        .first
        .trim()
        .replaceFirst(RegExp(r'^#+\s*'), '');
    final model = widget.viewModel;
    final path = await showMarkdownNoteDialog(
      context,
      initialTitle: title,
      converting: true,
      titleExists: model.markdownNoteTitleExists,
      onSave: (value) =>
          model.convertNoteToMarkdown(state.note.id, title: value.title),
    );
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Заметка сохранена: ${AndroidGraphFiles.displayPath(path)}',
          ),
        ),
      );
    }
  }

  Future<void> _showCreationMenu(Offset position, Offset canvasPoint) async {
    final model = widget.viewModel;
    if (model.currentSphereId == null || model.isClosing) return;
    final dialogs = GraphNodeDialogs(
      registry: model.nodeEditors,
      commands: model.commands,
    );
    final editors = dialogs.standaloneEditors;
    if (editors.isEmpty) return;
    final create = model.standaloneCreationAt(canvasPoint);
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final point = overlay.globalToLocal(position);
    final palette = AppGraphThemes.dark;
    final editor = await showMenu<GraphNodeEditor>(
      context: context,
      position: RelativeRect.fromSize(
        Rect.fromLTWH(point.dx, point.dy, 0, 0),
        overlay.size,
      ),
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      items: [
        for (final editor in editors)
          PopupMenuItem(
            value: editor,
            child: Text(
              editor.standaloneForm!.label,
              style: TextStyle(color: palette.text, fontSize: 13),
            ),
          ),
      ],
    );
    if (editor == null || !mounted || widget.viewModel != model) return;
    await dialogs.createStandalone(context, editor, create);
  }

  Future<void> _showSelectionMenu(
    graph.GraphSelection selection,
    Offset position,
  ) async {
    final model = widget.viewModel;
    final delete = model.deletionForSelection(
      nodeIds: selection.nodeIds,
      noteIds: selection.noteIds,
    );
    final canDelete = selection.nodeIds.every((id) {
      final node = model.nodeById(id);
      return node != null && model.commands.canDelete(node.kind);
    });
    final disconnections = selection.length == 1 && selection.nodeIds.isNotEmpty
        ? model.disconnectionsFor(selection.nodeIds.single)
        : const <GraphDisconnection>[];
    if (!canDelete && disconnections.isEmpty) return;
    final palette = AppGraphThemes.dark;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final point = overlay.globalToLocal(position);
    final action = await showMenu<_SelectionMenuAction>(
      context: context,
      position: RelativeRect.fromSize(
        Rect.fromLTWH(point.dx, point.dy, 0, 0),
        overlay.size,
      ),
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      items: [
        if (disconnections.isNotEmpty)
          const PopupMenuItem(
            value: _SelectionMenuAction.disconnect,
            child: Row(
              children: [
                Icon(Icons.link_off, size: 18),
                SizedBox(width: 10),
                Text('Отсоединить…'),
              ],
            ),
          ),
        if (canDelete)
          PopupMenuItem(
            value: _SelectionMenuAction.delete,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: palette.textDim, size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    selection.length == 1
                        ? 'Удалить объект'
                        : 'Удалить выбранные (${selection.length})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.text, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (!mounted || widget.viewModel != model) return;
    if (action == _SelectionMenuAction.disconnect) {
      await _chooseDisconnection(disconnections);
      return;
    }
    if (action != _SelectionMenuAction.delete) return;
    final hasNodes = selection.nodeIds.isNotEmpty;
    await showDialog<void>(
      context: context,
      builder: (_) => _SelectionDeleteDialog(
        count: selection.length,
        hasNodes: hasNodes,
        onDelete: delete,
      ),
    );
  }

  Future<void> _chooseDisconnection(List<GraphDisconnection> options) async {
    final model = widget.viewModel;
    final selected = await showDialog<GraphDisconnection>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Какую связь убрать?'),
        children: [
          for (final option in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${option.link.source.title} → ${option.link.target.title}',
                ),
                subtitle: Text(
                  option.link.linkType == GraphLinkType.hierarchy
                      ? 'Иерархия'
                      : 'Последовательность',
                ),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted || widget.viewModel != model) return;
    try {
      await selected.apply();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось убрать связь: $error')),
      );
    }
  }

  Future<void> _showNoteMenu(graph.NoteState state, Offset position) async {
    state.select();
    final action = await showGraphNoteContextMenu(
      context,
      position,
      accent: state.accent,
      canEdit: !state.note.isReadOnly,
      canConvert:
          state.note.source == null && widget.viewModel.canCreateMarkdown,
      canDelete: state.canDelete,
      canSaveCopy: widget.viewModel.canSaveMarkdownCopy,
      canReload:
          widget.viewModel.hasCanvasBoard &&
          widget.viewModel.saveStatus.value == GraphSaveStatus.failed,
    );
    if (!mounted || widget.viewModel.currentSphereId == null) return;
    switch (action) {
      case GraphNoteMenuAction.edit:
        state.beginEdit();
      case GraphNoteMenuAction.markdown:
        await _convertNote(state);
      case GraphNoteMenuAction.remove:
        state.remove();
      case GraphNoteMenuAction.saveCopy:
        await _saveNoteCopy(state);
      case GraphNoteMenuAction.reload:
        await _reloadCanvas();
      case null:
        break;
    }
  }

  Future<void> _saveNoteCopy(graph.NoteState state) async {
    state.endEdit();
    try {
      final directory = await widget.pickDirectory();
      if (directory == null || !mounted) return;
      final model = widget.viewModel;
      final path = await showMarkdownNoteDialog(
        context,
        initialTitle: state.text
            .split('\n')
            .first
            .trim()
            .replaceFirst(RegExp(r'^#+\s*'), ''),
        converting: true,
        savingCopy: true,
        onSave: (value) => model.saveNoteMarkdownCopy(
          state.note.id,
          directory: directory,
          title: value.title,
        ),
      );
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Копия заметки сохранена: ${AndroidGraphFiles.displayPath(path)}',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showVaultNotePicker(
    BuildContext context, {
    required bool markdown,
  }) async {
    final treeNodes = buildVaultHierarchy(
      markdown
          ? widget.viewModel.markdownLibraryNotes
          : widget.viewModel.obsidianLibraryNotes,
    );
    if (treeNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            markdown
                ? 'В выбранной папке Notes нет заметок.'
                : 'В подключённом Obsidian нет заметок.',
          ),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text(markdown ? 'Markdown-хранилище' : 'Obsidian Vault'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: HierarchyColumn(
              height: 1000,
              nodes: treeNodes,
              emptyText: 'Заметки не найдены',
              onNodeTap: (node) async {
                if (node.type != NodeType.note || node.data is! VaultNote)
                  return;
                final note = node.data as VaultNote;
                Navigator.pop(ctx);
                try {
                  await widget.viewModel.createNoteWithText(
                    title: note.title,
                    text: note.content,
                    obsidianPath: note.absolutePath,
                  );
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Заметка «' + note.title + '» добавлена на граф!',
                        ),
                      ),
                    );
                } catch (error) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Не удалось добавить заметку: ' + error.toString(),
                        ),
                      ),
                    );
                }
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }
}

// ── Вспомогательные виджеты ─────────────────────────────────────────────────

class _SphereDropdown extends StatelessWidget {
  final LifeGraphViewModel viewModel;

  const _SphereDropdown({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sphere>>(
      stream: viewModel.spheresStream,
      builder: (context, snapshot) {
        final spheres = snapshot.data ?? [];
        if (spheres.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            //color: AppColors.surfaceContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            //border: Border.all(color: AppColors.borderGlass),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButton<String>(
            value: viewModel.currentSphereId,
            dropdownColor: AppColors.surfaceContainerHigh,
            style: AppTypography.codeLabel,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: spheres
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (id) {
              if (id != null) viewModel.switchSphere(id);
            },
          ),
        );
      },
    );
  }
}

class _StatsChip extends StatelessWidget {
  final int count;

  const _StatsChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final nodes = count;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGlass),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$nodes ${_plural(nodes, 'нода', 'ноды', 'нод')} · '
        //'$links ${_plural(links, 'связь', 'связи', 'связей')} · '
        'тап — изменить, «+» — добавить',
        style: const TextStyle(
          fontSize: 10.5,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String _plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_tree_rounded,
            size: 64,
            color: Colors.white38,
          ),
          const SizedBox(height: 16),
          const Text(
            'Сфера пуста',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// Сплэш восстановления: пульсирующий мини-граф, пока грузятся сохранённые данные.
class _GraphSplash extends StatefulWidget {
  const _GraphSplash();

  @override
  State<_GraphSplash> createState() => _GraphSplashState();
}

class _GraphSplashState extends State<_GraphSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) =>
                  CustomPaint(painter: _SplashGraph(_ctrl.value)),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Восстанавливаем граф…',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashGraph extends CustomPainter {
  final double t;

  const _SplashGraph(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 26.0;
    final pts = [
      for (var i = 0; i < 3; i++)
        Offset(
          c.dx + r * math.cos(-math.pi / 2 + i * 2 * math.pi / 3),
          c.dy + r * math.sin(-math.pi / 2 + i * 2 * math.pi / 3),
        ),
    ];

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.borderGlass;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(pts[i], pts[(i + 1) % 3], line);
    }
    for (var i = 0; i < 3; i++) {
      final pulse = 0.5 + 0.5 * math.sin((t + i / 3) * 2 * math.pi);
      canvas.drawCircle(
        pts[i],
        9 + 3 * pulse,
        Paint()..color = AppColors.primary.withValues(alpha: 0.14),
      );
      canvas.drawCircle(
        pts[i],
        4.5 + 1.8 * pulse,
        Paint()..color = AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashGraph old) => true;
}

/// Бейдж автосохранения позиций: черновик / сохраняем… / сохранено.
class _SaveBadge extends StatelessWidget {
  final LifeGraphViewModel viewModel;

  const _SaveBadge({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GraphSaveStatus>(
      valueListenable: viewModel.saveStatus,
      builder: (context, status, _) {
        final color = switch (status) {
          GraphSaveStatus.failed => Colors.redAccent,
          GraphSaveStatus.draft => AppColors.onSurfaceVariant,
          GraphSaveStatus.saving => AppColors.primary,
          GraphSaveStatus.saved => const Color(0xFF4CAF50),
        };
        final label = switch (status) {
          GraphSaveStatus.failed => 'ошибка сохранения',
          GraphSaveStatus.draft => 'черновик',
          GraphSaveStatus.saving => 'сохраняем…',
          GraphSaveStatus.saved => 'сохранено',
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGlass),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectionDeleteDialog extends StatefulWidget {
  const _SelectionDeleteDialog({
    required this.count,
    required this.hasNodes,
    required this.onDelete,
  });
  final int count;
  final bool hasNodes;
  final Future<void> Function(bool keepChildren) onDelete;
  @override
  State<_SelectionDeleteDialog> createState() => _SelectionDeleteDialogState();
}

class _SelectionDeleteDialogState extends State<_SelectionDeleteDialog> {
  bool _deleting = false;
  String? _error;
  Future<void> _delete(bool keepChildren) async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.onDelete(keepChildren);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Не удалось завершить удаление: $error');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: AlertDialog(
      title: Text('Удалить объекты (${widget.count})?'),
      content: Text(
        _error ??
            (widget.hasNodes
                ? 'Выбранные сущности будут удалены из приложения. Что сделать с дочерними объектами? Стикеры удаляются только с доски, файлы .md сохраняются.'
                : 'Стикеры будут удалены с доски. Связанные файлы .md сохраняются.'),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        if (widget.hasNodes)
          TextButton(
            onPressed: _deleting ? null : () => _delete(false),
            child: const Text('Удалить всё поддерево'),
          ),
        FilledButton(
          onPressed: _deleting ? null : () => _delete(true),
          child: Text(
            widget.hasNodes ? 'Сохранить детей (скрыть)' : 'Удалить с доски',
          ),
        ),
      ],
    ),
  );
}
