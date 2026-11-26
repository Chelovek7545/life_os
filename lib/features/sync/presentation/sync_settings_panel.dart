import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart' show Wrapped;
import 'sync_address_field.dart';
import 'sync_conflict_comparison.dart';
import 'sync_pairing_qr.dart';
import 'sync_progress.dart';

class SyncSettingsPanel extends StatefulWidget {
  const SyncSettingsPanel({
    super.key,
    required this.control,
    this.onVisibilityChanged,
  });
  final LocalSyncControl control;
  final ValueChanged<bool>? onVisibilityChanged;
  @override
  State<SyncSettingsPanel> createState() => _SyncSettingsPanelState();
}

class _SyncSettingsPanelState extends State<SyncSettingsPanel> {
  final _host = TextEditingController();
  final _invitation = TextEditingController();
  String? _error;
  bool _ipMissing = false;
  late final int _generation;
  @override
  void initState() {
    super.initState();
    widget.onVisibilityChanged?.call(true);
    _generation = widget.control.generation;
    _host.text = syncAddressOf(widget.control.state);
  }

  @override
  void dispose() {
    widget.onVisibilityChanged?.call(false);
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

  void _clearIpError(String value) {
    if (_ipMissing && value.trim().isNotEmpty) {
      setState(() => _ipMissing = false);
    }
  }

  Future<void> _withHost(Future<void> Function(String) action) =>
      _run(() async {
        final host = _host.text.trim();
        if (host.isEmpty) {
          setState(() => _ipMissing = true);
          return;
        }
        await action(host);
      });

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
                    title: Text(syncRevisionTitle(item.revision)),
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
              'Обмен в одной сети передаёт задачи, проекты, сферы, цели, привычки, доски Canvas и Markdown из папки Notes.',
            ),
            if (s.run case final run?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SyncProgress(
                  run: run,
                  notesNeedFolder: s.notesNeedFolder,
                ),
              ),
            if (s.joining)
              const Text(
                'Завершаем сопряжение. Подтвердите запрос на втором устройстве.',
              )
            else if (s.confirmingDevice case final name?)
              Text('Ожидаем завершения подключения от «$name».')
            else if (s.peers.isEmpty &&
                s.awaitingApproval == null &&
                s.unverifiedPeers.isEmpty)
              const Text('Подключённых устройств пока нет.'),
            if (s.notesNeedFolder)
              const Text(
                'Выберите папку Notes в настройках графа на устройствах.',
              ),
            const SizedBox(height: 12),
            SyncAddressField(
              control: widget.control,
              controller: _host,
              enabled: !s.busy,
              onChanged: _clearIpError,
              errorText: _ipMissing
                  ? LocalSyncException.missingLocalIp.message
                  : null,
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
                    : () => _withHost(
                        (host) =>
                            widget.control.join(_invitation.text.trim(), host),
                      ),
                child: const Text('Присоединиться с пустой базой'),
              ),
            ] else ...[
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
                        : () => _withHost(
                            (host) => widget.control.join(
                              _invitation.text.trim(),
                              host,
                            ),
                          ),
                    child: const Text('Подключить устройство'),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed:
                    s.busy ||
                        s.awaitingApproval != null ||
                        s.confirmingDevice != null
                    ? null
                    : () => _withHost(widget.control.invite),
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
                      SyncInvitationQr(invitation: s.invitation!),
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
                      if (s.pairingCode case final code?) ...[
                        const Text('Сверьте код на обоих экранах'),
                        SyncPairCode(code),
                      ] else ...[
                        const Text('Подтвердите, если это ваше устройство.'),
                        SelectableText(
                          peer.fingerprint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: s.busy
                                ? null
                                : () => _run(
                                    () => widget.control.approve(peer.id),
                                  ),
                            child: Text(
                              s.pairingCode == null
                                  ? 'Подтвердить'
                                  : 'Коды совпадают',
                            ),
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
            for (final peer in [...s.unverifiedPeers, ...s.peers])
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
                        if (s.unverifiedPeers.contains(peer))
                          OutlinedButton(
                            onPressed: s.busy
                                ? null
                                : () => _run(
                                    () => widget.control.verifyPair(peer.id),
                                  ),
                            child: const Text('Проверить сопряжение'),
                          )
                        else
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
            if (s.busy && s.run == null)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
            if (s.lastSync != null)
              Text(
                'Последний обмен: ${s.lastSync!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
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
