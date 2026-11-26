import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:sync_plugin/sync_logic.dart';

import 'sync_address_field.dart';
import 'sync_conflicts_panel.dart';
import 'sync_pairing_qr.dart';
import 'sync_progress.dart';
import 'sync_radar.dart';
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
  bool _addingDevice = false;
  bool _showQr = false;
  bool _showConflicts = false;
  late final int _generation;

  @override
  void initState() {
    super.initState();
    _generation = widget.control.generation;
    unawaited(
      widget.control.setDiscoveryVisible(true).catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    if (widget.control.generation == _generation) {
      unawaited(
        widget.control.setDiscoveryVisible(false).catchError((Object _) {}),
      );
    }
    super.dispose();
  }

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
    final address = await _resolveLocalAddress();
    if (!mounted || !widget.isCurrent()) return;
    await control.listen(address);
    _addressDraft = null;
  }, 'Не удалось изменить приём по локальной сети.');

  Future<String> _resolveLocalAddress() async {
    final control = widget.control;
    final current = _addressDraft ?? syncAddressOf(control.state);
    if (current.isNotEmpty) return current;
    final address = (await control.addresses()).firstOrNull;
    if (address == null || address.isEmpty) {
      throw LocalSyncException.missingLocalIp;
    }
    return address;
  }

  Future<void> _pairNearby(String id) => _runAction(() async {
    final address = await _resolveLocalAddress();
    if (mounted && widget.isCurrent()) {
      await widget.control.joinNearby(id, address);
      if (mounted && widget.isCurrent()) setState(() => _addingDevice = false);
    }
  }, 'Не удалось запросить сопряжение.');

  Future<void> _showInvitation() => _runAction(() async {
    final address = await _resolveLocalAddress();
    if (!mounted || !widget.isCurrent()) return;
    await widget.control.invite(address);
    if (mounted && widget.isCurrent()) setState(() => _showQr = true);
  }, 'Не удалось создать QR сопряжения.');

  Future<void> _readInvitation() => _runAction(() async {
    final invitation = await readSyncInvitationQr(context);
    if (invitation == null || !mounted || !widget.isCurrent()) return;
    final address = await _resolveLocalAddress();
    if (mounted && widget.isCurrent()) {
      await widget.control.join(invitation, address);
      if (mounted && widget.isCurrent()) setState(() => _addingDevice = false);
    }
  }, 'Не удалось подключиться по QR.');

  Future<void> _decideNearby(bool accepted) async {
    if (!widget.isCurrent() ||
        widget.control.state.pairReview?.canConfirm != true) {
      return;
    }
    try {
      await widget.control.confirmNearby(accepted);
    } on LocalSyncException catch (error) {
      if (mounted && widget.isCurrent()) setState(() => _error = error.message);
    }
  }

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
      if (state.busy &&
          run != null &&
          run.phase != LocalSyncPhase.complete &&
          run.phase != LocalSyncPhase.failed) {
        _selectedPeerId = run.peerId;
      }
      final selectedId = _selectedPeerId ?? run?.peerId;
      final peer =
          state.peers.where((item) => item.id == selectedId).firstOrNull ??
          state.peers.firstOrNull;
      final currentRun = run?.peerId == peer?.id ? run : null;
      final connected =
          currentRun?.phase == LocalSyncPhase.transferring ||
          currentRun?.phase == LocalSyncPhase.applying;
      final error = _error ?? state.error;
      final theme = Theme.of(context);
      final localizations = MaterialLocalizations.of(context);
      final lastSync = state.lastSync?.toLocal();
      final entrance = widget.animation.drive(
        CurveTween(curve: Curves.easeOutCubic),
      );

      void openSettings() => Navigator.pop(context, true);

      final conflictAction = state.conflictCount == 0
          ? null
          : ActionChip(
              avatar: const Icon(Icons.merge_type_rounded, size: 16),
              label: Text('Конфликты: ${state.conflictCount}'),
              onPressed: busy
                  ? null
                  : () => setState(() => _showConflicts = true),
            );
      final network = _SyncReceiveCard(
        listening: state.listening,
        enrolled: state.enrolled,
        address: _addressDraft ?? syncAddressOf(state),
        onChanged: !busy && (state.enrolled || state.listening)
            ? _toggleReceive
            : null,
        onEditAddress: !busy && state.enrolled ? _editAddress : null,
      );
      final issue = error == null
          ? null
          : _SyncNotice(
              message: error,
              icon: Icons.error_outline_rounded,
              tint: theme.colorScheme.error,
            );
      final request = state.awaitingApproval;
      final pairedIds = {
        ...state.peers.map((peer) => peer.id),
        ...state.unverifiedPeers.map((peer) => peer.id),
      };
      final nearbyCandidates = state.nearby
          .where((peer) => !pairedIds.contains(peer.id))
          .toList();
      final needsPairingPanel =
          peer == null ||
          _addingDevice ||
          request != null ||
          state.pairReview != null ||
          state.confirmingDevice != null ||
          nearbyCandidates.isNotEmpty;
      final setup = needsPairingPanel
          ? _SyncSetupPrompt(
              state: state,
              nearbyCandidates: nearbyCandidates,
              openSettings: openSettings,
              selectNearby: busy ? null : _pairNearby,
              showInvitation: !busy && state.enrolled ? _showInvitation : null,
              readInvitation: busy ? null : _readInvitation,
              showQr: _showQr,
              hideQr: () => setState(() => _showQr = false),
              decide: state.pairReview?.canConfirm == true
                  ? _decideNearby
                  : request == null || busy
                  ? null
                  : (accepted) => _runAction(
                      () => accepted
                          ? widget.control.approve(request.id)
                          : widget.control.reject(request.id),
                      'Не удалось подтвердить сопряжение.',
                    ),
            )
          : TextButton.icon(
              onPressed: busy
                  ? null
                  : () => setState(() => _addingDevice = true),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Добавить устройство'),
            );
      final Widget? devices = peer == null
          ? null
          : _SyncDevices(
              state: state,
              selected: peer.id,
              connected: connected,
              onSelect: busy || state.peers.length < 2
                  ? null
                  : (id) => setState(() {
                      _selectedPeerId = id;
                      _error = null;
                    }),
            );
      final Widget? overview = peer == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                ?issue,
                SyncProgress(
                  run: currentRun,
                  notesNeedFolder: state.notesNeedFolder,
                ),
                if (state.notesNeedFolder)
                  const _SyncNotice(
                    message:
                        'Выберите папку Notes в настройках графа на обоих устройствах для отображения заметок.',
                    icon: Icons.folder_open_outlined,
                    tint: AppColors.primary,
                  ),
                if (state.conflictCount > 0 || state.pendingCount > 0)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ?conflictAction,
                      if (state.pendingCount > 0)
                        ActionChip(
                          avatar: const Icon(Icons.pending_outlined, size: 16),
                          label: Text(
                            'Ожидающие изменения: ${state.pendingCount}',
                          ),
                          onPressed: busy ? null : openSettings,
                        ),
                    ],
                  ),
                if (lastSync != null || currentRun == null)
                  Text(
                    lastSync == null
                        ? 'В этом сеансе обмена ещё не было.'
                        : 'Последний обмен: ${localizations.formatCompactDate(lastSync)}, '
                              '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(lastSync), alwaysUse24HourFormat: true)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            );
      final actionColor = busy
          ? theme.colorScheme.onSurfaceVariant
          : const Color(0xFF2C1A14);
      final Widget? action = !available || peer == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: busy ? null : () => _synchronize(peer.id),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: const Color(0xFF2C1A14),
                disabledBackgroundColor: AppColors.surfaceGlass,
                disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                minimumSize: const Size(0, 48),
              ),
              icon: Icon(
                currentRun?.phase == LocalSyncPhase.failed
                    ? Icons.refresh_rounded
                    : Icons.sync_rounded,
                color: actionColor,
              ),
              label: Text(
                currentRun?.phase == LocalSyncPhase.failed
                    ? 'Повторить обмен'
                    : 'Синхронизировать',
                style: theme.textTheme.labelLarge?.copyWith(color: actionColor),
              ),
            );

      return Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        constraints: _showConflicts
            ? const BoxConstraints(maxWidth: 1320, maxHeight: 820)
            : const BoxConstraints(maxWidth: 752),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SlideTransition(
          position: entrance.drive(
            Tween(begin: const Offset(0, -.25), end: Offset.zero),
          ),
          child: FadeTransition(
            opacity: entrance,
            child: GlassPanel(
              borderRadius: 28,
              blurLevel: 20,
              borderColor: AppColors.borderGlass,
              color: _showConflicts
                  ? const Color(0xF41A1A20)
                  : const Color(0xE7201A1D),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.25,
                      colors: _showConflicts
                          ? const [Color(0x4A494653), Color(0x17141419)]
                          : const [Color(0x46593329), Color(0x17141419)],
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (available && _showConflicts) {
                        return SyncConflictsPanel(
                          control: widget.control,
                          isCurrent: widget.isCurrent,
                          onBack: () => setState(() => _showConflicts = false),
                          onClose: () => Navigator.pop(context),
                        );
                      }
                      final compact = constraints.maxWidth < 480;
                      final wide = constraints.maxWidth >= 600;
                      final inset = compact ? 14.0 : 20.0;
                      final header = Padding(
                        padding: EdgeInsets.fromLTRB(inset, 12, inset, 8),
                        child: Row(
                          spacing: compact ? 6 : 12,
                          children: [
                            if (!compact) const _SyncEmblem(size: 42),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  'Синхронизация',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: compact ? 19 : 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            _headerButton(
                              tooltip: 'Настройки',
                              icon: Icons.settings_outlined,
                              onPressed: available ? openSettings : null,
                            ),
                            _headerButton(
                              tooltip: 'Закрыть',
                              icon: Icons.close_rounded,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                      final body = Padding(
                        padding: EdgeInsets.fromLTRB(inset, 8, inset, 12),
                        child: !available
                            ? const Text('Откройте панель заново.')
                            : wide && devices != null && overview != null
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 16,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      spacing: 12,
                                      children: [network, devices, setup],
                                    ),
                                  ),
                                  Expanded(child: overview),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 12,
                                children: [
                                  if (peer == null && conflictAction != null)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: conflictAction,
                                    ),
                                  network,
                                  if (request != null ||
                                      state.pairReview != null)
                                    setup,
                                  if (currentRun != null) ?overview,
                                  ?devices,
                                  if (request == null &&
                                      state.pairReview == null)
                                    setup,
                                  if (currentRun == null) ?overview,
                                  if (peer == null && issue != null) issue,
                                ],
                              ),
                      );
                      final footer = action == null
                          ? null
                          : Padding(
                              padding: EdgeInsets.fromLTRB(inset, 8, inset, 12),
                              child: action,
                            );

                      return DefaultTextStyle.merge(
                        style: AppTypography.bodySm.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        child: constraints.maxHeight < 250
                            ? SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [header, body, ?footer],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  header,
                                  Flexible(
                                    child: SingleChildScrollView(child: body),
                                  ),
                                  ?footer,
                                ],
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

class _SyncSetupPrompt extends StatelessWidget {
  const _SyncSetupPrompt({
    required this.state,
    required this.nearbyCandidates,
    required this.openSettings,
    required this.selectNearby,
    required this.showInvitation,
    required this.readInvitation,
    required this.showQr,
    required this.hideQr,
    required this.decide,
  });

  final LocalSyncState state;
  final List<LocalSyncPeer> nearbyCandidates;
  final VoidCallback openSettings;
  final ValueChanged<String>? selectNearby;
  final VoidCallback? showInvitation, readInvitation;
  final bool showQr;
  final VoidCallback hideQr;
  final ValueChanged<bool>? decide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = state.pairReview;
    final code = review?.code ?? state.pairingCode;
    final prompt = review == null
        ? switch (state) {
            LocalSyncState(awaitingApproval: final request?) =>
              '${request.name} запрашивает подключение.',
            LocalSyncState(confirmingDevice: final name?) =>
              'Ожидаем завершения подключения от «$name».',
            LocalSyncState(joining: true) => 'Завершаем сопряжение…',
            _ when state.nearby.isNotEmpty => 'Устройства рядом',
            _ when state.unverifiedPeers.isNotEmpty =>
              'Проверьте сохранённое сопряжение в настройках.',
            _ => 'Подключённых устройств пока нет.',
          }
        : review.canConfirm
        ? 'Подтвердите подключение к «${review.peer.name}»'
        : 'Ожидаем подтверждения от «${review.peer.name}»';
    final pairing =
        review != null ||
        state.joining ||
        state.awaitingApproval != null ||
        state.confirmingDevice != null;
    final invitation = showQr && !pairing ? state.invitation : null;

    return DecoratedBox(
      decoration: _syncCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          spacing: 9,
          children: [
            if (invitation != null) ...[
              SyncInvitationQr(invitation: invitation),
              TextButton(onPressed: hideQr, child: const Text('Скрыть QR')),
            ] else ...[
              if (!pairing)
                SyncRadar(
                  receiving: state.listening && state.discovering,
                  deviceIds: state.nearby.map((peer) => peer.id).toList(),
                ),
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              if (!pairing && state.discovering)
                Text(
                  state.listening && state.enrolled
                      ? 'Устройство видно в локальной сети'
                      : 'Откройте Pulse и включите приём на другом устройстве.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (code != null) ...[
                const Text(
                  'Сверьте код на обоих экранах',
                  textAlign: TextAlign.center,
                ),
                SyncPairCode(code),
              ],
              if (decide case final confirm?)
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => confirm(true),
                      child: Text(
                        code == null
                            ? 'Подтвердить подключение'
                            : 'Коды совпадают',
                      ),
                    ),
                    TextButton(
                      onPressed: () => confirm(false),
                      child: const Text('Отклонить'),
                    ),
                  ],
                ),
              if (!pairing) ...[
                for (final peer in nearbyCandidates)
                  _SyncDeviceRow(
                    name: peer.name,
                    detail: Uri.parse(peer.endpoint).host,
                    icon: Icons.wifi_tethering_rounded,
                    onTap: selectNearby == null
                        ? null
                        : () => selectNearby!(peer.id),
                  ),
                Wrap(
                  spacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (state.enrolled)
                      TextButton.icon(
                        onPressed: showInvitation,
                        icon: const Icon(Icons.qr_code_rounded),
                        label: const Text('Показать QR'),
                      ),
                    TextButton.icon(
                      onPressed: readInvitation,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(
                        canScanSyncQrWithCamera
                            ? 'Сканировать QR'
                            : 'Открыть QR с изображения',
                      ),
                    ),
                  ],
                ),
                if (!state.enrolled || state.unverifiedPeers.isNotEmpty)
                  FilledButton.tonal(
                    onPressed: openSettings,
                    child: Text(
                      state.unverifiedPeers.isNotEmpty
                          ? 'Открыть настройки'
                          : 'Подключить устройство',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncDevices extends StatelessWidget {
  const _SyncDevices({
    required this.state,
    required this.selected,
    required this.connected,
    required this.onSelect,
  });

  final LocalSyncState state;
  final String selected;
  final bool connected;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text('Устройства', style: theme.textTheme.titleSmall),
        _SyncDeviceRow(
          name: state.deviceName,
          detail: state.deviceName == 'Это устройство'
              ? null
              : 'Это устройство',
          icon: switch (theme.platform) {
            TargetPlatform.android ||
            TargetPlatform.iOS => Icons.phone_android_outlined,
            _ => Icons.laptop_outlined,
          },
        ),
        for (final peer in state.peers)
          _SyncDeviceRow(
            name: peer.name,
            detail: switch ((peer.id == selected, connected)) {
              (true, true) => 'Прямое соединение · P2P',
              _ when state.nearby.any((other) => other.id == peer.id) =>
                'Видно в локальной сети',
              (true, false) => 'Выбрано для обмена',
              _ => null,
            },
            icon: Icons.devices_other_outlined,
            selected: peer.id == selected,
            connected: peer.id == selected && connected,
            onTap: onSelect == null ? null : () => onSelect!(peer.id),
          ),
      ],
    );
  }
}

class _SyncDeviceRow extends StatelessWidget {
  const _SyncDeviceRow({
    required this.name,
    required this.detail,
    required this.icon,
    this.selected = false,
    this.connected = false,
    this.onTap,
  });

  final String name;
  final String? detail;
  final IconData icon;
  final bool selected, connected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final tint = selected ? AppColors.primary : muted;
    return Semantics(
      selected: selected ? true : null,
      child: Material(
        color: selected ? tint.withValues(alpha: .10) : AppColors.surfaceGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? tint.withValues(alpha: .34)
                : AppColors.borderGlass,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              spacing: 10,
              children: [
                Icon(icon, color: tint, size: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (detail case final text?)
                        Text(
                          text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: connected ? _syncSuccess : muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected || onTap != null)
                  Icon(
                    selected
                        ? Icons.check_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: tint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({
    required this.message,
    required this.icon,
    required this.tint,
  });

  final String message;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tint.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tint),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
