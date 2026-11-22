import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lifegraph_plugin/graph_storage_settings.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:path/path.dart' as p;

class AndroidGraphFiles extends LocalVaultFiles {
  const AndroidGraphFiles();

  static const _picker = MethodChannel('pulse/graph_folder_picker');
  static const _channel = MethodChannel('pulse/graph_files');
  static const _root = '/.pulse-android-folder';

  static String displayPath(String path) {
    if (!p.isWithin(_root, path)) return path;
    final parts = p.split(p.relative(path, from: _root));
    try {
      final uri = Uri.parse(utf8.decode(base64Url.decode(parts.first)));
      final documentId = uri.pathSegments.last;
      final directory = documentId.substring(documentId.indexOf(':') + 1);
      return p.joinAll([directory, ...parts.skip(1)]);
    } on FormatException {
      return path;
    }
  }

  static Future<GraphStorageTarget?> pickFolder() async {
    final folder = await _picker.invokeMapMethod<String, String>('pickFolder');
    if (folder == null) return null;
    final id = base64Url.encode(utf8.encode(folder['uri']!));
    return GraphStorageTarget(
      mode: GraphStorageMode.sharedFolder,
      localPath: p.join(_root, id),
      folderName: folder['name']!,
    );
  }

  bool _isShared(String path) => p.isWithin(_root, path);

  Future<T?> _invoke<T>(
    String method,
    String path, [
    Map<String, Object?>? arguments,
  ]) async {
    final parts = p.split(p.relative(path, from: _root));
    try {
      return await _channel.invokeMethod<T>(method, {
        'tree': utf8.decode(base64Url.decode(parts.first)),
        'parts': parts.sublist(1),
        ...?arguments,
      });
    } on PlatformException catch (error) {
      throw FileSystemException(
        error.message ?? 'Ошибка доступа к выбранной папке',
        path,
      );
    }
  }

  FileSystemEntityType _type(String? value) => switch (value) {
    'file' => FileSystemEntityType.file,
    'directory' => FileSystemEntityType.directory,
    _ => FileSystemEntityType.notFound,
  };

  @override
  Future<FileSystemEntityType> type(
    String path, {
    bool followLinks = true,
  }) async => _isShared(path)
      ? _type(await _invoke<String>('type', path))
      : super.type(path, followLinks: followLinks);

  @override
  Future<List<VaultEntry>> list(String path) async {
    if (!_isShared(path)) return super.list(path);
    final entries = await _invoke<List<Object?>>('list', path);
    return [
      for (final entry in entries!.cast<Map<Object?, Object?>>())
        (
          name: entry['name']! as String,
          type: _type(entry['type'] as String?),
          modifiedAt: DateTime.fromMillisecondsSinceEpoch(
            entry['modifiedAt']! as int,
          ),
        ),
    ];
  }

  @override
  Future<String?> read(String path) =>
      _isShared(path) ? _invoke<String>('read', path) : super.read(path);

  @override
  Future<void> createDirectory(String path) => _isShared(path)
      ? _invoke<void>('createDirectory', path)
      : super.createDirectory(path);

  @override
  Future<void> writeNew(String path, String content) => _isShared(path)
      ? _invoke<void>('writeNew', path, {'content': content})
      : super.writeNew(path, content);

  @override
  Future<bool> replace(
    String path,
    String content, {
    required String? expected,
  }) async => _isShared(path)
      ? (await _invoke<bool>('replace', path, {
          'content': content,
          'expected': expected,
        }))!
      : super.replace(path, content, expected: expected);

  @override
  Future<void> delete(String path) =>
      _isShared(path) ? _invoke<void>('delete', path) : super.delete(path);

  @override
  Future<String> canonicalPath(String path) async =>
      _isShared(path) ? p.normalize(path) : super.canonicalPath(path);

  @override
  Stream<FileSystemEvent> watch(String path) =>
      _isShared(path) ? const Stream.empty() : super.watch(path);
}
