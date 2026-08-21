import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'; // для ChangeNotifier
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as gv;

/// Хранилище заметок графа (стикеры) в SharedPreferences.
///
/// Каждый граф (сфера) — отдельный ключ со снимком:
/// `{ "v": 1, "notes": { "noteId": {"x": 100.0, "y": 200.0, "w": 212, "h": 150, "text": "..."} } }`.
class GraphNotesRepository extends ChangeNotifier {
  GraphNotesRepository({this.prefix = 'graph_notes'});

  final String prefix;
  static const int _version = 1;

  /// Кэш всех заметок в памяти: Map<sphereId, List<Note>>
  final Map<String, List<gv.GraphNote>> _cache = {};
  bool _initialized = false;

  String _key(String sphereId) => '$prefix.$sphereId';

  /// Инициализация: загружает весь кэш из SharedPreferences.
  /// Должна быть вызвана один раз при старте приложения.
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
        final notes = _parseNotes(data);
        if (notes != null) _cache[sphereId] = notes;
      } catch (_) {
        // повреждённая запись — пропускаем
      }
    }
    _initialized = true;
  }

  /// Синхронное получение всех заметок из кэша.
  List<gv.GraphNote> getAllNotes() {
    return _cache.values.expand((notes) => notes).toList();
  }

  /// Синхронное получение заметок конкретной сферы.
  List<gv.GraphNote> getNotes(String sphereId) {
    return _cache[sphereId] ?? [];
  }

  Future<List<gv.GraphNote>?> loadNotes(String sphereId) async {
    if (!_initialized) await init();
    return _cache[sphereId];
  }

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

    // Обновляем кэш и уведомляем всех слушателей
    _cache[sphereId] = List.from(notes);
    notifyListeners();
  }

  Future<void> deleteNotes(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(sphereId));

    _cache.remove(sphereId);
    notifyListeners();
  }

  List<gv.GraphNote>? _parseNotes(Map<String, dynamic> data) {
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
  }
}