import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:sync_plugin/sync_logic.dart';

const _success = Color(0xFF57D995);

class SyncProgress extends StatelessWidget {
  const SyncProgress({
    super.key,
    required this.run,
    required this.notesNeedFolder,
  });

  final LocalSyncRun? run;
  final bool notesNeedFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phase = run?.phase;
    final transfer = run?.transfer;
    final progress = switch (phase) {
      LocalSyncPhase.complete => 1.0,
      _ when transfer != null => transfer.done / (transfer.total + 1),
      _ => null,
    };
    final (label, icon, tint) = switch (phase) {
      LocalSyncPhase.connecting => (
        'Подключение…',
        Icons.link_rounded,
        AppColors.primary,
      ),
      LocalSyncPhase.transferring => (
        'Передача изменений…',
        Icons.sync_rounded,
        AppColors.primary,
      ),
      LocalSyncPhase.applying => (
        'Сохранение Canvas и заметок…',
        Icons.save_outlined,
        AppColors.primary,
      ),
      LocalSyncPhase.complete => (
        'Обмен завершён',
        Icons.check_rounded,
        _success,
      ),
      LocalSyncPhase.failed => (
        'Обмен прерван',
        Icons.priority_high_rounded,
        theme.colorScheme.error,
      ),
      null => ('Готово к обмену', Icons.sync_alt_rounded, AppColors.primary),
    };
    final summary = switch (transfer) {
      SyncTransferProgress(total: 0) when phase == LocalSyncPhase.complete =>
        'Новых изменений нет',
      SyncTransferProgress(total: final total, done: final done)
          when total > 0 =>
        '$done из $total записей журнала',
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tint.withValues(alpha: .24)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tint.withValues(alpha: .14), AppColors.surfaceGlass],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              spacing: 14,
              children: [
                SizedBox.square(
                  dimension: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress ?? 0,
                        color: tint,
                        backgroundColor: tint.withValues(alpha: .20),
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        semanticsLabel: 'Прогресс обмена',
                      ),
                      Center(
                        child:
                            phase == LocalSyncPhase.failed || progress == null
                            ? Icon(icon, size: 25, color: tint)
                            : Padding(
                                padding: const EdgeInsets.all(8),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (phase == LocalSyncPhase.complete)
                                        Icon(icon, size: 18, color: tint),
                                      Text(
                                        '${(progress * 100).floor()}%',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: tint,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      if (summary != null)
                        Text(
                          summary,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (run != null || notesNeedFolder)
          for (final section in SyncSection.values)
            _SyncStageRow(
              section: section,
              run: run,
              needsFolder: section == SyncSection.notes && notesNeedFolder,
            ),
      ],
    );
  }
}

class _SyncStageRow extends StatelessWidget {
  const _SyncStageRow({
    required this.section,
    required this.run,
    required this.needsFolder,
  });

  final SyncSection section;
  final LocalSyncRun? run;
  final bool needsFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = switch (section) {
      SyncSection.notes => ('Заметки', Icons.description_outlined),
      SyncSection.tasks => ('Задачи', Icons.check_box_outlined),
      SyncSection.projects => ('Проекты', Icons.layers_outlined),
      SyncSection.graph => ('Граф', Icons.hub_outlined),
      SyncSection.habits => ('Привычки', Icons.event_repeat_outlined),
    };
    final phase = run?.phase;
    final total = run?.transfer?.planned[section] ?? 0;
    final done = run?.transfer?.transferred[section] ?? 0;
    final isFileSection =
        section == SyncSection.notes || section == SyncSection.graph;
    final wasPlanned = run?.transfer != null;
    final active =
        phase == LocalSyncPhase.applying && isFileSection ||
        phase == LocalSyncPhase.transferring &&
            (run?.transfer?.active.contains(section) ?? false);
    final complete =
        phase == LocalSyncPhase.complete ||
        !isFileSection && total > 0 && done == total;
    final muted = theme.colorScheme.onSurfaceVariant;
    final (status, statusIcon, tint) = switch ((
      needsFolder,
      active,
      complete,
    )) {
      (true, _, _) => (
        'Выберите папку Notes',
        Icons.folder_open_outlined,
        AppColors.primary,
      ),
      (_, true, _) => ('В работе', Icons.sync_rounded, AppColors.primary),
      _ when total == 0 && wasPlanned => (
        'Без изменений',
        Icons.remove_rounded,
        muted,
      ),
      (_, _, true) => ('Готово', Icons.check_circle_outline, _success),
      _ when phase == LocalSyncPhase.failed => (
        'Прервано',
        Icons.remove_circle_outline,
        theme.colorScheme.error,
      ),
      _ when isFileSection && total > 0 && done == total => (
        'Ожидает записи',
        Icons.drive_file_move_outlined,
        AppColors.primary,
      ),
      _ => ('Ожидает обмена', Icons.circle_outlined, muted),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? AppColors.primary.withValues(alpha: .24)
              : AppColors.borderGlass,
        ),
        color: AppColors.surfaceGlass,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          spacing: 10,
          children: [
            Icon(icon, size: 19, color: active ? AppColors.primary : muted),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(label, style: theme.textTheme.labelLarge),
                  Text(
                    total > 0 ? '$status · $done из $total' : status,
                    style: theme.textTheme.bodySmall?.copyWith(color: tint),
                  ),
                  if (total > 0)
                    LinearProgressIndicator(
                      value: done / total,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(8),
                      color: tint,
                      backgroundColor: tint.withValues(alpha: .16),
                      semanticsLabel: label,
                    ),
                ],
              ),
            ),
            Icon(statusIcon, color: tint, size: 17),
          ],
        ),
      ),
    );
  }
}
