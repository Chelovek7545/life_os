import 'package:graph_ui/graph_ui.dart';
import 'package:graph_api/graph_api.dart'
    show GraphLinkType, GraphNodeData, graphPredecessorIds;
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path/path.dart' as p;
import 'package:life_os/core/ui/hierarchy/build_note_hierarchy.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/features/lifegraph/data/android_graph_files.dart';
import 'package:graph_canvas/graph_canvas.dart' as graph;
import 'package:lifegraph_plugin/lifegraph_plugin.dart'
    show CanvasSummary, LifeGraphViewModel, GraphSaveStatus, GraphDisconnection;
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_sizes.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:notes_api/notes_api.dart';
import 'package:projects_plugin/projects_logic.dart'
    show ProjectsGraphContributor;
import 'package:tasks_plugin/tasks_logic.dart' show TasksGraphContributor;
import 'package:tasks_api/tasks_api.dart' show wouldCreateSequenceCycle;
import 'widgets/markdown_note_dialog.dart';
import 'widgets/graph_note_creation_dialog.dart';
import 'widgets/graph_note_context_menu.dart';
import 'widgets/graph_directory_picker.dart';
import 'widgets/canvas_add_dialog.dart';
import 'widgets/canvas_visuals.dart';
import 'widgets/canvas_editor_chrome.dart';
import 'widgets/canvas_editor_panels.dart';
import 'widgets/canvas_entity_editor.dart';
import 'canvas_export.dart';

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
    this.canvasChoices = const [],
  });
  final Future<String?> Function() pickDirectory;
  final List<CanvasSummary> canvasChoices;

  @override
  State<LifeGraphScreen> createState() => _LifeGraphScreenState();
}

enum _SelectionMenuAction { disconnect, delete }

enum _BackgroundMenuAction { placeTask, placeEntity }

enum _CanvasMoreAction { focus, branch, disconnect, copyTitle }

enum _CanvasTool { pointer, hand, frame }

class _LifeGraphScreenState extends State<LifeGraphScreen> {
  final graph.GraphViewCamera _camera = graph.GraphViewCamera();
  String? _syncedSphereId;
  bool _allowPop = false;
  bool _closing = false;
  bool _exporting = false;
  bool _arranging = false;
  _CanvasTool _canvasTool = _CanvasTool.pointer;
  ({String id, GraphPresentedForm form})? _entityEditor;
  CanvasDisplayOptions _display = const CanvasDisplayOptions();
  final _filters = BehaviorSubject.seeded(const CanvasFilters());
  final _nodeScale = BehaviorSubject.seeded(1.0);

  late final _visibleNodes = Rx.combineLatest3(
    widget.viewModel.graphStream,
    _filters.stream,
    _nodeScale.stream,
    (nodes, filters, scale) => [
      for (final node in nodes)
        if (_includesNode(filters, node.id))
          if (scale == 1)
            node
          else
            graph.GraphNode(
              id: node.id,
              label: node.label,
              index: node.index,
              depth: node.depth,
              parentId: node.parentId,
              predecessorIds: node.predecessorIds,
              size: node.size * scale,
              position: node.position,
            ),
    ],
  ).shareReplay(maxSize: 1);

  late final _visibleNotes = Rx.combineLatest2(
    widget.viewModel.notesStream,
    _filters.stream,
    (notes, filters) =>
        filters.includesKind('note') ? notes : const <graph.GraphNote>[],
  ).shareReplay(maxSize: 1);

  late final _visibleCount = Rx.combineLatest2(
    _visibleNodes,
    _visibleNotes,
    (nodes, notes) => nodes.length + notes.length,
  ).distinct();

