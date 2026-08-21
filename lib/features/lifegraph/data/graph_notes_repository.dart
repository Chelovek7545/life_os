import 'dart:convert';
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;

/// Хранилище заметок графа (стикеры) в SharedPreferences.
///
/// Каждый граф (сфера) — отдельный ключ со снимком:
/// `{ "v": 1, "notes": { "noteId": {"x": 100.0, "y": 200.0, "w": 212, "h": 150, "text": "..."} } }`.
class GraphNotesRepository {
  GraphNotesRepository({this.prefix = 'graph_notes'});

  final String prefix;

  static const int _version = 1;

  String _key(String sphereId) => '$prefix.$sphereId';

  /// Загружает заметки для графа (сферы).
  /// Возвращает null, если заметок ещё нет.
  Future<List<gv.GraphNote>?> loadNotes(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sphereId));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['v'] != _version) return null;
      final notes = data['notes'] as Map<String, dynamic>?;
      if (notes == null) return null;
      return notes.entries.map((entry) {
        final map = entry.value as Map<String, dynamic>;
        return gv.GraphNote(
          id: entry.key,
          index: (map['index'] as num?)?.toInt() ?? 0,
          size: ui.Size(
            (map['w'] as num?)?.toDouble() ?? 212.0,
            (map['h'] as num?)?.toDouble() ?? 150.0,
          ),
          text: map['text'] as String? ?? '',
          position: ui.Offset(
            (map['x'] as num?)?.toDouble() ?? 0.0,
            (map['y'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Сохраняет заметки для графа.
  Future<void> saveNotes(String sphereId, List<gv.GraphNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(sphereId), jsonEncode({
      'v': _version,
      'notes': Map.fromIterables(
        notes.map((n) => n.id),
        notes.map((n) => {
          'x': n.position.dx,
          'y': n.position.dy,
          'w': n.size.width,
          'h': n.size.height,
          'text': n.text,
          'index': n.index,
        }),
      ),
    }));
  }

  /// Удаляет заметки графа (например, при удалении сферы).
  Future<void> deleteNotes(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(sphereId));
  }
}