import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/features/sync/presentation/sync_completion_notice.dart';
import 'package:life_os/features/sync/presentation/sync_quick_action.dart';
import 'package:life_os/features/sync/presentation/sync_pairing_qr.dart';
import 'package:life_os/features/sync/presentation/sync_radar.dart';
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
  final visibility = <bool>[];
  List<String> localAddresses = ['192.168.1.2'];
  Future<void> Function(String)? exchange;
  Map<String, List<SyncRevision>> variants = {};
  Set<String>? resolvedBasis;
  String? repairedPayload;
  String? resolvedPayload;
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
  Future<void> setDiscoveryVisible(bool visible) async {
    visibility.add(visible);
  }

  @override
  Future<void> joinNearby(String peerId, String host) async {
    calls.add('nearby:$peerId:$host');
  }

  @override
  Future<void> confirmNearby(bool accepted) async {
    calls.add('confirm-nearby:$accepted');
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
  Future<void> resolve(
    SyncRevision chosen,
    Set<String> expected, {
    String? mergedPayload,
  }) async {
    calls.add('resolve:${chosen.id}');
    resolvedBasis = expected;
    resolvedPayload = mergedPayload;
    variants.remove(chosen.entityId);
    emit(
      LocalSyncState(
        enrolled: true,
        deviceId: state.deviceId,
        peers: state.peers,
        conflictCount: variants.length,
      ),
    );
  }
}