  bool _includesNode(CanvasFilters filters, String id) {
    if (!filters.active) return true;
    final node = widget.viewModel.canvasEntityData(id);
    return node != null &&
        filters.includesCard(
          node,
          filters.projects.isEmpty
              ? null
              : widget.viewModel.canvasProjectFor(id)?.id,
        );
  }

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
    unawaited(_filters.close());
    unawaited(_nodeScale.close());
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
    return PopScope<CanvasSummary>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _closing) return;
        if (result == null && _entityEditor != null) {
          setState(() => _entityEditor = null);
          return;
        }
        _closing = true;
        try {
          if (!widget.viewModel.isClosing) await widget.viewModel.flush();
          if (!mounted) return;
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop(result);
          });
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось сохранить граф. Повторите выход.'),
              ),
            );
          }
        } finally {
          _closing = false;
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceDim,
        body: SafeArea(
          child: CallbackShortcuts(
            bindings: widget.viewModel.isIndependentCanvas
                ? {
                    const SingleActivator(
                      LogicalKeyboardKey.keyF,
                      control: true,
                    ): _searchCanvas,
                    const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                        _searchCanvas,
                  }
                : const {},
            child: Stack(
              children: [
                Positioned.fill(child: _buildContent(context)),
                if (!widget.viewModel.isIndependentCanvas)
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
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return StreamBuilder<List<graph.GraphNode>>(
      stream: widget.viewModel.graphStream,
      builder: (context, snapshot) {
        final nodes = snapshot.data ?? const <graph.GraphNode>[];
        final sphereId = widget.viewModel.currentGraphId;
        if (sphereId == null) {
          _syncedSphereId = null;
          return const _EmptyState();
        }

        final independent = widget.viewModel.isIndependentCanvas;
        final ready =
            independent ||
            nodes.any((n) => n.parentId == null && n.id == sphereId);
        if (ready) _maybeFit(sphereId);
        final stale = _syncedSphereId != sphereId;
        final editor = _entityEditor;

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
                nodes: independent
                    ? _visibleNodes
                    : widget.viewModel.graphStream,
                notes: independent
                    ? _visibleNotes
                    : widget.viewModel.notesStream,
                onAction: _onAction,
                camera: _camera,
                theme: AppGraphThemes.dark,
                showControls: !independent,
                showGrid: !independent || _display.grid,
                straightEdges: independent && _display.straight,
                panTool: independent && _canvasTool == _CanvasTool.hand,
                animateTransitions:
                    !independent ||
                    (_display.animations &&
                        !MediaQuery.disableAnimationsOf(context)),
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
            if (independent) ...[
              Positioned.fill(child: _editorChrome()),
              Positioned.fill(
                child: CanvasEntityEditorPanel(
                  form: editor?.form,
                  onClose: () {
                    if (mounted &&
                        identical(_entityEditor?.form, editor?.form)) {
                      setState(() => _entityEditor = null);
                    }
                  },
                ),
              ),
            ] else ...[
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
          ],
        );
      },
    );
  }

  Widget _editorChrome() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 660;
      final short = constraints.maxHeight < 450;
      final horizontalZoom = short || (!wide && _entityEditor != null);
      const toolSize = 38.0;
      const gap = 7.0;
      final toolInset = math.min(
        14 + toolSize + gap,
        constraints.maxHeight / 4,
      );
      Widget tool(
        IconData icon,
        String title,
        VoidCallback? action, {
        bool active = false,
      }) => graph.ControlButton(
        theme: AppGraphThemes.dark,
        icon: icon,
        tooltip: title,
        onTap: action,
        active: active,
        size: toolSize,
      );
      final status = _SaveBadge(viewModel: widget.viewModel, compact: !wide);
      final actions = <Widget>[
        tool(Icons.search, 'Поиск по канвасу', _searchCanvas),
        tool(
          Icons.filter_alt_outlined,
          'Фильтры канваса',
          _configureFilters,
          active: _filters.value.active,
        ),
        tool(Icons.tune, 'Настройки отображения', _configureDisplay),
        if (wide) status,
        tool(
          Icons.ios_share_rounded,
          'Экспорт канваса',
          _exporting ? null : _chooseCanvasExport,
        ),
      ];

      final zoom = <Widget>[
        SizedBox.square(
          key: const ValueKey('canvas-zoom-indicator'),
          //dimension: toolSize,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGlass),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ValueListenableBuilder<double>(
                  valueListenable: _camera.scale,
                  builder: (context, value, _) => Text(
                    '${(value * 100).round()}%',
                    style: const TextStyle(
                      color: canvasToolInk,
                      fontSize: 12,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        tool(Icons.add, 'Увеличить масштаб', () => _camera.zoomBy(1.25)),
        tool(Icons.remove, 'Уменьшить масштаб', () => _camera.zoomBy(.8)),
        tool(Icons.fit_screen, 'Вписать канвас', () => _camera.fitView()),
      ];
      List<Widget> spaced(List<Widget> children, Axis axis) => [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0)
            axis == Axis.horizontal
                ? const SizedBox(width: gap)
                : const SizedBox(height: gap),
          children[index],
        ],
      ];
      return Stack(
        children: [
          Positioned(
            top: 14,
            left: 14,
            right: wide ? 350 : 14,
            child: Row(
              children: [
                tool(
                  Icons.arrow_back_rounded,
                  'Назад',
                  () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: gap),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: CanvasBreadcrumb(
                      title: widget.viewModel.canvasTitle!,
                      compact: !wide,
                      onPressed: widget.canvasChoices.isEmpty
                          ? null
                          : _switchCanvas,
                    ),
                  ),
                ),
                if (!wide) ...[const SizedBox(width: gap), status],
              ],
            ),
          ),
          Positioned(
            top: wide ? 14 : 14 + toolSize + gap,
            right: 14,
            child: Row(children: spaced(actions, Axis.horizontal)),
          ),
          Positioned(
            top: toolInset,
            bottom: toolInset,
            left: 14,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GlassPanel(
                key: const ValueKey('canvas-tools'),
                padding: const EdgeInsets.all(4),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      tool(
                        Icons.sticky_note_2_outlined,
                        'Заметки канваса',
                        () => _searchCanvas(notesOnly: true),
                      ),
                      tool(
                        Icons.pan_tool_outlined,
                        'Рука',
                        () => _toggleCanvasTool(_CanvasTool.hand),
                        active: _canvasTool == _CanvasTool.hand,
                      ),
                      tool(
                        Icons.select_all,
                        'Выделение рамкой',
                        () => _toggleCanvasTool(_CanvasTool.frame),
                        active: _canvasTool == _CanvasTool.frame,
                      ),
                      tool(
                        Icons.add,
                        'Добавить карточку',
                        _showAddCanvasObjects,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!short || wide)
            Positioned(
              bottom: 14,
              left: 14,
              right: wide ? null : (horizontalZoom ? 200 : 80),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: CanvasToolSurface(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(
                        80,
                        math.min(
                          wide ? 385 : 290,
                          constraints.maxWidth - (wide ? 334 : 94),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: StreamBuilder<int>(
                        stream: _visibleCount,
                        initialData:
                            widget.viewModel.graph.length +
                            widget.viewModel.notes.length,
                        builder: (_, snapshot) => Text(
                          '${canvasCardCount(snapshot.data ?? 0)}${wide ? ' · ПКМ — действия' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: canvasToolInk,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 14,
            right: 14,
            child: horizontalZoom
                ? Row(children: spaced(zoom, Axis.horizontal))
                : Column(children: spaced(zoom, Axis.vertical)),
          ),
        ],
      );
    },
  );

  void _toggleCanvasTool(_CanvasTool tool) {
    setState(
      () => _canvasTool = _canvasTool == tool ? _CanvasTool.pointer : tool,
    );
    _camera.setSelectionMode(_canvasTool == _CanvasTool.frame);
  }

  Future<void> _switchCanvas() async {
    final model = widget.viewModel;
    final next = await showDialog<CanvasSummary>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Переключить канвас'),
        children: [
          for (final board in widget.canvasChoices)
            SimpleDialogOption(
              onPressed: board.id == model.currentCanvasId
                  ? null
                  : () => Navigator.pop(context, board),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  board.id == model.currentCanvasId ? Icons.check : canvasIcon,
                ),
                title: Text(board.title),
              ),
            ),
        ],
      ),
    );
    if (next != null && mounted) await Navigator.of(context).maybePop(next);
  }

  Future<void> _searchCanvas({bool notesOnly = false}) async {
    final model = widget.viewModel;
    final cards = <CanvasSearchResult>[
      if (!notesOnly)
        for (final view in model.graph)
          if (model.nodeById(view.id) case final node?)
            (
              id: node.id,
              kind: node.kind,
              title: node.title,
              details: node.subtitle,
            ),
      for (final note in model.notes)
        (
          id: note.id,
          kind: 'note',
          details: note.text,
          title: note.source != null
              ? p.basenameWithoutExtension(note.source!.path)
              : note.text
                        .split('\n')
                        .map((line) => line.trim())
                        .where((line) => line.isNotEmpty)
                        .firstOrNull ??
                    'Пустой стикер',
        ),
    ];
    final result = await showCanvasSearch(context, cards, notesOnly: notesOnly);
    if (result == null || !mounted || model.isClosing) return;
    final note = result.kind == 'note';
    final included = note
        ? _filters.value.includesKind('note')
        : _includesNode(_filters.value, result.id);
    if (!included) {
      _applyFilters(const CanvasFilters());
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted) _camera.focusCard(result.id, note: note);
  }

  void _applyFilters(CanvasFilters filters) =>
      setState(() => _filters.add(filters));

  Future<void> _configureFilters() async {
    final model = widget.viewModel;
    final kinds = <String>{if (model.notes.isNotEmpty) 'note'};
    final projects = <String, String>{};
    final tags = <String>{};
    for (final view in model.graph) {
      final node = model.nodeById(view.id);
      if (node == null) continue;
      kinds.add(canvasTaskKind(node.kind));
      if (model.canvasProjectFor(node.id) case final project?)
        projects[project.id] = project.title;
      if (node.attributes['tagNames'] case final Iterable names)
        tags.addAll(names.whereType<String>());
    }
    final selected = await showCanvasFilters(
      context,
      initial: _filters.value,
      availableKinds: kinds,
      availableProjects: projects,
      availableTags: tags,
    );
    if (selected != null && mounted) _applyFilters(selected);
  }

  Future<void> _configureDisplay() async {
    final result = await showCanvasDisplayOptions(
      context,
      _display,
      canResetSizes: widget.viewModel.hasCustomNodeSizes,
      resetSizes: _resetNodeSizes,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (_display.nodeScale != result.nodeScale)
        _nodeScale.add(result.nodeScale);
      _display = result;
    });
  }

  Future<void> _showAddCanvasObjects() async {
    final model = widget.viewModel;
    if (model.isClosing) return;
    final point =
        _camera.viewportCenter ??
        const Offset(
          LifeGraphViewModel.worldCenter,
          LifeGraphViewModel.worldCenter,
        );
    final dialogs = GraphNodeDialogs(
      registry: model.nodeEditors,
      commands: model.commands,
    );
    final action = await showCanvasAddDialog(
      context,
      editors: dialogs.standaloneEditors,
    );
    if (!mounted || widget.viewModel != model || model.isClosing) return;
    if (action == CanvasAddAction.note) {
      await _showCreateNoteOptions(context);
    } else if (action == CanvasAddAction.existingObject) {
      await _pickCanvasEntity(point);
    } else if (action is GraphNodeEditor) {
      await _showStandaloneCanvasForm(dialogs, action, point);
    }
  }

  Future<void> _showStandaloneCanvasForm(
    GraphNodeDialogs dialogs,
    GraphNodeEditor editor,
    Offset point,
  ) {
    final create = widget.viewModel.standaloneCreationAt(point);
    return dialogs.createStandalone(context, editor, (draft, active) async {
      final id = await create(draft, active);
      if (!mounted) return id;
      if (!_includesNode(_filters.value, id))
        _applyFilters(const CanvasFilters());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _camera.revealNode(id);
      });
      return id;
    });
  }

  Future<void> _chooseCanvasExport() async {
    final format = await showDialog<CanvasExportFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Экспорт канваса'),
        children: [
          for (final format in CanvasExportFormat.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, format),
              child: Text(format.label),
            ),
        ],
      ),
    );
    if (format == null || !mounted || _exporting) return;
    if (format == CanvasExportFormat.pulse &&
        widget.viewModel.canExportCanvas) {
      await _exportCanvas();
      return;
    }
    setState(() => _exporting = true);
    try {
      final model = widget.viewModel;
      final result = await saveCanvasExport(
        format,
        model.canvasTitle!,
        await model.snapshotCanvas(),
        straight: _display.straight,
      );
      if (result != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Канвас сохранён: $result')));
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось экспортировать канвас: $error')),
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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

  Widget _nodeBuilder(
    BuildContext context,
    graph.NodeState state,
  ) => ListenableBuilder(
    listenable: widget.viewModel.nodeEditors,
    builder: (context, _) {
      final node = widget.viewModel.nodeById(state.node.id);
      if (node == null) return const SizedBox.shrink();
      final independent = widget.viewModel.isIndependentCanvas;
      final live = widget.viewModel.canEditCanvasEntity(node.id);
      final actions = widget.viewModel.actionsFor(node.id);
      final disconnections = state.selected
          ? widget.viewModel.disconnectionsFor(node.id)
          : const <GraphDisconnection>[];
      final removeFromBoard = widget.viewModel.canRemoveTaskFromBoard(node.id)
          ? widget.viewModel.removeTaskFromBoard(node.id)
          : null;
      final dialogs = GraphNodeDialogs(
        registry: widget.viewModel.nodeEditors,
        commands: widget.viewModel.commands,
      );
      final canDelete = widget.viewModel.commands.canDelete(node.kind);
      void showRemoveTaskDialog() => _showDeleteDialog(
        count: 1,
        hasNodes: true,
        delete: canDelete ? actions.deleteNode : null,
        removeFromGraph: removeFromBoard,
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
          showLabels: !independent || _display.labels,
          showDetails: !independent || _display.details,
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
          edit: live && dialogs.canEdit(node.kind)
              ? independent
                    ? () => _openEntityEditor(node.id)
                    : () => dialogs.edit(context, actions)
              : null,
          addChild: !independent && dialogs.canAddChild(node.kind)
              ? () => dialogs.addChild(context, actions)
              : null,
          remove: independent
              ? () => _changeBoardPlacement(
                  () => widget.viewModel.removeCanvasSelection([
                    node.id,
                  ], const []),
                )
              : removeFromBoard != null
              ? showRemoveTaskDialog
              : canDelete
              ? () => dialogs.remove(context, actions)
              : null,
          createChild: independent ? null : actions.createChild,
          updateNode: live && widget.viewModel.commands.canUpdate(node.kind)
              ? actions.updateNode
              : null,
          deleteNode:
              (independent || widget.viewModel.commands.canDelete(node.kind))
              ? actions.deleteNode
              : null,
        ),
      );
    },
  );

  bool _canStartConnection(String id) {
    final model = widget.viewModel;
    if (model.isIndependentCanvas) return model.nodeById(id) != null;
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
    if (widget.viewModel.isIndependentCanvas) {
      return widget.viewModel.canConnectCanvasCards(source, target);
    }
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
        graphPredecessorIds(task.attributes).contains(source)) {
      return {};
    }

    bool wouldCycleInHierarchy() {
      final visited = {target};
      String? id = source;
      while (id != null) {
        if (!visited.add(id)) return true;
        final node = model.nodeById(id);
        id = node?.parentId;
      }
      return false;
    }

    return {
      if (!wouldCycleInHierarchy()) GraphLinkType.hierarchy,
      if (!wouldCreateSequenceCycle(
        source,
        target,
        model.sequencePredecessorsFor,
      ))
        GraphLinkType.sequence,
    };
  }

  Future<void> _connectNodes(String source, String target) async {
    final model = widget.viewModel;
    try {
      if (!_canConnect(source, target)) return;
      if (model.isIndependentCanvas) {
        await model.connectCanvasCards(source, target);
        return;
      }
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
      widget.viewModel.createNote(
        position: widget.viewModel.isIndependentCanvas
            ? _camera.viewportCenter
            : null,
      );
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
    if (model.currentGraphId == null || model.isClosing) return;
    final independent = model.isIndependentCanvas;
    final dialogs = GraphNodeDialogs(
      registry: model.nodeEditors,
      commands: model.commands,
    );
    final editors = dialogs.standaloneEditors;
    final canPlace = !independent && model.tasksRemovedFromBoard.isNotEmpty;
    if (editors.isEmpty && !canPlace && !independent) return;
    final create = independent ? null : model.standaloneCreationAt(canvasPoint);
    final place = canPlace ? model.placeRemovedTaskAt(canvasPoint) : null;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final point = overlay.globalToLocal(position);
    final palette = AppGraphThemes.dark;
    final action = await showMenu<Object>(
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
        if (independent)
          const PopupMenuItem(
            value: _BackgroundMenuAction.placeEntity,
            child: Text('Добавить существующий объект'),
          ),
        if (canPlace)
          const PopupMenuItem(
            value: _BackgroundMenuAction.placeTask,
            child: Text('Добавить существующую задачу'),
          ),
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
    if (!mounted || widget.viewModel != model || model.isClosing) return;
    if (action == _BackgroundMenuAction.placeTask && place != null) {
      await _showTaskPlacement(place);
    } else if (action == _BackgroundMenuAction.placeEntity) {
      await _pickCanvasEntity(canvasPoint);
    } else if (action is GraphNodeEditor) {
      if (create == null) {
        await _showStandaloneCanvasForm(dialogs, action, canvasPoint);
      } else {
        await dialogs.createStandalone(context, action, create);
      }
    }
  }

  Future<void> _showSelectionMenu(
    graph.GraphSelection selection,
    Offset position,
  ) async {
    final model = widget.viewModel;
    final independent = model.isIndependentCanvas;
    if (independent && selection.length == 1 && selection.nodeIds.isNotEmpty) {
      await _showCanvasNodeMenu(selection.nodeIds.single, position);
      return;
    }
    final delete = independent
        ? (_) =>
              model.removeCanvasSelection(selection.nodeIds, selection.noteIds)
        : model.deletionForSelection(
            nodeIds: selection.nodeIds,
            noteIds: selection.noteIds,
          );
    final removeFromBoard =
        !independent &&
            selection.length == 1 &&
            selection.nodeIds.isNotEmpty &&
            model.canRemoveTaskFromBoard(selection.nodeIds.single)
        ? model.removeTaskFromBoard(selection.nodeIds.single)
        : null;
    final canDelete =
        independent ||
        selection.nodeIds.every((id) {
          final node = model.nodeById(id);
          return node != null && model.commands.canDelete(node.kind);
        });
    final disconnections = selection.length == 1 && selection.nodeIds.isNotEmpty
        ? model.disconnectionsFor(selection.nodeIds.single)
        : const <GraphDisconnection>[];
    if (!canDelete && disconnections.isEmpty && removeFromBoard == null) return;
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
        if (canDelete || removeFromBoard != null)
          PopupMenuItem(
            value: _SelectionMenuAction.delete,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, color: palette.textDim, size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    independent
                        ? 'Убрать с канваса'
                        : removeFromBoard != null
                        ? 'Удалить'
                        : selection.length == 1
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
    if (independent) {
      await _changeBoardPlacement(() => delete(false));
      return;
    }
    await _showDeleteDialog(
      count: selection.length,
      hasNodes: selection.nodeIds.isNotEmpty,
      delete: canDelete ? delete : null,
      removeFromGraph: removeFromBoard,
    );
  }

  Future<void> _openEntityEditor(String id) async {
    final model = widget.viewModel;
    if (_closing ||
        model.isClosing ||
        _entityEditor?.id == id ||
        !model.canEditCanvasEntity(id)) {
      return;
    }
    final dialogs = GraphNodeDialogs(
      registry: model.nodeEditors,
      commands: model.commands,
    );
    await dialogs.edit(
      context,
      model.actionsFor(id),
      present: (_, form) async =>
          setState(() => _entityEditor = (id: id, form: form)),
    );
  }

  Future<void> _showCanvasNodeMenu(String id, Offset pointer) async {
    final model = widget.viewModel;
    final node = model.nodeById(id);
    if (node == null || model.isClosing) return;
    final dialogs = GraphNodeDialogs(
      registry: model.nodeEditors,
      commands: model.commands,
    );
    final action = await showCanvasNodeActions(
      context,
      _camera.screenBoundsOfNode(id) ??
          Rect.fromCenter(center: pointer, width: 1, height: 1),
      canEdit: model.canEditCanvasEntity(id) && dialogs.canEdit(node.kind),
      canLink: model.graph.any(
        (candidate) => model.canConnectCanvasCards(id, candidate.id),
      ),
    );
    if (!mounted ||
        widget.viewModel != model ||
        model.isClosing ||
        model.nodeById(id) == null) {
      return;
    }
    switch (action) {
      case CanvasNodeAction.edit:
        await _openEntityEditor(id);
      case CanvasNodeAction.link:
        final target = await showDialog<GraphNodeData>(
          context: context,
          builder: (_) => CanvasEntityPicker(
            title: 'Связать с карточкой',
            entities: [
              for (final card in model.graph)
                if (model.canConnectCanvasCards(id, card.id))
                  if (model.nodeById(card.id) case final other?) other.toData(),
            ],
          ),
        );
        if (target != null && mounted && !model.isClosing) {
          await _changeBoardPlacement(
            () => model.connectCanvasCards(id, target.id),
          );
        }
      case CanvasNodeAction.copy:
        final view = model.graph.where((card) => card.id == id).firstOrNull;
        if (view == null) return;
        await _changeBoardPlacement(
          () => model.createNoteWithText(
            title: node.title,
            text: node.subtitle == 'Нет описания' ? '' : node.subtitle,
            position: view.position + Offset(view.size.width + 26, 24),
          ),
        );
      case CanvasNodeAction.delete:
        await _changeBoardPlacement(
          () => model.removeCanvasSelection([id], const []),
        );
      case CanvasNodeAction.more:
        await _showMoreCanvasActions(id);
      case null:
        break;
    }
  }

  Future<void> _showMoreCanvasActions(String id) async {
    final model = widget.viewModel;
    final node = model.nodeById(id);
    if (node == null) return;
    final links = model.disconnectionsFor(id);
    final hasChildren = model.graph.any((card) => card.parentId == id);
    final action = await showDialog<_CanvasMoreAction>(
      context: context,
      builder: (context) {
        Widget option(_CanvasMoreAction value, String title) =>
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Text(title),
            );
        return SimpleDialog(
          title: Text(node.title),
          children: [
            option(_CanvasMoreAction.focus, 'Показать в центре'),
            if (hasChildren)
              option(
                _CanvasMoreAction.branch,
                _camera.isCollapsed(id) ? 'Развернуть ветку' : 'Свернуть ветку',
              ),
            if (links.isNotEmpty)
              option(_CanvasMoreAction.disconnect, 'Отсоединить…'),
            option(_CanvasMoreAction.copyTitle, 'Скопировать название'),
          ],
        );
      },
    );
    if (!mounted || model.isClosing) return;
    switch (action) {
      case _CanvasMoreAction.focus:
        _camera.focusCard(id);
      case _CanvasMoreAction.branch:
        _camera.toggleBranch(id);
      case _CanvasMoreAction.disconnect:
        await _chooseDisconnection(links);
      case _CanvasMoreAction.copyTitle:
        await Clipboard.setData(ClipboardData(text: node.title));
      case null:
        break;
    }
  }

  Future<void> _showDeleteDialog({
    required int count,
    required bool hasNodes,
    required Future<void> Function(bool)? delete,
    required Future<void> Function()? removeFromGraph,
  }) => showDialog<void>(
    context: context,
    builder: (_) => _SelectionDeleteDialog(
      count: count,
      hasNodes: hasNodes,
      onDelete: delete,
      onRemoveFromGraph: removeFromGraph,
    ),
  );

  Future<void> _showTaskPlacement(Future<void> Function(String) place) async {
    final model = widget.viewModel;
    final tasks = model.tasksRemovedFromBoard;
    if (tasks.isEmpty) return;
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Добавить задачу на доску'),
        children: [
          for (final node in tasks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, node.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(node.title),
                trailing: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
    if (id == null || !mounted || widget.viewModel != model) return;
    await _changeBoardPlacement(() => place(id));
  }

  Future<void> _pickCanvasEntity([Offset? point]) async {
    final model = widget.viewModel;
    if (model.isClosing) return;
    final entity = await showDialog<GraphNodeData>(
      context: context,
      builder: (_) =>
          CanvasEntityPicker(entities: model.availableCanvasEntities),
    );
    if (!mounted || entity == null || model.isClosing) return;
    final y = model.graph.fold<double>(
      LifeGraphViewModel.worldCenter,
      (bottom, node) =>
          math.max(bottom, node.position.dy + node.size.height + 28),
    );
    await _changeBoardPlacement(() async {
      await model.addCanvasEntity(
        entity.id,
        point ?? Offset(LifeGraphViewModel.worldCenter, y),
      );
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _camera.revealNode(entity.id);
      });
    });
  }

  Future<void> _changeBoardPlacement(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось изменить размещение задачи: $error'),
        ),
      );
    }
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
    if (!mounted || widget.viewModel.currentGraphId == null) return;
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
  final bool compact;

  const _SaveBadge({required this.viewModel, this.compact = false});

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
        if (compact) {
          return Tooltip(
            message: label,
            child: CanvasToolSurface(
              child: SizedBox.square(
                dimension: 38,
                child: Icon(Icons.circle, size: 9, color: color),
              ),
            ),
          );
        }
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
    required this.onRemoveFromGraph,
  });
  final int count;
  final bool hasNodes;
  final Future<void> Function(bool keepChildren)? onDelete;
  final Future<void> Function()? onRemoveFromGraph;
  @override
  State<_SelectionDeleteDialog> createState() => _SelectionDeleteDialogState();
}

