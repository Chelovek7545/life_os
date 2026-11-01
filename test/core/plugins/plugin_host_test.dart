import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

class TestPlugin implements AppPlugin {
  TestPlugin(
    this.id,
    this.events, {
    this.dependencies = const {},
    this.failStart = false,
    this.failStop = false,
    this.gate,
  });
  @override
  final String id;
  final List<String> events;
  @override
  final Set<String> dependencies;
  bool failStart;
  bool failStop;
  final Completer<void>? gate;
  @override
  Future<void> start() async {
    events.add('start:' + id);
    await gate?.future;
    if (failStart) throw StateError('start');
  }

  @override
  Future<void> stop() async {
    events.add('stop:' + id);
    if (failStop) throw StateError('stop');
  }
}

void main() {
  test(
    'starts dependencies first and stops in reverse order exactly once',
    () async {
      final events = <String>[];
      final host = PluginHost([
        TestPlugin('telegram', events, dependencies: {'tasks'}),
        TestPlugin('tasks', events),
      ]);
      await host.start();
      await host.start();
      await host.stop();
      await host.stop();
      expect(events, [
        'start:tasks',
        'start:telegram',
        'stop:telegram',
        'stop:tasks',
      ]);
      expect(host.states.values, everyElement(PluginState.inactive));
    },
  );
  test(
    'rejects missing dependencies, duplicates and cycles before startup',
    () {
      final events = <String>[];
      expect(
        () => PluginHost([
          TestPlugin('a', events, dependencies: {'b'}),
        ]),
        throwsArgumentError,
      );
      expect(
        () => PluginHost([TestPlugin('a', events), TestPlugin('a', events)]),
        throwsArgumentError,
      );
      expect(
        () => PluginHost([
          TestPlugin('a', events, dependencies: {'b'}),
          TestPlugin('b', events, dependencies: {'a'}),
        ]),
        throwsArgumentError,
      );
      expect(events, isEmpty);
    },
  );
  test(
    'cleans a partially started plugin and rolls back its dependencies',
    () async {
      final events = <String>[];
      final broken = TestPlugin(
        'b',
        events,
        dependencies: {'a'},
        failStart: true,
      );
      final host = PluginHost([TestPlugin('a', events), broken]);
      await expectLater(host.start(), throwsA(isA<PluginLifecycleException>()));
      expect(events, ['start:a', 'start:b', 'stop:b', 'stop:a']);
      broken.failStart = false;
      await host.start();
      expect(host.states.values, everyElement(PluginState.active));
      await host.stop();
    },
  );
  test(
    'stop continues after failure and retries resources not yet released',
    () async {
      final events = <String>[];
      final broken = TestPlugin(
        'b',
        events,
        dependencies: {'a'},
        failStop: true,
      );
      final host = PluginHost([TestPlugin('a', events), broken]);
      await host.start();
      await expectLater(host.stop(), throwsA(isA<PluginLifecycleException>()));
      expect(events, contains('stop:a'));
      await expectLater(host.start(), throwsStateError);
      broken.failStop = false;
      await host.stop();
      expect(host.states.values, everyElement(PluginState.inactive));
    },
  );
  test('shutdown waits for an in-flight startup', () async {
    final events = <String>[];
    final gate = Completer<void>();
    final host = PluginHost([TestPlugin('a', events, gate: gate)]);
    final starting = host.start();
    final stopping = host.stop();
    await Future<void>.delayed(Duration.zero);
    expect(events, ['start:a']);
    gate.complete();
    await Future.wait([starting, stopping]);
    expect(events, ['start:a', 'stop:a']);
  });
}
