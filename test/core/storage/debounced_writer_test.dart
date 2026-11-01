import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/storage/debounced_writer.dart';

void main() {
  test('close flushes the last snapshot before its debounce expires', () async {
    final saved = <String>[];
    final writer = DebouncedWriter<String>((value) async {
      saved.add(value);
    });
    writer.schedule('old');
    writer.schedule('latest');
    await writer.close();
    expect(saved, ['latest']);
    expect(() => writer.schedule('closed'), throwsStateError);
  });
  test('serializes writes and waits for the in-flight write', () async {
    final saved = <String>[];
    final gate = Completer<void>();
    final writer = DebouncedWriter<String>((value) async {
      if (value == 'a') await gate.future;
      saved.add(value);
    });
    writer.schedule('a');
    final first = writer.flush();
    writer.schedule('b');
    final second = writer.close();
    await Future<void>.delayed(Duration.zero);
    expect(saved, isEmpty);
    gate.complete();
    await Future.wait([first, second]);
    expect(saved, ['a', 'b']);
  });
  test('retains a failed snapshot for a retry', () async {
    var fail = true;
    final saved = <String>[];
    final writer = DebouncedWriter<String>((value) async {
      if (fail) throw StateError('disk full');
      saved.add(value);
    });
    writer.schedule('note');
    await expectLater(writer.flush(), throwsStateError);
    fail = false;
    await writer.close();
    expect(saved, ['note']);
  });
  test('a failed old write cannot replace a newer queued snapshot', () async {
    final gate = Completer<void>();
    final saved = <String>[];
    final writer = DebouncedWriter<String>((value) async {
      if (value == 'old') {
        await gate.future;
        throw StateError('old failure');
      }
      saved.add(value);
    });
    writer.schedule('old');
    final failure = expectLater(writer.flush(), throwsStateError);
    writer.schedule('new');
    final newest = writer.flush();
    gate.complete();
    await failure;
    await newest;
    await writer.close();
    expect(saved, ['new']);
  });
  testWidgets('debounce saves automatically and reports idle', (tester) async {
    final saved = <String>[];
    var idle = false;
    final writer = DebouncedWriter<String>((value) async {
      saved.add(value);
    }, onIdle: () => idle = true);
    writer.schedule('note');
    await tester.pump(const Duration(milliseconds: 401));
    expect(saved, ['note']);
    expect(idle, isTrue);
    await writer.close();
  });
}