void main() {
  late _Control control;
  setUp(() => control = _Control());
  tearDown(() => control.events.close());

  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

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
            run: LocalSyncRun(
              peer.id,
              LocalSyncPhase.complete,
              SyncTransferProgress(
                {SyncSection.notes: 1, SyncSection.habits: 2},
                {SyncSection.notes: 1, SyncSection.habits: 2},
                [],
              ),
            ),
          ),
        );
      } on LocalSyncException catch (error) {
        control.emit(
          LocalSyncState(
            enrolled: true,
            peers: [peer],
            error: error.message,
            run: LocalSyncRun(peer.id, LocalSyncPhase.failed),
          ),
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
    final ring = find.byWidgetPredicate(
      (widget) =>
          widget is CircularProgressIndicator &&
          widget.semanticsLabel == 'Прогресс обмена',
    );
    expect(ring, findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(tester.widget<CircularProgressIndicator>(ring).value, .25);
    expect(
      tester.getTopLeft(ring).dy,
      lessThan(tester.getTopLeft(find.text('Устройства')).dy),
    );
    expect(find.text('Заметки'), findsOneWidget);
    expect(find.text('Привычки'), findsOneWidget);
    expect(tester.widget<FilledButton>(sync).onPressed, isNull);
    checks.single.completeError(
      const LocalSyncException('Устройство недоступно.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Устройство недоступно.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Повторить обмен'));
    await tester.pump();
    checks.last.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Последний обмен:'), findsOneWidget);
    expect(find.text('Конфликты: 1'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Устройство недоступно.'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(control.calls, ['sync:phone', 'sync:phone']);
  });

  testWidgets(
    'wide sync panel shows devices beside progress and selects a peer',
    (tester) async {
      control.state = LocalSyncState(
        enrolled: true,
        deviceName: 'ПК',
        localAddress: '192.168.1.2',
        peers: [
          const LocalSyncPeer(
            id: 'phone',
            name: 'Телефон',
            endpoint: 'https://192.168.1.3:48766/',
            fingerprint: 'fingerprint',
          ),
          const LocalSyncPeer(
            id: 'tablet',
            name: 'Планшет',
            endpoint: 'https://192.168.1.4:48766/',
            fingerprint: 'fingerprint',
          ),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(900, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncQuickAction(control: control)),
        ),
      );
      await tester.tap(find.byTooltip('Локальная синхронизация'));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Устройства')).dx,
        lessThan(tester.getCenter(find.text('Готово к обмену')).dx),
      );
      await tester.tap(find.text('Планшет'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Синхронизировать'));
      await tester.pumpAndSettle();
      expect(control.calls, ['sync:tablet']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quick sync opens the existing setup without enrolling', (
    tester,
  ) async {
    reduceMotion(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SyncQuickAction(control: control)),
      ),
    );
    await tester.tap(find.byTooltip('Локальная синхронизация'));
    await tester.pumpAndSettle();
    expect(find.text('Подключённых устройств пока нет.'), findsOneWidget);
    expect(find.byType(SyncRadar), findsOneWidget);
    expect(find.text('Синхронизировать'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Подключить устройство'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SyncSettingsPanel), findsOneWidget);
    expect(
      find.text('Создать пространство на этом устройстве'),
      findsOneWidget,
    );
    expect(control.calls, isEmpty);
  });

  testWidgets('radar keeps sweeping, while reduced motion stops it', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: Center(child: SyncRadar(receiving: false)),
      ),
    );
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(seconds: 9));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Center(child: SyncRadar(receiving: true)),
      ),
    );
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(SyncRadar), findsOneWidget);
  });

  testWidgets('pairing exposes the sync action only after confirmation', (
    tester,
  ) async {
    reduceMotion(tester);
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

  testWidgets(
    'radar shows discovered devices, comparison codes and QR fallback',
    (tester) async {
      reduceMotion(tester);
      const tablet = LocalSyncPeer(
        id: 'tablet',
        name: 'Планшет',
        endpoint: 'https://192.168.1.3:48766/',
        fingerprint: 'fingerprint',
      );
      control.state = LocalSyncState(
        enrolled: true,
        localAddress: '192.168.1.2',
        discovering: true,
        listening: true,
        nearby: [tablet],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncQuickAction(control: control)),
        ),
      );
      await tester.tap(find.byTooltip('Локальная синхронизация'));
      await tester.pumpAndSettle();
      expect(control.visibility, [true]);
      expect(tester.widget<SyncRadar>(find.byType(SyncRadar)).deviceIds, [
        'tablet',
      ]);
      await tester.ensureVisible(find.text('Планшет'));
      await tester.tap(find.text('Планшет'));
      await tester.pumpAndSettle();
      expect(control.calls, ['nearby:tablet:192.168.1.2']);

      control.emit(
        LocalSyncState(
          enrolled: true,
          busy: true,
          joining: true,
          pairReview: (
            peer: tablet,
            code: 'F2A7 97ED 01BC 57EA',
            canConfirm: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SyncPairCode), findsOneWidget);
      expect(find.text('Синхронизировать'), findsNothing);
      await tester.ensureVisible(find.text('Коды совпадают'));
      await tester.tap(find.text('Коды совпадают'));
      expect(control.calls.last, 'confirm-nearby:true');

      control.emit(LocalSyncState(enrolled: true, localAddress: '192.168.1.2'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Показать QR'));
      await tester.tap(find.text('Показать QR'));
      await tester.pumpAndSettle();
      expect(control.calls.last, 'invite:192.168.1.2');
      control.emit(
        LocalSyncState(
          enrolled: true,
          localAddress: '192.168.1.2',
          invitation: 'aW52aXRhdGlvbg==',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SyncInvitationQr), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      expect(control.visibility, [true, false]);
    },
  );

  testWidgets('the displayed Pulse QR can be read back from an image', (
    tester,
  ) async {
    final boundary = GlobalKey();
    const invitation = 'aW52aXRhdGlvbg==';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundary,
              child: const SyncInvitationQr(invitation: invitation),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final decoded = await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        return await decodeSyncInvitationImage(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    expect(decoded, invitation);
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
    reduceMotion(tester);
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
    reduceMotion(tester);
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
    'quick sync compares versions and resolves the displayed alternatives',
    (tester) async {
      reduceMotion(tester);
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
                task.copyWith(title: 'Задача', description: 'Version $id'),
              ),
            ),
        ],
      };
      control.state = LocalSyncState(
        enrolled: true,
        deviceId: 'a',
        conflictCount: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SyncQuickAction(control: control)),
        ),
      );
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Конфликты: 1'));
      await tester.pumpAndSettle();
      expect(find.byType(SyncSettingsPanel), findsNothing);
      expect(find.text('Разрешение конфликтов синхронизации'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Только различия'));
      await tester.pumpAndSettle();
      expect(find.text('Оставить локальную'), findsNothing);
      expect(find.text('Оставить удалённую'), findsNothing);
      expect(find.text('Выбрать более новую'), findsNothing);
      final confirm = find.widgetWithText(FilledButton, 'Подтвердить версию');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.byTooltip('Выбрать версию: Это устройство'));
      await tester.pumpAndSettle();
      expect(control.calls, isEmpty);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Описание'), 70);
      await tester.pumpAndSettle();
      expect(find.text('Название'), findsNothing);
      expect(find.text('Version a', findRichText: true), findsOneWidget);
      expect(find.text('Version b', findRichText: true), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(control.resolvedBasis, {'a', 'b'});
      expect(control.calls, ['resolve:a']);
      expect(find.text('Конфликтов нет.'), findsOneWidget);
      await tester.tap(find.byTooltip('Назад к синхронизации'));
      await tester.pumpAndSettle();
      expect(find.text('Синхронизация'), findsOneWidget);
    },
  );
  testWidgets('wide conflict panel keeps the list beside aligned versions', (
    tester,
  ) async {
    reduceMotion(tester);
    await tester.binding.setSurfaceSize(const Size(1240, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final first = Task.blank().copyWith(title: 'Первый конфликт');
    final second = Task.blank().copyWith(title: 'Второй конфликт');
    control.variants = {
      for (final task in [first, second])
        task.id: [
          for (final id in ['a', 'b'])
            SyncRevision(
              id: '${task.id}:$id',
              deviceId: id,
              entityId: task.id,
              parents: [],
              payload: TaskSyncCodec.encode(
                task.copyWith(
                  description: '${task.title} · $id',
                  status: id == 'a'
                      ? TaskStatus.inProgress
                      : TaskStatus.notStarted,
                ),
              ),
            ),
        ],
    };
    control.state = LocalSyncState(
      enrolled: true,
      deviceId: 'a',
      conflictCount: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SyncQuickAction(control: control)),
      ),
    );
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Конфликты: 2'));
    await tester.pumpAndSettle();

    final listTitle = find.text('Записи с конфликтами');
    expect(listTitle, findsOneWidget);
    await tester.tap(find.text(second.title));
    await tester.pumpAndSettle();
    final local = find.text('${second.title} · a', findRichText: true);
    final remote = find.text('${second.title} · b', findRichText: true);
    expect(
      tester.getTopLeft(listTitle).dx,
      lessThan(tester.getTopLeft(local).dx),
    );
    expect(tester.getTopLeft(local).dx, lessThan(tester.getTopLeft(remote).dx));
    expect(tester.getTopLeft(local).dy, tester.getTopLeft(remote).dy);
    expect(find.text('Название'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Только различия'));
    await tester.pumpAndSettle();
    expect(find.text('Название'), findsNothing);
    expect(find.text('Изменённых полей: 2'), findsOneWidget);
    await tester.tap(find.text('Объединить вручную'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Выбрать версию: Другое устройство'), findsNothing);
    await tester.tap(remote);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить объединение'));
    await tester.pumpAndSettle();
    final merged = TaskSyncCodec.decode(control.resolvedPayload!);
    expect(merged.description, '${second.title} · b');
    expect(merged.status, TaskStatus.inProgress);
    expect(control.resolvedBasis, {'${second.id}:a', '${second.id}:b'});
    await tester.tap(find.byTooltip('Выбрать версию: Это устройство'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Выбрать версию: Другое устройство'));
    await tester.pumpAndSettle();
    expect(control.calls, ['resolve:${second.id}:a']);
    await tester.tap(find.text('Подтвердить версию'));
    await tester.pumpAndSettle();
    expect(control.calls, ['resolve:${second.id}:a', 'resolve:${first.id}:b']);
    expect(control.resolvedBasis, {'${first.id}:a', '${first.id}:b'});
    expect(control.resolvedPayload, isNull);
  });
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
