import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart' show WorkLogsApi;
import 'package:life_os/features/tasks/domain/work_log_model.dart';
import 'package:life_os/features/tasks/presentation/work_logs_view_model.dart';

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
  final TextEditingController _descController = TextEditingController();

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
    _descController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showAddDialog({WorkLog? existing}) {
    if (existing != null) {
      _descController.text = existing.description;
    } else {
      _descController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            existing == null ? 'Добавить ворклог' : 'Редактировать ворклог',
          ),
          content: TextField(
            controller: _descController,
            decoration: const InputDecoration(
              labelText: 'Описание этапа',
              hintText: 'Что было сделано...',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = _descController.text.trim();
                if (text.isNotEmpty) {
                  if (existing == null) {
                    await _viewModel.addWorkLog(description: text);
                  } else {
                    await _viewModel.updateWorkLog(
                      existing.copyWith(description: text),
                    );
                  }
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
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
                const Text(
                  'Ворклоги (Этапы выполнения)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                              _viewModel.updateWorkLog(
                                log.copyWith(status: (val == true) ? 1 : 0),
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
                            onPressed: () => _viewModel.deleteWorkLog(log.id),
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
