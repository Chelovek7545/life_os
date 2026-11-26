import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:sync_plugin/sync_logic.dart';

import 'sync_address_field.dart';
import 'sync_progress.dart';
import 'sync_settings_panel.dart';

class SyncQuickAction extends StatefulWidget {
  const SyncQuickAction({
    super.key,
    required this.control,
    this.onVisibilityChanged,
  });

  final LocalSyncControl control;
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<SyncQuickAction> createState() => _SyncQuickActionState();
}

class _SyncQuickActionState extends State<SyncQuickAction> {
  Future<void> _open() async {
    final changeVisibility = widget.onVisibilityChanged;
    changeVisibility?.call(true);
    try {
      await _openPanel();
    } finally {
      changeVisibility?.call(false);
    }
  }

  Future<void> _openPanel() async {
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
  String? _addressDraft;
  String? _selectedPeerId;
  bool _runningAction = false;

  Future<void> _synchronize(String id) async {
    if (!widget.control.state.peers.any((peer) => peer.id == id)) return;
    await _runAction(
      () => widget.control.synchronize(id),
      'Не удалось завершить обмен.',
    );
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String fallback,
  ) async {
    if (!widget.isCurrent() || widget.control.state.busy || _runningAction) {
      return;
    }
    setState(() {
      _error = null;
      _runningAction = true;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted || !widget.isCurrent()) return;
      setState(() {
        _error = error is LocalSyncException
            ? error.message
            : widget.control.state.error ?? fallback;
      });
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _toggleReceive(bool enabled) => _runAction(() async {
    final control = widget.control;
    if (!enabled) {
      await control.closeListener();
      return;
    }
    var address = _addressDraft ?? syncAddressOf(control.state);
    if (address.isEmpty) {
      address = (await control.addresses()).firstOrNull ?? '';
    }
    if (!mounted || !widget.isCurrent()) return;
    if (address.isEmpty) throw LocalSyncException.missingLocalIp;
    await control.listen(address);
    _addressDraft = null;
  }, 'Не удалось изменить приём по локальной сети.');

  Future<void> _editAddress() async {
    final control = widget.control;
    if (!widget.isCurrent() || control.state.busy || _runningAction) return;
    final address = await showDialog<String>(
      context: context,
      builder: (_) => _ReceiveAddressDialog(
        control: control,
        address: _addressDraft ?? syncAddressOf(control.state),
      ),
    );
    if (address == null || !mounted || !widget.isCurrent()) return;
    if (control.state.listening) {
      await _runAction(() async {
        await control.listen(address);
        _addressDraft = null;
      }, 'Не удалось изменить IP для приёма.');
    } else {
      setState(() {
        _addressDraft = address;
        _error = null;
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
      final busy = state.busy || _runningAction;
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
                              if (available)
                                _SyncReceiveCard(
                                  listening: state.listening,
                                  enrolled: state.enrolled,
                                  address:
                                      _addressDraft ?? syncAddressOf(state),
                                  onChanged:
                                      !busy &&
                                          (state.enrolled || state.listening)
                                      ? _toggleReceive
                                      : null,
                                  onEditAddress: !busy && state.enrolled
                                      ? _editAddress
                                      : null,
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
                                if (connected)
                                  const Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: _SyncConnection(),
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
                                      enabled: !busy,
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
                                SyncProgress(
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
                                  onPressed: busy
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
final _syncCardDecoration = BoxDecoration(
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0x2AFFFFFF)),
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x507E4330), Color(0x2CFFFFFF), Color(0x12FFFFFF)],
  ),
);

class _SyncReceiveCard extends StatelessWidget {
  const _SyncReceiveCard({
    required this.listening,
    required this.enrolled,
    required this.address,
    required this.onChanged,
    required this.onEditAddress,
  });

  final bool listening, enrolled;
  final String address;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onEditAddress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _syncCardDecoration,
      child: Row(
        spacing: 10,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: listening
                  ? _syncWarm.withValues(alpha: .18)
                  : const Color(0x12FFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.wifi_tethering_rounded,
              size: 20,
              color: listening ? _syncWarm : colors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  'Приём по локальной сети',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  listening
                      ? 'Приём включён'
                      : enrolled
                      ? 'Приём выключен'
                      : 'Сначала создайте пространство',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: listening ? _syncSuccess : colors.onSurfaceVariant,
                  ),
                ),
                if (enrolled)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: onEditAddress,
                      style: TextButton.styleFrom(
                        foregroundColor: _syncWarm,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(40, 40),
                        textStyle: theme.textTheme.bodySmall,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: Text(
                        address.isEmpty ? 'Выбрать IP' : 'IP $address',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Semantics(
            label: 'Приём по локальной сети',
            child: Switch(
              value: listening,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF332016),
              activeTrackColor: _syncWarm,
              inactiveThumbColor: colors.onSurfaceVariant,
              inactiveTrackColor: const Color(0x28FFFFFF),
              trackOutlineColor: WidgetStateProperty.all(
                const Color(0x38FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveAddressDialog extends StatefulWidget {
  const _ReceiveAddressDialog({required this.control, required this.address});

  final LocalSyncControl control;
  final String address;

  @override
  State<_ReceiveAddressDialog> createState() => _ReceiveAddressDialogState();
}

class _ReceiveAddressDialogState extends State<_ReceiveAddressDialog> {
  late final _address = TextEditingController(text: widget.address);

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _apply() {
    final address = _address.text.trim();
    if (address.isNotEmpty) Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('IP для приёма'),
    content: SyncAddressField(control: widget.control, controller: _address),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      ListenableBuilder(
        listenable: _address,
        builder: (context, _) {
          return FilledButton(
            onPressed: _address.text.trim().isEmpty ? null : _apply,
            child: const Text('Применить'),
          );
        },
      ),
    ],
  );
}

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
  const _SyncConnection();

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
        children: const [
          Icon(Icons.circle, size: 8, color: _syncSuccess),
          Flexible(child: Text('Прямое соединение · P2P')),
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
      decoration: _syncCardDecoration,
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
