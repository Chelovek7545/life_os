import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart' show WorkLogsApi, WorkLog;
import 'package:tasks_plugin/tasks_plugin.dart' show WorkLogsViewModel;

class WorkLogsSection extends StatefulWidget {
  const WorkLogsSection({
    super.key,
    required this.taskId,
    required this.repository,
  });

  final String taskId;
  final WorkLogsApi repository;

  @override
  State<WorkLogsSection> createState() => _WorkLogsSectionState();
}

class _WorkLogsSectionState extends State<WorkLogsSection> {
  late WorkLogsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = WorkLogsViewModel(widget.repository, widget.taskId);
  }

  @override
  void didUpdateWidget(covariant WorkLogsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId ||
        oldWidget.repository != widget.repository) {
      _viewModel.dispose();
      _viewModel = WorkLogsViewModel(widget.repository, widget.taskId);
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showAddDialog({WorkLog? existing}) {
    final model = _viewModel;
    showDialog<void>(
      context: context,
      builder: (_) => _WorkLogEditor(model: model, existing: existing),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить изменения.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Ворклоги (Этапы выполнения)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _showAddDialog(),
                  tooltip: 'Добавить ворклог',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_viewModel.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_viewModel.workLogs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Нет ворклогов для этой задачи',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _viewModel.workLogs.length,
                itemBuilder: (context, index) {
                  final log = _viewModel.workLogs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(log.description),
                      subtitle: Text(
                        'Дата: ${log.date.toLocal().toString().split('.').first}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: log.status == 1,
                            onChanged: (val) {
                              final model = _viewModel;
                              _run(
                                () => model.updateWorkLog(
                                  log.copyWith(status: (val == true) ? 1 : 0),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _showAddDialog(existing: log),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              final model = _viewModel;
                              _run(() => model.deleteWorkLog(log.id));
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _WorkLogEditor extends StatefulWidget {
  const _WorkLogEditor({required this.model, this.existing});
  final WorkLogsViewModel model;
  final WorkLog? existing;
  @override
  State<_WorkLogEditor> createState() => _WorkLogEditorState();
}

class _WorkLogEditorState extends State<_WorkLogEditor> {
  late final _controller = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    if (_saving) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existing case final log?) {
        await widget.model.updateWorkLog(log.copyWith(description: text));
      } else {
        await widget.model.addWorkLog(description: text);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Не удалось сохранить запись. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Добавить ворклог' : 'Редактировать ворклог',
    ),
    content: TextField(
      controller: _controller,
      enabled: !_saving,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Описание этапа',
        hintText: 'Что было сделано...',
        errorText: _error,
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      ElevatedButton(
        onPressed: _saving ? null : _save,
        child: const Text('Сохранить'),
      ),
    ],
  );
}
