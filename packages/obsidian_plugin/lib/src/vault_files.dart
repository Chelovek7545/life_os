import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

typedef VaultEntry = ({
  String name,
  FileSystemEntityType type,
  DateTime modifiedAt,
});

abstract interface class VaultFiles {
  Future<FileSystemEntityType> type(String path, {bool followLinks = true});
  Future<List<VaultEntry>> list(String path);
  Future<String?> read(String path);
  Future<void> createDirectory(String path);
  Future<void> writeNew(String path, String content);
  Future<bool> replace(
    String path,
    String content, {
    required String? expected,
  });
  Future<void> delete(String path);
  Future<String> canonicalPath(String path);
  Stream<FileSystemEvent> watch(String path);
}

class LocalVaultFiles implements VaultFiles {
  const LocalVaultFiles();

  @override
  Future<FileSystemEntityType> type(String path, {bool followLinks = true}) =>
      FileSystemEntity.type(path, followLinks: followLinks);

  @override
  Future<List<VaultEntry>> list(String path) async => [
    await for (final entity in Directory(path).list(followLinks: false))
      if (entity is File || entity is Directory)
        (
          name: p.basename(entity.path),
          type: entity is File
              ? FileSystemEntityType.file
              : FileSystemEntityType.directory,
          modifiedAt: entity is File
              ? (await entity.stat()).modified
              : DateTime.fromMillisecondsSinceEpoch(0),
        ),
  ];

  @override
  Future<String?> read(String path) async {
    final file = File(path);
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> createDirectory(String path) =>
      Directory(path).create(recursive: true);

  @override
  Future<void> writeNew(String path, String content) async {
    final file = await File(path).create(exclusive: true);
    try {
      await file.writeAsString(content, flush: true);
    } catch (_) {
      await file.delete();
      rethrow;
    }
  }

  @override
  Future<bool> replace(
    String path,
    String content, {
    required String? expected,
  }) async {
    final temporary = File(
      p.join(p.dirname(path), '.${const Uuid().v4()}.tmp'),
    );
    try {
      await temporary.writeAsString(content, flush: true);
      if (await read(path) != expected) return false;
      await temporary.rename(path);
      return true;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<void> delete(String path) => File(path).delete();

  @override
  Future<String> canonicalPath(String path) =>
      File(path).resolveSymbolicLinks();

  @override
  Stream<FileSystemEvent> watch(String path) => Directory(path).watch();
}
