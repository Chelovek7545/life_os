import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:sync_plugin/sync_logic.dart';

import 'sync_settings_panel.dart';

class SyncQuickAction extends StatefulWidget {
  const SyncQuickAction({super.key, required this.control});

  final LocalSyncControl control;

  @override
  State<SyncQuickAction> createState() => _SyncQuickActionState();
}

class _SyncQuickActionState extends State<SyncQuickAction> {
  Future<void> _open() async {
    final control = widget.control;
    final generation = control.generation;
    bool isCurrent() =>
        mounted &&
        identical(widget.control, control) &&
        control.generation == generation;

    final openSettings = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть панель синхронизации',
      barrierColor: AppColors.surfaceDim.withValues(alpha: .65),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      transitionBuilder: (_, _, _, child) => child,
      pageBuilder: (_, animation, _) => SafeArea(
        child: _QuickSyncDialog(
          control: control,
          isCurrent: isCurrent,
          animation: animation,
        ),
      ),
    );
    if (openSettings != true || !isCurrent() || !mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Локальная синхронизация')),
          body: SafeArea(
            child: SingleChildScrollView(
              child: SyncSettingsPanel(control: control),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<LocalSyncState>(
    stream: widget.control.states,
    initialData: widget.control.state,
    builder: (context, snapshot) {
      final state = snapshot.data!;
      final colors = Theme.of(context).colorScheme;
      final exchanging = switch (state.run?.phase) {
        LocalSyncPhase.connecting ||
        LocalSyncPhase.transferring ||
        LocalSyncPhase.applying => true,
        _ => false,
      };
      final (icon, tooltip, color) = switch (state) {
        LocalSyncState(joining: true) ||
        LocalSyncState(confirmingDevice: final String _) => (
          Icons.person_add_alt_1,
          'Идёт сопряжение устройств',
          colors.primary,
        ),
        _ when exchanging => (Icons.sync, 'Идёт синхронизация', colors.primary),
        LocalSyncState(error: final String _) => (
          Icons.sync_problem,
          'Ошибка синхронизации',
          colors.error,
        ),
        LocalSyncState(awaitingApproval: final LocalSyncPeer _) => (
          Icons.person_add_alt_1,
          'Запрос на подключение устройства',
          colors.primary,
        ),
        _ when state.conflictCount > 0 || state.pendingCount > 0 => (
          Icons.sync_problem,
          'Есть изменения, требующие внимания',
          colors.error,
        ),
        _ => (Icons.sync, 'Локальная синхронизация', AppColors.primary),
      };
      return IconButton(
        tooltip: tooltip,
        color: color,
        onPressed: _open,
        icon: exchanging
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
      );
    },
  );
}

class _QuickSyncDialog extends StatefulWidget {
  const _QuickSyncDialog({
    required this.control,
    required this.isCurrent,
    required this.animation,
  });

  final LocalSyncControl control;
  final bool Function() isCurrent;
  final Animation<double> animation;

  @override
  State<_QuickSyncDialog> createState() => _QuickSyncDialogState();
}

class _QuickSyncDialogState extends State<_QuickSyncDialog> {
  String? _error;

  Future<void> _synchronize(String id) async {
    final state = widget.control.state;
    if (!widget.isCurrent() ||
        state.busy ||
        !state.peers.any((peer) => peer.id == id)) {
      return;
    }
    setState(() => _error = null);
    try {
      await widget.control.synchronize(id);
    } catch (error) {
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        _error = error is LocalSyncException
            ? error.message
            : widget.control.state.error ?? 'Не удалось завершить обмен.';
      });
    }
  }

  String? _selectedPeerId;

  @override
  Widget build(BuildContext context) => StreamBuilder<LocalSyncState>(
    stream: widget.control.states,
    initialData: widget.control.state,
    builder: (context, snapshot) {
      final state = snapshot.data!;
      final available = widget.isCurrent();
      final run = state.run;
      final selectedId = state.busy
          ? run?.peerId ?? _selectedPeerId
          : _selectedPeerId ?? run?.peerId;
      final peer =
          state.peers.where((peer) => peer.id == selectedId).firstOrNull ??
          state.peers.firstOrNull;
      final currentRun = run?.peerId == peer?.id ? run : null;
      final connected =
          currentRun?.phase == LocalSyncPhase.transferring ||
          currentRun?.phase == LocalSyncPhase.applying;
      final error = _error ?? state.error;
      final colors = Theme.of(context).colorScheme;
      final localizations = MaterialLocalizations.of(context);
      final lastSync = state.lastSync?.toLocal();
      final entrance = widget.animation.drive(
        CurveTween(curve: Curves.easeOutCubic),
      );
      return Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 680),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SlideTransition(
          position: entrance.drive(
            Tween(begin: const Offset(0, -.25), end: Offset.zero),
          ),
          child: FadeTransition(
            opacity: entrance,
            child: GlassPanel(
              borderRadius: 30,
              blurLevel: 20,
              borderColor: const Color(0xFF64545D),
              color: const Color(0xCF211E25),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(29),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomLeft,
                      radius: 1.25,
                      colors: [
                        Color(0x80552C22),
                        Color(0x30141419),
                        Color(0x22141419),
                      ],
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 480;
                      return SingleChildScrollView(
                        padding: EdgeInsets.all(compact ? 14 : 26),
                        child: DefaultTextStyle.merge(
                          style: AppTypography.bodySm.copyWith(
                            color: colors.onSurface,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            spacing: compact ? 14 : 22,
                            children: [
                              Row(
                                spacing: compact ? 8 : 14,
                                children: [
                                  if (!compact) const _SyncEmblem(size: 50),
                                  Expanded(
                                    child: Semantics(
                                      header: true,
                                      child: Text(
                                        'Синхронизация',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontSize: compact ? 19 : 28,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                  _headerButton(
                                    tooltip: 'Настройки',
                                    icon: Icons.settings_outlined,
                                    onPressed: available
                                        ? () => Navigator.pop(context, true)
                                        : null,
                                  ),
                                  _headerButton(
                                    tooltip: 'Закрыть',
                                    icon: Icons.close_rounded,
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                              if (!available)
                                const Text('Откройте панель заново.')
                              else if (peer == null) ...[
                                Text(switch (state) {
                                  LocalSyncState(
                                    awaitingApproval: final request?,
                                  ) =>
                                    '${request.name} запрашивает подключение.',
                                  LocalSyncState(
                                    confirmingDevice: final name?,
                                  ) =>
                                    'Ожидаем завершения подключения от «$name».',
                                  LocalSyncState(joining: true) =>
                                    'Завершаем сопряжение…',
                                  _ when state.unverifiedPeers.isNotEmpty =>
                                    'Проверьте сохранённое сопряжение в настройках.',
                                  _ => 'Подключённых устройств пока нет.',
                                }),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    icon: const Icon(Icons.settings_outlined),
                                    label: Text(switch (state) {
                                      LocalSyncState(
                                        awaitingApproval: final LocalSyncPeer _,
                                      ) =>
                                        'Подтвердить подключение',
                                      LocalSyncState(joining: true) ||
                                      LocalSyncState(
                                        confirmingDevice: final String _,
                                      ) => 'Открыть настройки',
                                      _ when state.unverifiedPeers.isNotEmpty =>
                                        'Открыть настройки',
                                      _ => 'Подключить устройство',
                                    }),
                                  ),
                                ),
                              ] else ...[
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: _SyncConnection(
                                    listening: state.listening,
                                    connected: connected,
                                  ),
                                ),
                                Row(
                                  spacing: compact ? 6 : 12,
                                  children: [
                                    Expanded(
                                      child: _SyncDeviceCard(
                                        name: state.deviceName,
                                        subtitle: 'Это устройство',
                                        icon: switch (Theme.of(
                                          context,
                                        ).platform) {
                                          TargetPlatform.android ||
                                          TargetPlatform.iOS =>
                                            Icons.phone_android_outlined,
                                          _ => Icons.laptop_outlined,
                                        },
                                        compact: compact,
                                      ),
                                    ),
                                    _SyncBridge(
                                      compact: compact,
                                      active: connected,
                                    ),
                                    Expanded(
                                      child: _SyncDeviceCard(
                                        name: peer.name,
                                        subtitle: connected
                                            ? 'На связи'
                                            : 'Связь не проверена',
                                        icon: Icons.devices_other_outlined,
                                        compact: compact,
                                        active: connected,
                                      ),
                                    ),
                                  ],
                                ),
                                if (state.peers.length > 1)
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: PopupMenuButton<String>(
                                      enabled: !state.busy,
                                      initialValue: peer.id,
                                      tooltip: 'Выбрать устройство',
                                      onSelected: (id) => setState(() {
                                        _selectedPeerId = id;
                                        _error = null;
                                      }),
                                      itemBuilder: (_) => [
                                        for (final item in state.peers)
                                          PopupMenuItem(
                                            value: item.id,
                                            child: Text(item.name),
                                          ),
                                      ],
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text('Выбрать устройство'),
                                      ),
                                    ),
                                  ),
                                _SyncProgress(
                                  run: currentRun,
                                  busy: state.busy,
                                  notesNeedFolder: state.notesNeedFolder,
                                ),
                                if (state.notesNeedFolder)
                                  const Text(
                                    'Выберите папку Notes в настройках графа на обоих устройствах для отображения заметок.',
                                  ),
                                if (state.awaitingApproval case final request?)
                                  Text(
                                    '${request.name} запрашивает подключение.',
                                  ),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      lastSync == null
                                          ? 'В этом сеансе обмена ещё не было.'
                                          : 'Последний обмен: ${localizations.formatCompactDate(lastSync)}, '
                                                '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(lastSync), alwaysUse24HourFormat: true)}',
                                    ),
                                    if (state.conflictCount > 0)
                                      Text('Конфликты: ${state.conflictCount}'),
                                    if (state.pendingCount > 0)
                                      Text(
                                        'Ожидающие изменения: ${state.pendingCount}',
                                      ),
                                  ],
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: state.busy
                                      ? null
                                      : () => _synchronize(peer.id),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _syncWarm,
                                    foregroundColor: const Color(0xFF2C1A14),
                                  ),
                                  icon: const Icon(Icons.sync_rounded),
                                  label: const Text('Синхронизировать'),
                                ),
                              ],
                              if (available && error != null)
                                Text(
                                  error,
                                  style: TextStyle(color: colors.error),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _headerButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(backgroundColor: const Color(0x18FFFFFF)),
    icon: Icon(icon),
  );
}

const _syncWarm = Color(0xFFFFA269);
const _syncSuccess = Color(0xFF57D995);

class _SyncEmblem extends StatelessWidget {
  const _SyncEmblem({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .27),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA75838), Color(0xFF4A3030), Color(0xFF864838)],
      ),
      border: Border.all(color: _syncWarm.withValues(alpha: .6)),
      boxShadow: [
        BoxShadow(
          color: _syncWarm.withValues(alpha: .28),
          blurRadius: size * .55,
        ),
      ],
    ),
    child: Icon(
      Icons.sync_rounded,
      size: size * .61,
      color: const Color(0xFFFFEEE6),
    ),
  );
}

class _SyncConnection extends StatelessWidget {
  const _SyncConnection({required this.listening, required this.connected});
  final bool listening;
  final bool connected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x18FFFFFF),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: connected ? _syncSuccess : Colors.white38,
          ),
          Flexible(
            child: Text(
              connected
                  ? 'Прямое соединение · P2P'
                  : listening
                  ? 'Приём включён · LAN'
                  : 'Приём выключен · LAN',
            ),
          ),
        ],
      ),
    ),
  );
}

