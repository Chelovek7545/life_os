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
      final (icon, tooltip, color) = switch (state) {
        LocalSyncState(busy: true) => (
          Icons.sync,
          'Идёт синхронизация',
          colors.primary,
        ),
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
        icon: state.busy
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
    if (!widget.isCurrent() || widget.control.state.busy) return;
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

  @override
  Widget build(BuildContext context) => StreamBuilder<LocalSyncState>(
    stream: widget.control.states,
    initialData: widget.control.state,
    builder: (context, snapshot) {
      final state = snapshot.data!;
      final available = widget.isCurrent();
      final localizations = MaterialLocalizations.of(context);
      final lastSync = state.lastSync?.toLocal();
      final entrance = widget.animation.drive(
        CurveTween(curve: Curves.easeOutCubic),
      );
      return Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 440),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SlideTransition(
          position: entrance.drive(
            Tween(begin: const Offset(0, -1), end: Offset.zero),
          ),
          child: FadeTransition(
            opacity: entrance,
            child: GlassPanel(
              color: AppColors.surfaceContainer.withValues(alpha: .94),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: _content(
                      context,
                      state,
                      available,
                      localizations,
                      lastSync,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _content(
    BuildContext context,
    LocalSyncState state,
    bool available,
    MaterialLocalizations localizations,
    DateTime? lastSync,
  ) => DefaultTextStyle.merge(
    style: AppTypography.bodySm,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: [
        Row(
          spacing: AppSpacing.sm,
          children: [
            const Icon(Icons.sync, color: AppColors.primary),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Локальная синхронизация',
                  style: AppTypography.headlineLgMobile.copyWith(fontSize: 20),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Закрыть',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        if (!available)
          const Text('Откройте панель заново.')
        else if (!state.enrolled)
          const Text('Подключите свои устройства в настройках.')
        else ...[
          Text(
            state.listening
                ? 'Приём по локальной сети включён'
                : 'Приём по локальной сети выключен',
          ),
          if (state.awaitingApproval case final request?)
            Text('${request.name} запрашивает подключение.'),
          if (state.peers.isEmpty)
            const Text('Подключённых устройств пока нет.'),
          for (final peer in state.peers)
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(peer.name, style: AppTypography.bodyMd),
                    FilledButton.tonalIcon(
                      onPressed: state.busy
                          ? null
                          : () => _synchronize(peer.id),
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Синхронизировать'),
                    ),
                  ],
                ),
              ),
            ),
          if (lastSync == null)
            const Text('В этом сеансе обмена ещё не было.')
          else
            Text(
              'Последний обмен: ${localizations.formatCompactDate(lastSync)}, '
              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(lastSync), alwaysUse24HourFormat: true)}',
            ),
          if (state.conflictCount > 0)
            Text('Конфликты: ${state.conflictCount}'),
          if (state.pendingCount > 0)
            Text('Ожидающие изменения: ${state.pendingCount}'),
        ],
        if (available && state.busy) ...[
          const LinearProgressIndicator(),
          const Text('Выполняется операция синхронизации…'),
        ],
        if ((_error ?? state.error) case final error? when available)
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: available ? () => Navigator.pop(context, true) : null,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Настройки'),
          ),
        ),
      ],
    ),
  );
}
