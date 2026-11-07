import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/core/ui/resizable_panel.dart';
import 'collapsible_task_form.dart';

/// Module-owned editor hosted above all registered application screens.
class TaskEditorOverlay extends StatelessWidget {
  const TaskEditorOverlay({
    super.key,
    required this.viewModel,
    required this.workLogs,
  });
  final TasksViewModel viewModel;
  final WorkLogsApi workLogs;

  @override
  Widget build(BuildContext context) => StreamBuilder<TasksUiFlags>(
    stream: viewModel.uiFlags,
    initialData: viewModel.currentUiFlags,
    builder: (context, snapshot) {
      final visible = snapshot.data?.isFormVisible ?? false;
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      return LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Align(
              alignment: landscape
                  ? Alignment.centerRight
                  : Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(
                    begin: landscape ? const Offset(1, 0) : const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
                child: !visible
                    ? const SizedBox.shrink()
                    : SizedBox(
                        key: ValueKey(viewModel.draftTask.id),
                        width: landscape ? null : constraints.maxWidth,
                        height: landscape
                            ? constraints.maxHeight
                            : constraints.maxHeight * .8,
                        child: _EditorSurface(
                          viewModel: viewModel,
                          workLogs: workLogs,
                          task: viewModel.draftTask,
                          editing: viewModel.activeTaskWithProject != null,
                          landscape: landscape,
                          height: landscape
                              ? constraints.maxHeight
                              : constraints.maxHeight * .8,
                          maxWidth: constraints.maxWidth,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _EditorSurface extends StatefulWidget {
  const _EditorSurface({
    required this.viewModel,
    required this.workLogs,
    required this.task,
    required this.editing,
    required this.landscape,
    required this.height,
    required this.maxWidth,
  });
  final TasksViewModel viewModel;
  final WorkLogsApi workLogs;
  final Task task;
  final bool editing;
  final bool landscape;
  final double height;
  final double maxWidth;
  @override
  State<_EditorSurface> createState() => _EditorSurfaceState();
}

class _EditorSurfaceState extends State<_EditorSurface> {
  bool _saving = false;
  bool get _current =>
      widget.viewModel.isActive &&
      widget.viewModel.draftTask.id == widget.task.id;

  void _close() {
    if (!_current) return;
    widget.viewModel.hideForm();
    widget.viewModel.disableForm();
  }

  Future<void> _write(Future<void> Function() action) async {
    if (_saving || !_current) return;
    setState(() {
      _saving = true;
    });
    try {
      await action();
      if (mounted && _current) _close();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось сохранить изменения. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = Stack(
      children: [
        IgnorePointer(
          ignoring: _saving,
          child: CollapsibleTaskForm(
            task: widget.task,
            workLogs: widget.workLogs,
            resetAfterSubmit: false,
            projects: widget.viewModel.watchProjects(),
            isEditMode: widget.editing,
            forceExpanded: widget.landscape,
            height: widget.height,
            onFormVisibilityChanged: null,
            onChanged: (task) {
              if (_current) widget.viewModel.draftTask = task;
            },
            onCancel: _close,
            onSubmit: (task) => _write(
              () => widget.editing
                  ? widget.viewModel.updateTaskFromEditor(task)
                  : widget.viewModel.addTask(task),
            ),
            onDelete: (id) => _write(() => widget.viewModel.deleteTask(id)),
          ),
        ),
        if (_saving)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
    return KeyedSubtree(
      key: const ValueKey('task-editor.surface'),
      child: widget.landscape
          ? ResizablePanel(
              initialWidth: math.min(350, widget.maxWidth),
              minWidth: math.min(310, widget.maxWidth),
              maxWidth: math.min(500, widget.maxWidth),
              child: form,
            )
          : form,
    );
  }
}
