import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits_api/habits_api.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/habits/data/habit_model_extension.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/lifegraph/data/graph_storage_repository.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/sync/data/sync_canvas_boards.dart';
import 'package:life_os/features/sync/data/sync_markdown_files.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:lifegraph_plugin/graph_storage_settings.dart';
import 'package:lifegraph_plugin/canvas_board.dart';
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:sync_plugin/sync_native.dart';
import 'package:tasks_api/tasks_api.dart';

class MemorySyncSecrets implements SyncSecretStore {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    if (failWrites) throw StateError('Vault locked');
    value = text;
  }
}

class _MemoryNetworkSettings implements SyncNetworkSettings {
  SyncNetworkPreference value = (address: null, listening: false);

  @override
  Future<SyncNetworkPreference> read() async => value;

  @override
  Future<void> write(SyncNetworkPreference preference) async {
    value = preference;
  }
}

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _GateSyncData implements LocalSyncData {
  @override
  Future<Map<String, String>> entityNames({bool liveOnly = false}) =>
      inner.entityNames(liveOnly: liveOnly);
  @override
  Future<List<LocalSyncPending>> pendingRepairs() => inner.pendingRepairs();
  @override
  Future<void> repair(
    SyncRevision revision,
    String payload,
    Set<String> expected,
  ) => inner.repair(revision, payload, expected);
  _GateSyncData(this.inner) : gate = _GateStore(inner.store);
  final LocalSyncData inner;
  final _GateStore gate;
  @override
  SyncStore get store => gate;
  @override
  Future<SyncIdentity?> existingIdentity() => inner.existingIdentity();
  @override
  Future<bool> canJoin() => inner.canJoin();
  @override
  Future<void> enroll(
    String datasetId,
    String deviceId, {
    required bool requireEmpty,
  }) => inner.enroll(datasetId, deviceId, requireEmpty: requireEmpty);
  @override
  Future<List<SyncRevision>> pendingRevisions() => inner.pendingRevisions();
  @override
  Future<Map<String, List<SyncRevision>>> conflicts() => inner.conflicts();
  @override
  Future<void> resolve(
    SyncRevision chosen,
    Set<String> expected, {
    String? mergedPayload,
  }) => inner.resolve(chosen, expected, mergedPayload: mergedPayload);
}

class _GateStore implements SyncStore {
  _GateStore(this.inner);
  final SyncStore inner;
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<SyncIdentity> identity() => inner.identity();
  @override
  Future<SyncBatch> readFeed({int after = 0, int limit = 100}) =>
      inner.readFeed(after: after, limit: limit);
  @override
  Future<SyncFeedPlan> planFeed({required int after}) =>
      inner.planFeed(after: after);
  @override
  Future<int> receivedCursor(String deviceId) => inner.receivedCursor(deviceId);
  @override
  Future<void> receive(SyncBatch batch) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await inner.receive(batch);
  }
}

