import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/core/database/database.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart' show PulsePanelSlots;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:sync_plugin/sync_native.dart';
import 'package:tasks_api/tasks_api.dart';

class _Secrets implements SyncSecretStore {
  String? value;
  int reads = 0;
  @override
  Future<String?> read() async {
    reads++;
    return value;
  }

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

void main() {
  test(
    'default application has no sync UI, listener or credential access',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = _Secrets();
      final app = DependencyContainer(
        database: AppDatabase(NativeDatabase.memory()),
        enableTelegram: false,
        enableObsidian: false,
        syncSecrets: secrets,
      );
      addTearDown(app.dispose);
      await app.init();
      expect(app.syncPlugin, isNull);
      expect(secrets.reads, 0);
      expect(app.ui.panelsFor(PulsePanelSlots.toolbar), isEmpty);
      expect(
        app.ui.settings.any((s) => s.id == 'sync.local.settings'),
        isFalse,
      );
      expect(await app.taskSyncStore.existingIdentity(), isNull);
    },
  );
  test(
    'enabled sync registers settings but leaves networking and enrollment explicit',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = _Secrets();
      final cert = await generateSyncTlsIdentity('fixture');
      final app = DependencyContainer(
        database: AppDatabase(NativeDatabase.memory()),
        enableTelegram: false,
        enableObsidian: false,
        enableSync: true,
        syncSecrets: secrets,
        syncOptions: LanSyncOptions(
          port: 0,
          bindAddress: '127.0.0.1',
          identityFactory: (id) async =>
              SyncTlsMaterial(id, cert.certificatePem, cert.privateKeyPem),
        ),
      );
      addTearDown(app.dispose);
      await app.init();
      expect(app.plugins.states.containsKey('sync.local'), isTrue);
      expect(app.ui.settings.any((s) => s.id == 'sync.local.settings'), isTrue);
      expect(
        app.ui.panelsFor(PulsePanelSlots.toolbar).single.id,
        'sync.local.quick',
      );
      expect(app.syncPlugin!.state.listening, isFalse);
      expect(await app.taskSyncStore.existingIdentity(), isNull);
      await app.syncPlugin!.createSpace();
      final task = Task.blank();
      await app.tasksRepository.addTask(task);
      expect((await app.taskSyncStore.readFeed()).entries, hasLength(1));
      await app.dispose();
      expect(app.ui.panelsFor(PulsePanelSlots.toolbar), isEmpty);
      expect(
        app.ui.settings.any((s) => s.id == 'sync.local.settings'),
        isFalse,
      );
    },
  );
}
