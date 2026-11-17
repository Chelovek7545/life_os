import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