class _SelectionDeleteDialogState extends State<_SelectionDeleteDialog> {
  bool _deleting = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Не удалось завершить удаление: $error');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: AlertDialog(
      title: Text(
        widget.onRemoveFromGraph != null
            ? 'Что сделать с задачей?'
            : 'Удалить объекты (${widget.count})?',
      ),
      content: Text(
        _error ??
            (widget.onRemoveFromGraph != null
                ? '«Убрать с графа» удалит карточку с доски и сохранит задачу в приложении.'
                : widget.hasNodes
                ? 'Выбранные сущности будут удалены из приложения. Что сделать с дочерними объектами? Стикеры удаляются только с доски, файлы .md сохраняются.'
                : 'Стикеры будут удалены с доски. Связанные файлы .md сохраняются.'),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        if (widget.onRemoveFromGraph case final remove?)
          TextButton(
            onPressed: _deleting ? null : () => _run(remove),
            child: const Text('Убрать с графа'),
          ),
        if (widget.onRemoveFromGraph == null && widget.hasNodes)
          TextButton(
            onPressed: _deleting
                ? null
                : () => _run(() => widget.onDelete!(false)),
            child: const Text('Удалить всё поддерево'),
          ),
        if (widget.onDelete case final delete?)
          FilledButton(
            onPressed: _deleting ? null : () => _run(() => delete(true)),
            style: widget.onRemoveFromGraph != null
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: Text(
              widget.onRemoveFromGraph != null
                  ? 'Удалить задачу'
                  : widget.hasNodes
                  ? 'Сохранить детей (скрыть)'
                  : 'Удалить с доски',
            ),
          ),
      ],
    ),
  );
}
