import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';

class TestUiPlugin implements AppPlugin {
  TestUiPlugin(this.id, {this.failStop = false});
  @override
  final String id;
  final bool failStop;
  bool stopped = false;
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {
    stopped = true;
    if (failStop) throw StateError('stop');
  }
}

PluginActionContribution action(String id) => PluginActionContribution(
  id: id,
  locations: {PluginActionLocation.appBar},
  builder: (_, _) =>
      TextButton(onPressed: () {}, child: const Text('Plugin action')),
);
void main() {
  test(
    'duplicate contribution registration rolls back partially started plugins',
    () async {
      final registry = PluginUiRegistry();
      final first = TestUiPlugin('first');
      final second = TestUiPlugin('second');
      final host = PluginHost([
        UiPluginRegistration(
          plugin: first,
          registry: registry,
          actions: [action('same')],
        ),
        UiPluginRegistration(
          plugin: second,
          registry: registry,
          actions: [action('same')],
        ),
      ]);
      await expectLater(host.start(), throwsA(isA<PluginLifecycleException>()));
      expect(first.stopped && second.stopped, isTrue);
      expect(registry.actionsFor(PluginActionLocation.appBar), isEmpty);
      registry.dispose();
    },
  );
  test('failed shutdown still unregisters plugin UI', () async {
    final registry = PluginUiRegistry();
    final host = PluginHost([
      UiPluginRegistration(
        plugin: TestUiPlugin('failing', failStop: true),
        registry: registry,
        actions: [action('action')],
      ),
    ]);
    await host.start();
    await expectLater(host.stop(), throwsA(isA<PluginLifecycleException>()));
    expect(registry.actionsFor(PluginActionLocation.appBar), isEmpty);
    registry.dispose();
  });
  testWidgets('action surfaces follow registration and shutdown', (
    tester,
  ) async {
    final registry = PluginUiRegistry();
    final host = PluginHost([
      UiPluginRegistration(
        plugin: TestUiPlugin('custom'),
        registry: registry,
        actions: [action('custom')],
      ),
    ]);
    await host.start();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginActions(
            registry: registry,
            location: PluginActionLocation.appBar,
          ),
        ),
      ),
    );
    expect(find.text('Plugin action'), findsOneWidget);
    await host.stop();
    await tester.pump();
    expect(find.text('Plugin action'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    registry.dispose();
  });
  testWidgets('a failed setting save keeps the dialog open for retry', (
    tester,
  ) async {
    final value = ValueNotifier('old');
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginTextSetting(
            title: 'Custom setting',
            icon: Icons.edit,
            value: value,
            save: (text) async {
              if (fail) throw StateError('save failed');
              value.value = text;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Custom setting'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(value.value, 'old');
    fail = false;
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(value.value, 'new');
    await tester.pumpWidget(const SizedBox());
    value.dispose();
  });
}