void main() {
  _NetworkBinding();
  late SyncTlsMaterial certA, certB;
  late AppDatabase aDb, bDb;
  late DriftSyncStore aData, bData;
  late MemorySyncSecrets aSecrets, bSecrets;
  late LanSyncService a, b;
  LanSyncOptions options(SyncTlsMaterial cert, {int port = 0}) =>
      LanSyncOptions(
        port: port,
        bindAddress: '127.0.0.1',
        timeout: const Duration(seconds: 4),
        pairingTimeout: const Duration(seconds: 8),
        identityFactory: (id) async =>
            SyncTlsMaterial(id, cert.certificatePem, cert.privateKeyPem),
      );
  Future<void> pair() async {
    await a.createSpace();
    await a.invite('127.0.0.1');
    final pending = a.states.firstWhere((s) => s.awaitingApproval != null);
    final joining = b.join(a.state.invitation!, '127.0.0.1');
    final request = (await pending.timeout(
      const Duration(seconds: 10),
    )).awaitingApproval!;
    await a.approve(request.id);
    await joining;
    expect(a.state.peers, hasLength(1));
    expect(b.state.peers, hasLength(1));
  }

  Future<int> request(
    Map<String, Object?> body, {
    String? token,
    String? deviceId,
    String path = '/v1/hello',
  }) async {
    final client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    try {
      final r = await client.postUrl(
        Uri.parse(a.state.endpoint!).replace(path: path),
      );
      r.headers.contentType = ContentType.json;
      if (token != null) {
        r.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (deviceId != null) r.headers.set('X-Life-Device', deviceId);
      r.write(jsonEncode(body));
      final response = await r.close();
      await response.drain<void>();
      return response.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  test(
    'radar discovers a visible peer and pairing needs both confirmations',
    () async {
      await a.stop();
      await b.stop();
      final reservation = await RawDatagramSocket.bind('127.0.0.1', 0);
      final port = reservation.port;
      reservation.close();
      LanSyncOptions nearbyOptions(
        SyncTlsMaterial cert,
        String host,
        String target,
      ) => LanSyncOptions(
        port: 0,
        bindAddress: host,
        discoveryPort: port,
        discoveryTargets: [target],
        timeout: const Duration(seconds: 4),
        pairingTimeout: const Duration(seconds: 8),
        identityFactory: (id) async =>
            SyncTlsMaterial(id, cert.certificatePem, cert.privateKeyPem),
      );
      a = LanSyncService(
        data: aData,
        secrets: aSecrets,
        deviceName: 'PC',
        options: nearbyOptions(certA, '127.0.0.1', '127.0.0.2'),
      );
      b = LanSyncService(
        data: bData,
        secrets: bSecrets,
        deviceName: 'Tablet',
        options: nearbyOptions(certB, '127.0.0.2', '127.0.0.1'),
      );
      await a.start();
      await b.start();
      await a.createSpace();
      await a.listen('127.0.0.1');
      await a.setDiscoveryVisible(true);
      final discovery = b.states.firstWhere((s) => s.nearby.isNotEmpty);
      await b.setDiscoveryVisible(true);
      final discovered = (await discovery.timeout(
        const Duration(seconds: 6),
      )).nearby.single;
      expect(discovered.name, 'PC');
      expect(discovered.endpoint, a.state.endpoint);

      await a.setDiscoveryVisible(false);
      await expectLater(
        b.joinNearby(discovered.id, '127.0.0.2'),
        throwsA(isA<LocalSyncException>()),
      );
      expect(a.state.awaitingApproval, isNull);
      await a.setDiscoveryVisible(true);
      expect(a.state.invitation, isNull);

      final declinedRequest = a.states.firstWhere(
        (s) => s.awaitingApproval != null,
      );
      final declined = expectLater(
        b.joinNearby(discovered.id, '127.0.0.2'),
        throwsA(isA<LocalSyncException>()),
      );
      final first = await declinedRequest.timeout(const Duration(seconds: 6));
      final readyToDecline = b.states.firstWhere(
        (s) => s.pairReview?.canConfirm == true,
      );
      await a.approve(first.awaitingApproval!.id);
      await readyToDecline.timeout(const Duration(seconds: 6));
      await b.confirmNearby(false);
      await declined.timeout(const Duration(seconds: 6));
      expect(a.state.confirmingDevice, isNull);
      expect(a.state.peers, isEmpty);
      expect(await bData.existingIdentity(), isNull);

      final pending = a.states.firstWhere((s) => s.awaitingApproval != null);
      final joining = b.joinNearby(discovered.id, '127.0.0.2');
      final firstReview = await pending.timeout(const Duration(seconds: 6));
      expect(firstReview.awaitingApproval!.name, 'Tablet');
      expect(
        firstReview.pairingCode,
        matches(r'^[A-F0-9]{4}( [A-F0-9]{4}){3}$'),
      );
      expect(firstReview.pairingCode, b.state.pairReview?.code);
      expect(a.state.peers, isEmpty);
      expect(b.state.peers, isEmpty);

      final ready = b.states.firstWhere(
        (s) => s.pairReview?.canConfirm == true,
      );
      await a.approve(firstReview.awaitingApproval!.id);
      await ready.timeout(const Duration(seconds: 6));
      expect(a.state.pairingCode, b.state.pairReview?.code);
      expect(await bData.existingIdentity(), isNull);
      expect(a.state.peers, isEmpty);
      await b.confirmNearby(true);
      await joining.timeout(const Duration(seconds: 6));
      expect(a.state.peers.single.name, 'Tablet');
      expect(b.state.peers.single.name, 'PC');
      expect(b.state.nearby.single.id, discovered.id);
      expect(a.state.pairingCode, isNull);
      expect(b.state.pairReview, isNull);
      await b.setDiscoveryVisible(false);
      expect(b.state.nearby, isEmpty);
      await b.synchronize(a.state.deviceId!);
    },
  );

  test(
    'both devices publish the names exchanged during completed pairing',
    () async {
      await b.stop();
      b = LanSyncService(
        data: bData,
        secrets: bSecrets,
        deviceName: 'android',
        resolveDeviceName: () async => 'Redmi Pad Pro',
        options: options(certB),
      );
      await b.start();
      await a.createSpace();
      await a.invite('127.0.0.1');
      final pending = a.states.firstWhere((s) => s.awaitingApproval != null);
      final joining = b.join(a.state.invitation!, '127.0.0.1');
      final request = (await pending).awaitingApproval!;
      expect(request.name, 'Redmi Pad Pro');
      expect(a.state.peers, isEmpty);
      expect(b.state.peers, isEmpty);
      final confirming = a.states.firstWhere((s) => s.confirmingDevice != null);
      await a.approve(request.id);
      final confirmation = await confirming;
      expect(confirmation.confirmingDevice, 'Redmi Pad Pro');
      expect(confirmation.peers, isEmpty);
      await joining;
      expect(a.state.confirmingDevice, isNull);
      expect(a.state.peers.single.name, 'Redmi Pad Pro');
      expect(b.state.peers.single.name, 'Computer');
      await b.synchronize(b.state.peers.single.id);
    },
  );

  test(
    'anonymous requests and forged batch identities never access data',
    () async {
      await pair();
      final identity = (await aData.existingIdentity())!;
      expect(
        await request({'protocol': 1, 'datasetId': identity.datasetId}),
        400,
      );
      final credential = jsonDecode(bSecrets.value!) as Map<String, dynamic>;
      final peer = (credential['peers'] as List).single as Map<String, dynamic>;
      final revision = SyncRevision(
        id: 'forged',
        deviceId: identity.deviceId,
        entityId: 'task',
        parents: [],
        payload: null,
      );
      expect(
        await request(
          {
            'protocol': 1,
            'datasetId': identity.datasetId,
            'batch': {
              'datasetId': identity.datasetId,
              'deviceId': identity.deviceId,
              'after': 0,
              'entries': [
                {'sequence': 1, 'revision': jsonDecode(revision.encode())},
              ],
            },
          },
          token: peer['token'] as String,
          deviceId: credential['deviceId'] as String,
          path: '/v1/push',
        ),
        400,
      );
      expect((await aData.readFeed()).entries, isEmpty);
    },
  );
  test(
    'wrong TLS fingerprint cannot consume the invitation or enroll the client',
    () async {
      await a.createSpace();
      await a.invite('127.0.0.1');
      final m =
          jsonDecode(utf8.decode(base64Url.decode(a.state.invitation!)))
              as Map<String, dynamic>;
      m['fingerprint'] = List.filled(64, '0').join();
      final wrong = base64UrlEncode(utf8.encode(jsonEncode(m)));
      await expectLater(b.join(wrong, '127.0.0.1'), throwsA(anything));
      expect(await bData.existingIdentity(), isNull);
      expect(a.state.awaitingApproval, isNull);
      expect(a.state.invitation, isNotNull);
    },
  );
  test(
    'host rejection consumes the invitation without granting access',
    () async {
      await a.createSpace();
      await a.invite('127.0.0.1');
      final invitation = a.state.invitation!;
      final pending = a.states.firstWhere((s) => s.awaitingApproval != null);
      final joining = expectLater(
        b.join(invitation, '127.0.0.1'),
        throwsA(anything),
      );
      final nonce = (await pending).awaitingApproval!.id;
      expect(await bData.existingIdentity(), isNull);
      expect(a.state.peers, isEmpty);
      await a.reject(nonce);
      await joining;
      await expectLater(b.join(invitation, '127.0.0.1'), throwsA(anything));
      expect(a.state.peers, isEmpty);
      expect(b.state.peers, isEmpty);
    },
  );
  test(
    'legacy pairs require a one-time network check before exchanging data',
    () async {
      await pair();
      final old = jsonDecode(aSecrets.value!) as Map<String, dynamic>;
      final saved = (old['peers'] as List).single as Map<String, dynamic>;
      saved.remove('verified');
      aSecrets.value = jsonEncode(old);
      await a.stop();
      await a.start();
      final id = a.state.unverifiedPeers.single.id;
      expect(a.state.peers, isEmpty);
      await expectLater(a.synchronize(id), throwsA(isA<LocalSyncException>()));
      await a.verifyPair(id);
      expect(a.state.unverifiedPeers, isEmpty);
      expect(a.state.peers.single.id, id);
      await a.synchronize(id);
      await a.stop();
      await a.start();
      expect(a.state.peers.single.id, id);
    },
  );

  test(
    'a populated independent database is preserved and cannot join automatically',
    () async {
      final repo = TasksRepository(TasksDao(bDb, journal: bData));
      final task = Task.blank();
      await repo.addTask(task);
      await a.createSpace();
      await a.invite('127.0.0.1');
      await expectLater(
        b.join(a.state.invitation!, '127.0.0.1'),
        throwsA(isA<LocalSyncException>()),
      );
      expect(await bData.existingIdentity(), isNull);
      expect((await repo.getById(task.id))!.title, task.title);
      expect(b.state.listening, isFalse);
      expect(a.state.invitation, isNotNull);
    },
  );
  test(
    'revocation prevents later pull and push while preserving local data',
    () async {
      await pair();
      final id = a.state.peers.single.id;
      await a.revoke(id);
      final repo = TasksRepository(TasksDao(bDb, journal: bData));
      final task = Task.blank();
      await repo.addTask(task);
      await expectLater(
        b.synchronize(b.state.peers.single.id),
        throwsA(anything),
      );
      expect(await aDb.select(aDb.tasks).get(), isEmpty);
      expect(await repo.getById(task.id), isNotNull);
      expect((jsonDecode(aSecrets.value!)['peers'] as List), isEmpty);
      expect(b.state.peers, isEmpty);
    },
  );
  test(
    'offline task is delivered after retry when the trusted peer restarts',
    () async {
      await pair();
      final peerId = b.state.peers.single.id;
      await b.synchronize(peerId);
      final lastExchange = b.state.lastSync;
      final port = Uri.parse(a.state.endpoint!).port;
      final old = aSecrets.value;
      await a.stop();

      final tasksA = TasksRepository(TasksDao(aDb, journal: aData));
      final tasksB = TasksRepository(TasksDao(bDb, journal: bData));
      final offline = Task.blank().copyWith(title: 'Created offline');
      await tasksB.addTask(offline);
      await expectLater(
        b.synchronize(peerId),
        throwsA(isA<LocalSyncException>()),
      );
      expect(b.state.error, isNotNull);
      expect(b.state.lastSync, lastExchange);
      expect(await tasksA.getById(offline.id), isNull);

      a = LanSyncService(
        data: aData,
        secrets: aSecrets,
        options: options(certA, port: port),
      );
      await a.start();
      expect(a.state.peers, hasLength(1));
      expect(aSecrets.value, old);
      await a.listen('127.0.0.1');
      await b.synchronize(peerId);
      await b.synchronize(peerId);
      expect(b.state.error, isNull);
      expect((await tasksA.getAllTasks()).single.title, offline.title);
    },
  );
  test(
    'startup restores the selected address and listener preference',
    () async {
      await a.stop();
      final settings = _MemoryNetworkSettings();
      var addresses = ['192.168.10.2', '192.168.20.2'];
      a = LanSyncService(
        data: aData,
        secrets: aSecrets,
        networkSettings: settings,
        options: LanSyncOptions(
          port: 0,
          bindAddress: '127.0.0.1',
          addressProvider: () async => addresses,
          identityFactory: (id) async =>
              SyncTlsMaterial(id, certA.certificatePem, certA.privateKeyPem),
        ),
      );
      await a.start();
      expect(a.state.localAddress, addresses.first);
      expect(a.state.listening, isFalse);
      await a.createSpace();
      await a.listen(addresses.last);
      await a.stop();
      await a.start();
      expect(a.state.localAddress, addresses.last);
      expect(Uri.parse(a.state.endpoint!).host, addresses.last);
      expect(a.state.listening, isTrue);

      addresses = ['192.168.10.3'];
      await a.stop();
      await a.start();
      expect(Uri.parse(a.state.endpoint!).host, addresses.single);
      await a.closeListener();
      await a.stop();
      await a.start();
      expect(a.state.localAddress, addresses.single);
      expect(a.state.listening, isFalse);
    },
  );

  test(
    'stop rejects pending approval; an old approval cannot authorize a new request',
    () async {
      await a.createSpace();
      await a.invite('127.0.0.1');
      var pending = a.states.firstWhere((s) => s.awaitingApproval != null);
      var joining = expectLater(
        b.join(a.state.invitation!, '127.0.0.1'),
        throwsA(anything),
      );
      final old = (await pending).awaitingApproval!.id;
      await a.stop();
      await joining;
      expect(await bData.existingIdentity(), isNull);
      await a.start();
      await a.invite('127.0.0.1');
      pending = a.states.firstWhere((s) => s.awaitingApproval != null);
      joining = expectLater(
        b.join(a.state.invitation!, '127.0.0.1'),
        throwsA(anything),
      );
      final current = (await pending).awaitingApproval!.id;
      expect(current, isNot(old));
      await expectLater(a.approve(old), throwsA(anything));
      expect(a.state.peers, isEmpty);
      await a.reject(current);
      await joining;
    },
  );
  test('stop drains an admitted database write before returning', () async {
    await b.stop();
    final gated = _GateSyncData(bData);
    b = LanSyncService(data: gated, secrets: bSecrets, options: options(certB));
    await b.start();
    await pair();
    final task = Task.blank();
    await TasksRepository(TasksDao(aDb, journal: aData)).addTask(task);
    final syncing = expectLater(
      a.synchronize(a.state.peers.single.id),
      throwsA(anything),
    );
    await gated.gate.started.future.timeout(const Duration(seconds: 5));
    expect(b.state.busy, isTrue);
    expect(b.state.run?.phase, LocalSyncPhase.transferring);
    expect(b.state.run?.transfer?.active, {SyncSection.tasks});
    var stopped = false;
    final stopping = b.stop().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    gated.gate.release.complete();
    await stopping.timeout(const Duration(seconds: 5));
    expect(b.state.run?.phase, LocalSyncPhase.failed);
    await syncing;
    expect(stopped, isTrue);
    expect((await bDb.select(bDb.tasks).get()).single.id, task.id);
    await expectLater(
      Future.sync(() => b.synchronize('old')),
      throwsA(anything),
    );
  });
  test(
    'offline conflict remains visible until an explicit version is selected',
    () async {
      await pair();
      final repoA = TasksRepository(TasksDao(aDb, journal: aData));
      final repoB = TasksRepository(TasksDao(bDb, journal: bData));
      final task = Task.blank();
      await repoA.addTask(task);
      await a.synchronize(a.state.peers.single.id);
      final one = (await repoA.getById(task.id))!,
          two = (await repoB.getById(task.id))!;
      await repoA.updateTask(one.copyWith(title: 'Computer edit'));
      await repoB.updateTask(two.copyWith(title: 'Phone edit'));
      await a.synchronize(a.state.peers.single.id);
      expect(a.state.conflictCount, 1);
      final conflicts = await a.conflicts();
      final versions = conflicts[task.id]!;
      await a.resolve(versions.first, versions.map((r) => r.id).toSet());
      await a.synchronize(a.state.peers.single.id);
      expect(a.state.conflictCount, 0);
      expect(
        (await repoA.getById(task.id))!.title,
        (await repoB.getById(task.id))!.title,
      );
    },
  );

  setUpAll(() async {
    final certs = await Future.wait([
      generateSyncTlsIdentity('fixture-a'),
      generateSyncTlsIdentity('fixture-b'),
    ]);
    certA = certs[0];
    certB = certs[1];
  });
  setUp(() async {
    aDb = AppDatabase(NativeDatabase.memory());
    bDb = AppDatabase(NativeDatabase.memory());
    aData = DriftSyncStore(aDb);
    bData = DriftSyncStore(bDb);
    aSecrets = MemorySyncSecrets();
    bSecrets = MemorySyncSecrets();
    a = LanSyncService(
      data: aData,
      secrets: aSecrets,
      deviceName: 'Computer',
      options: options(certA),
    );
    b = LanSyncService(
      data: bData,
      secrets: bSecrets,
      deviceName: 'Phone',
      options: options(certB),
    );
    await a.start();
    await b.start();
  });
  tearDown(() async {
    await a.stop();
    await b.stop();
    await aDb.close();
    await bDb.close();
  });

  test(
    'LAN sync transfers habits, daily entries and Markdown with committed progress',
    () async {
      final directory = await Directory.systemTemp.createTemp('pulse_sync_');
      addTearDown(() async {
        expect(
          p.isWithin(
            await Directory.systemTemp.resolveSymbolicLinks(),
            await directory.resolveSymbolicLinks(),
          ),
          isTrue,
        );
        await directory.delete(recursive: true);
      });
      Future<GraphStorageRepository> storageFor(String name) async {
        final target = ValueNotifier(
          GraphStorageTarget(
            mode: GraphStorageMode.local,
            localPath: p.join(directory.path, name),
          ),
        );
        final folders = ValueNotifier(const VaultFolders());
        final storage = GraphStorageRepository(
          target: target,
          vaultFolders: folders,
          beforeSwitch: () async {},
        );
        addTearDown(() async {
          await storage.dispose();
          target.dispose();
          folders.dispose();
        });
        await storage.start();
        return storage;
      }

      final filesA = await storageFor('pc');
      final filesB = await storageFor('tablet');
      await filesB.selectTarget(
        const GraphStorageTarget(),
        copyExisting: false,
      );
      await a.stop();
      await b.stop();
      a = LanSyncService(
        data: aData,
        secrets: aSecrets,
        options: options(certA),
        reconcileNotes: SyncMarkdownFiles(
          aData,
          filesA,
          flushEdits: () async {},
        ).reconcile,
      );
      b = LanSyncService(
        data: bData,
        secrets: bSecrets,
        options: options(certB),
        reconcileNotes: SyncMarkdownFiles(
          bData,
          filesB,
          flushEdits: () async {},
        ).reconcile,
      );
      await a.start();
      await b.start();

      final habitsA = HabitsDao(aDb, capture: aData.trackHabit);
      final habitsB = HabitsDao(bDb, capture: bData.trackHabit);
      final habit = Habit.create(title: 'Чтение', type: const EveningHabit());
      await habitsA.createHabit(habit.toDrift());
      const day = '2026-11-22';
      await habitsA.setEntryStatus(habit.id, day, HabitEntryStatus.completed);
      final original = await filesA.createNote('Тема', '# Текст с ПК');
      final received = File(
        p.join(directory.path, 'tablet', 'Notes', 'Тема.md'),
      );
      await File(
        p.join(directory.path, 'pc', 'external.md'),
      ).writeAsString('external');
      await pair();

      final runs = <LocalSyncRun>[];
      final changes = b.states.listen((state) {
        if (state.run case final run?) runs.add(run);
      });
      addTearDown(changes.cancel);
      final mirrored = <LocalSyncRun>[];
      final mirrorChanges = a.states.listen((state) {
        if (state.run case final run?) {
          if (mirrored.isEmpty || !identical(mirrored.last, run)) {
            mirrored.add(run);
          }
        }
      });
      addTearDown(mirrorChanges.cancel);
      final peer = b.state.peers.single.id;
      await b.synchronize(peer);
      expect((await habitsB.getAllHabits()).single.title, habit.title);
      expect(
        (await habitsB.getEntry(habit.id, day))!.status,
        HabitEntryStatus.completed,
      );
      expect(await received.exists(), isFalse);
      expect(b.state.notesNeedFolder, isTrue);
      expect(
        await File(p.join(directory.path, 'tablet', 'external.md')).exists(),
        isFalse,
      );
      expect(
        runs.map((run) => run.phase),
        containsAllInOrder([
          LocalSyncPhase.connecting,
          LocalSyncPhase.transferring,
          LocalSyncPhase.applying,
          LocalSyncPhase.complete,
        ]),
      );
      expect(b.state.run!.transfer!.planned[SyncSection.habits], 2);
      expect(b.state.run!.transfer!.transferred[SyncSection.notes], 1);
      expect(b.state.run!.transfer!.done, b.state.run!.transfer!.total);
      expect(mirrored.first.phase, LocalSyncPhase.connecting);
      expect(
        mirrored.any(
          (run) => run.transfer?.active.contains(SyncSection.habits) == true,
        ),
        isTrue,
      );
      expect(mirrored[mirrored.length - 2].phase, LocalSyncPhase.applying);
      expect(mirrored.last.phase, LocalSyncPhase.complete);
      expect(a.state.busy, isFalse);
      expect(a.state.notesNeedFolder, isTrue);
      expect(
        a.state.run!.transfer!.transferred,
        b.state.run!.transfer!.transferred,
      );

      await filesB.selectTarget(
        GraphStorageTarget(
          mode: GraphStorageMode.local,
          localPath: p.join(directory.path, 'tablet'),
        ),
      );
      await b.synchronize(peer);
      expect(b.state.notesNeedFolder, isFalse);
      expect(await received.readAsString(), '# Текст с ПК');
      expect(filesB.graphMarkdownState.notes.single.title, 'Тема');

      const nextDay = '2026-11-23';
      await habitsA.setEntryStatus(habit.id, nextDay, HabitEntryStatus.skipped);
      await habitsB.setEntryStatus(
        habit.id,
        nextDay,
        HabitEntryStatus.completed,
      );
      await filesA.writeContent(original.absolutePath, 'Правка ПК');
      await filesB.writeContent(received.path, 'Правка планшета');
      await b.synchronize(peer);
      expect(await received.readAsString(), 'Правка планшета');
      expect(await filesA.readContent(original.absolutePath), 'Правка ПК');
      expect(await bDb.select(bDb.habitEntries).get(), hasLength(2));
      final conflicts = await b.conflicts();
      final noteConflict = conflicts.values.singleWhere(
        (versions) => versions.first.entityType == 'note',
      );
      final entryConflict = conflicts.values.singleWhere(
        (versions) => versions.first.entityType == 'habitEntry',
      );
      final chosenEntry = entryConflict.singleWhere(
        (version) =>
            HabitSyncCodec.decodeEntry(version.payload!).status ==
            HabitEntryStatus.completed,
      );
      await b.resolve(
        chosenEntry,
        entryConflict.map((version) => version.id).toSet(),
      );
      final chosenNote = noteConflict.singleWhere(
        (version) =>
            MarkdownSyncNote.decode(version.payload!).text == 'Правка планшета',
      );
      await b.resolve(
        chosenNote,
        noteConflict.map((version) => version.id).toSet(),
      );
      await b.synchronize(peer);
      expect(
        await filesA.readContent(original.absolutePath),
        'Правка планшета',
      );
      expect(
        (await habitsA.getEntry(habit.id, nextDay))!.status,
        HabitEntryStatus.completed,
      );

      final renamed = await filesB.renameMarkdownNote(
        received.path,
        'Новое имя',
      );
      await b.synchronize(peer);
      final renamedA = File(
        p.join(directory.path, 'pc', 'Notes', 'Новое имя.md'),
      );
      expect(await renamedA.readAsString(), 'Правка планшета');
      expect(await File(original.absolutePath).exists(), isFalse);
      await filesB.deleteMarkdownNote(renamed);
      await habitsB.deleteHabit(habit.id);
      await b.synchronize(peer);
      await b.synchronize(peer);
      expect(await renamedA.exists(), isFalse);
      expect(await habitsA.getAllHabits(), isEmpty);
      expect(await aDb.select(aDb.habitEntries).get(), isEmpty);
      expect(await b.conflicts(), isEmpty);
    },
  );
  test(
    'LAN sync transfers whole Canvas boards and preserves both conflict versions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final temporary = await Directory.systemTemp.createTemp(
        'pulse_board_lan_',
      );
      addTearDown(() async {
        expect(
          p.isWithin(
            await Directory.systemTemp.resolveSymbolicLinks(),
            await temporary.resolveSymbolicLinks(),
          ),
          isTrue,
        );
        await temporary.delete(recursive: true);
      });
      const sphereId = 'test-sphere';
      const geometry = {'x': 10, 'y': 20, 'width': 160, 'height': 80};
      final entity = {
        'id': 'pulse:task',
        'pulse': {'entityId': 'task'},
        'type': 'text',
        'text': 'Задача',
        ...geometry,
      };
      final nodes = [
        entity,
        {
          'id': 'note:text',
          'pulse': {'noteId': 'text'},
          'type': 'text',
          'text': 'С ПК',
          ...geometry,
        },
        {
          'id': 'note:markdown',
          'pulse': {'noteId': 'markdown', 'cachedText': 'Устаревший текст'},
          'type': 'file',
          'file': 'Notes/Тема.md',
          ...geometry,
        },
        {
          'id': 'group',
          'type': 'group',
          'label': 'Группа',
          'custom': {'order': 4},
          ...geometry,
        },
        {
          'id': 'note:external',
          'type': 'text',
          'text': 'Локальные данные',
          'pulse': {
            'noteId': 'external',
            'externalPath': p.join(temporary.path, 'personal.md'),
          },
          ...geometry,
        },
      ];
      final edges = [
        {'id': 'custom-edge', 'fromNode': 'group', 'toNode': 'pulse:task'},
      ];
      Map<String, Object> document(
        List<Map<String, Object>> boardNodes,
        List<Map<String, String>> boardEdges,
      ) => {
        'pulse': {'sphereId': sphereId, 'version': 1},
        'nodes': boardNodes,
        'edges': boardEdges,
      };
      Future<
        ({CanvasBoardSession session, SyncCanvasBoards sync, String backups})
      >
      fixture(String name, DriftSyncStore store, VaultFolders layout) async {
        final root = await Directory(p.join(temporary.path, name)).create();
        final vault = ObsidianVault();
        await vault.openVault(root.path);
        final target = ValueNotifier(
          const GraphStorageTarget(mode: GraphStorageMode.obsidian),
        );
        final folders = ValueNotifier(layout);
        final catalog = GraphNotesRepository(prefix: 'boards_$name');
        final storage = GraphStorageRepository(
          target: target,
          vaultFolders: folders,
          obsidian: vault,
          beforeSwitch: () async {},
        );
        addTearDown(() async {
          await storage.dispose();
          await catalog.dispose();
          await vault.dispose();
          target.dispose();
          folders.dispose();
        });
        await storage.start();
        await storage.createNote('Тема', '# Markdown уже есть');
        return (
          session: await storage.openCanvasBoard(sphereId),
          sync: SyncCanvasBoards(store, storage, catalog),
          backups: p.join(root.path, layout.backups),
        );
      }

      final pc = await fixture('pc', aData, const VaultFolders(notes: 'Notes'));
      final tablet = await fixture(
        'tablet',
        bData,
        const VaultFolders(notes: 'More/Notes'),
      );
      await pc.session.write(
        jsonEncode({
          ...document(nodes, edges),
          'custom': {'zoom': 3},
        }),
        expected: null,
      );
      final refreshed = <String>{};
      Future<bool> reconcile(
        SyncCanvasBoards sync, {
        bool received = false,
      }) async {
        await sync.reconcile(
          [sphereId],
          refresh: (ids) async => refreshed.addAll(ids),
          afterReceive: received,
        );
        return true;
      }

      await a.stop();
      await b.stop();
      a = LanSyncService(
        data: aData,
        secrets: aSecrets,
        options: options(certA),
        reconcileNotes: () => reconcile(pc.sync),
        applyNotes: () => reconcile(pc.sync, received: true),
      );
      b = LanSyncService(
        data: bData,
        secrets: bSecrets,
        options: options(certB),
        reconcileNotes: () => reconcile(tablet.sync),
        applyNotes: () async {
          if (await tablet.session.read() == null) {
            await tablet.session.write(
              jsonEncode(
                document([
                  {...entity, 'x': 999},
                ], []),
              ),
              expected: null,
            );
          }
          return reconcile(tablet.sync, received: true);
        },
      );
      await a.start();
      await b.start();
      await pair();
      final peer = b.state.peers.single.id;

      Future<CanvasBoardDocument> board(CanvasBoardSession session) async =>
          CanvasBoardDocument((await session.read())!);
      Future<void> move(CanvasBoardSession session, int x, String group) async {
        final raw = (await session.read())!;
        final doc = CanvasBoardDocument(raw);
        await session.write(
          jsonEncode({
            ...doc.data,
            'nodes': [
              for (final node in doc.nodes)
                switch (node['id']) {
                  'pulse:task' => {...node, 'x': x, 'width': 240},
                  'group' => {...node, 'label': group},
                  _ => node,
                },
            ],
          }),
          expected: raw,
        );
      }

      await b.synchronize(peer);
      expect(b.state.run!.transfer!.transferred[SyncSection.graph], 1);
      expect(refreshed, {sphereId});
      final first = await board(tablet.session);
      expect(
        first.nodes.map((node) => node['id']),
        nodes.map((node) => node['id']),
      );
      expect(first.nodes[0], entity);
      expect(first.nodes[1]['text'], 'С ПК');
      expect(first.nodes[2]['file'], 'More/Notes/Тема.md');
      expect(first.nodes[3], nodes[3]);
      expect(first.nodes[4]['text'], 'Локальный файл');
      expect(first.nodes[4]['pulse'], isNot(contains('externalPath')));
      expect(first.edges, edges);
      expect(first.data['custom'], {'zoom': 3});
      final tabletMd = p.join(
        temporary.path,
        'tablet',
        'More',
        'Notes',
        'Тема.md',
      );
      expect(
        first
            .notes(tablet.session.resolveNote)
            .singleWhere((note) => note.id == 'markdown')
            .document
            .source
            ?.path,
        tabletMd,
      );
      await b.synchronize(peer);
      for (final store in [aData, bData]) {
        expect(
          (await store.readFeed()).entries.where(
            (entry) => entry.revision.entityType == 'canvasBoard',
          ),
          hasLength(1),
        );
      }
      expect(await b.conflicts(), isEmpty);

      await move(pc.session, -80, 'Правка ПК');
      await move(tablet.session, 900, 'Правка планшета');
      await b.synchronize(peer);
      expect(
        (await board(pc.session)).nodes[0]['x'],
        (await board(tablet.session)).nodes[0]['x'],
      );
      final versions = (await b.conflicts()).values.single;
      expect(versions, hasLength(2));
      expect(
        versions.every((version) => version.entityType == 'canvasBoard'),
        isTrue,
      );
      int position(SyncRevision revision) =>
          (SyncCanvasBoard.decode(revision.payload!).document['nodes'] as List)
                  .first['x']
              as int;
      expect(versions.map(position), unorderedEquals([-80, 900]));
      final selected = versions.singleWhere(
        (version) => position(version) == 900,
      );
      await b.resolve(selected, versions.map((version) => version.id).toSet());
      await b.synchronize(peer);
      for (final session in [pc.session, tablet.session]) {
        final synced = await board(session);
        expect(synced.nodes[0]['x'], 900);
        expect(synced.nodes[0]['width'], 240);
        expect(synced.nodes[3]['label'], 'Правка планшета');
        expect(synced.edges, edges);
      }
      final backups = await Directory(pc.backups)
          .list()
          .where((file) => p.basename(file.path).startsWith('$sphereId.sync-'))
          .cast<File>()
          .asyncMap((file) => file.readAsString())
          .toList();
      expect(
        backups.map((raw) => CanvasBoardDocument(raw).nodes[0]['x']),
        contains(-80),
      );

      final raw = (await tablet.session.read())!;
      final changed = CanvasBoardDocument(raw);
      await tablet.session.write(
        jsonEncode({
          ...changed.data,
          'nodes': changed.nodes
              .where((node) => node['id'] != 'note:markdown')
              .toList(),
          'edges': [],
        }),
        expected: raw,
      );
      await b.synchronize(peer);
      await b.synchronize(peer);
      expect(
        (await board(pc.session)).nodes.map((node) => node['id']),
        isNot(contains('note:markdown')),
      );
      expect((await board(pc.session)).edges, isEmpty);
      expect(await File(tabletMd).readAsString(), '# Markdown уже есть');
      expect(await b.conflicts(), isEmpty);
    },
  );

  test('missing local or peer IP is reported before pairing', () async {
    for (final request in [
      () => a.listen('  '),
      () => a.invite(''),
      () => a.join('invalid invitation', ''),
    ]) {
      await expectLater(
        request(),
        throwsA(same(LocalSyncException.missingLocalIp)),
      );
    }
    expect(a.state.listening, isFalse);
    await a.createSpace();
    await a.invite('127.0.0.1');
    final invitation =
        jsonDecode(utf8.decode(base64Url.decode(a.state.invitation!)))
            as Map<String, dynamic>;
    invitation.remove('endpoint');
    await expectLater(
      b.join(base64UrlEncode(utf8.encode(jsonEncode(invitation))), '127.0.0.1'),
      throwsA(
        isA<LocalSyncException>().having(
          (error) => error.message,
          'message',
          contains('Не указан IP второго устройства'),
        ),
      ),
    );
    expect(b.state.listening, isFalse);
  });
  test(
    'TLS pairing requires approval and synchronizes data in both directions',
    () async {
      expect(a.state.listening, isFalse);
      expect(await aData.existingIdentity(), isNull);
      await pair();
      final tasksA = TasksRepository(TasksDao(aDb, journal: aData));
      final tasksB = TasksRepository(TasksDao(bDb, journal: bData));
      final first = Task.blank().copyWith(
        title: 'Сеть "test"',
        tags: [const Tag(id: 0, name: 'Focus', colorHex: 123)],
      );
      await tasksA.addTask(first);
      await b.synchronize(b.state.peers.single.id);
      expect((await tasksB.getById(first.id))!.title, first.title);
      expect((await tasksB.getById(first.id))!.tags.single.colorHex, 123);
      final second = Task.blank().copyWith(title: 'From phone');
      await tasksB.addTask(second);
      await a.synchronize(a.state.peers.single.id);
      expect((await tasksA.getById(second.id))!.title, second.title);
      expect(a.state.lastSync, isNotNull);
      await a.synchronize(a.state.peers.single.id);
      expect(
        (await aData.readFeed()).entries.length,
        (await bData.readFeed()).entries.length,
      );
    },
  );
  test(
    'secure storage failure keeps networking disabled and retry never uses plaintext fallback',
    () async {
      await b.stop();
      final failing = MemorySyncSecrets()..failWrites = true;
      b = LanSyncService(
        data: bData,
        secrets: failing,
        options: options(certB),
      );
      await b.start();
      expect(b.state.error, isNotNull);
      expect(b.state.listening, isFalse);
      await expectLater(b.listen('127.0.0.1'), throwsA(anything));
      expect(failing.value, isNull);
      expect(await bData.existingIdentity(), isNull);
      failing.failWrites = false;
      await b.listen('127.0.0.1');
      expect(b.state.listening, isTrue);
      expect(failing.value, isNotNull);
    },
  );
  test(
    'stopping partial startup drains key preparation without late enrollment',
    () async {
      await b.stop();
      final started = Completer<void>(), release = Completer<void>();
      final secrets = MemorySyncSecrets();
      b = LanSyncService(
        data: bData,
        secrets: secrets,
        options: LanSyncOptions(
          port: 0,
          bindAddress: '127.0.0.1',
          identityFactory: (id) async {
            started.complete();
            await release.future;
            return SyncTlsMaterial(
              id,
              certB.certificatePem,
              certB.privateKeyPem,
            );
          },
        ),
      );
      final starting = b.start();
      await started.future;
      var finished = false;
      final closing = b.stop().then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      release.complete();
      await starting;
      await closing;
      expect(secrets.value, isNull);
      expect(await bData.existingIdentity(), isNull);
      expect(b.state.listening, isFalse);
    },
  );
  test(
    'data created during pairing cannot be replaced after approval',
    () async {
      await a.createSpace();
      await a.invite('127.0.0.1');
      final pending = a.states.firstWhere((s) => s.awaitingApproval != null);
      final joining = expectLater(
        b.join(a.state.invitation!, '127.0.0.1'),
        throwsA(anything),
      );
      final nonce = (await pending).awaitingApproval!.id;
      final task = Task.blank();
      await TasksRepository(TasksDao(bDb, journal: bData)).addTask(task);
      await a.approve(nonce);
      await joining;
      expect(await bData.existingIdentity(), isNull);
      expect((await bDb.select(bDb.tasks).get()).single.id, task.id);
      expect(a.state.peers, isEmpty);
      expect(b.state.peers, isEmpty);
      expect((jsonDecode(aSecrets.value!)['peers'] as List), isEmpty);
    },
  );
  test(
    'approved re-pairing within the same dataset preserves data after access revocation',
    () async {
      await pair();
      final task = Task.blank();
      await TasksRepository(TasksDao(bDb, journal: bData)).addTask(task);
      final identity = (await bData.existingIdentity())!;
      await a.revoke(a.state.peers.single.id);
      await a.invite('127.0.0.1');
      final pending = a.states.firstWhere((s) => s.awaitingApproval != null);
      final joining = b.join(a.state.invitation!, '127.0.0.1');
      await a.approve((await pending).awaitingApproval!.id);
      await joining;
      expect((await bData.existingIdentity())!.deviceId, identity.deviceId);
      expect((await bDb.select(bDb.tasks).get()).single.id, task.id);
      await b.synchronize(b.state.peers.single.id);
      expect((await aDb.select(aDb.tasks).get()).single.id, task.id);
    },
  );
  test(
    'pending offline tag collision can be repaired and propagated over TLS',
    () async {
      await pair();
      final repoA = TasksRepository(TasksDao(aDb, journal: aData)),
          repoB = TasksRepository(TasksDao(bDb, journal: bData));
      await repoA.addTask(
        Task.blank().copyWith(
          tags: [const Tag(id: 0, name: 'Same', colorHex: 1)],
        ),
      );
      await repoB.addTask(
        Task.blank().copyWith(
          tags: [const Tag(id: 0, name: 'Same', colorHex: 2)],
        ),
      );
      await a.synchronize(a.state.peers.single.id);
      expect(a.state.pendingCount, 4);
      final choice = (await a.pending()).firstWhere(
        (p) => p.revision.entityType == 'tag',
      );
      final tag = HierarchySyncCodec.decodeTag(choice.revision.payload!);
      await a.repair(
        choice.revision,
        HierarchySyncCodec.tag(tag.copyWith(name: 'Different')),
        choice.basis,
      );
      await a.synchronize(a.state.peers.single.id);
      expect(a.state.pendingCount, 0);
      expect(await b.pending(), isEmpty);
      expect(await bDb.select(bDb.tasks).get(), hasLength(2));
    },
  );
  test(
    'plaintext and non-LAN invitation endpoints are rejected before connecting',
    () async {
      await a.createSpace();
      await a.invite('127.0.0.1');
      final m =
          jsonDecode(utf8.decode(base64Url.decode(a.state.invitation!)))
              as Map<String, dynamic>;
      for (final endpoint in [
        'http://127.0.0.1:48766/',
        'https://example.com/',
        'https://8.8.8.8/',
      ]) {
        final text = base64UrlEncode(
          utf8.encode(jsonEncode({...m, 'endpoint': endpoint})),
        );
        await expectLater(
          b.join(text, '127.0.0.1'),
          throwsA(isA<LocalSyncException>()),
        );
      }
      expect(b.state.listening, isFalse);
      expect(await bData.existingIdentity(), isNull);
      expect(a.state.invitation, isNotNull);
    },
  );
  test(
    'pending time against a deleted task can be explicitly moved to a live task',
    () async {
      await pair();
      final repoA = TasksRepository(TasksDao(aDb, journal: aData));
      final removed = Task.blank(), target = Task.blank();
      await repoA.addTask(removed);
      await repoA.addTask(target);
      await a.synchronize(a.state.peers.single.id);
      final log = WorkLog.blank(
        removed.id,
      ).copyWith(description: 'Retain my time');
      await bData.saveWorkLog(log, expectedHeads: {});
      await repoA.deleteTask(removed.id);
      await a.synchronize(a.state.peers.single.id);
      final choice = (await a.pending()).singleWhere(
        (r) => r.revision.entityType == 'workLog',
      );
      final live = await a.entityNames(liveOnly: true);
      expect(live.containsKey(removed.id), isFalse);
      expect(live.containsKey(target.id), isTrue);
      await a.repair(
        choice.revision,
        WorkLogSyncCodec.encode(log.copyWith(taskId: target.id)),
        choice.basis,
      );
      await a.synchronize(a.state.peers.single.id);
      expect(a.state.pendingCount, 0);
      final saved = (await bDb.select(bDb.workLogs).get()).single;
      expect(saved.id, log.id);
      expect(saved.taskId, target.id);
      expect(saved.description, 'Retain my time');
      expect((await bDb.select(bDb.tasks).get()).map((t) => t.id), [target.id]);
    },
  );
}
