import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:life_os/core/ui/app_notifiacations.dart';
import 'package:sync_plugin/sync_logic.dart';

class SyncCompletionNotice extends StatefulWidget {
  const SyncCompletionNotice({
    super.key,
    required this.control,
    required this.isPanelOpen,
  });

  final LocalSyncControl control;
  final bool Function() isPanelOpen;

  @override
  State<SyncCompletionNotice> createState() => _SyncCompletionNoticeState();
}

class _SyncCompletionNoticeState extends State<SyncCompletionNotice> {
  late final StreamSubscription<LocalSyncState> _subscription;

  @override
  void initState() {
    super.initState();
    final control = widget.control;
    final generation = control.generation;
    var previous = control.state.run;
    _subscription = control.states.listen((state) {
      final run = state.run;
      if (identical(run, previous)) return;
      previous = run;
      if (!mounted ||
          control.generation != generation ||
          run?.phase != LocalSyncPhase.complete ||
          widget.isPanelOpen()) {
        return;
      }
      if (state.notesNeedFolder ||
          state.conflictCount > 0 ||
          state.pendingCount > 0) {
        AppNotification.showInfo(
          context,
          'Обмен завершён. Откройте настройки синхронизации, чтобы проверить изменения.',
        );
      } else {
        AppNotification.showSuccess(
          context,
          'Синхронизация завершена успешно.',
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
