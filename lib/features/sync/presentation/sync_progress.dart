import 'package:flutter/material.dart';
import 'package:sync_plugin/sync_logic.dart';

const _syncWarm = Color(0xFFFFA269);
const _syncSuccess = Color(0xFF57D995);

class SyncProgress extends StatelessWidget {
  const SyncProgress({
    super.key,
    required this.run,
    required this.busy,
    required this.notesNeedFolder,
  });
  final LocalSyncRun? run;
  final bool busy, notesNeedFolder;

  @override
  Widget build(BuildContext context) {
    final transfer = run?.transfer;
    final phase = run?.phase;
    final overall = switch (phase) {
      LocalSyncPhase.complete => 1.0,
      _ when transfer != null => transfer.done / (transfer.total + 1),
      _ when busy => null,
      _ => 0.0,
    };
    final label = switch (phase) {
      LocalSyncPhase.connecting => 'Подключение…',
      LocalSyncPhase.transferring => 'Передача изменений…',
      LocalSyncPhase.applying => 'Сохранение Canvas и заметок…',
      LocalSyncPhase.complete => 'Обмен завершён',
      LocalSyncPhase.failed => 'Обмен прерван',
      null => busy ? 'Синхронизация…' : 'Готово к обмену',
    };
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (overall != null && phase != null)
              Text(
                '${(overall * 100).floor()}%',
                style: TextStyle(color: secondary),
              ),
          ],
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: const LinearGradient(
              colors: [_syncWarm, Color(0xFFFF887C)],
            ).createShader,
            child: LinearProgressIndicator(
              value: overall,
              minHeight: 9,
              color: Colors.white,
              backgroundColor: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        if (transfer != null && transfer.total > 0)
          Text(
            '${transfer.done} из ${transfer.total} записей журнала',
            style: TextStyle(color: secondary),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final width = constraints.maxWidth;
            final columns =
                width >= 255 && MediaQuery.textScalerOf(context).scale(14) < 20
                ? 2
                : 1;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final section in SyncSection.values)
                  SizedBox(
                    width: (width - gap * (columns - 1)) / columns,
                    child: _SyncStageTile(
                      section: section,
                      run: run,
                      needsFolder:
                          section == SyncSection.notes && notesNeedFolder,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SyncStageTile extends StatelessWidget {
  const _SyncStageTile({
    required this.section,
    required this.run,
    required this.needsFolder,
  });
  final SyncSection section;
  final LocalSyncRun? run;
  final bool needsFolder;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (section) {
      SyncSection.notes => ('Заметки', Icons.description_outlined),
      SyncSection.tasks => ('Задачи', Icons.check_box_outlined),
      SyncSection.projects => ('Проекты', Icons.layers_outlined),
      SyncSection.graph => ('Граф', Icons.hub_outlined),
      SyncSection.habits => ('Привычки', Icons.event_repeat_outlined),
    };
    final total = run?.transfer?.planned[section];
    final done = run?.transfer?.transferred[section] ?? 0;
    final isFileSection =
        section == SyncSection.notes || section == SyncSection.graph;
    final writingNotes = isFileSection && run?.phase == LocalSyncPhase.applying;
    final active =
        run?.phase == LocalSyncPhase.transferring &&
        (run?.transfer?.active.contains(section) ?? false);
    final complete =
        run?.phase == LocalSyncPhase.complete ||
        (!isFileSection && total != null && total > 0 && done == total);
    final (status, statusIcon, tint) = needsFolder
        ? ('Выберите папку Notes', Icons.folder_open_outlined, _syncWarm)
        : switch ((writingNotes || active, complete, total)) {
            (true, _, _) => ('В работе', Icons.sync_rounded, _syncWarm),
            (_, _, 0) => (
              'Без изменений',
              Icons.remove_rounded,
              Colors.white54,
            ),
            (_, true, _) => (
              'Обмен завершён',
              Icons.check_circle_rounded,
              _syncSuccess,
            ),
            (_, _, final int count) when isFileSection && done == count => (
              'Ожидает записи',
              Icons.drive_file_move_outlined,
              _syncWarm,
            ),
            _ => ('Ожидает обмена', Icons.circle_outlined, Colors.white38),
          };
    return Semantics(
      value: total == null || total == 0 ? status : '$status, $done из $total',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x18FFFFFF),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0x13FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
          child: Row(
            spacing: 6,
            children: [
              Icon(icon, size: 18),
              Expanded(child: Text(label)),
              Tooltip(
                message: status,
                child: Icon(statusIcon, color: tint, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
