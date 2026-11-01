import 'dart:async';
import 'dart:convert';
import 'package:notes_api/notes_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/core/storage/storage_exception.dart';

class GraphNotesRepository implements CanvasNotesStore, NotesCatalog {
  GraphNotesRepository({this.prefix = 'graph_notes'});
  final String prefix;
  final Map<String, List<CanvasNote>> _cache = {};
  final _changes = StreamController<List<NoteDocument>>.broadcast();
  Future<void>? _initialization;
  String _key(String sphereId) => '$prefix.$sphereId';

  Future<void> init() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith('$prefix.'),
    )) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['v'] != 1) continue;
        final entries = data['notes'] as Map<String, dynamic>;
        final loaded = <CanvasNote>[];
        for (final entry in entries.entries) {
          final value = entry.value as Map<String, dynamic>;
          final path = value['obsidianPath'] as String?;
          final sourceId = value['sourceId'] as String? ?? 'obsidian';
          loaded.add(
            CanvasNote(
              document: NoteDocument(
                id: entry.key,
                text: value['text'] as String? ?? '',
                source: path == null
                    ? null
                    : NoteReference(sourceId: sourceId, path: path),
              ),
              x: (value['x'] as num?)?.toDouble() ?? 0,
              y: (value['y'] as num?)?.toDouble() ?? 0,
              width: (value['w'] as num?)?.toDouble() ?? 212,
              height: (value['h'] as num?)?.toDouble() ?? 150,
              index: (value['index'] as num?)?.toInt() ?? 0,
            ),
          );
        }
        _cache[key.substring('$prefix.'.length)] = List.unmodifiable(loaded);
      } catch (_) {
        // Leave unknown/corrupt persisted snapshots untouched for recovery.
      }
    }
    _changes.add(notes);
  }

  @override
  List<NoteDocument> get notes => List.unmodifiable(
    _cache.values.expand((items) => items).map((item) => item.document),
  );

  @override
  Stream<List<NoteDocument>> watchNotes() => Stream.multi((listener) {
    listener.add(notes);
    final subscription = _changes.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  }, isBroadcast: true);

  @override
  Future<List<CanvasNote>?> loadNotes(String sphereId) async {
    await init();
    return _cache[sphereId];
  }

  @override
  Future<void> saveNotes(String sphereId, List<CanvasNote> values) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final serialized = {
      for (final value in values)
        value.id: {
          'type': value.document.source == null ? 'graphNote' : 'obsidianNote',
          'text': value.text,
          'x': value.x,
          'y': value.y,
          'w': value.width,
          'h': value.height,
          'index': value.index,
          if (value.document.source case final source?) ...{
            'obsidianPath': source.path,
            'sourceId': source.sourceId,
          },
        },
    };
    if (!await prefs.setString(
      _key(sphereId),
      jsonEncode({'v': 1, 'notes': serialized}),
    )) {
      throw StorageException('Failed to save graph notes.');
    }
    _cache[sphereId] = List.unmodifiable(values);
    _changes.add(notes);
  }

  @override
  Future<void> deleteNotes(String sphereId) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key(sphereId)))
      throw StorageException('Failed to delete graph notes.');
    _cache.remove(sphereId);
    _changes.add(notes);
  }

  Future<void> dispose() => _changes.close();
}
