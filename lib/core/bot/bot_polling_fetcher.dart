import 'dart:async';

import 'package:teledart/model.dart';
import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';
import 'package:teledart/util.dart';

/// Polling whose stop future resolves only after the active getUpdates finishes.
/// Teledart's bundled LongPolling.stop() only flips a flag, so an immediate
/// restart can overlap its in-flight request and trigger Telegram's 409.
class BotPollingFetcher extends AbstractUpdateFetcher {
  BotPollingFetcher(
    Telegram telegram, {
    this.onConflict,
    this.onUnauthorized,
    this.onFailure,
    Future<List<Update>> Function(int offset, int timeout)? fetchUpdates,
    this.timeoutSeconds = 5,
    this.conflictRetries = 7,
    this.conflictRetryDelay = const Duration(seconds: 6),
  }) : _fetchUpdates =
           fetchUpdates ??
           ((offset, timeout) => telegram.getUpdates(
             offset: offset,
             timeout: timeout,
             allowedUpdates: ['message', 'callback_query'],
           ));

  final Future<List<Update>> Function(int offset, int timeout) _fetchUpdates;
  final void Function()? onConflict;
  final void Function()? onUnauthorized;
  final void Function()? onFailure;
  final int timeoutSeconds;
  final int conflictRetries;
  final Duration conflictRetryDelay;

  bool _running = false;
  int _offset = 0;
  Future<void>? _loop;
  Completer<void>? _stopSignal;

  @override
  Future<void> start() {
    if (_running) return Future.value();
    _running = true;
    _stopSignal = Completer<void>();
    _loop = _poll();
    return Future.value();
  }

  @override
  Future<void> stop() async {
    _running = false;
    final signal = _stopSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
    await _loop;
  }

  Future<void> _wait(Duration delay) async {
    await Future.any<void>([Future<void>.delayed(delay), _stopSignal!.future]);
  }

  Future<void> _poll() async {
    var conflicts = 0;
    var failures = 0;
    while (_running) {
      try {
        final updates = await _fetchUpdates(_offset, timeoutSeconds);
        if (!_running) break;
        conflicts = 0;
        failures = 0;
        for (final update in updates) {
          emitUpdate(update);
          _offset = update.updateId + 1;
        }
      } catch (error) {
        if (!_running) break;
        if (error is HttpClientException && error.code == 409) {
          conflicts++;
          if (conflicts >= conflictRetries) {
            _running = false;
            onConflict?.call();
            break;
          }
          await _wait(conflictRetryDelay);
        } else if (error is HttpClientException &&
            (error.code == 401 || error.code == 404)) {
          _running = false;
          onUnauthorized?.call();
          break;
        } else {
          conflicts = 0;
          failures++;
          if (failures >= 3) {
            _running = false;
            onFailure?.call();
            break;
          }
          // In particular, a timeout must not trigger an immediate second
          // request while the HTTP client might still be closing the first.
          await _wait(const Duration(seconds: 2));
        }
      }
    }
  }
}
