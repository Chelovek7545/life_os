import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/features/sync/presentation/sync_completion_notice.dart';
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
  List<String> localAddresses = ['192.168.1.2'];
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
  Future<List<String>> addresses() async => localAddresses;
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
  Future<void> verifyPair(String id) async {
    calls.add('verify:$id');
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
      control.emit(
        LocalSyncState(
          enrolled: true,
          busy: true,
          peers: [peer],
          run: LocalSyncRun(
            peer.id,
            LocalSyncPhase.transferring,
            SyncTransferProgress(
              {SyncSection.notes: 1, SyncSection.habits: 2},
              {SyncSection.notes: 1},
              [SyncSection.habits],
            ),
          ),
        ),
      );
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
    await tester.ensureVisible(sync);
    await tester.tap(sync);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .25,
    );
    expect(find.text('Заметки'), findsOneWidget);
    expect(find.text('Привычки'), findsOneWidget);
    expect(tester.widget<FilledButton>(sync).onPressed, isNull);
    checks.single.completeError(
      const LocalSyncException('Устройство недоступно.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Устройство недоступно.'), findsOneWidget);
    await tester.ensureVisible(sync);
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
    expect(find.text('Подключённых устройств пока нет.'), findsOneWidget);
    expect(find.text('Синхронизировать'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Подключить устройство'));
    await tester.pumpAndSettle();
    expect(find.byType(SyncSettingsPanel), findsOneWidget);
    expect(
      find.text('Создать пространство на этом устройстве'),
      findsOneWidget,
    );
    expect(control.calls, isEmpty);
  });

  testWidgets('pairing exposes the sync action only after confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SyncQuickAction(control: control)),
      ),
    );
    await tester.tap(find.byTooltip('Локальная синхронизация'));
    await tester.pumpAndSettle();
    const tablet = LocalSyncPeer(
      id: 'tablet',
      name: 'Redmi Pad Pro',
      endpoint: 'https://192.168.1.3:48766/',
      fingerprint: 'fingerprint',
    );
    control.emit(LocalSyncState(enrolled: true, awaitingApproval: tablet));
    await tester.pumpAndSettle();
    expect(find.text('Redmi Pad Pro запрашивает подключение.'), findsOneWidget);
    expect(find.text('Подтвердить подключение'), findsOneWidget);
    expect(find.text('Синхронизировать'), findsNothing);

    control.emit(LocalSyncState(enrolled: true, confirmingDevice: tablet.name));
    await tester.pumpAndSettle();
    expect(
      find.text('Ожидаем завершения подключения от «Redmi Pad Pro».'),
      findsOneWidget,
    );
    expect(find.text('Синхронизировать'), findsNothing);

    control.emit(LocalSyncState(enrolled: true, peers: [tablet]));
    await tester.pumpAndSettle();
    expect(find.text(tablet.name), findsOneWidget);
    expect(find.text('Сопряжено'), findsNothing);
    final sync = find.widgetWithText(FilledButton, 'Синхронизировать');
    expect(tester.widget<FilledButton>(sync).onPressed, isNotNull);
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

  testWidgets('a saved legacy device must be verified before sync', (
    tester,
  ) async {
    const tablet = LocalSyncPeer(
      id: 'tablet',
      name: 'Планшет',
      endpoint: 'https://192.168.1.3:48766/',
      fingerprint: 'fingerprint',
    );
    control.state = LocalSyncState(enrolled: true, unverifiedPeers: [tablet]);
    await show(tester);
    expect(find.text('Синхронизировать'), findsNothing);
    await tester.tap(find.text('Проверить сопряжение'));
    await tester.pumpAndSettle();
    expect(control.calls, ['verify:tablet']);
  });

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
      expect(find.text('Приём по локальной сети'), findsNothing);
      expect(find.text('Пригласить устройство'), findsOneWidget);
    },
  );

  testWidgets('quick sync controls receiving and can change the local IP', (
    tester,
  ) async {
    control.state = LocalSyncState(enrolled: true, localAddress: '192.168.1.2');
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SyncQuickAction(control: control)),
      ),
    );
    await tester.tap(find.byTooltip('Локальная синхронизация'));
    await tester.pumpAndSettle();
    expect(find.text('Подключённых устройств пока нет.'), findsOneWidget);
    expect(find.text('Приём выключен'), findsOneWidget);
    final toggle = find.byType(Switch);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(control.calls, ['listen:192.168.1.2']);

    control.emit(
      LocalSyncState(
        enrolled: true,
        localAddress: '192.168.1.2',
        listening: true,
        busy: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(tester.widget<Switch>(toggle).onChanged, isNull);
    expect(find.text('Приём включён'), findsOneWidget);
    control.emit(
      LocalSyncState(
        enrolled: true,
        localAddress: '192.168.1.2',
        listening: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('IP 192.168.1.2'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '192.168.1.4');
    await tester.pump();
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(control.calls, [
      'listen:192.168.1.2',
      'listen:192.168.1.4',
      'close',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick sync reports when there is no local IP for receiving', (
    tester,
  ) async {
    control.state = LocalSyncState(enrolled: true);
    control.localAddresses = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SyncQuickAction(control: control)),
      ),
    );
    await tester.tap(find.byTooltip('Локальная синхронизация'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      find.text(LocalSyncException.missingLocalIp.message),
      findsOneWidget,
    );
    expect(control.calls, isEmpty);
  });

  testWidgets('invitation uses the chosen IP when several are available', (
    tester,
  ) async {
    control.state = LocalSyncState(enrolled: true, localAddress: '192.168.1.8');
    control.localAddresses = ['10.6.7.1', '192.168.1.8'];
    await show(tester, width: 360);

    final host = tester.widget<TextField>(find.byType(TextField));
    expect(host.controller!.text, '192.168.1.8');
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Пригласить устройство'));
    await tester.pumpAndSettle();
    expect(
      find.text(LocalSyncException.missingLocalIp.message),
      findsOneWidget,
    );
    expect(control.calls, isEmpty);
    await tester.tap(find.byTooltip('Выбрать локальный IP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('192.168.1.8'));
    await tester.pumpAndSettle();
    expect(find.text(LocalSyncException.missingLocalIp.message), findsNothing);
    await tester.tap(find.text('Пригласить устройство'));
    await tester.pumpAndSettle();

    expect(control.calls, ['invite:192.168.1.8']);
  });

  testWidgets('completion shows one in-app notice only with the panel closed', (
    tester,
  ) async {
    var open = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SyncQuickAction(
                control: control,
                onVisibilityChanged: (value) => open = value,
              ),
              SyncCompletionNotice(control: control, isPanelOpen: () => open),
            ],
          ),
        ),
      ),
    );
    const tablet = LocalSyncPeer(
      id: 'tablet',
      name: 'Планшет',
      endpoint: 'https://192.168.1.8:48766/',
      fingerprint: 'fingerprint',
    );
    final done = find.text('Синхронизация завершена успешно.');
    control.emit(LocalSyncState(enrolled: true, peers: [tablet]));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Локальная синхронизация'));
    await tester.pumpAndSettle();
    control.emit(
      LocalSyncState(
        enrolled: true,
        peers: [tablet],
        run: const LocalSyncRun('tablet', LocalSyncPhase.complete),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(done, findsNothing);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(done, findsNothing);

    control.emit(
      LocalSyncState(
        enrolled: true,
        peers: [tablet],
        run: const LocalSyncRun('tablet', LocalSyncPhase.failed),
      ),
    );
    await tester.pumpAndSettle();
    expect(done, findsNothing);

    final result = LocalSyncState(
      enrolled: true,
      peers: [tablet],
      run: LocalSyncRun('tablet', LocalSyncPhase.complete),
    );
    control.emit(result);
    await tester.pumpAndSettle();
    expect(done, findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    control.emit(result);
    await tester.pumpAndSettle();
    expect(done, findsNothing);
  });

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
