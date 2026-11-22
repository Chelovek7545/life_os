import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart' show Wrapped;

class SyncSettingsPanel extends StatefulWidget {
  const SyncSettingsPanel({super.key, required this.control});
  final LocalSyncControl control;
  @override
  State<SyncSettingsPanel> createState() => _SyncSettingsPanelState();
}

class _SyncSettingsPanelState extends State<SyncSettingsPanel> {
  final _host = TextEditingController();
  final _invitation = TextEditingController();
  List<String> _addresses = const [];
  String? _error;
  late final int _generation;
  @override
  void initState() {
    super.initState();
    _generation = widget.control.generation;
    final endpoint = widget.control.state.endpoint;
    if (endpoint != null) {
      _host.text = Uri.parse(endpoint).host;
    }
    widget.control.addresses().then((addresses) {
      if (!mounted || _generation != widget.control.generation) return;
      setState(() => _addresses = addresses.toSet().toList());
      if (_addresses.length == 1 && _host.text.isEmpty) {
        _host.text = _addresses.single;
      }
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _host.dispose();
    _invitation.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted || _generation != widget.control.generation) return;
    setState(() => _error = null);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is LocalSyncException
              ? error.message
              : 'Не удалось завершить действие. Данные сохранены локально.',
        );
      }
    }
  }

  String _label(SyncRevision r) {
    if (r.deleted) return 'Удаление';
    final m = jsonDecode(r.payload!) as Map<String, dynamic>;
    return (m['title'] ?? m['name'] ?? m['description'] ?? 'Запись').toString();
  }

  Future<void> _pending() async {
    final items = await widget.control.pending();
    if (!mounted) return;
    final selected = await showDialog<LocalSyncPending>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ожидающие изменения'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Неполные группы завершатся после повторного обмена. Конфликт имени или связей можно исправить явно.',
                ),
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_label(item.revision)),
                    subtitle: Text(
                      item.revision.deleted
                          ? 'Ожидает завершения группы удаления'
                          : 'Сохранённый вариант',
                    ),
                    trailing: item.revision.deleted
                        ? null
                        : TextButton(
                            onPressed: () => Navigator.pop(dialogContext, item),
                            child: const Text('Исправить'),
                          ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) await _editPending(selected);
  }

  Future<void> _editPending(LocalSyncPending item) async {
    final revision = item.revision;
    if (revision.payload == null) return;
    final m = jsonDecode(revision.payload!) as Map<String, dynamic>;
    final live = await widget.control.entityNames(liveOnly: true);
    if (!mounted) return;
    var tagName = m['name'] as String? ?? '';
    final form = GlobalKey<FormState>();
    final cleared = <String>{};
    String? taskId;
    final fields = <String, String>{
      if (revision.entityType == 'task') ...{
        if (m['predecessorTaskId'] != null)
          'predecessorTaskId': 'Убрать предшествующую задачу',
        if (m['parentTaskId'] != null)
          'parentTaskId': 'Убрать связь с родительской задачей',
        if (m['projectId'] != null) 'projectId': 'Отвязать от проекта',
        if (m['tagIds'] is List && (m['tagIds'] as List).isNotEmpty)
          'tagIds': 'Снять теги с этой задачи',
      },
      if (revision.entityType == 'project') ...{
        if (m['parentProjectId'] != null)
          'parentProjectId': 'Убрать связь с родительским проектом',
        if (m['goalId'] != null) 'goalId': 'Отвязать от цели',
      },
      if (revision.entityType == 'goal' && m['sphereId'] != '')
        'sphereId': 'Отвязать от сферы',
    };
    String payload() {
      switch (revision.entityType) {
        case 'tag':
          return HierarchySyncCodec.tag(
            HierarchySyncCodec.decodeTag(
              revision.payload!,
            ).copyWith(name: tagName.trim()),
          );
        case 'task':
          return TaskSyncCodec.encode(
            TaskSyncCodec.decode(revision.payload!).copyWith(
              predecessorTaskId: cleared.contains('predecessorTaskId')
                  ? const Wrapped(null)
                  : null,
              parentTaskId: cleared.contains('parentTaskId')
                  ? const Wrapped(null)
                  : null,
              projectId: cleared.contains('projectId')
                  ? const Wrapped(null)
                  : null,
              tags: cleared.contains('tagIds') ? [] : null,
            ),
          );
        case 'project':
          return HierarchySyncCodec.project(
            HierarchySyncCodec.decodeProject(revision.payload!).copyWith(
              parentProejectId: cleared.contains('parentProjectId')
                  ? const Wrapped(null)
                  : null,
              goalId: cleared.contains('goalId') ? const Wrapped(null) : null,
            ),
          );
        case 'goal':
          return HierarchySyncCodec.goal(
            HierarchySyncCodec.decodeGoal(
              revision.payload!,
            ).copyWith(sphereId: ''),
          );
        case 'workLog':
          return WorkLogSyncCodec.encode(
            WorkLogSyncCodec.decode(revision.payload!).copyWith(taskId: taskId),
          );
        default:
          return revision.payload!;
      }
    }

    String? repaired;
    repaired = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final enabled =
              revision.entityType == 'tag' ||
              taskId != null ||
              cleared.isNotEmpty;
          return AlertDialog(
            title: const Text('Исправить сохранённый вариант'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Исходная версия останется в истории. Если не хватает частей группы, сначала повторите обмен.',
                      ),
                      if (revision.entityType == 'tag')
                        TextFormField(
                          initialValue: tagName,
                          onChanged: (value) => tagName = value,
                          decoration: const InputDecoration(
                            labelText: 'Новое имя тега',
                          ),
                          validator: (s) =>
                              s == null ||
                                  s.trim().isEmpty ||
                                  s.trim().length > 20
                              ? 'Введите имя от 1 до 20 символов'
                              : null,
                        ),
                      for (final field in fields.entries)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(field.value),
                          value: cleared.contains(field.key),
                          onChanged: (on) => setDialogState(() {
                            if (on == true) {
                              cleared.add(field.key);
                            } else {
                              cleared.remove(field.key);
                            }
                          }),
                        ),
                      if (revision.entityType == 'workLog')
                        DropdownButtonFormField<String>(
                          initialValue: taskId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Перенести запись времени в задачу',
                          ),
                          items: [
                            for (final e in live.entries)
                              if (SyncPayload.typeOf(e.key) == 'task')
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => taskId = value),
                        ),
                      if (!enabled &&
                          fields.isEmpty &&
                          revision.entityType != 'tag' &&
                          revision.entityType != 'workLog')
                        const Text(
                          'Для этой записи сначала нужен повторный обмен.',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: !enabled
                    ? null
                    : () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(dialogContext, payload());
                        }
                      },
                child: const Text('Сохранить исправление'),
              ),
            ],
          );
        },
      ),
    );
    if (repaired != null && mounted) {
      await _run(() => widget.control.repair(revision, repaired!, item.basis));
    }
  }

  Future<void> _conflicts() async {
    final conflicts = await widget.control.conflicts();
    final names = await widget.control.entityNames();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Конфликтующие изменения'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (conflicts.isEmpty) const Text('Конфликтов нет.'),
                for (final entry in conflicts.entries) ...[
                  Text(
                    _label(
                      entry.value.firstWhere(
                        (r) => !r.deleted,
                        orElse: () => entry.value.first,
                      ),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (entry.value.any((r) => r.deleted))
                    const Text(
                      'Сохранено удаление и варианты текста. Восстановление выполняется отдельной копией.',
                    ),
                  for (final revision in entry.value)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_label(revision)),
                            ..._details(revision, names),
                            if (revision.payload != null) ...[
                              Text(
                                (jsonDecode(revision.payload!)
                                            as Map<
                                              String,
                                              dynamic
                                            >)['description']
                                        ?.toString() ??
                                    '',
                              ),
                              Text(
                                revision.deviceId ==
                                        widget.control.state.deviceId
                                    ? 'Это устройство'
                                    : 'Источник: ${widget.control.state.peers.where((p) => p.id == revision.deviceId).map((p) => p.name).firstOrNull ?? 'Другое устройство'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            FilledButton(
                              onPressed:
                                  !revision.deleted &&
                                      entry.value.any((r) => r.deleted)
                                  ? null
                                  : () {
                                      Navigator.pop(dialogContext);
                                      _run(
                                        () => widget.control.resolve(
                                          revision,
                                          entry.value.map((r) => r.id).toSet(),
                                        ),
                                      );
                                    },
                              child: Text(
                                revision.deleted
                                    ? 'Принять удаление'
                                    : 'Выбрать эту версию',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  List<Widget> _details(SyncRevision r, Map<String, String> names) {
    if (r.payload == null) return [];
    final m = jsonDecode(r.payload!) as Map<String, dynamic>;
    const labels = {
      'status': 'Статус',
      'startsAt': 'Начало',
      'endsAt': 'Окончание',
      'dueDate': 'Срок',
      'date': 'Дата',
      'startedAt': 'Начало работы',
      'endedAt': 'Конец работы',
      'isArchived': 'В архиве',
    };
    const statuses = {
      'open': 'Открыта',
      'notStarted': 'Не начата',
      'inProgress': 'В работе',
      'done': 'Выполнена',
    };
    const relations = {
      'parentTaskId': 'Родительская задача',
      'predecessorTaskId': 'Предшествующая задача',
      'projectId': 'Проект',
      'parentProjectId': 'Родительский проект',
      'goalId': 'Цель',
      'sphereId': 'Сфера',
    };
    const types = {
      'parentTaskId': 'task',
      'predecessorTaskId': 'task',
      'projectId': 'project',
      'parentProjectId': 'project',
      'goalId': 'goal',
      'sphereId': 'sphere',
    };
    return [
      for (final entry in labels.entries)
        if (m[entry.key] != null)
          Text(
            '${entry.value}: ${m[entry.key] is bool ? (m[entry.key] as bool ? 'Да' : 'Нет') : statuses[m[entry.key]] ?? m[entry.key]}',
          ),
      for (final entry in relations.entries)
        if (m[entry.key] is String && (m[entry.key] as String).isNotEmpty)
          Text(
            '${entry.value}: ${names[SyncPayload.key(types[entry.key]!, m[entry.key] as String)] ?? 'Недоступный объект'}',
          ),
      if (m['tagIds'] is List)
        Text(
          'Теги: ${(m['tagIds'] as List).map((id) => names['tag/$id'] ?? 'Недоступный тег').join(', ')}',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<LocalSyncState>(
    stream: widget.control.states,
    initialData: widget.control.state,
    builder: (context, snapshot) {
      final s = snapshot.data ?? widget.control.state;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Обмен между доверенными устройствами в одной сети. Привычки, заметки и файлы пока не передаются.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _host,
              enabled: !s.busy,
              decoration: InputDecoration(
                labelText: 'IP этого устройства',
                helperText: 'Адрес Wi-Fi или Ethernet в локальной сети',
                suffixIcon: _addresses.length > 1
                    ? PopupMenuButton<String>(
                        enabled: !s.busy,
                        tooltip: 'Выбрать локальный IP',
                        onSelected: (address) => _host.text = address,
                        itemBuilder: (_) => [
                          for (final address in _addresses)
                            PopupMenuItem(value: address, child: Text(address)),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            if (!s.enrolled) ...[
              FilledButton(
                onPressed: s.busy
                    ? null
                    : () => _run(widget.control.createSpace),
                child: const Text('Создать пространство на этом устройстве'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _invitation,
                enabled: !s.busy,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Приглашение с другого устройства',
                ),
              ),
              TextButton(
                onPressed: s.busy
                    ? null
                    : () => _run(
                        () => widget.control.join(
                          _invitation.text.trim(),
                          _host.text.trim(),
                        ),
                      ),
                child: const Text('Присоединиться с пустой базой'),
              ),
            ] else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Приём по локальной сети'),
                subtitle: Text(
                  s.listening
                      ? 'Устройство доступно для подключённых устройств'
                      : 'Приём остановлен',
                ),
                value: s.listening,
                onChanged: s.busy
                    ? null
                    : (on) => _run(
                        () => on
                            ? widget.control.listen(_host.text.trim())
                            : widget.control.closeListener(),
                      ),
              ),
              if (s.endpoint != null)
                SelectableText(
                  s.endpoint!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ExpansionTile(
                title: const Text('Подключить приглашение в этом пространстве'),
                children: [
                  TextField(
                    controller: _invitation,
                    enabled: !s.busy,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Приглашение с другого устройства',
                    ),
                  ),
                  TextButton(
                    onPressed: s.busy
                        ? null
                        : () => _run(
                            () => widget.control.join(
                              _invitation.text.trim(),
                              _host.text.trim(),
                            ),
                          ),
                    child: const Text('Подключить устройство'),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: s.busy
                    ? null
                    : () =>
                          _run(() => widget.control.invite(_host.text.trim())),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Пригласить устройство'),
              ),
            ],
            if (s.invitation != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Одноразовое приглашение · 5 минут. Передайте его только своему устройству.',
                      ),
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: s.invitation!),
                        ),
                        icon: const Icon(Icons.copy),
                        label: const Text('Скопировать приглашение'),
                      ),
                    ],
                  ),
                ),
              ),
            if (s.awaitingApproval case final peer?)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Подключается: ${peer.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text('Подтвердите, если это ваше устройство.'),
                      SelectableText(
                        peer.fingerprint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: s.busy
                                ? null
                                : () => _run(
                                    () => widget.control.approve(peer.id),
                                  ),
                            child: const Text('Подтвердить'),
                          ),
                          TextButton(
                            onPressed: s.busy
                                ? null
                                : () => _run(
                                    () => widget.control.reject(peer.id),
                                  ),
                            child: const Text('Отклонить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            for (final peer in s.peers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      peer.endpoint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: s.busy
                              ? null
                              : () => _run(
                                  () => widget.control.synchronize(peer.id),
                                ),
                          icon: const Icon(Icons.sync),
                          label: const Text('Синхронизировать'),
                        ),
                        TextButton(
                          onPressed: s.busy
                              ? null
                              : () =>
                                    _run(() => widget.control.revoke(peer.id)),
                          child: const Text('Отозвать доступ'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (s.busy)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
            if (s.lastSync != null)
              Text(
                'Последний обмен: ${s.lastSync!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (s.conflictCount > 0)
              TextButton(
                onPressed: s.busy ? null : () => _run(_conflicts),
                child: Text('Разрешить конфликты: ${s.conflictCount}'),
              ),
            if (s.pendingCount > 0) ...[
              Text(
                'Ожидают завершения или исправления связей: ${s.pendingCount}. Повторите обмен, если соединение было прервано.',
              ),
              TextButton(
                onPressed: s.busy ? null : () => _run(_pending),
                child: const Text('Просмотреть ожидающие изменения'),
              ),
            ],
            if (s.enrolled &&
                !s.busy &&
                s.conflictCount == 0 &&
                s.pendingCount == 0)
              const Text('Нет ожидающих разрешения конфликтов.'),
            if (_error ?? s.error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      );
    },
  );
}