class _SyncBridge extends StatelessWidget {
  const _SyncBridge({required this.compact, required this.active});
  final bool compact, active;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 40 : 88,
    height: compact ? 44 : 68,
    child: CustomPaint(
      painter: compact ? null : _SyncLinkPainter(active),
      child: Center(child: _SyncEmblem(size: compact ? 34 : 48)),
    ),
  );
}

class _SyncLinkPainter extends CustomPainter {
  const _SyncLinkPainter(this.active);
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    final path = Path()
      ..moveTo(0, middle)
      ..cubicTo(15, middle - 14, 15, middle + 14, size.width / 2, middle)
      ..cubicTo(
        size.width - 15,
        middle - 14,
        size.width - 15,
        middle + 14,
        size.width,
        middle,
      );
    final paint = Paint()
      ..color = _syncWarm.withValues(alpha: active ? .85 : .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      paint
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_SyncLinkPainter oldDelegate) =>
      oldDelegate.active != active;
}

class _SyncDeviceCard extends StatelessWidget {
  const _SyncDeviceCard({
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.compact,
    this.active = false,
  });
  final String name, subtitle;
  final IconData icon;
  final bool compact, active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 9 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x2AFFFFFF)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x507E4330), Color(0x2CFFFFFF), Color(0x12FFFFFF)],
        ),
      ),
      child: Row(
        spacing: 10,
        children: [
          if (!compact) Icon(icon, size: 30, color: colors.onSurfaceVariant),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                if (compact)
                  Icon(icon, size: 18, color: colors.onSurfaceVariant),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: active ? _syncSuccess : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncProgress extends StatelessWidget {
  const _SyncProgress({
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
