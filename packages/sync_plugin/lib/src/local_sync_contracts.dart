import 'sync_models.dart';

abstract interface class SyncSecretStore {
  Future<String?> read();
  Future<void> write(String value);
}

abstract interface class LocalSyncData {
  SyncStore get store;
  Future<SyncIdentity?> existingIdentity();
  Future<void> enroll(
    String datasetId,
    String deviceId, {
    required bool requireEmpty,
  });
  Future<bool> canJoin();
  Future<List<SyncRevision>> pendingRevisions();
  Future<Map<String, List<SyncRevision>>> conflicts();
  Future<Map<String, String>> entityNames({bool liveOnly = false});
  Future<List<LocalSyncPending>> pendingRepairs();
  Future<void> repair(
    SyncRevision revision,
    String payload,
    Set<String> expected,
  );
  Future<void> resolve(SyncRevision chosen, Set<String> expected);
}

class SyncTlsMaterial {
  const SyncTlsMaterial(this.deviceId, this.certificatePem, this.privateKeyPem);
  final String deviceId, certificatePem, privateKeyPem;
}

class LanSyncOptions {
  const LanSyncOptions({
    this.port = 48766,
    this.bindAddress = '0.0.0.0',
    this.timeout = const Duration(seconds: 15),
    this.pairingTimeout = const Duration(minutes: 2),
    this.identityFactory,
  });
  final int port;
  final String bindAddress;
  final Duration timeout, pairingTimeout;
  final Future<SyncTlsMaterial> Function(String deviceId)? identityFactory;
}

class LocalSyncException implements Exception {
  const LocalSyncException(this.message);
  static const missingLocalIp = LocalSyncException(
    'Укажите IP этого устройства. Выберите адрес Wi-Fi или Ethernet.',
  );
  final String message;
  @override
  String toString() => message;
}

class LocalSyncPeer {
  const LocalSyncPeer({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.fingerprint,
  });
  final String id, name, endpoint, fingerprint;
}

class LocalSyncPending {
  LocalSyncPending(this.revision, Iterable<String> basis)
    : basis = Set.unmodifiable(basis);
  final SyncRevision revision;
  final Set<String> basis;
}

enum LocalSyncPhase { connecting, transferring, applying, complete, failed }

class LocalSyncRun {
  const LocalSyncRun(this.peerId, this.phase, [this.transfer]);
  final String peerId;
  final LocalSyncPhase phase;
  final SyncTransferProgress? transfer;
}

class LocalSyncState {
  LocalSyncState({
    this.listening = false,
    this.busy = false,
    this.enrolled = false,
    this.endpoint,
    this.deviceId,
    this.deviceName = 'Это устройство',
    this.invitation,
    this.awaitingApproval,
    this.joining = false,
    this.confirmingDevice,
    this.error,
    this.lastSync,
    this.run,
    this.notesNeedFolder = false,
    Iterable<LocalSyncPeer> peers = const [],
    Iterable<LocalSyncPeer> unverifiedPeers = const [],
    this.conflictCount = 0,
    this.pendingCount = 0,
  }) : peers = List.unmodifiable(peers),
       unverifiedPeers = List.unmodifiable(unverifiedPeers);
  final bool listening, busy, enrolled;
  final String? endpoint, invitation, error, deviceId;
  final String deviceName;
  final LocalSyncPeer? awaitingApproval;
  final bool joining;
  final String? confirmingDevice;
  final List<LocalSyncPeer> peers;
  final List<LocalSyncPeer> unverifiedPeers;
  final DateTime? lastSync;
  final LocalSyncRun? run;
  final bool notesNeedFolder;
  final int conflictCount, pendingCount;
}

abstract interface class LocalSyncControl {
  Future<Map<String, String>> entityNames({bool liveOnly = false});
  Future<List<LocalSyncPending>> pending();
  Future<void> repair(
    SyncRevision revision,
    String payload,
    Set<String> expected,
  );
  int get generation;
  LocalSyncState get state;
  Stream<LocalSyncState> get states;
  Future<List<String>> addresses();
  Future<void> createSpace();
  Future<void> listen(String host);
  Future<void> closeListener();
  Future<void> invite(String host);
  Future<void> join(String invitation, String host);
  Future<void> approve(String id);
  Future<void> reject(String id);
  Future<void> verifyPair(String id);
  Future<void> synchronize(String id);
  Future<void> revoke(String id);
  Future<Map<String, List<SyncRevision>>> conflicts();
  Future<void> resolve(SyncRevision chosen, Set<String> expected);
}
