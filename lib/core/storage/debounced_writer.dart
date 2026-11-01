import 'dart:async';

class DebouncedWriter<T extends Object> {
  DebouncedWriter(
    this.write, {
    this.delay = const Duration(milliseconds: 400),
    this.onError,
    this.onIdle,
  });
  final Future<void> Function(T value) write;
  final Duration delay;
  final void Function(Object error, StackTrace stack)? onError;
  final void Function()? onIdle;
  int _generation = 0;
  int _writes = 0;
  bool get isIdle => _pending == null && _writes == 0;
  Timer? _timer;
  T? _pending;
  Future<void> _tail = Future.value();
  Future<void> _latest = Future.value();
  bool _closed = false;

  void schedule(T value) {
    if (_closed) throw StateError('Writer is closed.');
    _generation++;
    _pending = value;
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(
        flush().catchError((Object error, StackTrace stack) {
          onError?.call(error, stack);
        }),
      );
    });
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final value = _pending;
    if (value == null) return _latest;
    _pending = null;
    final generation = _generation;
    _writes++;
    final attempt = _tail.then((_) async {
      try {
        await write(value);
      } catch (_) {
        // A newer snapshot supersedes a failed older write.
        if (generation == _generation) _pending ??= value;
        rethrow;
      } finally {
        _writes--;
        if (isIdle) onIdle?.call();
      }
    });
    _latest = attempt;
    _tail = attempt.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return attempt;
  }

  Future<void> close() {
    _closed = true;
    return flush();
  }
}
