import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;
import 'package:life_os/features/resources/data/obsidian_repository.dart';

abstract class GraphNoteType {
  static const String obsidian = 'obsidianNote';
  static const String graph = 'graphNote';
}

class GraphNotesRepository extends ChangeNotifier {
  GraphNotesRepository({
    required this.obsidianRepository,
    this.prefix = 'graph_notes',
  });

  final ObsidianRepository obsidianRepository;
  final String prefix;
  static const int _version = 1;

  final Map<String, List<gv.GraphNote>> _cache = {};
  bool _initialized = false;

  String _key(String sphereId) => '$prefix.$sphereId';

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('$prefix.'));

    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final sphereId = key.substring('$prefix.'.length);
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final notes = await _parseNotes(data);
        if (notes != null) _cache[sphereId] = notes;
      } catch (_) {}
    }
    _initialized = true;
  }

  List<gv.GraphNote> getAllNotes() {
    return _cache.values.expand((notes) => notes).toList();
  }

  List<gv.GraphNote> getNotes(String sphereId) {
    return _cache[sphereId] ?? [];
  }

  Future<List<gv.GraphNote>?> loadNotes(String sphereId) async {
    if (!_initialized) await init();
    return _cache[sphereId];
  }

  Future<void> saveNotes(String sphereId, List<gv.GraphNote> notes) async {
    final prefs = await SharedPreferences.getInstance();

    final serializedNotes = Map.fromIterables(
      notes.map((n) => n.id),
      notes.map((n) {
        final isObsidian = n.obsidianPath != null;
        final type = isObsidian ? GraphNoteType.obsidian : GraphNoteType.graph;

        final noteData = <String, dynamic>{
          'type': type,
          'x': n.position.dx,
          'y': n.position.dy,
          'w': n.size.width,
          'h': n.size.height,
          'index': n.index,
        };

        if (isObsidian) {
          noteData['obsidianPath'] = n.obsidianPath;
        } else {
          noteData['text'] = n.text;
        }

        return noteData;
      }),
    );

    await prefs.setString(_key(sphereId), jsonEncode({
      'v': _version,
      'notes': serializedNotes,
    }));

    _cache[sphereId] = List.from(notes);
    notifyListeners();
  }

  Future<void> deleteNotes(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(sphereId));

    _cache.remove(sphereId);
    notifyListeners();
  }

  /// Асинхронный парсинг с параллельной подгрузкой файлов Obsidian
  Future<List<gv.GraphNote>?> _parseNotes(Map<String, dynamic> data) async {
    if (data['v'] != _version) return null;
    final notes = data['notes'] as Map<String, dynamic>?;
    if (notes == null) return null;

    final parsedNotes = await Future.wait(
      notes.entries.map((entry) async {
        final map = entry.value as Map<String, dynamic>;
        final obsidianPath = map['obsidianPath'] as String?;

        final type = map['type'] as String? ??
            (obsidianPath != null ? GraphNoteType.obsidian : GraphNoteType.graph);

        final isObsidian = type == GraphNoteType.obsidian;

        String content = '';
        if (isObsidian && obsidianPath != null && obsidianPath.isNotEmpty) {
          // Считываем контент .md файла через ObsidianRepository
          content = await obsidianRepository.getNoteContent(obsidianPath);
        } else {
          content = map['text'] as String? ?? '';
        }

        return gv.GraphNote(
          id: entry.key,
          index: (map['index'] as num?)?.toInt() ?? 0,
          size: ui.Size(
            (map['w'] as num?)?.toDouble() ?? 212.0,
            (map['h'] as num?)?.toDouble() ?? 150.0,
          ),
          text: content,
          position: ui.Offset(
            (map['x'] as num?)?.toDouble() ?? 0.0,
            (map['y'] as num?)?.toDouble() ?? 0.0,
          ),
          obsidianPath: obsidianPath,
        );
      }),
    );

    return parsedNotes;
  }
}