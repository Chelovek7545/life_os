import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/features/sync/presentation/sync_quick_action.dart';
import 'package:life_os/features/sync/presentation/sync_settings_panel.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart';

class _Control implements LocalSyncControl {
  @override
  Future<Map<String, String>> entityNames({bool liveOnly = false}) async => {};
  List<LocalSyncPending> waiting = [];
  @override
  Future<List<LocalSyncPending>> pending() async => waiting;
  @override
  Future<void> repair(
    SyncRevision revision,
    String payload,
    Set<String> expected,
  ) async {
    calls.add('repair:${revision.id}');
    repairedPayload = payload;
    resolvedBasis = expected;
  }

  @override
  int generation = 1;
  @override
  LocalSyncState state = LocalSyncState();
  final events = StreamController<LocalSyncState>.broadcast();
  final calls = <String>[];
  Future<void> Function(String)? exchange;
  Map<String, List<SyncRevision>> variants = {};
  Set<String>? resolvedBasis;
  String? repairedPayload;
  @override
  Stream<LocalSyncState> get states => events.stream;
  void emit(LocalSyncState value) {
    state = value;
    events.add(value);
  }

  @override
  Future<List<String>> addresses() async => ['192.168.1.2'];
  @override
  Future<void> createSpace() async {
    calls.add('create');
    emit(LocalSyncState(enrolled: true));
  }

  @override
  Future<void> listen(String host) async {
    calls.add('listen:$host');
  }

  @override
  Future<void> closeListener() async {
    calls.add('close');
  }

  @override
  Future<void> invite(String host) async {
    calls.add('invite:$host');
  }

  @override
  Future<void> join(String invitation, String host) async {
    calls.add('join');
  }

  @override
  Future<void> approve(String id) async {
    calls.add('approve:$id');
  }

  @override
  Future<void> reject(String id) async {
    calls.add('reject:$id');
  }

  @override
  Future<void> synchronize(String id) async {
    calls.add('sync:$id');
    await exchange?.call(id);
  }

  @override
  Future<void> revoke(String id) async {
    calls.add('revoke:$id');
  }

  @override
  Future<Map<String, List<SyncRevision>>> conflicts() async => variants;
  @override
  Future<void> resolve(SyncRevision chosen, Set<String> expected) async {
    calls.add('resolve:${chosen.id}');
    resolvedBasis = expected;
  }
}

