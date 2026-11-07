import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';

class ProbePlugin implements AppPlugin {
  ProbePlugin(this.id, {this.onStop});
  @override
  final String id;
  final void Function()? onStop;
  bool stopped = false;
  @override
  Set<String> get dependencies => {};
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {
    stopped = true;
    onStop?.call();
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage(this.id, {super.key, this.onDispose});
  final String id;
  final VoidCallback? onDispose;
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int count = 0;
  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('${widget.id}:$count'),
  );
}

PluginScreenContribution screen(
  String id, {
  int order = 0,
  Widget? child,
  void Function(Object?)? onOpen,
}) => PluginScreenContribution(
  id: id,
  label: id,
  icon: Icons.home,
  order: order,
  builder: (_, _) => child ?? CounterPage(id),
  onOpen: onOpen,
);

void main() {
  test(
    'overlay requests preserve selection and reject a revoked screen context',
    () {
      final registry = PluginUiRegistry();
      Object? request;
      registry.register(
        'source',
        screens: [
          PluginScreenContribution(
            id: 'source',
            label: 'Source',
            icon: Icons.home,
            builder: (_, _) => const SizedBox(),
          ),
        ],
      );
      registry.register(
        'editor',
        screens: [
          PluginScreenContribution(
            id: 'editor',
            label: 'Editor',
            icon: Icons.edit,
            builder: (_, _) => const SizedBox(),
            onOpen: (argument) => request = argument,
          ),
        ],
      );
      final navigation = PluginNavigationController(registry);
      final source = navigation.contextFor(registry.screens.first);
      expect(
        source.openScreen('editor', argument: 'draft', select: false),
        isTrue,
      );
      expect(request, 'draft');
      expect(navigation.selectedId, 'source');
      registry.unregister('source');
      request = null;
      expect(
        source.openScreen('editor', argument: 'stale', select: false),
        isFalse,
      );
      expect(request, isNull);
      navigation.dispose();
      registry.dispose();
    },
  );

  test(
    'screen and panel IDs share atomic registration with existing UI contributions',
    () {
      final registry = PluginUiRegistry();
      registry.register(
        'existing',
        settings: [
          PluginSettingsContribution(
            id: 'occupied',
            title: 'Existing',
            builder: (_) => const SizedBox(),
          ),
        ],
      );
      expect(
        () => registry.register(
          'bad',
          screens: [screen('fresh')],
          panels: [
            PluginPanelContribution(
              id: 'occupied',
              slot: 'slot',
              builder: (_, _) => const SizedBox(),
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(registry.screens, isEmpty);
      expect(registry.panelsFor('slot'), isEmpty);
      expect(registry.settings.single.id, 'occupied');
      registry.dispose();
    },
  );

  test(
    'failed registration does not remove an existing UI owner during rollback',
    () async {
      final registry = PluginUiRegistry()
        ..register('same', screens: [screen('original')]);
      final plugin = ProbePlugin('same');
      final host = PluginHost([
        UiPluginRegistration(
          plugin: plugin,
          registry: registry,
          screens: [screen('new')],
        ),
      ]);
      await expectLater(host.start(), throwsA(isA<PluginLifecycleException>()));
      expect(plugin.stopped, isTrue);
      expect(registry.screens.single.id, 'original');
      registry.dispose();
    },
  );

  test(
    'selection uses IDs, routes arguments and reconciles removal and an empty registry',
    () {
      final registry = PluginUiRegistry();
      final navigation = PluginNavigationController(registry);
      Object? received;
      registry.register(
        'main',
        screens: [
          screen('one'),
          screen('two', order: 10, onOpen: (argument) => received = argument),
        ],
      );
      expect(navigation.open('two', argument: 42), isTrue);
      expect(received, 42);
      registry.register('before', screens: [screen('before', order: -10)]);
      expect(navigation.selectedId, 'two');
      expect(navigation.open('absent'), isFalse);
      registry.unregister('main');
      expect(navigation.selectedId, 'before');
      registry.unregister('before');
      expect(navigation.selectedId, isNull);
      navigation.dispose();
      registry.dispose();
    },
  );

  test(
    'layout overrides belong to each screen and old contexts cannot control replacements',
    () async {
      final registry = PluginUiRegistry();
      final first = screen('one');
      final second = screen('two', order: 10);
      registry.register('first', screens: [first]);
      registry.register('second', screens: [second]);
      final navigation = PluginNavigationController(registry);
      final one = navigation.contextFor(first);
      final oldTwo = navigation.contextFor(second);
      oldTwo.setResizeToAvoidBottomInset(false);
      expect(navigation.resizeToAvoidBottomInset, isTrue);
      navigation.open('two');
      expect(navigation.resizeToAvoidBottomInset, isFalse);
      navigation.open('one');
      expect(navigation.resizeToAvoidBottomInset, isTrue);
      registry.unregister('second');
      registry.register('second', screens: [second]);
      expect(oldTwo.isActive, isFalse);
      expect(oldTwo.openScreen('two'), isFalse);
      oldTwo.setResizeToAvoidBottomInset(false);
      navigation.open('two');
      expect(navigation.resizeToAvoidBottomInset, isTrue);
      expect(one.openScreen('one'), isTrue);
      await Future<void>.delayed(Duration.zero);
      navigation.dispose();
      registry.dispose();
    },
  );

  testWidgets(
    'screen state survives selection and insertion but is released on unload',
    (tester) async {
      final registry = PluginUiRegistry();
      var disposed = 0;
      final first = screen(
        'one',
        child: CounterPage('one', onDispose: () => disposed++),
      );
      registry.register('first', screens: [first]);
      registry.register('second', screens: [screen('two', order: 10)]);
      final navigation = PluginNavigationController(registry);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PluginScreenDeck(navigation: navigation)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('one:0'));
      await tester.pump();
      navigation.open('two');
      await tester.pumpAndSettle();
      registry.register('before', screens: [screen('before', order: -10)]);
      await tester.pump();
      navigation.open('one');
      await tester.pumpAndSettle();
      expect(find.text('one:1'), findsOneWidget);
      registry.unregister('first');
      await tester.pumpAndSettle();
      expect(disposed, 1);
      registry.register('first', screens: [first]);
      navigation.open('one');
      await tester.pumpAndSettle();
      expect(find.text('one:0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      registry.dispose();
    },
  );

  testWidgets(
    'panel order changes preserve retained state and invalidate removed contexts',
    (tester) async {
      final registry = PluginUiRegistry();
      late PluginPanelContext oldContext;
      final contribution = PluginPanelContribution(
        id: 'counter',
        slot: 'slot',
        order: 10,
        builder: (_, panel) {
          oldContext = panel;
          return const CounterPage('panel');
        },
      );
      registry.register('first', panels: [contribution]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PluginPanelSlot(registry: registry, slot: 'slot'),
          ),
        ),
      );
      await tester.tap(find.text('panel:0'));
      await tester.pump();
      registry.register(
        'before',
        panels: [
          PluginPanelContribution(
            id: 'before',
            slot: 'slot',
            builder: (_, _) => const Text('Before'),
          ),
        ],
      );
      await tester.pump();
      expect(find.text('panel:1'), findsOneWidget);
      final removedContext = oldContext;
      registry.unregister('first');
      await tester.pump();
      registry.register('first', panels: [contribution]);
      await tester.pump();
      expect(removedContext.isActive, isFalse);
      expect(find.text('panel:0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      registry.dispose();
    },
  );

  test(
    'UI disappears before service shutdown even when shutdown fails',
    () async {
      final registry = PluginUiRegistry();
      final plugin = ProbePlugin(
        'module',
        onStop: () {
          expect(registry.screens, isEmpty);
          expect(registry.panelsFor('slot'), isEmpty);
          throw StateError('stop failed');
        },
      );
      final host = PluginHost([
        UiPluginRegistration(
          plugin: plugin,
          registry: registry,
          screens: [screen('screen')],
          panels: [
            PluginPanelContribution(
              id: 'panel',
              slot: 'slot',
              builder: (_, _) => const SizedBox(),
            ),
          ],
        ),
      ]);
      await host.start();
      await expectLater(host.stop(), throwsA(isA<PluginLifecycleException>()));
      expect(registry.screens, isEmpty);
      registry.dispose();
    },
  );
}
