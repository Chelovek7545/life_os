import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart' show WorkLogsApi, WorkLog, Wrapped;
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
  late DateTime _day = widget.existing?.date.toLocal() ?? DateTime.now();
  late DateTime? _start = widget.existing?.startedAt?.toLocal();
  late DateTime? _end = widget.existing?.endedAt?.toLocal();
  late final _controller = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    if (_saving) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if ((_start == null) != (_end == null)) {
      setState(() => _error = 'Укажите начало и конец или уберите время.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existing case final log?) {
        await widget.model.updateWorkLog(
          log.copyWith(
            description: text,
            date: _start ?? _day,
            startedAt: Wrapped(_start),
            endedAt: Wrapped(_end),
          ),
        );
      } else {
        await widget.model.addWorkLog(
          description: text,
          date: _start ?? _day,
          startedAt: _start,
          endedAt: _end,
        );
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
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            enabled: !_saving,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Описание этапа',
              hintText: 'Что было сделано...',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text('${_day.day}.${_day.month}.${_day.year}'),
            onPressed: _saving
                ? null
                : () async {
                    final day = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2140),
                    );
                    if (!mounted || day == null) return;
                    setState(() {
                      final overnight =
                          _start != null &&
                          _end != null &&
                          !DateUtils.isSameDay(_start, _end);
                      _day = day;
                      if (_start != null) {
                        _start = DateTime(
                          day.year,
                          day.month,
                          day.day,
                          _start!.hour,
                          _start!.minute,
                        );
                      }
                      if (_end != null) {
                        _end = DateTime(
                          day.year,
                          day.month,
                          day.day + (overnight ? 1 : 0),
                          _end!.hour,
                          _end!.minute,
                        );
                      }
                    });
                  },
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _saving ? null : () => _pickTime(true),
                child: Text(
                  _start == null
                      ? 'Начало'
                      : 'Начало: ${TimeOfDay.fromDateTime(_start!).format(context)}',
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => _pickTime(false),
                child: Text(
                  _end == null
                      ? 'Конец'
                      : 'Конец: ${TimeOfDay.fromDateTime(_end!).format(context)}',
                ),
              ),
              if (_start != null || _end != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _start = null;
                          _end = null;
                        }),
                  child: const Text('Без времени'),
                ),
            ],
          ),
        ],
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

  Future<void> _pickTime(bool start) async {
    final current = (start ? _start : _end)?.toLocal() ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted || time == null) return;
    setState(() {
      final value = DateTime(
        _day.year,
        _day.month,
        _day.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
      if (_start != null && _end != null) {
        _end = DateTime(
          _day.year,
          _day.month,
          _day.day,
          _end!.hour,
          _end!.minute,
        );
        if (!_end!.isAfter(_start!)) {
          _end = DateTime(
            _day.year,
            _day.month,
            _day.day + 1,
            _end!.hour,
            _end!.minute,
          );
        }
      }
    });
  }
}