void main() {
  late _Control control;
  setUp(() => control = _Control());
  tearDown(() => control.events.close());

  testWidgets('quick sync handles progress and retry on a narrow screen', (
    tester,
  ) async {
    const peer = LocalSyncPeer(
      id: 'phone',
      name: 'Телефон',
      endpoint: 'https://192.168.1.3:48766/',
      fingerprint: 'fingerprint',
    );
    control.state = LocalSyncState(enrolled: true, peers: [peer]);
    final checks = <Completer<void>>[];
    control.exchange = (_) async {
      final result = Completer<void>();
      checks.add(result);
      control.emit(LocalSyncState(enrolled: true, busy: true, peers: [peer]));
      try {
        await result.future;
        control.emit(
          LocalSyncState(
            enrolled: true,
            peers: [peer],
            lastSync: DateTime(2026, 11, 19, 14, 30),
            conflictCount: 1,
          ),
        );
      } on LocalSyncException catch (error) {
        control.emit(
          LocalSyncState(enrolled: true, peers: [peer], error: error.message),
        );
        rethrow;
      }
    };
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SyncQuickAction(control: control),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Локальная синхронизация'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    final card = find.byType(GlassPanel);
    final enteringTop = tester.getTopLeft(card).dy;
    await tester.pumpAndSettle();
    expect(tester.getCenter(card).dx, closeTo(160, .1));
    expect(tester.getTopLeft(card).dy, closeTo(12, .1));
    expect(enteringTop, lessThan(tester.getTopLeft(card).dy));
    expect(find.text('Телефон'), findsOneWidget);
    expect(find.text('В этом сеансе обмена ещё не было.'), findsOneWidget);
    final sync = find.widgetWithText(FilledButton, 'Синхронизировать');
    await tester.tap(sync);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(sync).onPressed, isNull);
    checks.single.completeError(
      const LocalSyncException('Устройство недоступно.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Устройство недоступно.'), findsOneWidget);
    await tester.tap(sync);
    await tester.pump();
    checks.last.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Последний обмен:'), findsOneWidget);
    expect(find.text('Конфликты: 1'), findsOneWidget);
    expect(find.text('Устройство недоступно.'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(control.calls, ['sync:phone', 'sync:phone']);
  });

  testWidgets('quick sync opens the existing setup without enrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SyncQuickAction(control: control)),
      ),
    );
    await tester.tap(find.byTooltip('Локальная синхронизация'));
    await tester.pumpAndSettle();
    expect(
      find.text('Подключите свои устройства в настройках.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Настройки'));
    await tester.pumpAndSettle();
    expect(find.byType(SyncSettingsPanel), findsOneWidget);
    expect(
      find.text('Создать пространство на этом устройстве'),
      findsOneWidget,
    );
    expect(control.calls, isEmpty);
  });

  Future<void> show(WidgetTester tester, {double width = 800}) async {
    await tester.binding.setSurfaceSize(Size(width, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SyncSettingsPanel(control: control),
          ),
        ),
      ),
    );
    if (control.state.busy) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'fresh setup uses explicit enrollment and preserves the local address',
    (tester) async {
      await show(tester);
      expect(
        find.text('Создать пространство на этом устройстве'),
        findsOneWidget,
      );
      expect(find.text('Присоединиться с пустой базой'), findsOneWidget);
      expect(find.text('192.168.1.2'), findsOneWidget);
      await tester.tap(find.text('Создать пространство на этом устройстве'));
      await tester.pumpAndSettle();
      expect(control.calls, ['create']);
      expect(find.text('Приём по локальной сети'), findsOneWidget);
    },
  );
  testWidgets(
    'narrow layout shows approval, pending and busy state without an overflow',
    (tester) async {
      control.state = LocalSyncState(
        enrolled: true,
        listening: true,
        busy: true,
        pendingCount: 3,
        endpoint: 'https://192.168.1.2:48766/',
        peers: [
          const LocalSyncPeer(
            id: 'peer',
            name: 'Phone',
            endpoint: 'https://192.168.1.3:48766/',
            fingerprint: 'fingerprint',
          ),
        ],
        awaitingApproval: const LocalSyncPeer(
          id: 'request',
          name: 'New phone',
          endpoint: 'https://192.168.1.4:48766/',
          fingerprint: 'fingerprint',
        ),
      );
      await show(tester, width: 360);
      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final sync = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Синхронизировать'),
      );
      expect(sync.onPressed, isNull);
      expect(find.textContaining('Ожидают завершения'), findsOneWidget);
      expect(find.text('Нет ожидающих разрешения конфликтов.'), findsNothing);
    },
  );
  testWidgets(
    'conflict resolution submits the exact displayed revision basis',
    (tester) async {
      final task = Task.blank();
      control.variants = {
        task.id: [
          for (final id in ['a', 'b'])
            SyncRevision(
              id: id,
              deviceId: id,
              entityId: task.id,
              parents: [],
              payload: TaskSyncCodec.encode(
                task.copyWith(title: 'Version $id'),
              ),
            ),
        ],
      };
      control.state = LocalSyncState(enrolled: true, conflictCount: 1);
      await show(tester);
      await tester.tap(find.text('Разрешить конфликты: 1'));
      await tester.pumpAndSettle();
      expect(find.text('Конфликтующие изменения'), findsOneWidget);
      await tester.tap(find.text('Выбрать эту версию').first);
      await tester.pumpAndSettle();
      expect(control.resolvedBasis, {'a', 'b'});
      expect(control.calls, ['resolve:a']);
    },
  );
  testWidgets('an old panel callback cannot act on a restarted module', (
    tester,
  ) async {
    await show(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(
        FilledButton,
        'Создать пространство на этом устройстве',
      ),
    );
    control.generation++;
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(control.calls, isEmpty);
  });
  testWidgets('pending tag can be renamed with the captured revision basis', (
    tester,
  ) async {
    final r = SyncRevision(
      id: 'pending-tag',
      deviceId: 'peer',
      entityId: 'tag',
      entityType: 'tag',
      parents: [],
      payload: HierarchySyncCodec.tag(
        const Tag(id: 0, syncId: 'tag', name: 'Same', colorHex: 1),
      ),
      schemaVersion: 3,
    );
    control.waiting = [
      LocalSyncPending(r, {'pending-tag'}),
    ];
    control.state = LocalSyncState(enrolled: true, pendingCount: 1);
    await show(tester);
    await tester.tap(find.text('Просмотреть ожидающие изменения'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Исправить'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Новое имя тега'),
      'Different',
    );
    await tester.tap(find.text('Сохранить исправление'));
    await tester.pumpAndSettle();
    expect(control.calls, ['repair:pending-tag']);
    expect(control.resolvedBasis, {'pending-tag'});
    expect(
      HierarchySyncCodec.decodeTag(control.repairedPayload!).name,
      'Different',
    );
    expect(tester.takeException(), isNull);
  });
}
