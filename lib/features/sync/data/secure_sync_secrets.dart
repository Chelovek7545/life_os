import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sync_plugin/sync_logic.dart';

class SecureSyncSecrets implements SyncSecretStore {
  SecureSyncSecrets({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'life_os.sync.identity.v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
}
