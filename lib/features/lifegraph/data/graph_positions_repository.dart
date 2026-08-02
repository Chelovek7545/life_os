import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Хранилище позиций нод графа (layout) и последней открытой сферы.
///
/// Каждый граф (сфера) — отдельный ключ со снимком:
/// `{ "v": 1, "entities": { "entityId": {"x": 100.0, "y": 200.0} } }`.
class GraphPositionsRepository {
  GraphPositionsRepository({this.prefix = 'graph_positions'});

  final String prefix;

  static const int _version = 1;
  static const String _lastSphereKey = 'life_graph.last_sphere';

  String _key(String sphereId) => '$prefix.$sphereId';

  /// Загружает позиции для графа (сферы).
  /// Возвращает null, если позиций ещё нет.
  Future<Map<String, Offset>?> loadPositions(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sphereId));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['v'] != _version) return null;
      final entities = data['entities'] as Map<String, dynamic>?;
      if (entities == null) return null;
      return entities.map((id, value) {
        final map = value as Map<String, dynamic>;
        return MapEntry(id, Offset(
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
        ));
      });
    } catch (_) {
      return null;
    }
  }

  /// Сохраняет позиции для графа.
  Future<void> savePositions(String sphereId, Map<String, Offset> positions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(sphereId), jsonEncode({
      'v': _version,
      'entities': positions.map((id, offset) => MapEntry(id, {
        'x': offset.dx,
        'y': offset.dy,
      })),
    }));
  }

  /// Удаляет позиции графа (например, при удалении сферы).
  Future<void> deletePositions(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(sphereId));
  }

  // ── App-state (не слот графа): какая сфера открыта последней ─────────────

  Future<String?> loadLastSphereId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSphereKey);
  }

  Future<void> saveLastSphereId(String sphereId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSphereKey, sphereId);
  }
}
