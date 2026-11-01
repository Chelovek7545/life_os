import 'dart:async';

class OwnedStreams {
  final _watches = <_Watch<dynamic>>{};
  bool _accepting = true;
  Future<void>? _closing;

  Stream<T> watch<T>(Stream<T> Function() source) {
    if (!_accepting) throw StateError('Task module streams are closed.');
    return Stream.multi((sink) {
      if (!_accepting) {
        sink.addError(StateError('Task module streams are closed.'));
        sink.close();
        return;
      }
      final watch = _Watch<T>(sink);
      _watches.add(watch);
      watch.onClosed = () => _watches.remove(watch);
      sink.onCancel = watch.close;
      try {
        watch.subscription = source().listen(
          sink.add,
          onError: sink.addError,
          onDone: () =>
              unawaited(watch.close().catchError((Object _, StackTrace _) {})),
        );
        sink.onPause = watch.subscription!.pause;
        sink.onResume = watch.subscription!.resume;
      } catch (error, stack) {
        sink.addError(error, stack);
        sink.close();
      }
    });
  }

  void stopAccepting() => _accepting = false;

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _accepting = false;
    await Future.wait([for (final watch in _watches.toList()) watch.close()]);
  }
}

class _Watch<T> {
  _Watch(this.sink);
  final MultiStreamController<T> sink;
  StreamSubscription<T>? subscription;
  late void Function() onClosed;
  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    try {
      await subscription?.cancel();
    } finally {
      // The owner observes cancellation failures through this future. Closing
      // the outgoing stream must not invoke the failed cancellation again.
      sink.onCancel = null;
      sink.close();
      onClosed();
    }
  }
}
