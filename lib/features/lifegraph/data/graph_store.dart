import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:life_os/features/lifegraph/presentation/v1.dart' as graph;

/// Key-value хранилище на shared_preferences.
///
/// Каждый граф — отдельный ключ, список слотов хранится MRU-первым.
class PrefsGraphStore implements graph.GraphStore {
  final String prefix;

  const PrefsGraphStore({this.prefix = 'graphview'});

  String _key(String slot) => '$prefix.slot.$slot';
  String get _indexKey => '$prefix.index';

  @override
  Future<List<String>> slots() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_indexKey) ?? [])
        .where((s) => prefs.getString(_key(s)) != null)
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> load(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(slot));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null; // повреждённый снимок — начнём с чистого листа
    }
  }

  @override
  Future<void> save(String slot, Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(slot), jsonEncode(snapshot));
    final index = (prefs.getStringList(_indexKey) ?? [])
        .where((s) => s != slot)
        .toList()
      ..insert(0, slot);
    await prefs.setStringList(_indexKey, index);
  }

  @override
  Future<void> delete(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(slot));
    final index = (prefs.getStringList(_indexKey) ?? [])
        .where((s) => s != slot)
        .toList();
    await prefs.setStringList(_indexKey, index);
  }
}

/// Тот же контракт, но JSON-файл на слот в документах приложения.
class FileGraphStore implements graph.GraphStore {
  final String folder;

  const FileGraphStore({this.folder = 'graphs'});

  String _safe(String slot) => slot.replaceAll(RegExp(r'[^\w\- ]'), '_');

  Future<Directory> get _dir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$folder');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> _file(String slot) async =>
      File('${(await _dir).path}/${_safe(slot)}.json');

  @override
  Future<Map<String, dynamic>?> load(String slot) async {
    final f = await _file(slot);
    if (!f.existsSync()) return null;
    try {
      final data = jsonDecode(await f.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String slot, Map<String, dynamic> snapshot) async {
    final f = await _file(slot);
    await f.writeAsString(jsonEncode(snapshot), flush: true);
  }

  @override
  Future<List<String>> slots() async {
    final dir = await _dir;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return [
      for (final f in files)
        f.uri.pathSegments.last.replaceAll('.json', ''),
    ];
  }

  @override
  Future<void> delete(String slot) async {
    final f = await _file(slot);
    if (f.existsSync()) await f.delete();
  }
}
