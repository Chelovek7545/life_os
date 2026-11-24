import 'package:plugin_runtime/plugin_runtime.dart';
import 'local_sync_contracts.dart';
import 'sync_models.dart';

String localSyncDeviceName() => 'Устройство';

Future<SyncTlsMaterial> generateSyncTlsIdentity(String deviceId) =>
    Future.error(UnsupportedError('TLS identity is unavailable on web.'));

class LanSyncService implements AppPlugin, LocalSyncControl {
  @override
  int get generation => 0;
  @override
  Future<Map<String, String>> entityNames({bool liveOnly = false}) async => {};
  @override
  Future<List<LocalSyncPending>> pending() async => [];
  @override
  Future<void> repair(
    SyncRevision revision,
    String payload,
    Set<String> expected,
  ) async => _unsupported();
  LanSyncService({
    required LocalSyncData data,
    required SyncSecretStore secrets,
    String deviceName = 'Устройство',
    Future<String?> Function()? resolveDeviceName,
    LanSyncOptions options = const LanSyncOptions(),
    Future<bool> Function()? reconcileNotes,
    Future<bool> Function()? applyNotes,
    Set<String> dependencies = const {},
  });
  Never _unsupported() =>
      throw UnsupportedError('LAN sync is available only on native platforms.');
  @override
  String get id => 'sync.local';
  @override
  Set<String> get dependencies => const {};
  @override
  LocalSyncState get state => LocalSyncState();
  @override
  Stream<LocalSyncState> get states => const Stream.empty();
  @override
  Future<void> start() async => _unsupported();
  @override
  Future<void> stop() async {}
  @override
  Future<List<String>> addresses() async => [];
  @override
  Future<void> createSpace() async => _unsupported();
  @override
  Future<void> listen(String host) async => _unsupported();
  @override
  Future<void> closeListener() async => _unsupported();
  @override
  Future<void> invite(String host) async => _unsupported();
  @override
  Future<void> join(String invitation, String host) async => _unsupported();
  @override
  Future<void> approve(String id) async => _unsupported();
  @override
  Future<void> reject(String id) async => _unsupported();
  @override
  Future<void> verifyPair(String id) async => _unsupported();
  @override
  Future<void> synchronize(String id) async => _unsupported();
  @override
  Future<void> revoke(String id) async => _unsupported();
  @override
  Future<Map<String, List<SyncRevision>>> conflicts() async => _unsupported();
  @override
  Future<void> resolve(SyncRevision chosen, Set<String> expected) async =>
      _unsupported();
}
