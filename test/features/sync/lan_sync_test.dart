import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
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
  Future<void> resolve(SyncRevision chosen, Set<String> expected) =>
      inner.resolve(chosen, expected);
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
    },
  );
  test(
    'credentials and trust survive restart without generating a new key',
    () async {
      await pair();
      final port = Uri.parse(a.state.endpoint!).port;
      final old = aSecrets.value;
      await a.stop();
      a = LanSyncService(
        data: aData,
        secrets: aSecrets,
        options: options(certA, port: port),
      );
      await a.start();
      expect(a.state.peers, hasLength(1));
      expect(aSecrets.value, old);
      await a.listen('127.0.0.1');
      await b.synchronize(b.state.peers.single.id);
      expect(b.state.lastSync, isNotNull);
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
    var stopped = false;
    final stopping = b.stop().then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    gated.gate.release.complete();
    await stopping.timeout(const Duration(seconds: 5));
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
