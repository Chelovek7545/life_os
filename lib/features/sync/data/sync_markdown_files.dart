import 'dart:convert';
import 'dart:io';

import 'package:life_os/features/lifegraph/data/graph_storage_repository.dart';
import 'package:sync_plugin/sync_logic.dart';

import 'drift_sync_store.dart';

class SyncMarkdownFiles {
  const SyncMarkdownFiles(this.store, this.storage, {required this.flushEdits});

  final DriftSyncStore store;
  final GraphStorageRepository storage;
  final Future<void> Function() flushEdits;

  Future<bool> reconcile() async {
    await flushEdits();
    try {
      return await storage.withMarkdownSyncFolder((folder) async {
        final snapshot = await folder.read();
        final files = <String, MarkdownSyncNote>{};
        for (final entry in snapshot.files.entries) {
          if (!MarkdownSyncNote.isPortable(entry.key)) continue;
          final note = MarkdownSyncNote(entry.key, entry.value);
          if (utf8.encode(note.encode()).length >
              SyncRevision.maxPayloadBytes) {
            throw const LocalSyncException(
              'Одна из Markdown-заметок превышает лимит синхронизации в 1 МБ.',
            );
          }
          if (files.containsKey(note.id)) {
            throw const LocalSyncException(
              'В папке Notes есть имена, различающиеся только регистром.',
            );
          }
          files[note.id] = note;
        }
        final plans = await store.stageExternalNotes('note', [
          (
            scope: folder.scope,
            idPrefix: null,
            payloads: files.map((id, note) => MapEntry(id, note.encode())),
            captureDeletes: snapshot.exists,
          ),
        ]);
        for (final plan in plans) {
          final current = files[plan.target.entityId];
          final payload = plan.target.payload;
          final desired = payload == null
              ? null
              : MarkdownSyncNote.decode(payload);
          await folder.write(
            (current ?? desired!).path,
            desired?.text,
            expected: current?.text,
          );
          await store.checkpointNote(folder.scope, plan.target);
        }
      });
    } on FileSystemException {
      throw const LocalSyncException(
        'Папка Notes недоступна или её содержимое изменилось. Повторите обмен.',
      );
    }
  }
}
